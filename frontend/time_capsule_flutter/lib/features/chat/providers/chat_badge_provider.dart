import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../models/chat_message.dart';

class ChatBadgeNotifier extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    ref.onDispose(() => _timer?.cancel());
    _fetchUnreadCount();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchUnreadCount());
    return 0;
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

final chatBadgeProvider = NotifierProvider<ChatBadgeNotifier, int>(ChatBadgeNotifier.new);
