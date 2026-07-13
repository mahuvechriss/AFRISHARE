import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../models/transfer_model.dart';
import '../../providers/transfer_provider.dart';
import '../../widgets/transfer/transfer_tile.dart';

class TransferQueueScreen extends ConsumerStatefulWidget {
  const TransferQueueScreen({super.key});

  @override
  ConsumerState<TransferQueueScreen> createState() =>
      _TransferQueueScreenState();
}

class _TransferQueueScreenState extends ConsumerState<TransferQueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transferState = ref.watch(transferListProvider);
    final sent = transferState.transfers
        .where((t) => t.direction == TransferDirection.sent)
        .toList();
    final received = transferState.transfers
        .where((t) => t.direction == TransferDirection.received)
        .toList();

    return Column(
      children: [
        // Summary Cards
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              _SummaryCard(
                icon: Icons.arrow_upward_rounded,
                label: 'Sent',
                count: sent.length,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                icon: Icons.arrow_downward_rounded,
                label: 'Received',
                count: received.length,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              _SummaryCard(
                icon: Icons.hourglass_empty_rounded,
                label: 'Active',
                count: transferState.activeTransfers.length,
                color: AppColors.primaryBlueLight,
              ),
            ],
          ),
        ),

        // Tab Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Sent'),
                Tab(text: 'Received'),
              ],
              labelColor: Colors.white,
              unselectedLabelColor: isDark
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              indicator: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerHeight: 0,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTransferList(transferState.transfers, isDark),
              _buildTransferList(sent, isDark),
              _buildTransferList(received, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferList(List<TransferModel> transfers, bool isDark) {
    if (transfers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGreenSurface,
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  size: 48,
                  color: AppColors.primaryGreen.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Nothing here yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start sharing files with nearby devices',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = List<TransferModel>.from(transfers)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final transfer = sorted[index];
        return TransferTile(
          transfer: transfer,
          onTap: () => _showTransferDetails(transfer),
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
        );
      },
    );
  }

  void _showTransferDetails(TransferModel transfer) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  transfer.direction == TransferDirection.sent
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 20,
                  color: transfer.direction == TransferDirection.sent
                      ? AppColors.primaryBlue
                      : AppColors.primaryGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    transfer.fileName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.file_present,
              label: 'Type',
              value: transfer.fileType,
            ),
            _DetailRow(
              icon: Icons.speed,
              label: 'Status',
              value: transfer.statusText,
            ),
            _DetailRow(
              icon: Icons.storage,
              label: 'Size',
              value: _formatBytes(transfer.fileSize),
            ),
            _DetailRow(
              icon: transfer.direction == TransferDirection.sent
                  ? Icons.person
                  : Icons.person_outline,
              label: transfer.direction == TransferDirection.sent
                  ? 'Sent to'
                  : 'From',
              value: transfer.direction == TransferDirection.sent
                  ? (transfer.receiverName ?? 'Unknown')
                  : (transfer.senderName ?? 'Unknown'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (transfer.filePath != null &&
                    File(transfer.filePath!).existsSync()) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => OpenFile.open(transfer.filePath!),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          Share.shareXFiles([XFile(transfer.filePath!)]),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
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
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
