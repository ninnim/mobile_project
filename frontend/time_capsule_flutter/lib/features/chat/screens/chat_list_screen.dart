import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';

final contactsProvider = FutureProvider.autoDispose<List<ContactModel>>((ref) async {
  final res = await dioClient.get('/chats/contacts');
  return (res.data as List<dynamic>)
      .map((e) => ContactModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class ChatListScreen extends ConsumerWidget {
  final void Function(String userId, String displayName) onOpenChat;

  const ChatListScreen({super.key, required this.onOpenChat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Icon(Icons.chat_bubble_rounded, color: scheme.primary, size: 22),
          const SizedBox(width: 8),
          const Text('Chats', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
      body: contactsAsync.when(
        loading: () => ListView.builder(
          itemCount: 5,
          itemBuilder: (ctx, i) => const SkeletonCard(),
        ),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Failed to load chats',
          actionLabel: 'Try Again',
          onAction: () => ref.refresh(contactsProvider),
        ),
        data: (contacts) => contacts.isEmpty
            ? const EmptyState(
                icon: Icons.chat_bubble_outline,
                title: 'No conversations yet',
                subtitle: 'Tap a user\'s name anywhere to start chatting',
              )
            : RefreshIndicator(
                color: scheme.primary,
                onRefresh: () async => ref.refresh(contactsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: contacts.length,
                  itemBuilder: (ctx, i) {
                    final c = contacts[i];
                    return _ContactTile(
                      contact: c,
                      onTap: () => onOpenChat(c.userId, c.displayName),
                    ).animate(delay: Duration(milliseconds: i * 40)).fadeIn().slideX(begin: -0.03);
                  },
                ),
              ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onTap;
  const _ContactTile({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = contact.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.onSurface.withAlpha(15))),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                AvatarWidget(url: contact.profilePictureUrl, name: contact.displayName, radius: 26),
                if (hasUnread)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle, border: Border.all(color: isDark ? const Color(0xFF0B0D21) : Colors.white, width: 2)),
                      child: Center(
                        child: Text(
                          contact.unreadCount > 9 ? '9+' : '${contact.unreadCount}',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: isDark ? Colors.black : Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName,
                    style: TextStyle(fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.lastMessage ?? 'No messages yet',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasUnread ? scheme.onSurface : scheme.onSurface.withAlpha(120),
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (contact.lastMessageAt != null)
              Text(_timeAgo(contact.lastMessageAt!), style: TextStyle(fontSize: 11, color: hasUnread ? scheme.primary : scheme.onSurface.withAlpha(100))),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) { return ''; }
  }
}
