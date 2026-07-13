import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import 'http_transfer_service.dart';
import 'nearby_connector.dart';

enum TransportMode { http, wifiDirect, hotspot, automatic }

class TransportManager {
  TransportManager._();
  static final TransportManager instance = TransportManager._();

  final HttpTransferService _httpTransfer = HttpTransferService.instance;
  final NearbyConnector _nearby = NearbyConnector.instance;

  TransportMode _mode = TransportMode.automatic;
  TransportMode get mode => _mode;

  void Function(TransportMode mode)? onTransportSwitched;

  void initialize() {
    _detectBestTransport();
  }

  Future<TransportMode> _detectBestTransport() async {
    try {
      if (Platform.isAndroid) {
        _mode = TransportMode.wifiDirect;
      } else if (Platform.isIOS) {
        _mode = TransportMode.wifiDirect;
      } else {
        _mode = TransportMode.http;
      }
    } catch (_) {
      _mode = TransportMode.http;
    }

    debugPrint('TransportManager: Using $_mode mode');
    return _mode;
  }

  Future<void> switchToMode(TransportMode mode) async {
    if (mode == _mode) return;

    switch (mode) {
      case TransportMode.http:
      case TransportMode.hotspot:
        await _nearby.stopAdvertising();
        await _nearby.startAdvertising();
        break;
      case TransportMode.wifiDirect:
        break;
      case TransportMode.automatic:
        await _detectBestTransport();
        break;
    }

    _mode = mode;
    onTransportSwitched?.call(mode);
    debugPrint('TransportManager: Switched to $mode');
  }

  Future<bool> isWifiDirectAvailable() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    return _nearby.isNativeAvailable;
  }

  Future<bool> isHotspotActive() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.43.')) {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  String? get localIp => _httpTransfer.localIp;
  int get port => _httpTransfer.port;

  Future<Map<String, dynamic>> sendFile({
    required String host,
    int port = AppConstants.discoveryPort,
    required String filePath,
    required String fileName,
    String? receiverId,
    String? receiverName,
  }) async {
    return await _httpTransfer.sendFile(
      host: host,
      port: port,
      filePath: filePath,
      fileName: fileName,
      receiverId: receiverId,
      receiverName: receiverName,
    );
  }

  Future<Map<String, dynamic>> testConnection(String host,
      {int port = AppConstants.discoveryPort}) async {
    return await _httpTransfer.testConnection(host, port: port);
  }

  Future<bool> requestTransfer({
    required String host,
    int port = AppConstants.discoveryPort,
    required List<String> fileNames,
    required List<int> fileSizes,
  }) async {
    return await _httpTransfer.requestTransfer(
      host: host,
      port: port,
      fileNames: fileNames,
      fileSizes: fileSizes,
    );
  }

  String getCurrentModeLabel() {
    switch (_mode) {
      case TransportMode.http:
        return 'HTTP (Local WiFi)';
      case TransportMode.wifiDirect:
        return 'Wi-Fi Direct';
      case TransportMode.hotspot:
        return 'Hotspot Mode';
      case TransportMode.automatic:
        return 'Auto Detect';
    }
  }

  void dispose() {}
}
