import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../providers/transfer_provider.dart';
import '../../providers/storage_provider.dart';
import '../../providers/resource_provider.dart';
import '../../services/transfer_service.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await TransferService.instance.getStatistics();
    setState(() => _stats = stats);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transferState = ref.watch(transferListProvider);
    final storageState = ref.watch(storageStateProvider);
    final resourceState = ref.watch(resourceStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Grid
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Total Transfers',
                    value: '${_stats?['totalTransfers'] ?? transferState.transfers.length}',
                    color: AppColors.primaryGreen,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.insert_drive_file_rounded,
                    title: 'Files Shared',
                    value: '${_stats?['totalFilesShared'] ?? 0}',
                    color: AppColors.primaryBlue,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.storage_rounded,
                    title: 'Storage Used',
                    value: storageState.stats?['totalSizeFormatted'] ?? '0 B',
                    color: AppColors.warning,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.devices_rounded,
                    title: 'Active Devices',
                    value: '${_stats?['activeDevices'] ?? 0}',
                    color: AppColors.info,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Most Shared Content
            const Text(
              'Most Shared Content Types',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_stats != null && _stats!['mostShared'] != null)
              ...(_stats!['mostShared'] as List).map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getFileTypeColor(item['file_type'] as String)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.insert_drive_file,
                          color:
                              _getFileTypeColor(item['file_type'] as String),
                          size: 24,
                        ),
                      ),
                      title: Text(
                        (item['file_type'] as String?)?.toUpperCase() ??
                            'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        '${item['count']} transfers • ${FileUtils.formatFileSize((item['total_size'] as int? ?? 0))}',
                      ),
                      trailing: Text(
                        '${item['count']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )),

            const SizedBox(height: 24),

            // Transfer Status Distribution
            const Text(
              'Transfer Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (_stats != null && _stats!['transfersByStatus'] != null)
              ...(_stats!['transfersByStatus'] as Map<String, dynamic>)
                  .entries
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getStatusColor(entry.key),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.key.capitalize(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )),

            const SizedBox(height: 24),

            // Resource Overview
            const Text(
              'Community Library',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MiniStat(
                      icon: Icons.library_books,
                      value: '${resourceState.resources.length}',
                      label: 'Resources',
                      color: AppColors.primaryGreen,
                    ),
                    _MiniStat(
                      icon: Icons.category,
                      value: '${resourceState.filteredResources.length}',
                      label: 'Categories',
                      color: AppColors.primaryBlue,
                    ),
                    _MiniStat(
                      icon: Icons.download_done,
                      value: '0',
                      label: 'Downloads',
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Color _getFileTypeColor(String fileType) {
    final type = FileUtils.getFileType(fileType);
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
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      case 'transferring':
        return AppColors.transferProgress;
      case 'paused':
        return AppColors.transferPaused;
      case 'queued':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
