import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../core/database/database_helper.dart';

/// Service managing in-app notifications
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final Uuid _uuid = const Uuid();
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<NotificationModel> _notifications = [];
  final StreamController<NotificationModel> _notificationController =
      StreamController<NotificationModel>.broadcast();

  Stream<NotificationModel> get notificationStream =>
      _notificationController.stream;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;

  /// Load notification history
  Future<void> initialize() async {
    final results = await _db.query(
      'notifications',
      orderBy: 'created_at DESC',
      limit: 50,
    );
    for (final row in results) {
      _notifications.add(NotificationModel.fromJson(row));
    }
  }

  /// Create a notification
  Future<NotificationModel> createNotification({
    required NotificationType type,
    required String title,
    required String body,
    String? data,
  }) async {
    final notification = NotificationModel(
      id: _uuid.v4(),
      type: type,
      title: title,
      body: body,
      data: data,
      createdAt: DateTime.now(),
    );

    _notifications.insert(0, notification);
    await _db.insert('notifications', notification.toJson());
    _notificationController.add(notification);

    // Trim old notifications
    if (_notifications.length > 100) {
      final oldNotifications = _notifications.sublist(100);
      _notifications.removeRange(100, _notifications.length);
      for (final old in oldNotifications) {
        await _db.delete('notifications', 'id = ?', [old.id]);
      }
    }

    return notification;
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index < 0) return;

    _notifications[index] = _notifications[index].copyWith(isRead: true);
    await _db.update(
      'notifications',
      {'is_read': 1},
      'id = ?',
      [notificationId],
    );
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    await _db.update('notifications', {'is_read': 1}, 'is_read = 0', []);
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    _notifications.removeWhere((n) => n.id == notificationId);
    await _db.delete('notifications', 'id = ?', [notificationId]);
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    await _db.delete('notifications', '1 = 1', []);
  }

  /// Create notification helpers
  Future<void> notifyConnectionRequest(String deviceName) async {
    await createNotification(
      type: NotificationType.connectionRequest,
      title: 'Connection Request',
      body: '$deviceName wants to connect',
      data: '{"device_name": "$deviceName"}',
    );
  }

  Future<void> notifyIncomingTransfer(String fileName) async {
    await createNotification(
      type: NotificationType.incomingTransfer,
      title: 'Incoming File',
      body: 'Receiving: $fileName',
      data: '{"file_name": "$fileName"}',
    );
  }

  Future<void> notifyTransferCompleted(String fileName) async {
    await createNotification(
      type: NotificationType.transferCompleted,
      title: 'Transfer Complete',
      body: '$fileName transferred successfully',
      data: '{"file_name": "$fileName"}',
    );
  }

  Future<void> notifyTransferFailed(String fileName, String error) async {
    await createNotification(
      type: NotificationType.transferFailed,
      title: 'Transfer Failed',
      body: 'Failed to transfer $fileName: $error',
      data: '{"file_name": "$fileName", "error": "$error"}',
    );
  }

  Future<void> notifyNewMessage(String senderName) async {
    await createNotification(
      type: NotificationType.newMessage,
      title: 'New Message',
      body: 'Message from $senderName',
      data: '{"sender_name": "$senderName"}',
    );
  }

  void dispose() {
    _notificationController.close();
    _notifications.clear();
  }
}
