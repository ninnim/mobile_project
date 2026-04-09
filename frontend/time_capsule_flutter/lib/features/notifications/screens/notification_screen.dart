import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notification_provider.dart';
import '../models/notification_model.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(notificationProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            floating: true,
            snap: true,
            title: Row(
              children: [
                Icon(Icons.notifications_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                const Text('Notifications'),
                if (state.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${state.unreadCount}',
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.1, duration: 800.ms),
                ],
              ],
            ),
            actions: [
              if (state.unreadCount > 0)
                IconButton(
                  icon: Icon(Icons.done_all_rounded, color: scheme.primary),
                  tooltip: 'Mark all as read',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(notificationProvider.notifier).markAllAsRead();
                  },
                ),
            ],
          ),

          // ── Content ──
          if (state.loading)
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const SkeletonBox(
                          width: 48,
                          height: 48,
                          borderRadius: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 180, height: 14),
                              const SizedBox(height: 6),
                              SkeletonBox(width: 120, height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  childCount: 8,
                ),
              ),
            )
          else if (state.error != null && state.notifications.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: scheme.error.withAlpha(150),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.error!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () =>
                          ref.read(notificationProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (state.notifications.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                icon: Icons.notifications_none_rounded,
                title: "You're all caught up!",
                subtitle:
                    'No notifications yet. Interact with friends to see activity here.',
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == state.notifications.length) {
                    if (state.loadingMore) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  final notification = state.notifications[index];
                  return _NotificationTile(
                    notification: notification,
                    index: index,
                    onTap: () => _onNotificationTap(notification),
                    onDismiss: () {
                      HapticFeedback.lightImpact();
                      ref
                          .read(notificationProvider.notifier)
                          .deleteNotification(notification.id);
                    },
                    onAcceptFriend: notification.type == 'FriendRequest'
                        ? () => _handleFriendAction(notification, true)
                        : null,
                    onRejectFriend: notification.type == 'FriendRequest'
                        ? () => _handleFriendAction(notification, false)
                        : null,
                  );
                },
                childCount:
                    state.notifications.length + (state.loadingMore ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }

  void _onNotificationTap(NotificationModel notification) {
    HapticFeedback.selectionClick();
    ref.read(notificationProvider.notifier).markAsRead(notification.id);

    switch (notification.type) {
      case 'FriendRequest':
      case 'FriendAccepted':
        Navigator.pushNamed(
          context,
          '/user-profile',
          arguments: notification.actorId,
        );
        break;
      case 'PostReaction':
      case 'PostComment':
      case 'CommentReaction':
        if (notification.referenceId != null) {
          Navigator.pushNamed(
            context,
            '/post-detail',
            arguments: notification.referenceId,
          );
        }
        break;
      case 'ChatMessage':
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'userId': notification.actorId,
            'name': notification.actorName,
          },
        );
        break;
      case 'CapsuleUnlocked':
        if (notification.referenceId != null) {
          Navigator.pushNamed(
            context,
            '/user-profile',
            arguments: notification.actorId,
          );
        }
        break;
      case 'ProfileReaction':
        Navigator.pushNamed(
          context,
          '/user-profile',
          arguments: notification.actorId,
        );
        break;
    }
  }

  Future<void> _handleFriendAction(
    NotificationModel notification,
    bool accept,
  ) async {
    HapticFeedback.mediumImpact();
    try {
      if (accept) {
        await dioClient.put('/friends/accept/${notification.actorId}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You and ${notification.actorName} are now friends!',
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        await dioClient.delete('/friends/decline/${notification.actorId}');
      }
      ref.read(notificationProvider.notifier).markAsRead(notification.id);
      ref
          .read(notificationProvider.notifier)
          .deleteNotification(notification.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Action failed. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ─── Notification Tile ──────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDismiss;
  final VoidCallback? onAcceptFriend;
  final VoidCallback? onRejectFriend;

  const _NotificationTile({
    required this.notification,
    required this.index,
    required this.onTap,
    required this.onDismiss,
    this.onAcceptFriend,
    this.onRejectFriend,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeInfo = _getTypeInfo(notification.type, scheme);

    return Dismissible(
          key: Key(notification.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.error.withAlpha(40),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.delete_rounded, color: scheme.error),
          ),
          onDismissed: (_) => onDismiss(),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: notification.isRead
                    ? (isDark
                          ? Colors.white.withAlpha(5)
                          : Colors.grey.withAlpha(10))
                    : scheme.primary.withAlpha(isDark ? 18 : 15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: notification.isRead
                      ? Colors.transparent
                      : scheme.primary.withAlpha(40),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Avatar with type icon overlay ──
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: scheme.primary.withAlpha(30),
                        backgroundImage:
                            notification.actorProfilePictureUrl != null
                            ? NetworkImage(
                                notification.actorProfilePictureUrl!.startsWith(
                                      'http',
                                    )
                                    ? notification.actorProfilePictureUrl!
                                    : '${ApiConstants.uploadsBase}/${notification.actorProfilePictureUrl}',
                              )
                            : null,
                        child: notification.actorProfilePictureUrl == null
                            ? Text(
                                notification.actorName.isNotEmpty
                                    ? notification.actorName[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: typeInfo.color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF0B0D21)
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            typeInfo.icon,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // ── Content ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: [
                              TextSpan(
                                text: notification.actorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: ' ${notification.message}'),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(notification.createdAt),
                          style: TextStyle(
                            color: notification.isRead
                                ? (isDark ? Colors.white38 : Colors.grey)
                                : scheme.primary,
                            fontSize: 12,
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                        // ── Friend request actions ──
                        if (notification.type == 'FriendRequest' &&
                            onAcceptFriend != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  label: 'Confirm',
                                  color: scheme.primary,
                                  textColor: isDark
                                      ? const Color(0xFF0B0D21)
                                      : Colors.white,
                                  onTap: onAcceptFriend!,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ActionButton(
                                  label: 'Delete',
                                  color: isDark
                                      ? Colors.white.withAlpha(20)
                                      : Colors.grey.withAlpha(40),
                                  textColor: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                  onTap: onRejectFriend!,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // ── Unread dot ──
                  if (!notification.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withAlpha(100),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 0.8, end: 1.2, duration: 1200.ms),
                  ],
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (50 * index.clamp(0, 15)).ms, duration: 300.ms)
        .slideX(
          begin: 0.05,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }

  static _TypeInfo _getTypeInfo(String type, ColorScheme scheme) {
    switch (type) {
      case 'FriendRequest':
        return _TypeInfo(Icons.person_add_rounded, scheme.primary);
      case 'FriendAccepted':
        return _TypeInfo(Icons.people_rounded, const Color(0xFF00E676));
      case 'PostReaction':
        return _TypeInfo(Icons.favorite_rounded, const Color(0xFFFF4081));
      case 'PostComment':
        return _TypeInfo(Icons.comment_rounded, const Color(0xFF7B2FBE));
      case 'CommentReaction':
        return _TypeInfo(Icons.thumb_up_rounded, const Color(0xFFFFD740));
      case 'ProfileReaction':
        return _TypeInfo(Icons.emoji_emotions_rounded, const Color(0xFFFF6D00));
      case 'CapsuleUnlocked':
        return _TypeInfo(Icons.lock_open_rounded, const Color(0xFF00E676));
      default:
        return _TypeInfo(Icons.notifications_rounded, scheme.primary);
    }
  }

  static String _formatTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _TypeInfo {
  final IconData icon;
  final Color color;
  const _TypeInfo(this.icon, this.color);
}

// ─── Action Button ──────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.textColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
