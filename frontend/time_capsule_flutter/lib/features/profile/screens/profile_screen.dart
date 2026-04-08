import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../../feed/models/post_model.dart';
import '../../feed/widgets/post_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  List<PostModel> _posts = [];
  bool _postsLoading = true;
  int _friendCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await ref.read(authProvider.notifier).refreshUser();
    _loadPosts();
    _loadFriendCount();
  }

  Future<void> _loadPosts() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    try {
      final res = await dioClient.get('/posts/user/${user.id}');
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

  Future<void> _loadFriendCount() async {
    try {
      final res = await dioClient.get('/friends');
      if (res.data is List) {
        if (mounted) setState(() => _friendCount = (res.data as List).length);
      }
    } catch (_) {}
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

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final res = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (res == null) return;
    try {
      final form = FormData.fromMap({
        'profilePicture': await MultipartFile.fromFile(
          res.path,
          filename: 'avatar.jpg',
        ),
      });
      await dioClient.put('/auth/me', data: form);
      await ref.read(authProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile picture updated!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update picture'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: scheme.primary)),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(60),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.settings_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              _loadData();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: scheme.primary,
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildProfileHeader(context, scheme, isDark, user),
            _buildStatsBar(context, scheme, isDark, user),
            _buildPostsSection(context, scheme, isDark),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // ── Profile Header ─────────────────────────────────────────────────────────
  Widget _buildProfileHeader(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
    dynamic user,
  ) {
    String? memberSince;
    try {
      final dt = DateTime.parse(user.createdAt);
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
                  // Avatar with camera overlay
                  GestureDetector(
                    onTap: _pickAvatar,
                    child: Stack(
                      children: [
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
                          child: AvatarWidget(
                            url: user.profilePictureUrl,
                            name: user.displayName,
                            radius: 36,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 12,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Name + bio + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 34),
                        Text(
                          user.displayName,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user.bio != null && user.bio!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              user.bio!,
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
          // Edit Profile button
          Transform.translate(
            offset: const Offset(0, -18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 36,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/settings');
                    _loadData();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.primary,
                    side: BorderSide(color: scheme.primary.withAlpha(100)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats Bar ──────────────────────────────────────────────────────────────
  Widget _buildStatsBar(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
    dynamic user,
  ) {
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
                      value: '${user.postCount}',
                      label: 'Posts',
                      color: scheme.primary,
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: scheme.onSurface.withAlpha(20),
                    ),
                    _StatItem(
                      value: '${user.capsuleCount}',
                      label: 'Capsules',
                      color: scheme.secondary,
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
                      value: '$_friendCount',
                      label: 'Friends',
                      color: Colors.green,
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
                  'Your posts will appear here',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withAlpha(100),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/create-post'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Post'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
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
