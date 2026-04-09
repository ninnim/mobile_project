class NotificationModel {
  final String id;
  final String userId;
  final String actorId;
  final String actorName;
  final String? actorProfilePictureUrl;
  final String type;
  final String? referenceId;
  final String message;
  final bool isRead;
  final String createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.actorName,
    this.actorProfilePictureUrl,
    required this.type,
    this.referenceId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) =>
      NotificationModel(
        id: j['id'] as String,
        userId: j['userId'] as String,
        actorId: j['actorId'] as String,
        actorName: j['actorName'] as String? ?? '',
        actorProfilePictureUrl: j['actorProfilePictureUrl'] as String?,
        type: j['type'] as String,
        referenceId: j['referenceId'] as String?,
        message: j['message'] as String,
        isRead: j['isRead'] as bool? ?? false,
        createdAt: j['createdAt'] as String,
      );

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    id: id,
    userId: userId,
    actorId: actorId,
    actorName: actorName,
    actorProfilePictureUrl: actorProfilePictureUrl,
    type: type,
    referenceId: referenceId,
    message: message,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );
}
