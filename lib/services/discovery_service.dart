import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/device_model.dart';
import '../core/constants/app_constants.dart';
import 'nearby_connector.dart';

/// Service to manage nearby device discovery
/// Uses nearby_connections package for actual peer-to-peer discovery
/// with Wi-Fi Direct and Nearby Connections API.
/// Falls back to simulated discovery when platform doesn't support it.
class DiscoveryService {
  DiscoveryService._();
  static final DiscoveryService instance = DiscoveryService._();

  final Uuid _uuid = const Uuid();
  final NearbyConnector _connector = NearbyConnector.instance;
  final List<DeviceModel> _discoveredDevices = [];
  bool _isDiscovering = false;
  bool _useSimulated = false;

  // Callbacks
  void Function(DeviceModel device)? onDeviceDiscovered;
  void Function(String deviceId)? onDeviceLost;
  void Function(DeviceModel device)? onDeviceUpdated;

  List<DeviceModel> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);
  bool get isDiscovering => _isDiscovering;

  /// Start discovering nearby devices using Nearby Connections
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    _isDiscovering = true;

    // Try real Nearby Connections first
    final started = await _connector.startDiscovery();
    if (!started) {
      // Fall back to simulated discovery
      _useSimulated = true;
      _startSimulatedDiscovery();
    }
  }

  /// Stop discovering devices
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    if (_useSimulated) {
      _stopSimulatedDiscovery();
    } else {
      await _connector.stopDiscovery();
    }
  }

  /// Manual device search
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

  /// Add a discovered device
  void addDevice(DeviceModel device) {
    final existingIndex =
        _discoveredDevices.indexWhere((d) => d.deviceId == device.deviceId);
    if (existingIndex >= 0) {
      _discoveredDevices[existingIndex] = device;
      onDeviceUpdated?.call(device);
    } else {
      _discoveredDevices.add(device);
      onDeviceDiscovered?.call(device);
    }
  }

  /// Remove a device (lost connection)
  void removeDevice(String deviceId) {
    _discoveredDevices.removeWhere((d) => d.deviceId == deviceId);
    onDeviceLost?.call(deviceId);
  }

  /// Get device by device ID
  DeviceModel? getDeviceByDeviceId(String deviceId) {
    try {
      return _discoveredDevices.firstWhere((d) => d.deviceId == deviceId);
    } catch (_) {
      return null;
    }
  }

  /// Update device status
  void updateDeviceStatus(String deviceId, DeviceStatus status) {
    final device = getDeviceByDeviceId(deviceId);
    if (device != null) {
      final updated = device.copyWith(
        status: status,
        lastSeen: DateTime.now(),
      );
      final index = _discoveredDevices.indexWhere((d) => d.deviceId == deviceId);
      if (index >= 0) {
        _discoveredDevices[index] = updated;
        onDeviceUpdated?.call(updated);
      }
    }
  }

  /// Pair with a device
  void pairDevice(String deviceId) {
    updateDeviceStatus(deviceId, DeviceStatus.paired);
    final device = getDeviceByDeviceId(deviceId);
    if (device != null) {
      final index = _discoveredDevices.indexWhere((d) => d.deviceId == deviceId);
      if (index >= 0) {
        _discoveredDevices[index] = device.copyWith(isPaired: true);
      }
    }
  }

  /// Block a device
  void blockDevice(String deviceId) {
    final device = getDeviceByDeviceId(deviceId);
    if (device != null) {
      final index = _discoveredDevices.indexWhere((d) => d.deviceId == deviceId);
      if (index >= 0) {
        _discoveredDevices[index] = device.copyWith(isBlocked: true);
      }
    }
  }

  /// Generate QR code data for pairing
  String generateQRPairingData(String deviceId, String deviceName) {
    final data = {
      'type': 'afrishare_pairing',
      'device_id': deviceId,
      'device_name': deviceName,
      'version': AppConstants.appVersion,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return jsonEncode(data);
  }

  /// Parse QR code pairing data
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

  /// Create a simulated device for testing
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

  /// Clean up
  void dispose() {
    stopDiscovery();
    _discoveredDevices.clear();
  }

  /// Hide/unhide current device
  Future<void> setDeviceHidden(bool hidden) async {
    // In production, this would update the discovery advertisement
    // to not broadcast the device's presence
  }

  /// Enable/disable discovery
  Future<void> setDiscoveryEnabled(bool enabled) async {
    if (enabled) {
      await startDiscovery();
    } else {
      await stopDiscovery();
    }
  }
}
