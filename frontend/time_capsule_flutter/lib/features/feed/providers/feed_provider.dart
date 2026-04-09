import 'package:dio/dio.dart' as dio_lib;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/post_model.dart';
import '../../../core/network/dio_client.dart';

class FeedState {
  final List<PostModel> posts;
  final bool loading;
  final bool refreshing;
  final String? error;
  const FeedState({
    this.posts = const [],
    this.loading = false,
    this.refreshing = false,
    this.error,
  });
  FeedState copyWith({
    List<PostModel>? posts,
    bool? loading,
    bool? refreshing,
    String? error,
  }) => FeedState(
    posts: posts ?? this.posts,
    loading: loading ?? this.loading,
    refreshing: refreshing ?? this.refreshing,
    error: error,
  );
}

class FeedNotifier extends Notifier<FeedState> {
  @override
  FeedState build() {
    Future.microtask(fetchFeed);
    return const FeedState(loading: true);
  }

  Future<void> fetchFeed({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(refreshing: true);
    } else {
      state = state.copyWith(loading: true, error: null);
    }
    try {
      final res = await dioClient.get(
        '/posts',
        queryParameters: {'page': 1, 'pageSize': 50},
      );
      final data = res.data;
      List<dynamic> items;
      if (data is Map && data['items'] != null) {
        items = data['items'] as List<dynamic>;
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }
      state = FeedState(
        posts: items
            .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      state = FeedState(error: 'Failed to load feed', posts: state.posts);
    }
  }

  Future<void> toggleLike(String postId) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final post = state.posts[idx];
    // Optimistic update
    final updated = List<PostModel>.from(state.posts);
    updated[idx] = post.copyWith(
      isLikedByMe: !post.isLikedByMe,
      likeCount: post.isLikedByMe ? post.likeCount - 1 : post.likeCount + 1,
    );
    state = state.copyWith(posts: updated);
    try {
      if (post.isLikedByMe) {
        await dioClient.delete('/posts/$postId/like');
      } else {
        await dioClient.post('/posts/$postId/like');
      }
    } catch (_) {
      // Revert on error
      final reverted = List<PostModel>.from(state.posts);
      reverted[idx] = post;
      state = state.copyWith(posts: reverted);
    }
  }

  /// React to a post with a specific emoji type (like, love, haha, wow, sad, angry).
  Future<void> reactToPost(String postId, String reactionType) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final post = state.posts[idx];

    // Optimistic update
    final newCounts = Map<String, int>.from(post.reactionCounts);
    // Remove old reaction count
    if (post.myReaction != null && newCounts.containsKey(post.myReaction!)) {
      newCounts[post.myReaction!] = (newCounts[post.myReaction!]! - 1);
      if (newCounts[post.myReaction!]! <= 0) newCounts.remove(post.myReaction!);
    }
    // Add new reaction count
    newCounts[reactionType] = (newCounts[reactionType] ?? 0) + 1;

    final updated = List<PostModel>.from(state.posts);
    updated[idx] = post.copyWith(
      myReaction: reactionType,
      reactionCounts: newCounts,
      isLikedByMe: true,
    );
    state = state.copyWith(posts: updated);

    try {
      await dioClient.post(
        '/posts/$postId/reactions',
        data: {'reactionType': reactionType},
      );
    } catch (_) {
      final reverted = List<PostModel>.from(state.posts);
      reverted[idx] = post;
      state = state.copyWith(posts: reverted);
    }
  }

  /// Remove reaction from a post.
  Future<void> removeReaction(String postId) async {
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final post = state.posts[idx];
    if (post.myReaction == null) return;

    // Optimistic update
    final newCounts = Map<String, int>.from(post.reactionCounts);
    if (newCounts.containsKey(post.myReaction!)) {
      newCounts[post.myReaction!] = (newCounts[post.myReaction!]! - 1);
      if (newCounts[post.myReaction!]! <= 0) newCounts.remove(post.myReaction!);
    }

    final updated = List<PostModel>.from(state.posts);
    updated[idx] = post.copyWith(
      clearReaction: true,
      reactionCounts: newCounts,
      isLikedByMe: false,
    );
    state = state.copyWith(posts: updated);

    try {
      await dioClient.delete('/posts/$postId/reactions');
    } catch (_) {
      final reverted = List<PostModel>.from(state.posts);
      reverted[idx] = post;
      state = state.copyWith(posts: reverted);
    }
  }

  /// Edit a post's content.
  Future<bool> editPost(String postId, String newContent) async {
    try {
      final res = await dioClient.put(
        '/posts/$postId',
        data: dio_lib.FormData.fromMap({'content': newContent}),
      );
      final updatedPost = PostModel.fromJson(res.data as Map<String, dynamic>);
      final updated = List<PostModel>.from(state.posts);
      final idx = updated.indexWhere((p) => p.id == postId);
      if (idx >= 0) updated[idx] = updatedPost;
      state = state.copyWith(posts: updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete a post.
  Future<bool> deletePost(String postId) async {
    try {
      await dioClient.delete('/posts/$postId');
      final updated = state.posts.where((p) => p.id != postId).toList();
      state = state.copyWith(posts: updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Share a post via reference-based sharing.
  Future<bool> sharePost(String originalPostId, String caption) async {
    try {
      await dioClient.post(
        '/posts',
        data: dio_lib.FormData.fromMap({
          'content': caption.isNotEmpty ? caption : 'Shared a post',
          'sharedPostId': originalPostId,
        }),
      );
      await fetchFeed(refresh: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<CommentModel>> getComments(String postId) async {
    try {
      final res = await dioClient.get('/posts/$postId/comments');
      return (res.data as List<dynamic>)
          .map((e) => CommentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addComment(String postId, String content) async {
    await dioClient.post('/posts/$postId/comments', data: {'content': content});
    final idx = state.posts.indexWhere((p) => p.id == postId);
    if (idx >= 0) {
      final updated = List<PostModel>.from(state.posts);
      updated[idx] = updated[idx].copyWith(
        commentCount: updated[idx].commentCount + 1,
      );
      state = state.copyWith(posts: updated);
    }
  }

  /// React to a comment with a specific emoji type.
  Future<void> reactToComment(
    String postId,
    String commentId,
    String reactionType,
  ) async {
    try {
      await dioClient.post(
        '/posts/$postId/comments/$commentId/reactions',
        data: {'reactionType': reactionType},
      );
    } catch (_) {
      // silently fail
    }
  }

  /// Remove reaction from a comment.
  Future<void> removeCommentReaction(String postId, String commentId) async {
    try {
      await dioClient.delete('/posts/$postId/comments/$commentId/reactions');
    } catch (_) {
      // silently fail
    }
  }

  /// Get reactors for a post.
  Future<ReactionSummaryModel> getPostReactors(String postId) async {
    try {
      final res = await dioClient.get('/posts/$postId/reactions');
      return ReactionSummaryModel.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return const ReactionSummaryModel();
    }
  }

  /// Get reactors for a comment.
  Future<ReactionSummaryModel> getCommentReactors(
    String postId,
    String commentId,
  ) async {
    try {
      final res = await dioClient.get(
        '/posts/$postId/comments/$commentId/reactions',
      );
      return ReactionSummaryModel.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return const ReactionSummaryModel();
    }
  }
}

final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);
