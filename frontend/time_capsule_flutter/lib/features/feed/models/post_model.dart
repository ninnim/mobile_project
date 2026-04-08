import 'dart:convert';

/// Marker prefix used to embed shared-post metadata in the content string.
/// Format: `[SHARE:base64json]\nCaption text`
const _sharePrefix = '[SHARE:';

class SharedPostData {
  final String originalUserName;
  final String? originalUserPicture;
  final String originalContent;
  final String? originalMediaUrl;

  const SharedPostData({
    required this.originalUserName,
    this.originalUserPicture,
    required this.originalContent,
    this.originalMediaUrl,
  });

  Map<String, dynamic> toJson() => {
    'u': originalUserName,
    'p': originalUserPicture,
    'c': originalContent,
    'm': originalMediaUrl,
  };

  factory SharedPostData.fromJson(Map<String, dynamic> j) => SharedPostData(
    originalUserName: j['u'] as String? ?? 'Unknown',
    originalUserPicture: j['p'] as String?,
    originalContent: j['c'] as String? ?? '',
    originalMediaUrl: j['m'] as String?,
  );

  /// Encode to a content prefix string.
  String encode() {
    final jsonStr = jsonEncode(toJson());
    final b64 = base64Encode(utf8.encode(jsonStr));
    return '$_sharePrefix$b64]';
  }

  /// Try parsing share data from the beginning of a content string.
  /// Returns `(SharedPostData, captionText)` or null.
  static (SharedPostData, String)? parse(String content) {
    if (!content.startsWith(_sharePrefix)) return null;
    final endIdx = content.indexOf(']');
    if (endIdx < 0) return null;
    try {
      final b64 = content.substring(_sharePrefix.length, endIdx);
      final jsonStr = utf8.decode(base64Decode(b64));
      final data = SharedPostData.fromJson(
        jsonDecode(jsonStr) as Map<String, dynamic>,
      );
      final caption = content.substring(endIdx + 1).trim();
      return (data, caption);
    } catch (_) {
      return null;
    }
  }
}

/// Reference-based shared post from the API.
class SharedPostRef {
  final String id;
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String content;
  final String? mediaUrl;
  final String createdAt;
  final bool isUnavailable;

  const SharedPostRef({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.content,
    this.mediaUrl,
    required this.createdAt,
    this.isUnavailable = false,
  });

  factory SharedPostRef.fromJson(Map<String, dynamic> j) {
    final userId = j['userId'] as String? ?? '';
    // If userId is empty/zeroed, the original post was deleted
    final isUnavailable =
        userId.isEmpty || userId == '00000000-0000-0000-0000-000000000000';
    return SharedPostRef(
      id: j['id'] as String? ?? '',
      userId: userId,
      userName: j['userName'] as String? ?? '',
      userProfilePicture: j['userProfilePicture'] as String?,
      content: j['content'] as String? ?? '',
      mediaUrl: j['mediaUrl'] as String?,
      createdAt: j['createdAt'] as String? ?? '',
      isUnavailable: isUnavailable,
    );
  }
}

class TaggedUser {
  final String userId;
  final String displayName;
  final String? profilePictureUrl;

  const TaggedUser({
    required this.userId,
    required this.displayName,
    this.profilePictureUrl,
  });

