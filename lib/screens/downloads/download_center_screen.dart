import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../models/transfer_model.dart';
import '../../providers/transfer_provider.dart';
import '../../widgets/common/empty_state.dart';

class DownloadCenterScreen extends ConsumerStatefulWidget {
  const DownloadCenterScreen({super.key});

  @override
  ConsumerState<DownloadCenterScreen> createState() =>
      _DownloadCenterScreenState();
}

class _DownloadCenterScreenState extends ConsumerState<DownloadCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(transferListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {},
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                _buildSummaryCard(
                  'Downloads',
                  transferState.completedTransfers.length,
                  AppColors.success,
                  Icons.download_done_rounded,
                ),
                const SizedBox(width: 8),
                _buildSummaryCard(
                  'Uploads',
                  transferState.transfers
                      .where((t) => t.direction == TransferDirection.sent)
                      .length,
                  AppColors.primaryGreen,
                  Icons.upload_file_rounded,
                ),
                const SizedBox(width: 8),
                _buildSummaryCard(
                  'Failed',
                  transferState.failedTransfers.length,
                  AppColors.error,
                  Icons.error_outline_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Downloads'),
              Tab(text: 'Uploads'),
              Tab(text: 'Failed'),
              Tab(text: 'All'),
            ],
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primaryGreen,
            dividerColor: Colors.transparent,
            isScrollable: false,
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransferList(
                  transferState.completedTransfers
                      .where((t) => t.direction == TransferDirection.received)
                      .toList(),
                  'Nothing downloaded yet',
                  Icons.download_for_offline_outlined,
                ),
                _buildTransferList(
                  transferState.transfers
                      .where((t) => t.direction == TransferDirection.sent)
                      .toList(),
                  'Nothing uploaded yet',
                  Icons.upload_file_outlined,
                ),
                _buildFailedList(transferState.failedTransfers),
                _buildTransferList(
                  transferState.transfers,
                  'Nothing here yet',
                  Icons.swap_horiz_rounded,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferList(
    List<TransferModel> transfers,
    String emptyMessage,
    IconData emptyIcon,
  ) {
    if (transfers.isEmpty) {
      return EmptyStateWidget(
        icon: emptyIcon,
        title: emptyMessage,
        subtitle: 'Share files and they will show up here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return _DownloadTile(
          transfer: transfer,
          onOpen: () => _openFile(transfer),
          onDelete: () => _deleteTransfer(transfer.id),
          onShare: () => _shareFile(transfer),
        );
      },
    );
  }

  Widget _buildFailedList(List<TransferModel> failedTransfers) {
    if (failedTransfers.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.check_circle_outline_rounded,
        title: 'All clear',
        subtitle: 'Failed transfers can be retried here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: failedTransfers.length,
      itemBuilder: (context, index) {
        final transfer = failedTransfers[index];
        return _DownloadTile(
          transfer: transfer,
          isFailed: true,
          onRetry: () => ref
              .read(transferListProvider.notifier)
              .retryTransfer(transfer.id),
          onDelete: () => _deleteTransfer(transfer.id),
        );
      },
    );
  }

  Future<void> _openFile(TransferModel transfer) async {
    if (transfer.filePath == null) {
      _showSnackBar('File not found locally');
      return;
    }
    try {
      final result = await OpenFile.open(transfer.filePath!);
      if (result.type != ResultType.done) {
        _showSnackBar('Could not open file: ${result.message}');
      }
    } catch (e) {
      _showSnackBar('Error opening file: $e');
    }
  }

  Future<void> _deleteTransfer(String transferId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transfer'),
        content: const Text(
          'This will remove the transfer record and delete the file. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(transferListProvider.notifier).deleteTransfer(transferId);
      if (mounted) _showSnackBar('Transfer deleted');
    }
  }

  Future<void> _shareFile(TransferModel transfer) async {
    if (transfer.filePath == null) {
      _showSnackBar('File not found');
      return;
    }
    try {
      await Share.shareXFiles([XFile(transfer.filePath!)]);
    } catch (e) {
      _showSnackBar('Could not share file');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final TransferModel transfer;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final VoidCallback? onRetry;
  final bool isFailed;

  const _DownloadTile({
    required this.transfer,
    this.onOpen,
    this.onDelete,
    this.onShare,
    this.onRetry,
    this.isFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // File icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _getFileColor().withValues(alpha: 0.1),
              ),
              child: Icon(_getFileIcon(), color: _getFileColor(), size: 22),
            ),
            const SizedBox(width: 12),
            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transfer.fileName,
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
                        FileUtils.formatFileSize(transfer.fileSize),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isFailed
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          transfer.statusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isFailed
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (transfer.completedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      FileUtils.formatDate(transfer.completedAt!),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'open':
                    onOpen?.call();
                    break;
                  case 'share':
                    onShare?.call();
                    break;
                  case 'retry':
                    onRetry?.call();
                    break;
                  case 'delete':
                    onDelete?.call();
                    break;
                }
              },
              itemBuilder: (context) => [
                if (!isFailed)
                  const PopupMenuItem(
                    value: 'open',
                    child: ListTile(
                      leading: Icon(Icons.open_in_new, size: 20),
                      title: Text('Open'),
                      dense: true,
                    ),
                  ),
                if (!isFailed)
                  const PopupMenuItem(
                    value: 'share',
                    child: ListTile(
                      leading: Icon(Icons.share, size: 20),
                      title: Text('Share'),
                      dense: true,
                    ),
                  ),
                if (isFailed)
                  const PopupMenuItem(
                    value: 'retry',
                    child: ListTile(
                      leading: Icon(Icons.refresh, size: 20),
                      title: Text('Retry'),
                      dense: true,
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, size: 20),
                    title: Text('Delete'),
                    dense: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getFileColor() {
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
}
