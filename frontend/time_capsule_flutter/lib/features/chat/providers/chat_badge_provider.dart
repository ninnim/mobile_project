import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/signalr_service.dart';
import '../models/chat_message.dart';

class ChatBadgeNotifier extends Notifier<int> {
  StreamSubscription? _messageSub;
  StreamSubscription? _notifSub;
  Timer? _fallbackTimer;

  @override
  int build() {
    _listenToSignalR();
    _startFallbackTimer();
    ref.onDispose(() {
      _messageSub?.cancel();
      _notifSub?.cancel();
      _fallbackTimer?.cancel();
    });
    _fetchUnreadCount();
    return 0;
  }

  void _listenToSignalR() {
    // Listen for incoming chat messages — bump badge
    _messageSub?.cancel();
    _messageSub = SignalRService.instance.onMessage.listen((_) {
      debugPrint('[ChatBadge] New message received via SignalR');
      _fetchUnreadCount();
    });
    // Also listen for ChatMessage notifications
    _notifSub?.cancel();
    _notifSub = SignalRService.instance.onNotification.listen((data) {
      if (data['type'] == 'ChatMessage') {
        debugPrint('[ChatBadge] ChatMessage notification via SignalR');
        _fetchUnreadCount();
      }
    });
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchUnreadCount();
    });
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await dioClient.get('/chats/contacts');
      final contacts = (res.data as List<dynamic>)
          .map((e) => ContactModel.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = contacts.fold<int>(0, (sum, c) => sum + c.unreadCount);
      if (total != state) state = total;
    } catch (e) {
      debugPrint('[ChatBadge] error: $e');
    }
  }

  void refresh() => _fetchUnreadCount();
}

final chatBadgeProvider = NotifierProvider<ChatBadgeNotifier, int>(
  ChatBadgeNotifier.new,
);
