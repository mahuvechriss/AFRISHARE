import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../models/transfer_model.dart';
import '../../providers/transfer_provider.dart';
import '../../widgets/transfer/transfer_tile.dart';
import '../../widgets/common/empty_state.dart';

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
    final transferState = ref.watch(transferListProvider);
    return Column(
      children: [
        // Summary Cards
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              _SummaryChip(
                label: 'Active',
                count: transferState.activeTransfers.length,
                color: AppColors.transferProgress,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Completed',
                count: transferState.completedTransfers.length,
                color: AppColors.transferCompleted,
              ),
              const SizedBox(width: 8),
              _SummaryChip(
                label: 'Failed',
                count: transferState.failedTransfers.length,
                color: AppColors.transferFailed,
              ),
            ],
          ),
        ),

        // Tab Bar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'History'),
          ],
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primaryGreen,
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildActiveTab(transferState),
              _buildCompletedTab(transferState),
              _buildHistoryTab(transferState),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveTab(TransferListState state) {
    final active = state.activeTransfers;

    if (active.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.check_circle_outline_rounded,
        title: 'No active transfers',
        subtitle: 'Your transfers will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final transfer = active[index];
        return TransferTile(
          transfer: transfer,
          onPause: () =>
              ref.read(transferListProvider.notifier).pauseTransfer(transfer.id),
          onResume: () =>
              ref.read(transferListProvider.notifier).resumeTransfer(transfer.id),
          onCancel: () =>
              ref.read(transferListProvider.notifier).cancelTransfer(transfer.id),
          onRetry: () =>
              ref.read(transferListProvider.notifier).retryTransfer(transfer.id),
        );
      },
    );
  }

  Widget _buildCompletedTab(TransferListState state) {
    final completed = state.completedTransfers;

    if (completed.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.done_all_rounded,
        title: 'No completed transfers',
        subtitle: 'Completed transfers will show here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: completed.length,
      itemBuilder: (context, index) {
        return TransferTile(
          transfer: completed[index],
          onTap: () => _showTransferDetails(completed[index]),
        );
      },
    );
  }

  Widget _buildHistoryTab(TransferListState state) {
    final history = state.transfers
        .where((t) => t.isTerminal)
        .toList();

    if (history.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.history_rounded,
        title: 'No transfer history',
        subtitle: 'Your transfer history will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        return TransferTile(
          transfer: history[index],
          onTap: () => _showTransferDetails(history[index]),
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
            Text(
              transfer.fileName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
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
              value: transfer.fileSize.toString(),
            ),
            _DetailRow(
              icon: Icons.person,
              label: transfer.direction.name == 'sent'
                  ? 'Receiver'
                  : 'Sender',
              value: transfer.senderName ?? 'Unknown',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
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
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
