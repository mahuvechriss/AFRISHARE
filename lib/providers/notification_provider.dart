import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

final notificationStateProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final notificationService = ref.read(notificationServiceProvider);
  return NotificationNotifier(notificationService);
});

class NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) =>
      NotificationState(
        notifications: notifications ?? this.notifications,
        unreadCount: unreadCount ?? this.unreadCount,
        isLoading: isLoading ?? this.isLoading,
      );
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _notificationService;

  NotificationNotifier(this._notificationService)
      : super(const NotificationState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    await _notificationService.initialize();
    _updateState();
    state = state.copyWith(isLoading: false);

    _notificationService.notificationStream.listen((_) {
      _updateState();
    });
  }

  void _updateState() {
    state = state.copyWith(
      notifications: _notificationService.notifications,
      unreadCount: _notificationService.unreadCount,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    await _notificationService.markAsRead(notificationId);
    _updateState();
  }

  Future<void> markAllAsRead() async {
    await _notificationService.markAllAsRead();
    _updateState();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _notificationService.deleteNotification(notificationId);
    _updateState();
  }

  Future<void> clearAll() async {
    await _notificationService.clearAll();
    _updateState();
  }
}
