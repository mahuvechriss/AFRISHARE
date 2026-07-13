import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../models/transfer_model.dart';
import '../../providers/transfer_provider.dart';

class TransferDetailScreen extends ConsumerWidget {
  final List<TransferModel> transfers;

  const TransferDetailScreen({super.key, required this.transfers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transferState = ref.watch(transferListProvider);
    final allTransfers = transferState.transfers;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Details'),
        actions: [
          if (transferState.activeTransfers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.cancel_outlined),
              tooltip: 'Cancel all',
              onPressed: () {
                for (final t in transferState.activeTransfers) {
                  ref
                      .read(transferListProvider.notifier)
                      .cancelTransfer(t.id);
                }
              },
            ),
        ],
      ),
      body: allTransfers.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 64, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text('No transfers yet',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54)),
                  const SizedBox(height: 8),
                  Text('Send or receive files to see them here',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade500)),
                ],
              ),
            )
          : Column(
              children: [
                _buildSummaryBar(context, transferState),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: allTransfers.length,
                    itemBuilder: (context, index) {
                      final transfer = allTransfers[index];
                      return _TransferDetailTile(
                        transfer: transfer,
                        onPause: () => ref
                            .read(transferListProvider.notifier)
                            .pauseTransfer(transfer.id),
                        onResume: () => ref
                            .read(transferListProvider.notifier)
                            .resumeTransfer(transfer.id),
                        onCancel: () => ref
                            .read(transferListProvider.notifier)
                            .cancelTransfer(transfer.id),
                        onRetry: () => ref
                            .read(transferListProvider.notifier)
                            .retryTransfer(transfer.id),
                        onOpen: transfer.filePath != null
                            ? () => OpenFile.open(transfer.filePath!)
                            : null,
                        onShare: transfer.filePath != null
                            ? () => Share.shareXFiles(
                                [XFile(transfer.filePath!)])
                            : null,
                        onDelete: () => 
                            _confirmDeleteTransfer(context, ref, transfer),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryBar(BuildContext context, TransferListState state) {
    final active = state.activeTransfers.length;
    final completed = state.completedTransfers.length;
    final failed = state.failedTransfers.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _SummaryChip(
            icon: Icons.cached_rounded,
            label: '$active active',
            color: AppColors.transferProgress,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            icon: Icons.check_circle_rounded,
            label: '$completed done',
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          _SummaryChip(
            icon: Icons.error_rounded,
            label: '$failed failed',
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTransfer(
    BuildContext context,
    WidgetRef ref,
    TransferModel transfer,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transfer'),
        content: Text(
          'Delete "${transfer.fileName}" from history?\n'
          'The file will also be removed from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(transferListProvider.notifier)
                  .deleteTransfer(transfer.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferDetailTile extends StatefulWidget {
  final TransferModel transfer;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  const _TransferDetailTile({
    required this.transfer,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onOpen,
    this.onShare,
    this.onDelete,
  });

  @override
  State<_TransferDetailTile> createState() => _TransferDetailTileState();
}

class _TransferDetailTileState extends State<_TransferDetailTile> {
  @override
  void initState() {
    super.initState();
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min}m ${sec}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = widget.transfer;
    final isTerminal = t.isTerminal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildFileIcon(t),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.fileName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            FileUtils.formatFileSize(t.fileSize),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(t),
                        ],
                      ),
                    ],
                  ),
                ),
                if (t.isActive) ...[
                  _buildActionIconButton(
                    icon: Icons.pause_circle_outline,
                    color: AppColors.warning,
                    onPressed: widget.onPause,
                  ),
                ] else if (t.status == TransferStatus.paused) ...[
                  _buildActionIconButton(
                    icon: Icons.play_circle_outline,
                    color: AppColors.primaryGreen,
                    onPressed: widget.onResume,
                  ),
                ] else if (t.status == TransferStatus.failed) ...[
                  _buildActionIconButton(
                    icon: Icons.refresh,
                    color: AppColors.primaryBlue,
                    onPressed: widget.onRetry,
                  ),
                ],
              ],
            ),

            // Direction and partner info
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    t.direction == TransferDirection.sent
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 14,
                    color: t.direction == TransferDirection.sent
                        ? AppColors.primaryBlue
                        : AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    t.direction == TransferDirection.sent
                        ? 'To: ${t.receiverName ?? "Unknown"}'
                        : 'From: ${t.senderName ?? "Unknown"}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            // Progress section
            if (t.isActive || t.status == TransferStatus.paused) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: t.progress / 100,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    t.status == TransferStatus.paused
                        ? AppColors.transferPaused
                        : AppColors.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${t.progress.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  if (t.speed > 0)
                    Text(
                      FileUtils.formatSpeed(t.speed.toInt()),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlueLight,
                      ),
                    ),
                  if (t.speed > 0 && t.progress > 0 && t.progress < 100) ...[
                    Text(
                      _formatDuration(_estimateRemaining(t)),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ],

            // Error message
            if (t.status == TransferStatus.failed &&
                t.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t.errorMessage!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons for terminal transfers
            if (isTerminal) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.onOpen != null && t.filePath != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onOpen,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(color: AppColors.primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.onShare != null && t.filePath != null) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onShare,
                        icon: const Icon(Icons.share, size: 16),
                        label: const Text('Share', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryBlue,
                          side: const BorderSide(color: AppColors.primaryBlue),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: IconButton(
                      onPressed: widget.onDelete,
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.error,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _estimateRemaining(TransferModel t) {
    if (t.speed <= 0 || t.progress <= 0) return 0;
    final remaining = (100 - t.progress) / 100 * t.fileSize;
    return (remaining / t.speed).round();
  }

  Widget _buildFileIcon(TransferModel t) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _getFileColor(t).withValues(alpha: 0.1),
      ),
      child: Icon(_getFileIcon(t), color: _getFileColor(t), size: 22),
    );
  }

  IconData _getFileIcon(TransferModel t) {
    final type = FileUtils.getFileType(t.fileType);
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

  Color _getFileColor(TransferModel t) {
    final type = FileUtils.getFileType(t.fileType);
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

  Widget _buildStatusBadge(TransferModel t) {
    Color color;
    switch (t.status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        t.statusText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 24),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
