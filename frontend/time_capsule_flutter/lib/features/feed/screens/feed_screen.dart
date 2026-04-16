import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feed_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/capsule_feed_card.dart';
import '../../capsule/models/capsule_model.dart';
import '../../capsule/screens/capsule_detail_screen.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';

/// Fetches public capsules for the feed.
final publicCapsulesProvider = FutureProvider.autoDispose<List<CapsuleModel>>((
  ref,
) async {
  final res = await dioClient.get('/capsules/public');
  return (res.data as List<dynamic>)
      .map((e) => CapsuleModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Unified feed item: either a post or a capsule.
class _FeedItem {
  final DateTime createdAt;
  final dynamic data; // PostModel or CapsuleModel
  final bool isCapsule;
  _FeedItem({
    required this.createdAt,
    required this.data,
    this.isCapsule = false,
  });
}

class FeedScreen extends ConsumerWidget {
  final void Function(String userId) onTapUser;
  final VoidCallback onCreatePost;

  const FeedScreen({
    super.key,
    required this.onTapUser,
    required this.onCreatePost,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(feedProvider);
    final capsulesAsync = ref.watch(publicCapsulesProvider);
    final scheme = Theme.of(context).colorScheme;

    // Build merged feed items
    List<_FeedItem>? mergedItems;
    if (!state.loading && state.error == null) {
      final postItems = state.posts
          .map(
            (p) => _FeedItem(
              createdAt: DateTime.tryParse(p.createdAt) ?? DateTime(2000),
              data: p,
            ),
          )
          .toList();

      final capsuleItems =
          capsulesAsync.whenOrNull(
            data: (capsules) => capsules
                .map(
                  (c) => _FeedItem(
                    createdAt: DateTime.tryParse(c.createdAt) ?? DateTime(2000),
                    data: c,
                    isCapsule: true,
                  ),
                )
                .toList(),
          ) ??
          [];

      mergedItems = [...postItems, ...capsuleItems]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.archive_rounded, color: scheme.primary, size: 22),
            const SizedBox(width: 8),
            const Text('Feed', style: TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: onCreatePost,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withAlpha(80),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add,
                    size: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Post',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: state.loading
          ? ListView.builder(
              itemCount: 4,
              itemBuilder: (ctx, i) => const SkeletonCard()
                  .animate(delay: Duration(milliseconds: i * 80))
                  .fadeIn(),
            )
          : state.error != null && state.posts.isEmpty
          ? EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load feed',
              subtitle: state.error,
              actionLabel: 'Try Again',
              onAction: () => ref.read(feedProvider.notifier).fetchFeed(),
            )
          : (mergedItems == null || mergedItems.isEmpty)
          ? EmptyState(
              icon: Icons.newspaper_outlined,
              title: 'Be the first to post!',
              subtitle: 'Share something with the community',
              actionLabel: 'Create Post',
              onAction: onCreatePost,
            )
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: () async {
                await ref.read(feedProvider.notifier).fetchFeed(refresh: true);
                ref.invalidate(publicCapsulesProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                physics: const BouncingScrollPhysics(),
                cacheExtent: 600,
                addRepaintBoundaries: false,
                itemCount: mergedItems.length,
                itemBuilder: (ctx, i) {
                  final item = mergedItems![i];
                  Widget card;
                  if (item.isCapsule) {
                    final capsule = item.data as CapsuleModel;
                    card = CapsuleFeedCard(
                      capsule: capsule,
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => CapsuleDetailScreen(capsule: capsule),
                        ),
                      ),
                    );
                  } else {
                    final post = item.data;
                    card = PostCard(
                      post: post,
                      onTapUser: () => onTapUser(post.userId),
                      onNavigateUser: onTapUser,
                    );
                  }
                  final wrapped = RepaintBoundary(child: card);
                  if (i < 5) {
                    return wrapped
                        .animate(delay: Duration(milliseconds: i * 35))
                        .fadeIn(duration: 250.ms)
                        .slideY(
                            begin: 0.04,
                            duration: 250.ms,
                            curve: Curves.easeOutCubic);
                  }
                  return wrapped;
                },
              ),
            ),
    );
  }
}
