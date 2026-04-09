import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../feed/models/post_model.dart';
import '../../feed/widgets/post_card.dart';

// Reaction data for profile reactions
const _reactionEmojis = {
  'like': '👍',
  'love': '❤️',
  'haha': '😂',
  'wow': '😮',
  'sad': '😢',
  'angry': '😡',
};
const _reactions = ['like', 'love', 'haha', 'wow', 'sad', 'angry'];
const _emojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String _friendStatus = 'none'; // none | pending | requested | friends
  bool _actionLoading = false;
  List<PostModel> _posts = [];
  bool _postsLoading = true;

  // Profile reactions
  String? _myProfileReaction;
  Map<String, int> _profileReactionCounts = {};
  int _profileReactionTotal = 0;
  List<Map<String, dynamic>> _profileReactors = [];
  bool _showProfileReactionPicker = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await dioClient.get('/auth/users/${widget.userId}');
      final statusRes = await dioClient.get('/friends/status/${widget.userId}');
      if (mounted) {
        setState(() {
          _user = res.data as Map<String, dynamic>;
          _friendStatus = _normalizeStatus(
            (statusRes.data as Map<String, dynamic>)['status'] as String? ??
                'None',
          );
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
    _loadPosts();
    _loadProfileReactions();
  }

  Future<void> _loadProfileReactions() async {
    try {
      final res = await dioClient.get('/auth/users/${widget.userId}/reactions');
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _myProfileReaction = data['myReaction'] as String?;
          _profileReactionTotal = data['totalReactions'] as int? ?? 0;
          final counts = <String, int>{};
          final reactors = (data['reactors'] as List<dynamic>?) ?? [];
          _profileReactors = reactors
              .map((e) => e as Map<String, dynamic>)
              .toList();
          for (final r in _profileReactors) {
            final type = r['reactionType'] as String? ?? 'like';
            counts[type] = (counts[type] ?? 0) + 1;
          }
          _profileReactionCounts = counts;
        });
      }
    } catch (_) {}
  }

  Future<void> _reactToProfile(String reactionType) async {
    HapticFeedback.lightImpact();
    final oldReaction = _myProfileReaction;
    final oldCounts = Map<String, int>.from(_profileReactionCounts);
    final oldTotal = _profileReactionTotal;

    // Optimistic update
    final newCounts = Map<String, int>.from(_profileReactionCounts);
    if (_myProfileReaction != null &&
        newCounts.containsKey(_myProfileReaction!)) {
      newCounts[_myProfileReaction!] = (newCounts[_myProfileReaction!]! - 1);
      if (newCounts[_myProfileReaction!]! <= 0)
        newCounts.remove(_myProfileReaction!);
    }
    newCounts[reactionType] = (newCounts[reactionType] ?? 0) + 1;

    setState(() {
      _myProfileReaction = reactionType;
      _profileReactionCounts = newCounts;
      _profileReactionTotal = newCounts.values.fold(0, (a, b) => a + b);
      _showProfileReactionPicker = false;
    });

    try {
      await dioClient.post(
        '/auth/users/${widget.userId}/reactions',
        data: {'reactionType': reactionType},
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _myProfileReaction = oldReaction;
          _profileReactionCounts = oldCounts;
          _profileReactionTotal = oldTotal;
        });
      }
    }
  }

  Future<void> _removeProfileReaction() async {
    if (_myProfileReaction == null) return;
    HapticFeedback.lightImpact();
    final oldReaction = _myProfileReaction;
    final oldCounts = Map<String, int>.from(_profileReactionCounts);
    final oldTotal = _profileReactionTotal;

    final newCounts = Map<String, int>.from(_profileReactionCounts);
    if (newCounts.containsKey(_myProfileReaction!)) {
      newCounts[_myProfileReaction!] = (newCounts[_myProfileReaction!]! - 1);
      if (newCounts[_myProfileReaction!]! <= 0)
        newCounts.remove(_myProfileReaction!);
    }

    setState(() {
      _myProfileReaction = null;
      _profileReactionCounts = newCounts;
      _profileReactionTotal = newCounts.values.fold(0, (a, b) => a + b);
    });

    try {
      await dioClient.delete('/auth/users/${widget.userId}/reactions');
    } catch (_) {
      if (mounted) {
        setState(() {
          _myProfileReaction = oldReaction;
          _profileReactionCounts = oldCounts;
          _profileReactionTotal = oldTotal;
        });
      }
    }
  }

  void _showProfileReactorsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProfileReactorsSheet(
        reactors: _profileReactors,
        counts: _profileReactionCounts,
        total: _profileReactionTotal,
      ),
    );
  }

  Future<void> _loadPosts() async {
    try {
      final res = await dioClient.get('/posts/user/${widget.userId}');
      final data = res.data;
      List<dynamic> items;
      if (data is Map && data['items'] != null) {
        items = data['items'] as List<dynamic>;
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      if (mounted) {
        setState(() {
          _posts = items
              .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _postsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  /// Normalize backend status strings to internal values
  String _normalizeStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'accepted':
        return 'friends';
      case 'pending':
        return 'pending';
      case 'requested':
        return 'requested';
      default:
        return 'none';
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendRequest() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    HapticFeedback.lightImpact();
    try {
      await dioClient.post('/friends/request/${widget.userId}');
      if (mounted) {
        setState(() => _friendStatus = 'pending');
        _showSnack('Friend request sent!');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to send request', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _cancelRequest() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    HapticFeedback.lightImpact();
    try {
      await dioClient.delete('/friends/${widget.userId}');
      if (mounted) {
        setState(() => _friendStatus = 'none');
        _showSnack('Request cancelled');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to cancel request', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _acceptRequest() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    HapticFeedback.lightImpact();
    try {
      await dioClient.put('/friends/accept/${widget.userId}');
      if (mounted) {
        setState(() => _friendStatus = 'friends');
        _showSnack('You are now friends!');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to accept request', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _declineRequest() async {
    if (_actionLoading) return;
    setState(() => _actionLoading = true);
    HapticFeedback.lightImpact();
    try {
      await dioClient.delete('/friends/decline/${widget.userId}');
      if (mounted) {
        setState(() => _friendStatus = 'none');
        _showSnack('Request declined');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to decline request', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _removeFriend() async {
    final name = _user?['displayName'] as String? ?? 'this user';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Friend'),
        content: Text('Are you sure you want to unfriend $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || _actionLoading) return;
    setState(() => _actionLoading = true);
    HapticFeedback.lightImpact();
    try {
      await dioClient.delete('/friends/${widget.userId}');
      if (mounted) {
        setState(() => _friendStatus = 'none');
        _showSnack('Friend removed');
      }
    } catch (_) {
      if (mounted) _showSnack('Failed to remove friend', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _toggleLike(String postId) async {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final post = _posts[idx];
    setState(() {
      _posts[idx] = post.copyWith(
        isLikedByMe: !post.isLikedByMe,
        likeCount: post.isLikedByMe ? post.likeCount - 1 : post.likeCount + 1,
      );
    });
    try {
      if (post.isLikedByMe) {
        await dioClient.delete('/posts/$postId/like');
      } else {
        await dioClient.post('/posts/$postId/like');
      }
    } catch (_) {
      if (mounted) setState(() => _posts[idx] = post);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(80),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? _buildSkeleton(context, scheme, isDark)
          : _user == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 56,
                    color: scheme.onSurface.withAlpha(60),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'User not found',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: () async => _load(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildProfileHeader(context, scheme, isDark),
                  _buildStatsBar(context, scheme, isDark),
                  _buildPostsSection(context, scheme, isDark),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  // ── Skeleton Loading ──────────────────────────────────────────────────────
  Widget _buildSkeleton(BuildContext context, ColorScheme scheme, bool isDark) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Cover shimmer
          Shimmer.fromColors(
            baseColor: isDark
                ? const Color(0xFF1A1D3D)
                : const Color(0xFFE0E0E0),
            highlightColor: isDark
                ? const Color(0xFF2A2D5D)
                : const Color(0xFFF5F5F5),
            child: Container(height: 160, color: const Color(0xFF1A1D3D)),
          ),
          const SizedBox(height: 16),
          // Profile row shimmer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const SkeletonBox(width: 72, height: 72, borderRadius: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        height: 18,
                      ),
                      const SizedBox(height: 8),
                      SkeletonBox(
                        width: MediaQuery.of(context).size.width * 0.55,
                        height: 12,
                      ),
                      const SizedBox(height: 10),
                      const SkeletonBox(
                        width: 120,
                        height: 32,
                        borderRadius: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Stats shimmer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(
                3,
                (_) => const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: SkeletonBox(
                      width: double.infinity,
                      height: 52,
                      borderRadius: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Post skeletons
          ...List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SkeletonCard(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile Header ─────────────────────────────────────────────────────────
  Widget _buildProfileHeader(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    final name = _user!['displayName'] as String? ?? 'Unknown';
    final pic = _user!['profilePictureUrl'] as String?;
    final bio = _user!['bio'] as String?;
    final createdAt = _user!['createdAt'] as String?;

    String? memberSince;
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        memberSince = 'Joined ${months[dt.month - 1]} ${dt.year}';
      } catch (_) {}
    }

    return SliverToBoxAdapter(
      child: Column(
        children: [
          // Cover gradient
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.secondary.withAlpha(180),
                  scheme.primary.withAlpha(80),
                ],
              ),
            ),
          ),
          // Profile row overlapping cover
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Avatar with border
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withAlpha(60),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: AvatarWidget(url: pic, name: name, radius: 36),
                  ),
                  const SizedBox(width: 14),
                  // Name + bio + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 34),
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (bio != null && bio.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              bio,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurface.withAlpha(160),
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (memberSince != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 11,
                                  color: scheme.onSurface.withAlpha(100),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  memberSince,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface.withAlpha(100),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Action buttons row + reaction button
          Transform.translate(
            offset: const Offset(0, -18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildFriendButton(scheme)),
                      const SizedBox(width: 10),
                      _buildMessageButton(scheme),
                      const SizedBox(width: 10),
                      _buildReactButton(scheme),
                    ],
                  ),
                  // Profile reaction summary
                  if (_profileReactionTotal > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: GestureDetector(
                        onTap: _showProfileReactorsSheet,
                        child: _ProfileReactionSummary(
                          reactionCounts: _profileReactionCounts,
                          total: _profileReactionTotal,
                        ),
                      ),
                    ),
                  // Inline reaction picker
                  if (_showProfileReactionPicker)
                    _ProfileReactionPicker(
                      currentReaction: _myProfileReaction,
                      onSelect: _reactToProfile,
                      onDismiss: () =>
                          setState(() => _showProfileReactionPicker = false),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactButton(ColorScheme scheme) {
    final hasReaction = _myProfileReaction != null;
    return SizedBox(
      height: 36,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          setState(
            () => _showProfileReactionPicker = !_showProfileReactionPicker,
          );
        },
        child: OutlinedButton(
          onPressed: () {
            if (hasReaction) {
              _removeProfileReaction();
            } else {
              setState(
                () => _showProfileReactionPicker = !_showProfileReactionPicker,
              );
            }
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: hasReaction
                ? _getProfileReactionColor(_myProfileReaction!)
                : scheme.onSurface,
            side: BorderSide(
              color: hasReaction
                  ? _getProfileReactionColor(_myProfileReaction!).withAlpha(120)
                  : scheme.onSurface.withAlpha(50),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: hasReaction
              ? Text(
                  _reactionEmojis[_myProfileReaction!] ?? '👍',
                  style: const TextStyle(fontSize: 18),
                )
              : const Icon(Icons.add_reaction_outlined, size: 18),
        ),
      ),
    );
  }

  Color _getProfileReactionColor(String type) {
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
        return Theme.of(context).colorScheme.primary;
    }
  }

  Widget _buildFriendButton(ColorScheme scheme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: _buildFriendButtonContent(scheme),
    );
  }

  Widget _buildFriendButtonContent(ColorScheme scheme) {
    if (_actionLoading) {
      return SizedBox(
        key: const ValueKey('loading'),
        height: 36,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            side: BorderSide(color: scheme.primary.withAlpha(60)),
          ),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          ),
        ),
      );
    }

    switch (_friendStatus) {
      case 'friends':
        return SizedBox(
          key: const ValueKey('friends'),
          height: 36,
          child: OutlinedButton.icon(
            onPressed: _removeFriend,
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Friends', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: BorderSide(color: Colors.green.withAlpha(120)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        );

      case 'pending':
        return SizedBox(
          key: const ValueKey('pending'),
          height: 36,
          child: OutlinedButton.icon(
            onPressed: _cancelRequest,
            icon: const Icon(Icons.hourglass_top_rounded, size: 16),
            label: const Text('Requested', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.onSurface.withAlpha(180),
              side: BorderSide(color: scheme.onSurface.withAlpha(60)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        );

      case 'requested':
        return Row(
          key: const ValueKey('requested'),
          children: [
            Expanded(
              child: SizedBox(
                height: 36,
                child: FilledButton.icon(
                  onPressed: _acceptRequest,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Accept', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: OutlinedButton(
                onPressed: _declineRequest,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: Colors.redAccent.withAlpha(120)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: const Text('Decline', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        );

      default: // 'none'
        return SizedBox(
          key: const ValueKey('none'),
          height: 36,
          child: FilledButton.icon(
            onPressed: _sendRequest,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
            label: const Text('Add Friend', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
          ),
        );
    }
  }

  Widget _buildMessageButton(ColorScheme scheme) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: () {
          final name = _user!['displayName'] as String? ?? 'Unknown';
          Navigator.pushNamed(
            context,
            '/chat',
            arguments: {'userId': widget.userId, 'name': name},
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.onSurface.withAlpha(50)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      ),
    );
  }

  // ── Stats Bar ──────────────────────────────────────────────────────────────
  Widget _buildStatsBar(BuildContext context, ColorScheme scheme, bool isDark) {
    final totalLikes = _posts.fold<int>(0, (sum, p) => sum + p.likeCount);
    return SliverToBoxAdapter(
      child: Transform.translate(
        offset: const Offset(0, -10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: scheme.surface.withAlpha(isDark ? 120 : 230),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.primary.withAlpha(30)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(
                      value: '${_posts.length}',
                      label: 'Posts',
                      color: scheme.primary,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: scheme.onSurface.withAlpha(20),
                    ),
                    _StatItem(
                      value: '$totalLikes',
                      label: 'Likes',
                      color: Colors.redAccent,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: scheme.onSurface.withAlpha(20),
                    ),
                    _StatItem(
                      value: _friendStatus == 'friends' ? '\u2713' : '\u2014',
                      label: 'Friend',
                      color: _friendStatus == 'friends'
                          ? Colors.green
                          : scheme.onSurface.withAlpha(100),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Posts Section ──────────────────────────────────────────────────────────
  Widget _buildPostsSection(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    if (_postsLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, __) => const SkeletonCard(),
          childCount: 3,
        ),
      );
    }
    if (_posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.article_outlined,
                    size: 40,
                    color: scheme.primary.withAlpha(120),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'When they share something, it\u2019ll show up here',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withAlpha(100),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => PostCard(
          post: _posts[index],
          onTapUser: () {},
          onLike: _toggleLike,
        ),
        childCount: _posts.length,
      ),
    );
  }
}

// ── Stat Item ────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(120),
          ),
        ),
      ],
    );
  }
}
// ── Profile Reaction Summary ─────────────────────────────────────────────────

class _ProfileReactionSummary extends StatelessWidget {
  final Map<String, int> reactionCounts;
  final int total;
  const _ProfileReactionSummary({
    required this.reactionCounts,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sorted = reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEmojis = sorted
        .take(3)
        .map((e) => _reactionEmojis[e.key] ?? '👍')
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stacked emoji circles
          SizedBox(
            width: topEmojis.length * 16.0 + 8,
            height: 24,
            child: Stack(
              children: [
                for (int i = 0; i < topEmojis.length; i++)
                  Positioned(
                    left: i * 14.0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary.withAlpha(35),
                            scheme.surface,
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withAlpha(20),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        topEmojis[i],
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$total',
            style: TextStyle(
              fontSize: 13,
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          // Individual counts
          ...sorted
              .take(3)
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _reactionEmojis[e.key] ?? '👍',
                        style: const TextStyle(fontSize: 11),
                      ),
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
                ),
              ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 14,
            color: scheme.onSurface.withAlpha(80),
          ),
        ],
      ),
    );
  }
}

// ── Profile Reaction Picker (3D style) ───────────────────────────────────────

class _ProfileReactionPicker extends StatefulWidget {
  final String? currentReaction;
  final void Function(String type) onSelect;
  final VoidCallback onDismiss;

  const _ProfileReactionPicker({
    this.currentReaction,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<_ProfileReactionPicker> createState() => _ProfileReactionPickerState();
}

class _ProfileReactionPickerState extends State<_ProfileReactionPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
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
          alignment: Alignment.topCenter,
          child: Opacity(
            opacity: (_entryCtrl.value * 2).clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onPanUpdate: (details) {
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
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: scheme.primary.withAlpha(50)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withAlpha(25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_reactions.length, (i) {
              final isCurrent = widget.currentReaction == _reactions[i];
              final isHovered = _hoveredIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onSelect(_reactions[i]);
                  },
                  onTapDown: (_) => setState(() => _hoveredIndex = i),
                  onTapCancel: () => setState(() => _hoveredIndex = null),
                  onTapUp: (_) => setState(() => _hoveredIndex = null),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 250 + i * 50),
                    curve: Curves.elasticOut,
                    builder: (_, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      transform: Matrix4.identity()
                        ..translate(0.0, isHovered ? -18.0 : 0.0)
                        ..scale(
                          isHovered ? 1.5 : (isCurrent ? 1.2 : 1.0),
                          isHovered ? 1.5 : (isCurrent ? 1.2 : 1.0),
                        ),
                      transformAlignment: Alignment.center,
                      alignment: Alignment.center,
                      decoration: isHovered
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: scheme.primary.withAlpha(40),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            )
                          : null,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isHovered)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                [
                                  'Like',
                                  'Love',
                                  'Haha',
                                  'Wow',
                                  'Sad',
                                  'Angry',
                                ][i],
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Text(
                            _emojis[i],
                            style: TextStyle(
                              fontSize: isHovered ? 32 : (isCurrent ? 26 : 22),
                              shadows: isHovered
                                  ? [
                                      Shadow(
                                        blurRadius: 8,
                                        color: Colors.black.withAlpha(40),
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ],
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

// ── Profile Reactors Sheet ──────────────────────────────────────────────────

class _ProfileReactorsSheet extends StatefulWidget {
  final List<Map<String, dynamic>> reactors;
  final Map<String, int> counts;
  final int total;
  const _ProfileReactorsSheet({
    required this.reactors,
    required this.counts,
    required this.total,
  });

  @override
  State<_ProfileReactorsSheet> createState() => _ProfileReactorsSheetState();
}

class _ProfileReactorsSheetState extends State<_ProfileReactorsSheet> {
  String? _filterType;

  List<Map<String, dynamic>> get _filteredReactors {
    if (_filterType == null) return widget.reactors;
    return widget.reactors
        .where((r) => (r['reactionType'] as String?) == _filterType)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final types = widget.counts.keys.toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
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
                  'Profile Reactions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${widget.total}',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (types.isNotEmpty)
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _ProfileFilterChip(
                    label: 'All',
                    count: widget.total,
                    isSelected: _filterType == null,
                    onTap: () => setState(() => _filterType = null),
                  ),
                  ...types.map(
                    (type) => _ProfileFilterChip(
                      emoji: _reactionEmojis[type] ?? '👍',
                      count: widget.counts[type] ?? 0,
                      isSelected: _filterType == type,
                      onTap: () => setState(() => _filterType = type),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          Expanded(
            child: _filteredReactors.isEmpty
                ? Center(
                    child: Text(
                      'No reactions yet',
                      style: TextStyle(color: scheme.onSurface.withAlpha(100)),
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _filteredReactors.length,
                    itemBuilder: (_, i) {
                      final r = _filteredReactors[i];
                      final name = r['displayName'] as String? ?? 'Unknown';
                      final pic = r['profilePictureUrl'] as String?;
                      final type = r['reactionType'] as String? ?? 'like';
                      final userId = r['userId'] as String? ?? '';
                      return ListTile(
                        leading: Stack(
                          children: [
                            AvatarWidget(url: pic, name: name, radius: 20),
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
                                    color: scheme.surface,
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _reactionEmojis[type] ?? '👍',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          _reactionEmojis[type] ?? '👍',
                          style: const TextStyle(fontSize: 20),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            '/user-profile',
                            arguments: userId,
                          );
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

class _ProfileFilterChip extends StatelessWidget {
  final String? label;
  final String? emoji;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProfileFilterChip({
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
            color: isSelected
                ? scheme.primary.withAlpha(25)
                : Colors.transparent,
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
