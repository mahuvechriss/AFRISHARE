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
  String generatePairingData(String deviceId, String deviceName) {
    return _discoveryService.generateQRPairingData(deviceId, deviceName);
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
    return QrImageView(
      data: data,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      eyeStyle: QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: color ?? Colors.green.shade700,
      ),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: color ?? Colors.green.shade700,
      ),
    );
  }

  /// Process scanned QR code data
  Future<Map<String, dynamic>?> processScannedCode(String qrData) async {
    final data = parseQRData(qrData);
    if (data == null) return null;

    // Create device from QR data
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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Add to discovered devices
    _discoveryService.addDevice(device);

    return data;
  }

  /// Update QR code data (for auto-refresh)
  String refreshQRData(String deviceId, String deviceName) {
    return generatePairingData(deviceId, deviceName);
  }
}
