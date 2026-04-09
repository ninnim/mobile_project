import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/notification_model.dart';

class NotificationState {
  final List<NotificationModel> notifications;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final int unreadCount;
  final int page;
  final bool hasMore;

  const NotificationState({
    this.notifications = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.unreadCount = 0,
    this.page = 1,
    this.hasMore = true,
  });

  NotificationState copyWith({
    List<NotificationModel>? notifications,
    bool? loading,
    bool? loadingMore,
    String? error,
    int? unreadCount,
    int? page,
    bool? hasMore,
    bool clearError = false,
  }) =>
      NotificationState(
        notifications: notifications ?? this.notifications,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : error ?? this.error,
        unreadCount: unreadCount ?? this.unreadCount,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
      );
}

class NotificationNotifier extends Notifier<NotificationState> {
  Timer? _pollingTimer;

  @override
  NotificationState build() {
    ref.onDispose(() => _pollingTimer?.cancel());
    _fetchInitial();
    _startPolling();
    return const NotificationState(loading: true);
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      fetchUnreadCount();
    });
  }

  Future<void> _fetchInitial() async {
    try {
      final res = await dioClient.get('/notifications', queryParameters: {'page': 1, 'pageSize': 20});
      final list = (res.data as List).map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
      final countRes = await dioClient.get('/notifications/unread-count');
      final count = (countRes.data as Map<String, dynamic>)['count'] as int? ?? 0;
      state = NotificationState(
        notifications: list,
        unreadCount: count,
        page: 1,
        hasMore: list.length >= 20,
      );
    } catch (e) {
      debugPrint('[Notifications] fetch error: $e');
      state = NotificationState(error: 'Failed to load notifications');
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await dioClient.get('/notifications', queryParameters: {'page': 1, 'pageSize': 20});
      final list = (res.data as List).map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
      final countRes = await dioClient.get('/notifications/unread-count');
      final count = (countRes.data as Map<String, dynamic>)['count'] as int? ?? 0;
      state = NotificationState(
        notifications: list,
        unreadCount: count,
        page: 1,
        hasMore: list.length >= 20,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Failed to refresh');
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final nextPage = state.page + 1;
      final res = await dioClient.get('/notifications', queryParameters: {'page': nextPage, 'pageSize': 20});
      final list = (res.data as List).map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
      state = state.copyWith(
        notifications: [...state.notifications, ...list],
        page: nextPage,
        hasMore: list.length >= 20,
        loadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> fetchUnreadCount() async {
    try {
      final res = await dioClient.get('/notifications/unread-count');
      final count = (res.data as Map<String, dynamic>)['count'] as int? ?? 0;
      if (count != state.unreadCount) {
        state = state.copyWith(unreadCount: count);
      }
    } catch (_) {}
  }

  Future<void> markAsRead(String notificationId) async {
    final idx = state.notifications.indexWhere((n) => n.id == notificationId);
    if (idx == -1) return;
    final notification = state.notifications[idx];
    if (notification.isRead) return;

    final updated = List<NotificationModel>.from(state.notifications);
    updated[idx] = notification.copyWith(isRead: true);
    state = state.copyWith(
      notifications: updated,
      unreadCount: (state.unreadCount - 1).clamp(0, 999),
    );

    try {
      await dioClient.put('/notifications/$notificationId/read');
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    state = state.copyWith(notifications: updated, unreadCount: 0);
    try {
      await dioClient.put('/notifications/read-all');
    } catch (_) {}
  }

  Future<void> deleteNotification(String notificationId) async {
    final wasUnread = state.notifications.any((n) => n.id == notificationId && !n.isRead);
    final updated = state.notifications.where((n) => n.id != notificationId).toList();
    state = state.copyWith(
      notifications: updated,
      unreadCount: wasUnread ? (state.unreadCount - 1).clamp(0, 999) : state.unreadCount,
    );
    try {
      await dioClient.delete('/notifications/$notificationId');
    } catch (_) {}
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, NotificationState>(NotificationNotifier.new);
