import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../services/qr_service.dart';
import '../../services/nearby_connector.dart';
import '../../services/discovery_service.dart';
import '../../services/http_transfer_service.dart';
import '../../services/encryption_service.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/transfer/transfer_cycle_indicator.dart';
import 'cloud_receive_screen.dart';

class ReceiveScreen extends StatefulWidget {
  final bool startScanning;
  const ReceiveScreen({super.key, this.startScanning = false});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final QRService _qrService = QRService.instance;
  final NearbyConnector _connector = NearbyConnector.instance;
  final DiscoveryService _discoveryService = DiscoveryService.instance;
  final HttpTransferService _httpTransfer = HttpTransferService.instance;
  bool _isScanning = false;
  bool _serverStarted = false;

  @override
  void initState() {
    super.initState();
    _startServerAutomatically();
    if (widget.startScanning) {
      Future.microtask(() => setState(() => _isScanning = true));
    }
  }

  Future<void> _startServerAutomatically() async {
    await _connector.startAdvertising();
    if (mounted) {
      setState(() => _serverStarted = _connector.isHttpServerRunning);
    }
  }

  Future<void> _toggleServer() async {
    if (_serverStarted) {
      await _connector.stopAdvertising();
    } else {
      await _connector.startAdvertising();
    }
    if (mounted) {
      setState(() => _serverStarted = _connector.isHttpServerRunning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Illustration / Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.blueGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.download_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Ready to Receive',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Files sent to you will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),

            // Active Transfer Cycle
            const TransferCycleIndicator(),

            // Server Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _serverStarted
                      ? AppColors.primaryGreen
                      : isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade200,
                  width: _serverStarted ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _serverStarted
                              ? AppColors.primaryGreenSurface
                              : Colors.grey.shade100,
                        ),
                        child: Icon(
                          _serverStarted
                              ? Icons.wifi_rounded
                              : Icons.wifi_off_rounded,
                          color: _serverStarted
                              ? AppColors.primaryGreen
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _serverStarted
                                  ? 'Receiving Server Active'
                                  : 'Receiving Server Off',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: _serverStarted
                                    ? AppColors.primaryGreen
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _serverStarted
                                  ? 'Listening on ${_connector.localIp ?? "..."}:${_connector.httpPort}'
                                  : 'Start the server to receive files',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _serverStarted,
                        onChanged: (_) => _toggleServer(),
                        activeTrackColor: AppColors.primaryGreen,
                      ),
                    ],
                  ),
                  if (_serverStarted && _connector.localIp != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreenSurface.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your IP: ${_connector.localIp}\n'
                              'Share this with the sender or scan their QR code',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // QR Scanner Section
            if (_isScanning) ...[
              Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBlue, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: MobileScanner(
                  onDetect: (capture) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final barcode = capture.barcodes.firstOrNull;
                      if (barcode?.rawValue == null) return;

                      final rawData = barcode!.rawValue!;
                      final parsed = await _qrService.processScannedCode(
                        rawData,
                      );

                      // Validate: must have device_id and ip
                      if (parsed == null ||
                          (parsed['device_id'] as String? ?? '').isEmpty ||
                          parsed['ip'] == null) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Invalid QR code — not an AfriShare pairing code',
                              ),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                        setState(() => _isScanning = false);
                        return;
                      }

                      final remoteDeviceId = parsed['device_id'] as String;
                      final remoteIp = parsed['ip'] as String;
                      final remotePort = parsed['port'] as int?;

                      // Pair locally
                      _discoveryService.pairDevice(remoteDeviceId);

                      // Send pair request back to sender so they pair us too
                      // and exchange encryption keys
                      final thisDeviceId = _httpTransfer.deviceId;
                      final thisDeviceName = _httpTransfer.deviceName;
                      final enc = EncryptionService.instance;
                      final paired = await _httpTransfer
                          .sendPairRequest(remoteIp, {
                            'device_id': thisDeviceId,
                            'device_name': thisDeviceName,
                            'ip': _connector.localIp,
                            'port': _connector.httpPort,
                            'encryption_key': enc.currentKey,
                            'encryption_iv': enc.currentIv,
                          }, port: remotePort);

                      setState(() => _isScanning = false);
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              paired
                                  ? 'Device paired successfully!'
                                  : 'QR scanned but could not reach sender — ensure both devices are on the same network',
                            ),
                            backgroundColor: paired
                                ? AppColors.success
                                : AppColors.warning,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint('ReceiveScreen: QR scan error: $e');
                      setState(() => _isScanning = false);
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Error processing QR code. Please try again.',
                            ),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: 'Cancel Scanning',
                isOutlined: true,
                onPressed: () => setState(() => _isScanning = false),
              ),
            ] else ...[
              AppButton(
                text: 'Scan QR Code',
                icon: Icons.qr_code_scanner,
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final status = await Permission.camera.request();
                  if (status.isGranted && mounted) {
                    setState(() => _isScanning = true);
                  } else if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Camera permission is required to scan QR codes',
                        ),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),

              // Auto-Receive Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreenSurface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.autorenew_rounded,
                            color: AppColors.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Auto-Receive Mode',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Automatically accept files',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _httpTransfer.autoAcceptTransfers,
                          onChanged: (value) {
                            setState(() {
                              _httpTransfer.autoAcceptTransfers = value;
                            });
                          },
                          activeTrackColor: AppColors.primaryGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Cloud Receive Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CloudReceiveScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cloud_download_outlined, size: 20),
                  label: const Text('Receive via Cloud (Remote)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Privacy Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueSurface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.security_rounded,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All transfers are end-to-end encrypted',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryBlueDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
