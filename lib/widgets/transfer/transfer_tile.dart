import 'package:flutter/material.dart';
import '../../models/transfer_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';

class TransferTile extends StatelessWidget {
  final TransferModel transfer;
  final VoidCallback? onTap;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  const TransferTile({
    super.key,
    required this.transfer,
    this.onTap,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildFileIcon(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transfer.fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              FileUtils.formatFileSize(transfer.fileSize),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildStatusChip(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildActionButton(),
                ],
              ),
              if (transfer.isActive || transfer.status == TransferStatus.paused) ...[
                const SizedBox(height: 12),
                TransferProgressBar(
                  progress: transfer.progress,
                  status: transfer.status,
                  speed: transfer.speed,
                ),
              ],
              if (transfer.status == TransferStatus.failed &&
                  transfer.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  transfer.errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _getFileTypeColor().withValues(alpha: 0.1),
      ),
      child: Icon(
        _getFileIcon(),
        color: _getFileTypeColor(),
        size: 22,
      ),
    );
  }

  IconData _getFileIcon() {
    final type = FileUtils.getFileType(transfer.fileType);
    switch (type) {
      case FileType.image:
        return Icons.image_outlined;
      case FileType.video:
        return Icons.videocam_outlined;
      case FileType.audio:
        return Icons.audiotrack_outlined;
      case FileType.document:
        return Icons.description_outlined;
      case FileType.archive:
        return Icons.folder_zip_outlined;
      case FileType.app:
        return Icons.android_outlined;
      case FileType.other:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getFileTypeColor() {
    final type = FileUtils.getFileType(transfer.fileType);
    switch (type) {
      case FileType.image:
        return Colors.purple;
      case FileType.video:
        return Colors.orange;
      case FileType.audio:
        return Colors.blue;
      case FileType.document:
        return Colors.teal;
      case FileType.archive:
        return Colors.brown;
      case FileType.app:
        return Colors.green;
      case FileType.other:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip() {
    Color color;
    switch (transfer.status) {
      case TransferStatus.completed:
        color = AppColors.transferCompleted;
      case TransferStatus.failed:
        color = AppColors.transferFailed;
      case TransferStatus.paused:
        color = AppColors.transferPaused;
      case TransferStatus.transferring:
      case TransferStatus.connecting:
        color = AppColors.transferProgress;
      case TransferStatus.cancelled:
        color = Colors.grey;
      case TransferStatus.queued:
      case TransferStatus.retrying:
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        transfer.statusText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    switch (transfer.status) {
      case TransferStatus.transferring:
      case TransferStatus.connecting:
        if (onPause != null) {
          return IconButton(
            onPressed: onPause,
            icon: const Icon(Icons.pause_circle_outline),
            color: AppColors.warning,
            iconSize: 28,
          );
        }
        return const SizedBox.shrink();
      case TransferStatus.paused:
        if (onResume != null) {
          return IconButton(
            onPressed: onResume,
            icon: const Icon(Icons.play_circle_outline),
            color: AppColors.primaryGreen,
            iconSize: 28,
          );
        }
        return const SizedBox.shrink();
      case TransferStatus.failed:
        if (onRetry != null) {
          return IconButton(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            color: AppColors.primaryBlue,
            iconSize: 28,
          );
        }
        return const SizedBox.shrink();
      case TransferStatus.queued:
        if (onCancel != null) {
          return IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel_outlined),
            color: Colors.grey,
            iconSize: 28,
          );
        }
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }
}

class TransferProgressBar extends StatelessWidget {
  final double progress;
  final TransferStatus status;
  final double speed;

  const TransferProgressBar({
    super.key,
    required this.progress,
    required this.status,
    this.speed = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${progress.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            if (speed > 0)
              Text(
                FileUtils.formatSpeed(speed.toInt()),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Color _getProgressColor() {
    switch (status) {
      case TransferStatus.paused:
        return AppColors.transferPaused;
      case TransferStatus.failed:
        return AppColors.transferFailed;
      default:
        return AppColors.primaryGreen;
    }
  }
}
