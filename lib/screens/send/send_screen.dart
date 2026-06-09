import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../providers/transfer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discovery_provider.dart';
import '../../widgets/device/device_tile.dart';

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final List<fp.PlatformFile> _selectedFiles = [];

  Future<void> _pickFiles() async {
    final result = await fp.FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: fp.FileType.any,
    );

    if (result != null) {
      setState(() {
        _selectedFiles.addAll(result.files);
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _clearFiles() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  Future<void> _sendToDevice(String receiverId, String receiverName) async {
    final authState = ref.read(authStateProvider);
    final transferNotifier = ref.read(transferListProvider.notifier);

    if (authState.user == null) return;

    for (final file in _selectedFiles) {
      final fileType = FileUtils.getFileType(file.name).name;
      await transferNotifier.queueTransfer(
        fileName: file.name,
        fileSize: file.size,
        fileType: fileType,
        mimeType: FileUtils.getMimeType(file.name),
        senderId: authState.user!.id,
        senderName: authState.user!.username,
        receiverId: receiverId,
        receiverName: receiverName,
        filePath: file.path,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sending ${_selectedFiles.length} file(s) to $receiverName'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      _clearFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final discoveryState = ref.watch(discoveryStateProvider);

    return Scaffold(
      body: Column(
        children: [
          // Selected Files Section
          if (_selectedFiles.isNotEmpty)
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
                ],
              ),
            ),

          // Pick Files Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 120,
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
                        size: 40,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to select files',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                      ),
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

          // Devices Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Select Receiving Device',
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

          // Device List
          Expanded(
            child: discoveryState.devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.devices_rounded,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No devices available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Discover nearby devices first',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: discoveryState.devices.length,
                    itemBuilder: (context, index) {
                      final device = discoveryState.devices[index];
                      return DeviceTile(
                        device: device,
                        showActions: false,
                        onTap: _selectedFiles.isNotEmpty
                            ? () {
                                if (device.isConnectable) {
                                  _sendToDevice(device.deviceId, device.name);
                                }
                              }
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
