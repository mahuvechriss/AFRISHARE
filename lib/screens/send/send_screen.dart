import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/file_utils.dart';
import '../../app.dart' as app;
import '../../services/nearby_connector.dart';
import '../../services/cloud_relay_service.dart';
import '../../services/discovery_service.dart';
import '../../services/auth_service.dart';
import '../../services/qr_service.dart';
import '../../providers/discovery_provider.dart';
import '../../widgets/device/device_tile.dart';
import '../../widgets/transfer/transfer_cycle_indicator.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final List<fp.PlatformFile> _selectedFiles = [];
  final NearbyConnector _connector = NearbyConnector.instance;
  final CloudRelayService _relay = CloudRelayService.instance;
  final QRService _qrService = QRService.instance;
  final AuthService _auth = AuthService.instance;

  bool _isUploading = false;
  String _sendingStatus = '';
  double _sendingProgress = 0;
  String? _shareCode;
  String? _uploadError;

  Future<void> _pickFiles() async {
    final result = await fp.FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: fp.FileType.any,
    );

    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.files);
        _shareCode = null;
        _uploadError = null;
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      _shareCode = null;
      _uploadError = null;
    });
  }

  void _clearFiles() {
    setState(() {
      _selectedFiles.clear();
      _shareCode = null;
      _uploadError = null;
    });
  }

  Future<void> _showManualIpDialog() async {
    final ipController = TextEditingController();
    final portController = TextEditingController(
      text: AppConstants.discoveryPort.toString(),
    );
    final nameController = TextEditingController(text: 'Hotspot Device');
    String? errorText;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Connect Manually'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the receiver\'s IP address shown on their screen',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  labelText: 'IP Address (e.g. 192.168.43.2)',
                  border: const OutlineInputBorder(),
                  errorText: errorText,
                  prefixIcon: const Icon(Icons.language),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portController,
                decoration: InputDecoration(
                  labelText: 'Port',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.settings_ethernet),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Device Name (optional)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.devices),
                ),
              ),
              if (_connector.localIp != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your IP: ${_connector.localIp}\nTell the receiver to enter this on their device.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final ip = ipController.text.trim();
                if (ip.isEmpty) {
                  setDialogState(() => errorText = 'IP address is required');
                  return;
                }
                final port =
                    int.tryParse(portController.text.trim()) ??
                    AppConstants.discoveryPort;
                Navigator.pop(context, {
                  'ip': ip,
                  'port': port.toString(),
                  'name': nameController.text.trim(),
                });
              },
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Connect'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final ip = result['ip']!;
      final port = int.parse(result['port']!);
      final name = result['name'] ?? 'Hotspot Device';

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Connecting to $ip:$port...'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final connResult = await _connector.connectManually(ip, port, name);
      if (connResult['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to ${connResult['deviceName'] ?? name}'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Connection failed: ${connResult['error'] ?? 'Unknown error'}',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  Future<void> _sendToDevice(String receiverId, String receiverName) async {
    final device = DiscoveryService.instance.getDeviceByDeviceId(receiverId);
    if (device?.ipAddress == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Device is unreachable. Try again.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    final filesToSend = _selectedFiles.where((f) => f.path != null).toList();

    if (filesToSend.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No files with valid paths selected'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
      _sendingStatus = 'Requesting $receiverName to accept...';
      _sendingProgress = 0;
    });

    try {
      final fileNames = filesToSend.map((f) => f.name).toList();
      final fileSizes = filesToSend.map((f) => f.size).toList();

      final accepted = await _connector.requestTransfer(
        host: device!.ipAddress!,
        port: device.port ?? AppConstants.discoveryPort,
        fileNames: fileNames,
        fileSizes: fileSizes,
      );

      if (!accepted) {
        if (mounted) {
          setState(() {
            _isUploading = false;
            _sendingStatus = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$receiverName rejected the transfer'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      final totalFiles = filesToSend.length;

      // Send files one by one for reliable progress tracking
      final List<String> failedFiles = [];
      int sentCount = 0;

      for (final file in filesToSend) {
        if (mounted) {
          setState(() {
            _sendingProgress = (sentCount / totalFiles) * 100;
            _sendingStatus =
                'Sending ${file.name} (${sentCount + 1}/$totalFiles)';
          });
        }
        try {
          final sent = await _connector.sendFile(
            endpointId: receiverId,
            filePath: file.path!,
          );
          if (sent) {
            sentCount++;
          } else {
            failedFiles.add(file.name);
          }
        } catch (e) {
          debugPrint('Send error for ${file.name}: $e');
          failedFiles.add(file.name);
        }
      }

      if (mounted) {
        setState(() {
          _sendingProgress = 100;
          _sendingStatus = failedFiles.isEmpty ? 'Complete!' : 'Failed';
        });
      }

      final allSent = failedFiles.isEmpty;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allSent
                  ? 'Sent $totalFiles file(s) to $receiverName'
                  : failedFiles.length == totalFiles
                  ? 'Failed to send files. Check both devices are on the same network.'
                  : '${failedFiles.length} file(s) failed: ${failedFiles.join(", ")}',
            ),
            backgroundColor: allSent ? AppColors.success : AppColors.warning,
            behavior: SnackBarBehavior.floating,
            duration: allSent
                ? const Duration(seconds: 6)
                : const Duration(seconds: 7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: allSent ? SnackBarAction(
              label: 'View',
              onPressed: () {
                app.navigateToTransfersNotifier.value = true;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ) : null,
          ),
        );
        if (allSent) {
          _clearFiles();
        }
      }
    } catch (e) {
      debugPrint('_sendToDevice error: $e');
      if (mounted) {
        setState(() {
          _sendingStatus = 'Error: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Send failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isUploading = false;
              _sendingStatus = '';
              _sendingProgress = 0;
            });
          }
        });
      }
    }
  }

  Future<void> _shareViaCloud() async {
    if (_selectedFiles.isEmpty) return;

    setState(() {
      _isUploading = true;
      _shareCode = null;
      _uploadError = null;
    });

    for (final file in _selectedFiles) {
      if (file.path == null) continue;
      final result = await _relay.uploadFile(filePath: file.path!);
      if (result['status'] == 'ok') {
        setState(() {
          _shareCode = result['shareCode'] as String?;
        });
      } else {
        setState(() {
          _uploadError = result['error'] as String? ?? 'Upload failed';
        });
      }
    }

    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final discoveryState = ref.watch(discoveryStateProvider);
    final hasPairedDevices = discoveryState.devices.any((d) => d.isPaired);
    final hasFiles = _selectedFiles.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          // Active Transfer Cycle
          const Padding(
            padding: EdgeInsets.only(top: 12, left: 16, right: 16),
            child: TransferCycleIndicator(),
          ),

          // Selected Files Section
          if (hasFiles)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedFiles.length} file(s) selected',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      TextButton(
                        onPressed: _clearFiles,
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedFiles.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final file = _selectedFiles[index];
                        return Chip(
                          label: Text(
                            file.name,
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeFile(index),
                          avatar: Text(
                            FileUtils.getFileIcon(file.name),
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      },
                    ),
                  ),

                  // Cloud Share Button
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _shareViaCloud,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_outlined, size: 20),
                      label: Text(
                        _isUploading
                            ? 'Uploading...'
                            : 'Send via Cloud (Remote)',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Share Code Display
                  if (_shareCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 36,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'File uploaded! Share this code:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: _shareCode!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Code $_shareCode copied!'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primaryGreen,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                _shareCode!,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 6,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to copy · Expires in 24 hours',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Upload Error
                  if (_uploadError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _uploadError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
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

          // Pick Files Button
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: hasFiles ? 0 : 24,
            ),
            child: SizedBox(
              width: double.infinity,
              height: hasFiles ? 80 : 120,
              child: InkWell(
                onTap: _pickFiles,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primaryGreen.withValues(alpha: 0.3),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    color: AppColors.primaryGreenSurface.withValues(alpha: 0.3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: hasFiles ? 28 : 40,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasFiles ? 'Add more files' : 'Tap to select files',
                        style: TextStyle(
                          fontSize: hasFiles ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      if (!hasFiles)
                        Text(
                          'Images, Videos, Audio, Documents, APK & more',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // QR Code Card for Pairing (only show when no paired devices)
          if ((!hasFiles || _shareCode == null) && !hasPairedDevices) ...[
            _buildQrCard(isDark),
            const SizedBox(height: 8),
          ],

          // Sending progress indicator
          if (_isUploading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreenSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _sendingStatus,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_sendingProgress > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _sendingProgress / 100,
                          minHeight: 6,
                          backgroundColor: Colors.white,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],

          // Devices Header
          if (!hasFiles || _shareCode == null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    hasFiles
                        ? 'Or send to nearby device'
                        : 'Select Receiving Device',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Device List or Connection Guide
          Expanded(
            child: discoveryState.devices.isEmpty
                ? _buildNoDevicesGuide(isDark)
                : ListView.builder(
                    itemCount: discoveryState.devices.length,
                    itemBuilder: (context, index) {
                      final device = discoveryState.devices[index];
                      return DeviceTile(
                        device: device,
                        showActions: false,
                        onTap: _isUploading
                            ? null
                            : (_selectedFiles.isNotEmpty
                                  ? () {
                                      if (device.isConnectable) {
                                        _sendToDevice(
                                          device.deviceId,
                                          device.name,
                                        );
                                      }
                                    }
                                  : null),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard(bool isDark) {
    final deviceId = _auth.deviceId;
    final deviceName = _auth.currentUser?.deviceName ?? 'AfriShare Device';

    return FutureBuilder<String>(
      future: _qrService.generatePairingData(deviceId, deviceName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 40,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Network not available',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Could not determine your device IP address.\n'
                  'Make sure WiFi is enabled and you are connected to a network.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          );
        }

        final pairingData = snapshot.data!;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_rounded,
                    size: 22,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Your Pairing QR Code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: _qrService.generateQRWidget(
                  data: pairingData,
                  size: 200,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                deviceName,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (_connector.localIp != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language,
                        size: 16,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_connector.localIp}:${_connector.httpPort}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(
                            ClipboardData(
                              text:
                                  '${_connector.localIp}:${_connector.httpPort}',
                            ),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('IP copied!'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.copy,
                          size: 16,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'On hotspot? Share this IP with receiver to connect manually',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoDevicesGuide(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Guide Card
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
              Icon(
                Icons.devices_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No devices available',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 16),
              _buildGuideRow(
                Icons.wifi,
                'Both devices must be on the same WiFi',
              ),
              const SizedBox(height: 10),
              _buildGuideRow(
                Icons.qr_code_scanner,
                'Receiver scans your QR code above to pair',
              ),
              const SizedBox(height: 10),
              _buildGuideRow(
                Icons.wifi_find,
                'Enable Discovery on the receiving device',
              ),
              if (_connector.localIp != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your IP: ${_connector.localIp}\n'
                          'Share this with the receiver if auto-discovery fails',
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showManualIpDialog,
                  icon: const Icon(Icons.link, size: 20),
                  label: const Text('Connect Manually (Enter IP)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              _buildGuideRow(
                Icons.cloud_upload_outlined,
                'Or use "Send via Cloud" for remote recipients',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuideRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.3)),
        ),
      ],
    );
  }
}
