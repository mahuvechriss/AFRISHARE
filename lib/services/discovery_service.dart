import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/device_model.dart';
import '../core/constants/app_constants.dart';
import 'nearby_connector.dart';
import 'http_transfer_service.dart';

/// Service to manage nearby device discovery
/// Uses nearby_connections package for actual peer-to-peer discovery
/// with Wi-Fi Direct and Nearby Connections API.
/// Falls back to simulated discovery when platform doesn't support it.
class DiscoveryService {
  DiscoveryService._();
  static final DiscoveryService instance = DiscoveryService._();

  final Uuid _uuid = const Uuid();
  late final NearbyConnector _connector = NearbyConnector.instance;
  final List<DeviceModel> _discoveredDevices = [];
  bool _isDiscovering = false;
  bool _useSimulated = false;

  Future<void> Function(DeviceModel device)? onDeviceDiscovered;
  void Function(String deviceId)? onDeviceLost;
  void Function(DeviceModel device)? onDeviceUpdated;

  List<DeviceModel> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  bool get isDiscovering => _isDiscovering;

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;

    // Try real discovery first
    final started = await _connector.startDiscovery();
    if (!started) {
      // Fall back to simulated discovery
      _useSimulated = true;
      _startSimulatedDiscovery();
    }
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    if (_useSimulated) {
      _stopSimulatedDiscovery();
    } else {
      await _connector.stopDiscovery();
    }
  }

  Future<void> searchForDevices() async {
    await stopDiscovery();
    _discoveredDevices.clear();
    await startDiscovery();
  }

  /// Simulated discovery fallback for development/testing
  Timer? _simulatedTimer;

  void _startSimulatedDiscovery() {
    _simulatedTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.discoveryIntervalMs),
      (_) => _scanForDevices(),
    );
  }

  void _stopSimulatedDiscovery() {
    _simulatedTimer?.cancel();
    _simulatedTimer = null;
  }

  void _scanForDevices() {
    // Simulated discovery stub
  }

  void addDevice(DeviceModel device) {
    final existingIndex = _discoveredDevices.indexWhere(
      (d) => d.deviceId == device.deviceId,
    );
    if (existingIndex >= 0) {
      _discoveredDevices[existingIndex] = device;
      onDeviceUpdated?.call(device);
    } else {
      _discoveredDevices.add(device);
      onDeviceDiscovered?.call(device);
    }
  }

  void removeDevice(String deviceId) {
    _discoveredDevices.removeWhere((d) => d.deviceId == deviceId);
    onDeviceLost?.call(deviceId);
  }

  DeviceModel? getDeviceByDeviceId(String deviceId) {
    try {
      return _discoveredDevices.firstWhere((d) => d.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  DeviceModel? getDeviceByIp(String ipAddress) {
    try {
      return _discoveredDevices.firstWhere((d) => d.ipAddress == ipAddress);
    } catch (_) {
      return null;
    }
  }

  void updateDeviceStatus(String deviceId, DeviceStatus status) {
    final device = getDeviceByDeviceId(deviceId);
    if (device != null) {
      final updated = device.copyWith(status: status, lastSeen: DateTime.now());
      final index = _discoveredDevices.indexWhere(
        (d) => d.deviceId == deviceId,
      );
      if (index >= 0) {
        _discoveredDevices[index] = updated;
        onDeviceUpdated?.call(updated);
      }
    }
  }

  void updateDeviceIp(String deviceId, String ipAddress, int port) {
    final index = _discoveredDevices.indexWhere((d) => d.deviceId == deviceId);
    if (index >= 0) {
      _discoveredDevices[index] = _discoveredDevices[index].copyWith(
        ipAddress: ipAddress,
        port: port,
        status: DeviceStatus.online,
      );
      onDeviceUpdated?.call(_discoveredDevices[index]);
    }
  }

  void pairDevice(String deviceId) {
    final existing = getDeviceByDeviceId(deviceId);
    if (existing != null) {
      final index = _discoveredDevices.indexWhere(
        (d) => d.deviceId == deviceId,
      );
      if (index >= 0) {
        _discoveredDevices[index] = existing.copyWith(
          status: DeviceStatus.paired,
          isPaired: true,
        );
        onDeviceUpdated?.call(_discoveredDevices[index]);
      }
    }
  }

  void blockDevice(String deviceId) {
    final device = getDeviceByDeviceId(deviceId);
    if (device != null) {
      final index = _discoveredDevices.indexWhere(
        (d) => d.deviceId == deviceId,
      );
      if (index >= 0) {
        _discoveredDevices[index] = device.copyWith(isBlocked: true);
      }
    }
  }

  Future<String> generateQRPairingData(
    String deviceId,
    String deviceName,
  ) async {
    final connector = NearbyConnector.instance;
    String? ip = connector.localIp;

    // If IP not resolved yet, try to resolve it
    if (ip == null || ip.isEmpty) {
      ip = await HttpTransferService.instance.resolveLocalIp();
    }

    // Fallback to a default if still null
    ip ??= '0.0.0.0';

    debugPrint(
      'Discovery: QR pairing IP resolved to $ip (port ${connector.httpPort})',
    );

    final data = {
      'type': 'afrishare_pairing',
      'device_id': deviceId,
      'device_name': deviceName,
      'ip': ip,
      'port': connector.httpPort,
      'version': AppConstants.appVersion,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  Map<String, dynamic>? parseQRPairingData(String qrData) {
    try {
      final data = jsonDecode(qrData) as Map<String, dynamic>;
      if (data['type'] == 'afrishare_pairing') {
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void addDeviceByIp(String ipAddress, int port, String name) {
    final existing = getDeviceByIp(ipAddress);
    if (existing != null) return;

    // Use a deterministic device ID derived from IP so re-pairing uses the same ID
    final deviceId = 'manual_${ipAddress.replaceAll('.', '_')}';

    final device = DeviceModel(
      id: _uuid.v4(),
      name: name,
      deviceId: deviceId,
      deviceType: DeviceType.android,
      status: DeviceStatus.online,
      lastSeen: DateTime.now(),
      isPaired: true,
      isBlocked: false,
      isHidden: false,
      ipAddress: ipAddress,
      port: port,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    addDevice(device);
  }

  DeviceModel createSimulatedDevice(String name) {
    return DeviceModel(
      id: _uuid.v4(),
      name: name,
      deviceId: 'device_${_uuid.v4().substring(0, 8)}',
      deviceType: DeviceType.android,
      status: DeviceStatus.online,
      lastSeen: DateTime.now(),
      isPaired: false,
      isBlocked: false,
      isHidden: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      signalStrength: 0,
    );
  }

  bool _isHidden = false;

  bool get isHidden => _isHidden;

  void dispose() {
    stopDiscovery();
    _discoveredDevices.clear();
  }

  Future<void> setDeviceHidden(bool hidden) async {
    _isHidden = hidden;
    if (hidden) {
      await stopDiscovery();
    } else {
      await startDiscovery();
    }
  }

  Future<void> setDiscoveryEnabled(bool enabled) async {
    if (enabled && !_isHidden) {
      await startDiscovery();
    } else {
      await stopDiscovery();
    }
  }
}
