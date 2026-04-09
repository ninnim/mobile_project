import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/feed_provider.dart';
import '../widgets/post_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton_loader.dart';

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
    final scheme = Theme.of(context).colorScheme;

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
          : state.posts.isEmpty
          ? EmptyState(
              icon: Icons.newspaper_outlined,
              title: 'Be the first to post!',
              subtitle: 'Share something with the community',
              actionLabel: 'Create Post',
              onAction: onCreatePost,
            )
          : RefreshIndicator(
              color: scheme.primary,
              onRefresh: () =>
                  ref.read(feedProvider.notifier).fetchFeed(refresh: true),
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                itemCount: state.posts.length,
                itemBuilder: (ctx, i) =>
                    PostCard(
                          post: state.posts[i],
                          onTapUser: () => onTapUser(state.posts[i].userId),
                          onNavigateUser: onTapUser,
                        )
                        .animate(delay: Duration(milliseconds: i * 40))
                        .fadeIn()
                        .slideY(begin: 0.05),
              ),
            ),
    );
  }
}
