import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/notification.dart';
import '../data/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  final NotificationRepository _repository;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  NotificationNotifier(this._repository) : super([]) {
    loadNotifications();
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _repository.streamUserNotifications().listen(
      (rows) {
        state = rows.map(_fromMap).toList();
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> loadNotifications() async {
    final raw = await _repository.getUserNotifications();
    state = raw.map(_fromMap).toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
    state = [
      for (final n in state)
        if (n.id == notificationId) n.copyWith(isRead: true) else n,
    ];
  }

  Future<void> deleteNotification(String notificationId) async {
    await _repository.deleteNotification(notificationId);
    state = state.where((n) => n.id != notificationId).toList();
  }

  void markAllAsRead() {
    state = [for (final n in state) n.copyWith(isRead: true)];
    for (final n in state) {
      _repository.markAsRead(n.id);
    }
  }

  AppNotification _fromMap(Map<String, dynamic> map) {
    NotificationType type;
    switch (map['type'] as String? ?? 'system') {
      case 'order_update':
        type = NotificationType.orderUpdate;
        break;
      case 'promotion':
        type = NotificationType.promotion;
        break;
      default:
        type = NotificationType.system;
    }
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      type: type,
      timestamp: DateTime.parse(map['created_at'] as String),
      isRead: map['is_read'] as bool? ?? false,
      orderId: map['order_id'] as String?,
    );
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>((ref) {
  return NotificationNotifier(ref.watch(notificationRepositoryProvider));
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationProvider);
  return notifications.where((n) => !n.isRead).length;
});
