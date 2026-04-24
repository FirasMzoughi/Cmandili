import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/notification.dart';

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  final _supabase = Supabase.instance.client;

  NotificationNotifier() : super([]) {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      state = (rows as List)
          .map((row) => _fromRow(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Keep empty list on error
    }
  }

  AppNotification _fromRow(Map<String, dynamic> row) {
    final typeStr = (row['type'] as String?) ?? 'general';
    final NotificationType type;
    if (typeStr == 'orderUpdate' || typeStr == 'order_update') {
      type = NotificationType.orderUpdate;
    } else if (typeStr == 'promotion') {
      type = NotificationType.promotion;
    } else {
      type = NotificationType.system;
    }

    final data = (row['data'] as Map<String, dynamic>?) ?? {};

    return AppNotification(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      message: row['message'] as String? ?? '',
      type: type,
      timestamp: DateTime.parse(row['created_at'] as String),
      isRead: row['is_read'] as bool? ?? false,
      orderId: data['order_id'] as String?,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (_) {}
    state = [
      for (final n in state)
        if (n.id == notificationId) n.copyWith(isRead: true) else n,
    ];
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (_) {}
    state = state.where((n) => n.id != notificationId).toList();
  }

  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('user_id', userId);
      } catch (_) {}
    }
    state = [for (final n in state) n.copyWith(isRead: true)];
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>((ref) {
  return NotificationNotifier();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationProvider);
  return notifications.where((n) => !n.isRead).length;
});
