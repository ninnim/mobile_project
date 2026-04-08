import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_model.dart';
import '../providers/feed_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/fullscreen_image_viewer.dart';
import '../../../core/constants/api_constants.dart';

// ─── Reaction data ──────────────────────────────────────────────────────────

const _reactionEmojis = {
  'like': '👍',
  'love': '❤️',
  'haha': '😂',
  'wow': '😮',
  'sad': '😢',
  'angry': '😡',
};

const _reactionLabels = {
  'like': 'Like',
  'love': 'Love',
  'haha': 'Haha',
  'wow': 'Wow',
  'sad': 'Sad',
  'angry': 'Angry',
};

const _reactions = ['like', 'love', 'haha', 'wow', 'sad', 'angry'];
const _emojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];

// ─── PostCard ───────────────────────────────────────────────────────────────

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback? onTapUser;
  final void Function(String postId)? onLike;

  const PostCard({super.key, required this.post, this.onTapUser, this.onLike});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartCtrl;
  bool _showDoubleTapHeart = false;
  OverlayEntry? _reactionOverlay;

  @override
  void initState() {
    super.initState();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _removeReactionOverlay();
    super.dispose();
  }

  String? get _currentUserId => ref.read(authProvider).user?.id;

  bool get _isOwnPost => _currentUserId == widget.post.userId;

  void _handleReactionTap() {
    final post = widget.post;
    if (post.myReaction != null) {
      HapticFeedback.lightImpact();
      ref.read(feedProvider.notifier).removeReaction(post.id);
    } else {
      HapticFeedback.lightImpact();
      _heartCtrl.forward(from: 0);
      ref.read(feedProvider.notifier).reactToPost(post.id, 'like');
    }
  }

  void _doubleTapLike() {
    if (widget.post.myReaction == null) {
      HapticFeedback.lightImpact();
      _heartCtrl.forward(from: 0);
      ref.read(feedProvider.notifier).reactToPost(widget.post.id, 'like');
    }
    setState(() => _showDoubleTapHeart = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showDoubleTapHeart = false);
    });
  }

  void _showReactionPickerOverlay(BuildContext context) {
    HapticFeedback.mediumImpact();
    _removeReactionOverlay();

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _reactionOverlay = OverlayEntry(
      builder: (ctx) => _ReactionPickerOverlay(
        anchorOffset: offset,
        anchorSize: renderBox.size,
        currentReaction: widget.post.myReaction,
        onSelect: (type) {
          HapticFeedback.lightImpact();
          ref.read(feedProvider.notifier).reactToPost(widget.post.id, type);
          _removeReactionOverlay();
        },
        onDismiss: _removeReactionOverlay,
      ),
    );
    Overlay.of(context).insert(_reactionOverlay!);
  }

  void _removeReactionOverlay() {
    _reactionOverlay?.remove();
    _reactionOverlay = null;
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(postId: widget.post.id),
    );
  }

  void _openShare(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareSheet(post: widget.post),
    );
  }

  void _showPostMenu() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(Icons.edit_rounded, color: scheme.primary),
                title: const Text('Edit Post'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditDialog();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_rounded, color: scheme.error),
                title: Text(
                  'Delete Post',
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirm();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog() {
    final ctrl = TextEditingController(text: widget.post.displayContent);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Post'),
          content: TextField(
            controller: ctrl,
            maxLines: 5,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Edit your post...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await ref
                    .read(feedProvider.notifier)
                    .editPost(widget.post.id, ctrl.text.trim());
                if (mounted) {
                  final s = Theme.of(context).colorScheme;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok ? 'Post updated!' : 'Failed to update post',
                      ),
                      backgroundColor: ok ? s.primary : s.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirm() {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref
                  .read(feedProvider.notifier)
                  .deletePost(widget.post.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'Post deleted' : 'Failed to delete post',
                    ),
                    backgroundColor: ok ? scheme.primary : scheme.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReactorsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReactorsSheet(postId: widget.post.id),
    );
  }

  String _resolveUrl(String? url) {
    if (url == null) return '';
    return url.startsWith('http') ? url : '${ApiConstants.uploadsBase}/$url';
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final scheme = Theme.of(context).colorScheme;
    final mediaUrl = post.mediaUrl != null ? _resolveUrl(post.mediaUrl) : null;
    final hasReactions =
        post.reactionCounts.isNotEmpty && post.totalReactions > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
              child: Row(
                children: [
                  AvatarWidget(
                    url: post.userProfilePicture,
                    name: post.userName,
                    radius: 20,
                    onTap: widget.onTapUser,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: widget.onTapUser,
                          child: Text(
                            post.userName,
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontSize: 15),
                          ),
                        ),
                        if (post.taggedUsers.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: _TaggedUsersLine(
                              taggedUsers: post.taggedUsers,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          _timeAgo(post.createdAt),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onSurface.withAlpha(100),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (post.isSharedPost)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: scheme.primary.withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 12,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Shared',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_isOwnPost)
                    IconButton(
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: scheme.onSurface.withAlpha(120),
                      ),
                      onPressed: _showPostMenu,
                      splashRadius: 20,
                    ),
                ],
              ),
            ),

            // ── Caption / display content ───────────────────────────
            if (post.displayContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Text(
                  post.displayContent,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),

            // ── Shared post embed (new reference-based) ─────────────
            if (post.sharedPost != null)
              _SharedPostEmbedRef(
                data: post.sharedPost!,
                resolveUrl: _resolveUrl,
                postId: post.id,
              )
            // ── Shared post embed (old prefix-based) ────────────────
            else if (post.sharedData != null)
              _SharedPostEmbedLegacy(
                data: post.sharedData!,
                resolveUrl: _resolveUrl,
                postId: post.id,
              ),

            // ── Post image (non-shared posts) ──────────────────────
            if (!post.isSharedPost && mediaUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: GestureDetector(
                  onDoubleTap: _doubleTapLike,
                  onTap: () => FullscreenImageViewer.open(
                    context,
                    imageUrl: mediaUrl,
                    heroTag: 'post_img_${post.id}',
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Hero(
                        tag: 'post_img_${post.id}',
                        child: CachedNetworkImage(
                          imageUrl: mediaUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(height: 240, color: scheme.surface),
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      AnimatedScale(
                        scale: _showDoubleTapHeart ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.elasticOut,
                        child: AnimatedOpacity(
                          opacity: _showDoubleTapHeart ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 80,
                            color: Colors.white.withAlpha(220),
                            shadows: [
                              Shadow(
                                blurRadius: 20,
                                color: Colors.black.withAlpha(120),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 4),

            // ── Reaction summary strip (tappable to show who reacted) ──
            if (hasReactions)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: GestureDetector(
                  onTap: _showReactorsSheet,
                  child: _ReactionSummary(
                    reactionCounts: post.reactionCounts,
                    total: post.totalReactions,
                  ),
                ),
              ),

            // ── Divider ────────────────────────────────────────────
            Divider(
              height: 1,
              color: scheme.onSurface.withAlpha(15),
              indent: 14,
              endIndent: 14,
            ),

            // ── Action bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (btnCtx) => GestureDetector(
                        onLongPress: () => _showReactionPickerOverlay(btnCtx),
                        child: _ActionButton(
                          icon: post.myReaction != null
                              ? null
                              : Icons.thumb_up_off_alt_rounded,
                          emoji: post.myReaction != null
                              ? _reactionEmojis[post.myReaction] ?? '👍'
                              : null,
                          label: post.myReaction != null
                              ? (_reactionLabels[post.myReaction] ?? 'Like')
                              : 'Like',
                          color: post.myReaction != null
                              ? _getReactionColor(post.myReaction!, scheme)
                              : scheme.onSurface.withAlpha(140),
                          onTap: _handleReactionTap,
                          animCtrl: _heartCtrl,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Comment',
                      color: scheme.onSurface.withAlpha(140),
                      onTap: _openComments,
                    ),
                  ),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share',
                      color: scheme.onSurface.withAlpha(140),
                      onTap: () => _openShare(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getReactionColor(String type, ColorScheme scheme) {
    switch (type) {
      case 'love':
        return Colors.redAccent;
      case 'haha':
        return Colors.amber;
      case 'wow':
        return Colors.amber;
      case 'sad':
        return Colors.amber;
      case 'angry':
        return Colors.deepOrange;
      default:
        return scheme.primary;
    }
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Reaction Summary (shows emoji icons + total count) ─────────────────────

class _ReactionSummary extends StatelessWidget {
  final Map<String, int> reactionCounts;
  final int total;
  const _ReactionSummary({required this.reactionCounts, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEmojis = sorted
        .take(3)
        .map((e) => _reactionEmojis[e.key] ?? '👍')
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Emoji stack with overlapping circles
          SizedBox(
            width: topEmojis.length * 18.0 + 8,
            height: 28,
            child: Stack(
              children: [
                for (int i = 0; i < topEmojis.length; i++)
                  Positioned(
                    left: i * 16.0,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + i * 100),
                      curve: Curves.elasticOut,
                      builder: (_, v, child) =>
                          Transform.scale(scale: v, child: child),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.primary.withAlpha(40),
                              scheme.surface,
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withAlpha(25),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(topEmojis[i],
                            style: const TextStyle(fontSize: 15)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Total count
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: total),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (_, val, __) => Text(
              _formatCount(val),
              style: TextStyle(
                fontSize: 13,
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 2),
          // Individual emoji counts
          ...sorted.take(3).map((e) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_reactionEmojis[e.key] ?? '👍',
                        style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 2),
                    Text(
                      '${e.value}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withAlpha(120),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              size: 16, color: scheme.onSurface.withAlpha(80)),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

// ─── Enhanced 3D Reaction Picker Overlay with Drag ──────────────────────────

class _ReactionPickerOverlay extends StatefulWidget {
  final Offset anchorOffset;
  final Size anchorSize;
  final String? currentReaction;
  final void Function(String type) onSelect;
  final VoidCallback onDismiss;

  const _ReactionPickerOverlay({
    required this.anchorOffset,
    required this.anchorSize,
    this.currentReaction,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_ReactionPickerOverlay> createState() => _ReactionPickerOverlayState();
}

class _ReactionPickerOverlayState extends State<_ReactionPickerOverlay>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _bgFadeCtrl;
  int? _hoveredIndex;
  int? _selectedIndex;
  final List<GlobalKey> _emojiKeys = List.generate(6, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _bgFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();

    if (widget.currentReaction != null) {
      final idx = _reactions.indexOf(widget.currentReaction!);
      if (idx >= 0) _selectedIndex = idx;
    }
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _glowCtrl.dispose();
    _bgFadeCtrl.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final pos = details.globalPosition;
    int? found;
    for (int i = 0; i < _emojiKeys.length; i++) {
      final key = _emojiKeys[i];
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final topLeft = box.localToGlobal(Offset.zero);
      final rect = Rect.fromLTWH(
        topLeft.dx - 8,
        topLeft.dy - 20,
        box.size.width + 16,
        box.size.height + 40,
      );
      if (rect.contains(pos)) {
        found = i;
        break;
      }
    }
    if (found != _hoveredIndex) {
      if (found != null) HapticFeedback.selectionClick();
      setState(() => _hoveredIndex = found);
    }
  }

  void _handlePanEnd(DragEndDetails _) {
    if (_hoveredIndex != null) {
      widget.onSelect(_reactions[_hoveredIndex!]);
    } else {
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final top = (widget.anchorOffset.dy - 90).clamp(40.0, double.infinity);
    final left = (widget.anchorOffset.dx + widget.anchorSize.width / 2 - 160)
        .clamp(12.0, screenWidth - 332.0);

    return GestureDetector(
      onTap: widget.onDismiss,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      behavior: HitTestBehavior.translucent,
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Animated backdrop
            AnimatedBuilder(
              animation: _bgFadeCtrl,
              builder: (_, __) => Positioned.fill(
                child: Container(
                  color: Colors.black.withAlpha(
                      (35 * _bgFadeCtrl.value).round()),
                ),
              ),
            ),
            Positioned(
              top: top,
              left: left,
              child: AnimatedBuilder(
                animation: _entryCtrl,
                builder: (_, child) {
                  final t = Curves.elasticOut
                      .transform(_entryCtrl.value.clamp(0.0, 1.0));
                  return Transform.scale(
                    scale: t,
                    alignment: Alignment.bottomCenter,
                    child: Opacity(
                      opacity: (_entryCtrl.value * 2).clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: AnimatedBuilder(
                  animation: _glowCtrl,
                  builder: (_, child) {
                    final glowAlpha = (25 + 20 * _glowCtrl.value).round();
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withAlpha(glowAlpha),
                            blurRadius: 28,
                            spreadRadius: 3,
                          ),
                          BoxShadow(
                            color: Colors.black.withAlpha(30),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Material(
                    elevation: 16,
                    shadowColor: Colors.black.withAlpha(70),
                    borderRadius: BorderRadius.circular(36),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A1D3D)
                        : Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withAlpha(25),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_reactions.length, (i) {
                          return _EmojiItem3D(
                            key: _emojiKeys[i],
                            emoji: _emojis[i],
                            label: _reactionLabels[_reactions[i]] ?? '',
                            isHovered: _hoveredIndex == i,
                            isSelected: _selectedIndex == i,
                            index: i,
                            entryAnimation: _entryCtrl,
                            onTap: () => widget.onSelect(_reactions[i]),
                            onHoverStart: () {
                              HapticFeedback.selectionClick();
                              setState(() => _hoveredIndex = i);
                            },
                            onHoverEnd: () =>
                                setState(() => _hoveredIndex = null),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Hovered emoji name floating indicator
            if (_hoveredIndex != null)
              Positioned(
                top: top - 22,
                left: left + 12 + _hoveredIndex! * 48.0,
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _reactionLabels[_reactions[_hoveredIndex!]] ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── 3D Emoji Item with bounce/perspective animation ────────────────────────

class _EmojiItem3D extends StatefulWidget {
  final String emoji;
  final String label;
  final bool isHovered;
  final bool isSelected;
  final int index;
  final Animation<double> entryAnimation;
  final VoidCallback onTap;
  final VoidCallback onHoverStart;
  final VoidCallback onHoverEnd;

  const _EmojiItem3D({
    super.key,
    required this.emoji,
    required this.label,
    required this.isHovered,
    required this.isSelected,
    required this.index,
    required this.entryAnimation,
    required this.onTap,
    required this.onHoverStart,
    required this.onHoverEnd,
  });

  @override
  State<_EmojiItem3D> createState() => _EmojiItem3DState();
}

class _EmojiItem3DState extends State<_EmojiItem3D>
    with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late AnimationController _wobbleCtrl;
  late AnimationController _shineCtrl;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _wobbleCtrl.dispose();
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _EmojiItem3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHovered && !oldWidget.isHovered) {
      _bounceCtrl.forward(from: 0);
      _wobbleCtrl.forward(from: 0);
      _shineCtrl.forward(from: 0);
    }
    if (!widget.isHovered && oldWidget.isHovered) {
      _wobbleCtrl.stop();
      _shineCtrl.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scale = widget.isHovered ? 1.65 : (widget.isSelected ? 1.2 : 1.0);
    final yOffset = widget.isHovered ? -28.0 : 0.0;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => widget.onHoverStart(),
      onTapCancel: widget.onHoverEnd,
      onTapUp: (_) => widget.onHoverEnd(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 300 + widget.index * 60),
        curve: Curves.elasticOut,
        builder: (_, entryVal, child) =>
            Transform.scale(scale: entryVal, child: child),
        child: AnimatedBuilder(
          animation: Listenable.merge([_bounceCtrl, _wobbleCtrl]),
          builder: (_, child) {
            final bounce = math.sin(_bounceCtrl.value * math.pi * 2) * 6;
            final wobble = math.sin(_wobbleCtrl.value * math.pi * 3) * 3;
            final rotZ = widget.isHovered
                ? math.sin(_wobbleCtrl.value * math.pi * 2) * 0.15
                : 0.0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              transform: Matrix4.identity()
                ..translate(wobble, yOffset - bounce.abs(), 0.0)
                ..scale(scale, scale, 1.0)
                ..setEntry(3, 2, 0.003)
                ..rotateX(widget.isHovered ? -0.15 : 0.0)
                ..rotateY(widget.isHovered ? 0.08 : 0.0)
                ..rotateZ(rotZ),
              transformAlignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: widget.isHovered ? 3 : 6,
                vertical: 2,
              ),
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label tooltip
              AnimatedOpacity(
                opacity: widget.isHovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 120),
                child: AnimatedSlide(
                  offset: Offset(0, widget.isHovered ? 0 : 0.5),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary.withAlpha(40),
                          scheme.primary.withAlpha(20),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.primary.withAlpha(80)),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withAlpha(30),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
              // Emoji with 3D glow + shine
              AnimatedBuilder(
                animation: _shineCtrl,
                builder: (_, child) {
                  return Container(
                    decoration: widget.isHovered
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: scheme.primary.withAlpha(
                                    (50 + 30 * math.sin(_shineCtrl.value * math.pi)).round()),
                                blurRadius: 18,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: Colors.white.withAlpha(
                                    (20 * _shineCtrl.value).round()),
                                blurRadius: 6,
                              ),
                            ],
                          )
                        : null,
                    child: child,
                  );
                },
                child: Text(
                  widget.emoji,
                  style: TextStyle(
                    fontSize: widget.isHovered ? 40 : 28,
                    shadows: widget.isHovered
                        ? [
                            Shadow(
                              blurRadius: 12,
                              color: Colors.black.withAlpha(50),
                              offset: const Offset(0, 6),
                            ),
                            Shadow(
                              blurRadius: 4,
                              color: Colors.white.withAlpha(30),
                              offset: const Offset(-1, -2),
                            ),
                          ]
                        : [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black.withAlpha(20),
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reactors Sheet (shows who reacted) ─────────────────────────────────────

class _ReactorsSheet extends ConsumerStatefulWidget {
  final String postId;
  const _ReactorsSheet({required this.postId});

  @override
  ConsumerState<_ReactorsSheet> createState() => _ReactorsSheetState();
}

class _ReactorsSheetState extends ConsumerState<_ReactorsSheet> {
  ReactionSummaryModel? _summary;
  bool _loading = true;
  String? _filterType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary =
        await ref.read(feedProvider.notifier).getPostReactors(widget.postId);
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  List<ReactorModel> get _filteredReactors {
    if (_summary == null) return [];
    if (_filterType == null) return _summary!.reactors;
    return _summary!.reactors
        .where((r) => r.reactionType == _filterType)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final types = _summary?.counts.keys.toList() ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Reactions',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (_summary != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_summary!.total}',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (!_loading && types.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _FilterChip(
                    label: 'All',
                    count: _summary!.total,
                    isSelected: _filterType == null,
                    onTap: () => setState(() => _filterType = null),
                  ),
                  ...types.map((type) => _FilterChip(
                        emoji: _reactionEmojis[type] ?? '👍',
                        count: _summary!.counts[type] ?? 0,
                        isSelected: _filterType == type,
                        onTap: () => setState(() => _filterType = type),
                      )),
                ],
              ),
            ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReactors.isEmpty
                    ? Center(
                        child: Text(
                          'No reactions yet',
                          style:
                              TextStyle(color: scheme.onSurface.withAlpha(100)),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: _filteredReactors.length,
                        itemBuilder: (_, i) {
                          final reactor = _filteredReactors[i];
                          return ListTile(
                            leading: Stack(
                              children: [
                                AvatarWidget(
                                  url: reactor.profilePictureUrl,
                                  name: reactor.displayName,
                                  radius: 20,
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context,
                                        '/user-profile',
                                        arguments: reactor.userId);
                                  },
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: scheme.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: scheme.surface, width: 1),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _reactionEmojis[reactor.reactionType] ??
                                          '👍',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              reactor.displayName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            trailing: Text(
                              _reactionEmojis[reactor.reactionType] ?? '👍',
                              style: const TextStyle(fontSize: 20),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/user-profile',
                                  arguments: reactor.userId);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String? label;
  final String? emoji;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    this.label,
    this.emoji,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:
                isSelected ? scheme.primary.withAlpha(25) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? scheme.primary
                  : scheme.onSurface.withAlpha(30),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 16)),
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? scheme.primary : scheme.onSurface,
                  ),
                ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? scheme.primary
                      : scheme.onSurface.withAlpha(100),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tagged Users Line ──────────────────────────────────────────────────────

class _TaggedUsersLine extends StatelessWidget {
  final List<TaggedUser> taggedUsers;
  const _TaggedUsersLine({required this.taggedUsers});

  @override
  Widget build(BuildContext context) {
    if (taggedUsers.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final first = taggedUsers.first;
    final othersCount = taggedUsers.length - 1;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/user-profile', arguments: first.userId);
      },
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 12,
            color: scheme.onSurface.withAlpha(140),
          ),
          children: [
            const TextSpan(text: 'with '),
            TextSpan(
              text: first.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
            if (othersCount > 0) ...[
              const TextSpan(text: ' and '),
              TextSpan(
                text: '$othersCount other${othersCount > 1 ? 's' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ],
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─── Action button ──────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  final IconData? icon;
  final String? emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final AnimationController? animCtrl;

  const _ActionButton({
    this.icon,
    this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.animCtrl,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    Widget leading;
    if (widget.emoji != null) {
      leading = Text(widget.emoji!, style: const TextStyle(fontSize: 18));
      if (widget.animCtrl != null) {
        leading = AnimatedBuilder(
          animation: widget.animCtrl!,
          builder: (_, child) => Transform.scale(
            scale: 1.0 +
                0.3 * Curves.elasticOut.transform(widget.animCtrl!.value),
            child: child,
          ),
          child: leading,
        );
      }
    } else {
      leading = Icon(widget.icon, size: 20, color: widget.color);
      if (widget.animCtrl != null) {
        leading = AnimatedBuilder(
          animation: widget.animCtrl!,
          builder: (_, child) => Transform.scale(
            scale: 1.0 +
                0.3 * Curves.elasticOut.transform(widget.animCtrl!.value),
            child: child,
          ),
          child: leading,
        );
      }
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.85),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared Post Embed (reference-based, new) ──────────────────────────────

class _SharedPostEmbedRef extends StatelessWidget {
  final SharedPostRef data;
  final String Function(String?) resolveUrl;
  final String postId;

  const _SharedPostEmbedRef({
    required this.data,
    required this.resolveUrl,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (data.isUnavailable) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Container(
          decoration: BoxDecoration(
            color:
                isDark ? scheme.error.withAlpha(15) : Colors.red.withAlpha(10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.error.withAlpha(40)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.error.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.link_off_rounded, color: scheme.error, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Content Unavailable',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: scheme.error)),
                    const SizedBox(height: 2),
                    Text(
                        'This post has been removed by the original author.',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurface.withAlpha(120))),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final mediaUrl = data.mediaUrl != null ? resolveUrl(data.mediaUrl) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/user-profile', arguments: data.userId);
        },
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? scheme.surface.withAlpha(120)
                : const Color(0xFFF5F7FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark
                    ? scheme.primary.withAlpha(30)
                    : Colors.grey.withAlpha(40)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    AvatarWidget(
                        url: data.userProfilePicture,
                        name: data.userName,
                        radius: 14),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(data.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13))),
                    Icon(Icons.public_rounded,
                        size: 14, color: scheme.onSurface.withAlpha(80)),
                  ],
                ),
              ),
              if (data.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Text(data.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 14)),
                ),
              if (mediaUrl != null && mediaUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () => FullscreenImageViewer.open(context,
                        imageUrl: mediaUrl, heroTag: 'shared_img_$postId'),
                    child: Hero(
                      tag: 'shared_img_$postId',
                      child: CachedNetworkImage(
                        imageUrl: mediaUrl,
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(height: 180, color: scheme.surface),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared Post Embed (legacy prefix-based) ────────────────────────────────

class _SharedPostEmbedLegacy extends StatelessWidget {
  final SharedPostData data;
  final String Function(String?) resolveUrl;
  final String postId;

  const _SharedPostEmbedLegacy({
    required this.data,
    required this.resolveUrl,
    required this.postId,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaUrl = data.originalMediaUrl != null
        ? resolveUrl(data.originalMediaUrl)
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? scheme.surface.withAlpha(120)
              : const Color(0xFFF5F7FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark
                  ? scheme.primary.withAlpha(30)
                  : Colors.grey.withAlpha(40)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  AvatarWidget(
                      url: data.originalUserPicture,
                      name: data.originalUserName,
                      radius: 14),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(data.originalUserName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13))),
                  Icon(Icons.public_rounded,
                      size: 14, color: scheme.onSurface.withAlpha(80)),
                ],
              ),
            ),
            if (data.originalContent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(data.originalContent,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 14)),
              ),
            if (mediaUrl != null && mediaUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GestureDetector(
                  onTap: () => FullscreenImageViewer.open(context,
                      imageUrl: mediaUrl, heroTag: 'shared_img_$postId'),
                  child: Hero(
                    tag: 'shared_img_$postId',
                    child: CachedNetworkImage(
                      imageUrl: mediaUrl,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(height: 180, color: scheme.surface),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

// ─── Enhanced Comments Sheet with Reactions ─────────────────────────────────

class _CommentsSheet extends ConsumerStatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  List<CommentModel> _comments = [];
  bool _loading = true;
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ref.read(feedProvider.notifier).getComments(widget.postId);
    if (mounted) {
      setState(() {
        _comments = c;
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    await ref.read(feedProvider.notifier).addComment(widget.postId, text);
    _ctrl.clear();
    await _load();
    setState(() => _sending = false);
  }

  void _reactToComment(int index, String reactionType) {
    final comment = _comments[index];
    final newCounts = Map<String, int>.from(comment.reactionCounts);
    if (comment.myReaction != null &&
        newCounts.containsKey(comment.myReaction!)) {
      newCounts[comment.myReaction!] = (newCounts[comment.myReaction!]! - 1);
      if (newCounts[comment.myReaction!]! <= 0) {
        newCounts.remove(comment.myReaction!);
      }
    }
    newCounts[reactionType] = (newCounts[reactionType] ?? 0) + 1;

    setState(() {
      _comments[index] = comment.copyWith(
        myReaction: reactionType,
        reactionCounts: newCounts,
        totalReactions: newCounts.values.fold<int>(0, (a, b) => a + b),
      );
    });

    ref
        .read(feedProvider.notifier)
        .reactToComment(widget.postId, comment.id, reactionType);
  }

  void _removeCommentReaction(int index) {
    final comment = _comments[index];
    if (comment.myReaction == null) return;

    final newCounts = Map<String, int>.from(comment.reactionCounts);
    if (newCounts.containsKey(comment.myReaction!)) {
      newCounts[comment.myReaction!] = (newCounts[comment.myReaction!]! - 1);
      if (newCounts[comment.myReaction!]! <= 0) {
        newCounts.remove(comment.myReaction!);
      }
    }

    setState(() {
      _comments[index] = comment.copyWith(
        clearReaction: true,
        reactionCounts: newCounts,
        totalReactions: newCounts.values.fold<int>(0, (a, b) => a + b),
      );
    });

    ref
        .read(feedProvider.notifier)
        .removeCommentReaction(widget.postId, comment.id);
  }

  void _showCommentReactors(CommentModel comment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentReactorsSheet(
        postId: widget.postId,
        commentId: comment.id,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Comments',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48,
                                color: scheme.onSurface.withAlpha(60)),
                            const SizedBox(height: 12),
                            Text('No comments yet',
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                            const SizedBox(height: 4),
                            Text('Be the first to comment!',
                                style:
                                    Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: scheme.onSurface.withAlpha(15),
                          indent: 68,
                        ),
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          return _CommentTile(
                            comment: c,
                            onTapUser: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/user-profile',
                                  arguments: c.userId);
                            },
                            onReact: (type) => _reactToComment(i, type),
                            onRemoveReaction: () =>
                                _removeCommentReaction(i),
                            onTapReactions: () => _showCommentReactors(c),
                          );
                        },
                      ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: scheme.onSurface.withAlpha(15)),
              ),
            ),
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              top: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      suffixIcon: IconButton(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : Icon(Icons.send_rounded,
                                color: scheme.primary, size: 20),
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Enhanced Comment Tile with Reactions ────────────────────────────────────

class _CommentTile extends StatefulWidget {
  final CommentModel comment;
  final VoidCallback onTapUser;
  final void Function(String type) onReact;
  final VoidCallback onRemoveReaction;
  final VoidCallback onTapReactions;

  const _CommentTile({
    required this.comment,
    required this.onTapUser,
    required this.onReact,
    required this.onRemoveReaction,
    required this.onTapReactions,
  });

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  bool _showReactionPicker = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    final scheme = Theme.of(context).colorScheme;
    final hasReactions = c.reactionCounts.isNotEmpty && c.totalReactions > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: widget.onTapUser,
                child: AvatarWidget(
                  url: c.userProfilePicture,
                  name: c.userName,
                  radius: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.surface.withAlpha(180),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: scheme.onSurface.withAlpha(15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: widget.onTapUser,
                            child: Text(c.userName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                          const SizedBox(height: 2),
                          Text(c.content,
                              style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          _timeAgo(c.createdAt),
                          style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurface.withAlpha(80)),
                        ),
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            if (c.myReaction != null) {
                              widget.onRemoveReaction();
                            } else {
                              widget.onReact('like');
                            }
                          },
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            setState(() =>
                                _showReactionPicker = !_showReactionPicker);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (c.myReaction != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 3),
                                  child: Text(
                                    _reactionEmojis[c.myReaction!] ?? '👍',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              Text(
                                c.myReaction != null
                                    ? (_reactionLabels[c.myReaction!] ??
                                        'Like')
                                    : 'Like',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: c.myReaction != null
                                      ? _getCommentReactionColor(
                                          c.myReaction!, scheme)
                                      : scheme.onSurface.withAlpha(120),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (hasReactions)
                          GestureDetector(
                            onTap: widget.onTapReactions,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ...c.reactionCounts.entries
                                    .toList()
                                    .take(3)
                                    .map((e) => Padding(
                                          padding:
                                              const EdgeInsets.only(right: 1),
                                          child: Text(
                                              _reactionEmojis[e.key] ?? '👍',
                                              style: const TextStyle(
                                                  fontSize: 12)),
                                        )),
                                const SizedBox(width: 2),
                                Text(
                                  '${c.totalReactions}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface.withAlpha(100),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    if (_showReactionPicker)
                      _CommentReactionPicker(
                        currentReaction: c.myReaction,
                        onSelect: (type) {
                          widget.onReact(type);
                          setState(() => _showReactionPicker = false);
                        },
                        onDismiss: () =>
                            setState(() => _showReactionPicker = false),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getCommentReactionColor(String type, ColorScheme scheme) {
    switch (type) {
      case 'love':
        return Colors.redAccent;
      case 'haha':
      case 'wow':
      case 'sad':
        return Colors.amber.shade700;
      case 'angry':
        return Colors.deepOrange;
      default:
        return scheme.primary;
    }
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }
}

// ─── Enhanced Comment Reaction Picker with 3D hover effect ──────────────────

class _CommentReactionPicker extends StatefulWidget {
  final String? currentReaction;
  final void Function(String type) onSelect;
  final VoidCallback onDismiss;

  const _CommentReactionPicker({
    this.currentReaction,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_CommentReactionPicker> createState() => _CommentReactionPickerState();
}

class _CommentReactionPickerState extends State<_CommentReactionPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _entryCtrl,
      builder: (_, child) {
        final t = Curves.elasticOut.transform(_entryCtrl.value.clamp(0.0, 1.0));
        return Transform.scale(
          scale: t,
          alignment: Alignment.centerLeft,
          child: Opacity(
            opacity: (_entryCtrl.value * 2).clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onPanUpdate: (details) {
          // Drag-to-select within the picker row
          final RenderBox? box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(details.globalPosition);
          final emojiWidth = box.size.width / 6;
          final idx = (local.dx / emojiWidth).floor().clamp(0, 5);
          if (idx != _hoveredIndex) {
            HapticFeedback.selectionClick();
            setState(() => _hoveredIndex = idx);
          }
        },
        onPanEnd: (_) {
          if (_hoveredIndex != null) {
            HapticFeedback.lightImpact();
            widget.onSelect(_reactions[_hoveredIndex!]);
          }
          setState(() => _hoveredIndex = null);
        },
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.primary.withAlpha(50)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withAlpha(20),
                blurRadius: 16,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_reactions.length, (i) {
              final isCurrent = widget.currentReaction == _reactions[i];
              final isHovered = _hoveredIndex == i;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onSelect(_reactions[i]);
                },
                onTapDown: (_) => setState(() => _hoveredIndex = i),
                onTapCancel: () => setState(() => _hoveredIndex = null),
                onTapUp: (_) => setState(() => _hoveredIndex = null),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 200 + i * 40),
                  curve: Curves.elasticOut,
                  builder: (_, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutBack,
                    transform: Matrix4.identity()
                      ..translate(0.0, isHovered ? -12.0 : 0.0)
                      ..scale(
                          isHovered ? 1.45 : (isCurrent ? 1.15 : 1.0),
                          isHovered ? 1.45 : (isCurrent ? 1.15 : 1.0)),
                    transformAlignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3),
                    decoration: (isCurrent && !isHovered)
                        ? BoxDecoration(
                            color: scheme.primary.withAlpha(25),
                            shape: BoxShape.circle,
                          )
                        : isHovered
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.primary.withAlpha(40),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              )
                            : null,
                    child: Text(
                      _emojis[i],
                      style: TextStyle(
                        fontSize: isHovered ? 26 : (isCurrent ? 22 : 18),
                        shadows: isHovered
                            ? [
                                Shadow(
                                  blurRadius: 8,
                                  color: Colors.black.withAlpha(40),
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─── Comment Reactors Sheet ─────────────────────────────────────────────────

class _CommentReactorsSheet extends ConsumerStatefulWidget {
  final String postId;
  final String commentId;
  const _CommentReactorsSheet(
      {required this.postId, required this.commentId});

  @override
  ConsumerState<_CommentReactorsSheet> createState() =>
      _CommentReactorsSheetState();
}

class _CommentReactorsSheetState
    extends ConsumerState<_CommentReactorsSheet> {
  ReactionSummaryModel? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final summary = await ref
        .read(feedProvider.notifier)
        .getCommentReactors(widget.postId, widget.commentId);
    if (mounted) {
      setState(() {
        _summary = summary;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text('Comment Reactions',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          const Divider(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_summary == null || _summary!.reactors.isEmpty)
                    ? Center(
                        child: Text('No reactions',
                            style: TextStyle(
                                color: scheme.onSurface.withAlpha(100))))
                    : ListView.builder(
                        itemCount: _summary!.reactors.length,
                        itemBuilder: (_, i) {
                          final r = _summary!.reactors[i];
                          return ListTile(
                            leading: Stack(
                              children: [
                                AvatarWidget(
                                    url: r.profilePictureUrl,
                                    name: r.displayName,
                                    radius: 18),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: scheme.surface,
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                        _reactionEmojis[r.reactionType] ??
                                            '👍',
                                        style:
                                            const TextStyle(fontSize: 9)),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(r.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            trailing: Text(
                                _reactionEmojis[r.reactionType] ?? '👍',
                                style: const TextStyle(fontSize: 18)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/user-profile',
                                  arguments: r.userId);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Share Sheet (reference-based) ──────────────────────────────────────────

class _ShareSheet extends ConsumerStatefulWidget {
  final PostModel post;
  const _ShareSheet({required this.post});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet>
    with SingleTickerProviderStateMixin {
  final _captionCtrl = TextEditingController();
  bool _sharing = false;
  late AnimationController _slideCtrl;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  String _resolveUrl(String? url) {
    if (url == null) return '';
    return url.startsWith('http') ? url : '${ApiConstants.uploadsBase}/$url';
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final String originalPostId;
      if (widget.post.sharedPost != null &&
          !widget.post.sharedPost!.isUnavailable) {
        originalPostId = widget.post.sharedPost!.id;
      } else {
        originalPostId = widget.post.id;
      }

      final caption = _captionCtrl.text.trim();
      final ok = await ref
          .read(feedProvider.notifier)
          .sharePost(originalPostId, caption);

      if (mounted) {
        Navigator.pop(context);
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                    ok ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: Colors.white,
                    size: 18),
                const SizedBox(width: 8),
                Text(ok ? 'Shared to your feed!' : 'Failed to share',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: ok ? scheme.primary : scheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        final scheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to share'),
            backgroundColor: scheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mediaUrl = widget.post.mediaUrl != null
        ? _resolveUrl(widget.post.mediaUrl)
        : null;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(
              parent: _slideCtrl, curve: Curves.easeOutCubic)),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1130) : Colors.white,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 20,
                offset: const Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 0),
              child: Row(
                children: [
                  Icon(Icons.repeat_rounded,
                      size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text('Share Post',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  FilledButton(
                    onPressed: _sharing ? null : _share,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Share',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ],
              ),
            ),
            Divider(color: scheme.onSurface.withAlpha(15), height: 20),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _captionCtrl,
                      autofocus: true,
                      maxLines: 4,
                      minLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Say something about this...',
                        hintStyle:
                            TextStyle(color: scheme.onSurface.withAlpha(80)),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? scheme.surface.withAlpha(120)
                            : const Color(0xFFF5F7FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isDark
                                ? scheme.primary.withAlpha(30)
                                : Colors.grey.withAlpha(40)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(12, 10, 12, 0),
                            child: Row(
                              children: [
                                AvatarWidget(
                                    url: widget.post.userProfilePicture,
                                    name: widget.post.userName,
                                    radius: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(widget.post.userName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13))),
                              ],
                            ),
                          ),
                          if (widget.post.displayContent.isNotEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: Text(widget.post.displayContent,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14)),
                            ),
                          if (mediaUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: CachedNetworkImage(
                                imageUrl: mediaUrl,
                                width: double.infinity,
                                height: 160,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                    height: 160, color: scheme.surface),
                                errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
