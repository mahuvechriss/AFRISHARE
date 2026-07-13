import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/device_model.dart';
import '../core/constants/app_constants.dart';
import 'discovery_service.dart';

class NetworkDiscoveryService {
  NetworkDiscoveryService._();
  static final NetworkDiscoveryService instance = NetworkDiscoveryService._();

  final Uuid _uuid = const Uuid();
  final DiscoveryService _discoveryService = DiscoveryService.instance;

  RawDatagramSocket? _socket;
  bool _isRunning = false;
  Timer? _broadcastTimer;
  Timer? _rebindTimer;
  String _deviceName = 'AfriShare Device';
  String _deviceId = '';
  final Set<String> _localIps = {};

  static const int _discoveryPort = AppConstants.discoveryPort;
  static const String _discoveryMagic = 'AFRISHARE_DISCOVER';

  bool get isRunning => _isRunning;

  void initialize({String? deviceName, String? deviceId}) {
    _deviceName = deviceName ?? 'AfriShare Device';
    _deviceId = deviceId ?? _uuid.v4();
  }

  Future<List<String>> _getBroadcastAddresses() async {
    final addrs = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          addrs.addAll(_broadcastForIp(ip));
        }
      }
    } catch (_) {
      // If enumeration fails, try common hotspot subnets
      addrs.addAll([
        '192.168.43.255',
        '192.168.44.255',
        '192.168.42.255',
        '192.168.0.255',
        '192.168.1.255',
        '10.0.0.255',
      ]);
    }
    return addrs.toSet().toList();
  }

  List<String> _broadcastForIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return [];

    // Generate broadcast address for standard private subnets
    if (ip.startsWith('192.168.')) {
      parts[3] = '255';
      return [parts.join('.')];
    } else if (ip.startsWith('10.')) {
      parts[3] = '255';
      return [parts.join('.')];
    } else if (ip.startsWith('172.')) {
      parts[3] = '255';
      return [parts.join('.')];
    }

    return [];
  }

  Future<void> startDiscovery() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      // Collect own IPs to filter out self-discovered devices
      _localIps.clear();
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            _localIps.add(addr.address);
          }
        }
      } catch (_) {}

      await _bindSocket();

      final addrs = await _getBroadcastAddresses();
      _broadcastTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _broadcastPresence(),
      );

      // Periodically rebind socket to handle network changes
      _rebindTimer = Timer.periodic(
        const Duration(seconds: 60),
        (_) async {
          if (_isRunning) {
            await _rebindSocket();
          }
        },
      );

      _broadcastPresence();
      debugPrint(
        'NetworkDiscovery: Started on port $_discoveryPort, ${addrs.length} broadcast addresses',
      );
    } catch (e) {
      debugPrint('NetworkDiscovery: Failed to start: $e');
      _isRunning = false;
    }
  }

  Future<void> _bindSocket() async {
    try {
      _socket?.close();
    } catch (_) {}
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
    } catch (e) {
      // reusePort not supported on all Android kernels — retry without it
      debugPrint('NetworkDiscovery: reusePort not supported, retrying without it: $e');
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
      );
    }
    _socket!.broadcastEnabled = true;
    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final packet = _socket!.receive();
        if (packet != null) {
          _handleDiscoveryPacket(packet.data, packet.address.address);
        }
      }
    });
  }

  Future<void> _rebindSocket() async {
    try {
      await _bindSocket();
      debugPrint('NetworkDiscovery: Socket rebound for network change resilience');
    } catch (e) {
      debugPrint('NetworkDiscovery: Socket rebind failed: $e');
    }
  }

  /// Update the device name used in broadcast packets
  void updateDeviceName(String name) {
    _deviceName = name;
  }

  Future<void> stopDiscovery() async {
    _isRunning = false;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _rebindTimer?.cancel();
    _rebindTimer = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    debugPrint('NetworkDiscovery: Stopped');
  }

  void _broadcastPresence() {
    final message = jsonEncode({
      'magic': _discoveryMagic,
      'device_id': _deviceId,
      'device_name': _deviceName,
      'version': AppConstants.appVersion,
      'timestamp': DateTime.now().toIso8601String(),
    });

    final data = utf8.encode(message);

    _getBroadcastAddresses().then((addrs) {
      for (final addr in addrs) {
        if (addr == '0.0.0.0' || addr.isEmpty) continue;
        try {
          _socket?.send(data, InternetAddress(addr), _discoveryPort);
        } catch (_) {}
      }
    }).catchError((_) {});
  }

  void _handleDiscoveryPacket(List<int> data, String sourceAddress) {
    try {
      // Ignore own broadcast reflected back (same device on another interface)
      if (_localIps.contains(sourceAddress)) return;

      final message = utf8.decode(data);
      final json = jsonDecode(message) as Map<String, dynamic>;

      if (json['magic'] != _discoveryMagic) return;

      final remoteDeviceId = json['device_id'] as String?;
      if (remoteDeviceId == null || remoteDeviceId == _deviceId) return;

      final remoteName = json['device_name'] as String? ?? 'Unknown Device';

      final device = DeviceModel(
        id: _uuid.v4(),
        name: remoteName,
        deviceId: remoteDeviceId,
        deviceType: DeviceType.android,
        status: DeviceStatus.online,
        lastSeen: DateTime.now(),
        isPaired: false,
        isBlocked: false,
        isHidden: false,
        ipAddress: sourceAddress,
        port: AppConstants.discoveryPort,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        signalStrength: 60,
      );

      _discoveryService.addDevice(device);
      debugPrint(
        'NetworkDiscovery: Found device $remoteName at $sourceAddress',
      );
    } catch (e) {
      debugPrint('NetworkDiscovery: Error parsing packet: $e');
    }
  }

  Future<void> dispose() async {
    await stopDiscovery();
  }
}
