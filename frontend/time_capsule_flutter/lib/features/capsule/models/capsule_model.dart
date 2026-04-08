class CapsuleMedia {
  final String id;
  final String fileUrl;
  final String fileType;
  const CapsuleMedia({required this.id, required this.fileUrl, required this.fileType});
  factory CapsuleMedia.fromJson(Map<String, dynamic> j) => CapsuleMedia(
        id: j['id'] as String,
        fileUrl: j['fileUrl'] as String,
        fileType: j['fileType'] as String? ?? 'Image',
      );
}

class CapsuleModel {
  final String id;
  final String senderId;
  final String senderName;
  final String title;
  final String? message;
  final double latitude;
  final double longitude;
  final String unlockDate;
  final bool isPublic;
  final String status;
  final int pointsReward;
  final int proximityTolerance;
  final String? receiverId;
  final List<CapsuleMedia> media;
  final String createdAt;

  const CapsuleModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.title,
    this.message,
    required this.latitude,
    required this.longitude,
    required this.unlockDate,
    required this.isPublic,
    required this.status,
    required this.pointsReward,
    required this.proximityTolerance,
    this.receiverId,
    required this.media,
    required this.createdAt,
  });

  factory CapsuleModel.fromJson(Map<String, dynamic> j) => CapsuleModel(
        id: j['id'] as String,
        senderId: j['senderId'] as String,
        senderName: j['senderName'] as String? ?? 'Unknown',
        title: j['title'] as String,
        message: j['message'] as String?,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        unlockDate: j['unlockDate'] as String,
        isPublic: j['isPublic'] as bool? ?? false,
        status: j['status'] as String? ?? 'Locked',
        pointsReward: j['pointsReward'] as int? ?? 0,
        proximityTolerance: j['proximityTolerance'] as int? ?? 50,
        receiverId: j['receiverUserId'] as String?,
        media: (j['media'] as List<dynamic>? ?? [])
            .map((e) => CapsuleMedia.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: j['createdAt'] as String,
      );

  bool get isLocked => status == 'Locked';
}
