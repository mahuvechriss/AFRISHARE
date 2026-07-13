import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/device_model.dart';
import 'discovery_service.dart';

/// Service managing QR code generation and scanning for device pairing
class QRService {
  QRService._();
  static final QRService instance = QRService._();

  final DiscoveryService _discoveryService = DiscoveryService.instance;

  /// Generate QR code data for pairing
  Future<String> generatePairingData(String deviceId, String deviceName) async {
    return await _discoveryService.generateQRPairingData(deviceId, deviceName);
  }

  /// Parse QR code data from scanning
  Map<String, dynamic>? parseQRData(String qrData) {
    return _discoveryService.parseQRPairingData(qrData);
  }

  /// Generate QR code widget for display
  Widget generateQRWidget({
    required String data,
    double size = 200,
    Color? color,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: QrImageView(
          data: data,
          version: QrVersions.auto,
          size: size,
          backgroundColor: Colors.white,
          eyeStyle: QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: color ?? Colors.black,
          ),
          dataModuleStyle: QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: color ?? Colors.black,
          ),
        ),
      ),
    );
  }

  /// Process scanned QR code data
  Future<Map<String, dynamic>?> processScannedCode(String qrData) async {
    final data = parseQRData(qrData);
    if (data == null) return null;

    // Create device from QR data with IP/port for HTTP connection
    final device = DeviceModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: data['device_name'] as String? ?? 'Unknown Device',
      deviceId: data['device_id'] as String? ?? '',
      deviceType: DeviceType.android,
      status: DeviceStatus.connecting,
      lastSeen: DateTime.now(),
      isPaired: false,
      isBlocked: false,
      isHidden: false,
      ipAddress: data['ip'] as String?,
      port: data['port'] as int?,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Add to discovered devices
    _discoveryService.addDevice(device);

    return data;
  }

  /// Update QR code data (for auto-refresh)
  Future<String> refreshQRData(String deviceId, String deviceName) async {
    return await generatePairingData(deviceId, deviceName);
  }
}
