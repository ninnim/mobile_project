import '../../capsule/models/capsule_model.dart';

class GameRoomModel {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final bool isPublic;
  final int capsuleCount;
  final String createdAt;
  final List<CapsuleModel>? capsules;

  const GameRoomModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.isPublic,
    required this.capsuleCount,
    required this.createdAt,
    this.capsules,
  });

  factory GameRoomModel.fromJson(Map<String, dynamic> j) => GameRoomModel(
        id: j['id'] as String,
        creatorId: j['creatorId'] as String,
        creatorName: j['creatorName'] as String? ?? '',
        title: j['title'] as String,
        isPublic: j['isPublic'] as bool? ?? true,
        capsuleCount: j['capsuleCount'] as int? ?? 0,
        createdAt: j['createdAt'] as String,
        capsules: (j['capsules'] as List<dynamic>?)
            ?.map((e) => CapsuleModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LeaderboardEntry {
  final String userId;
  final String displayName;
  final String? profilePictureUrl;
  final int totalPoints;
  final int unlockedCount;
  final int rank;

  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    this.profilePictureUrl,
    required this.totalPoints,
    required this.unlockedCount,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        profilePictureUrl: j['profilePictureUrl'] as String?,
        totalPoints: j['totalPoints'] as int? ?? 0,
        unlockedCount: j['unlockedCount'] as int? ?? 0,
        rank: j['rank'] as int? ?? 0,
      );
}