  factory TaggedUser.fromJson(Map<String, dynamic> j) => TaggedUser(
    userId: j['userId'] as String,
    displayName: j['displayName'] as String? ?? 'Unknown',
    profilePictureUrl: j['profilePictureUrl'] as String?,
  );
}

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String content;
  final String? mediaUrl;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;
  final Map<String, int> reactionCounts;
  final String? myReaction;
  final SharedPostRef? sharedPost;
  final String createdAt;
  final List<TaggedUser> taggedUsers;

  const PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.content,
    this.mediaUrl,
    required this.likeCount,
    required this.commentCount,
    required this.isLikedByMe,
    this.reactionCounts = const {},
    this.myReaction,
    this.sharedPost,
    required this.createdAt,
    this.taggedUsers = const [],
  });

  /// Backward-compat: parse old [SHARE:...] prefix
  SharedPostData? get sharedData => _parsedShare?.$1;
  String get displayContent => _parsedShare?.$2 ?? content;

  /// A post is "shared" if it has a reference-based sharedPost OR old-style prefix
  bool get isSharedPost => sharedPost != null || _parsedShare != null;

  (SharedPostData, String)? get _parsedShare => SharedPostData.parse(content);

  int get totalReactions {
    if (reactionCounts.isNotEmpty) {
      return reactionCounts.values.fold(0, (a, b) => a + b);
    }
    return likeCount;
  }

  factory PostModel.fromJson(Map<String, dynamic> j) => PostModel(
    id: j['id'] as String,
    userId: j['userId'] as String,
    userName:
        j['userName'] as String? ?? j['displayName'] as String? ?? 'Unknown',
    userProfilePicture: j['userProfilePicture'] as String?,
    content: j['content'] as String,
    mediaUrl: j['mediaUrl'] as String?,
    likeCount: j['likeCount'] as int? ?? 0,
    commentCount: j['commentCount'] as int? ?? 0,
    isLikedByMe: j['isLikedByMe'] as bool? ?? false,
    reactionCounts:
        (j['reactionCounts'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int),
        ) ??
        {},
    myReaction: j['myReaction'] as String?,
    sharedPost: j['sharedPost'] != null
        ? SharedPostRef.fromJson(j['sharedPost'] as Map<String, dynamic>)
        : null,
    createdAt: j['createdAt'] as String,
    taggedUsers:
        (j['taggedUsers'] as List<dynamic>?)
            ?.map((e) => TaggedUser.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  PostModel copyWith({
    String? content,
    String? mediaUrl,
    bool clearMedia = false,
    int? likeCount,
    bool? isLikedByMe,
    int? commentCount,
    Map<String, int>? reactionCounts,
    String? myReaction,
    bool clearReaction = false,
  }) => PostModel(
    id: id,
    userId: userId,
    userName: userName,
    userProfilePicture: userProfilePicture,
    content: content ?? this.content,
    mediaUrl: clearMedia ? null : (mediaUrl ?? this.mediaUrl),
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    reactionCounts: reactionCounts ?? this.reactionCounts,
    myReaction: clearReaction ? null : (myReaction ?? this.myReaction),
    sharedPost: sharedPost,
    createdAt: createdAt,
    taggedUsers: taggedUsers,
  );
}

class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String content;
  final String createdAt;
  final Map<String, int> reactionCounts;
  final String? myReaction;
  final int totalReactions;

  const CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.content,
    required this.createdAt,
    this.reactionCounts = const {},
    this.myReaction,
    this.totalReactions = 0,
  });

  factory CommentModel.fromJson(Map<String, dynamic> j) => CommentModel(
    id: j['id'] as String,
    userId: j['userId'] as String,
    userName: j['userName'] as String? ?? 'Unknown',
    userProfilePicture: j['userProfilePicture'] as String?,
    content: j['content'] as String,
    createdAt: j['createdAt'] as String,
    reactionCounts:
        (j['reactionCounts'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as int),
        ) ??
        {},
    myReaction: j['myReaction'] as String?,
    totalReactions: j['totalReactions'] as int? ?? 0,
  );

  CommentModel copyWith({
    Map<String, int>? reactionCounts,
    String? myReaction,
    bool clearReaction = false,
    int? totalReactions,
  }) =>
      CommentModel(
        id: id,
        userId: userId,
        userName: userName,
        userProfilePicture: userProfilePicture,
        content: content,
        createdAt: createdAt,
        reactionCounts: reactionCounts ?? this.reactionCounts,
        myReaction: clearReaction ? null : (myReaction ?? this.myReaction),
        totalReactions: totalReactions ?? this.totalReactions,
      );
}

/// Model for a reactor (user who reacted)
class ReactorModel {
  final String userId;
  final String displayName;
  final String? profilePictureUrl;
  final String reactionType;

  const ReactorModel({
    required this.userId,
    required this.displayName,
    this.profilePictureUrl,
    required this.reactionType,
  });

  factory ReactorModel.fromJson(Map<String, dynamic> j) => ReactorModel(
    userId: j['userId'] as String,
    displayName: j['displayName'] as String? ?? 'Unknown',
    profilePictureUrl: j['profilePictureUrl'] as String?,
    reactionType: j['reactionType'] as String? ?? 'like',
  );
}

/// Summary of reactions with counts and reactor list
class ReactionSummaryModel {
  final Map<String, int> counts;
  final int total;
  final List<ReactorModel> reactors;

  const ReactionSummaryModel({
    this.counts = const {},
    this.total = 0,
    this.reactors = const [],
  });

  factory ReactionSummaryModel.fromJson(Map<String, dynamic> j) =>
      ReactionSummaryModel(
        counts:
            (j['counts'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as int),
            ) ??
            {},
        total: j['total'] as int? ?? 0,
        reactors:
            (j['reactors'] as List<dynamic>?)
                ?.map((e) => ReactorModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
