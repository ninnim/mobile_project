import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/widgets/skeleton_loader.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  PostModel? _post;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPost();
  }

  Future<void> _fetchPost() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await dioClient.get('/posts/${widget.postId}');
      if (mounted) {
        setState(() {
          _post = PostModel.fromJson(res.data as Map<String, dynamic>);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load post';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SkeletonBox(width: double.infinity, height: 200),
                  const SizedBox(height: 12),
                  SkeletonBox(width: 200, height: 16),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 64, color: scheme.error.withAlpha(150)),
                      const SizedBox(height: 16),
                      Text(_error!, style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _fetchPost,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: scheme.primary,
                  onRefresh: _fetchPost,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 100),
                    children: [
                      PostCard(
                        post: _post!,
                        onTapUser: () => Navigator.pushNamed(
                          context,
                          '/user-profile',
                          arguments: _post!.userId,
                        ),
                        onNavigateUser: (userId) => Navigator.pushNamed(
                          context,
                          '/user-profile',
                          arguments: userId,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
