import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';
import '../../widgets/common/empty_state.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationState = ref.watch(notificationStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notificationState.unreadCount > 0)
            TextButton(
              onPressed: () {
                ref
                    .read(notificationStateProvider.notifier)
                    .markAllAsRead();
              },
              child: const Text('Mark All Read'),
            ),
        ],
      ),
      body: notificationState.notifications.isEmpty
          ? const EmptyStateWidget(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications',
              subtitle: 'You\'ll see notifications here when someone\nconnects or sends files',
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: notificationState.notifications.length,
              itemBuilder: (context, index) {
                final notification =
                    notificationState.notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () {
                    ref
                        .read(notificationStateProvider.notifier)
                        .markAsRead(notification.id);
                  },
                  onDelete: () {
                    ref
                        .read(notificationStateProvider.notifier)
                        .deleteNotification(notification.id);
                  },
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _NotificationTile({
    required this.notification,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getIconColor().withValues(alpha: 0.1),
          ),
          child: Icon(
            _getIcon(),
            color: _getIconColor(),
            size: 22,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.w400 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          notification.body,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              FileUtils.formatDate(notification.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
            if (!notification.isRead) ...[
              const SizedBox(height: 4),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.connectionRequest:
        return Icons.link;
      case NotificationType.incomingTransfer:
        return Icons.download;
      case NotificationType.transferCompleted:
        return Icons.check_circle;
      case NotificationType.transferFailed:
        return Icons.error;
      case NotificationType.newMessage:
        return Icons.chat;
      case NotificationType.pairingRequest:
        return Icons.devices;
      case NotificationType.system:
        return Icons.info;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case NotificationType.connectionRequest:
        return AppColors.primaryBlue;
      case NotificationType.incomingTransfer:
        return AppColors.primaryBlue;
      case NotificationType.transferCompleted:
        return AppColors.success;
      case NotificationType.transferFailed:
        return AppColors.error;
      case NotificationType.newMessage:
        return AppColors.warning;
      case NotificationType.pairingRequest:
        return AppColors.primaryGreen;
      case NotificationType.system:
        return Colors.grey;
    }
  }
}
