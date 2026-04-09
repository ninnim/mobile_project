class ChatReaction {
  final String id;
  final String chatId;
  final String userId;
  final String displayName;
  final String reactionType;
  final String createdAt;

  const ChatReaction({
    required this.id,
    required this.chatId,
    required this.userId,
    required this.displayName,
    required this.reactionType,
    required this.createdAt,
  });

  factory ChatReaction.fromJson(Map<String, dynamic> j) => ChatReaction(
        id: j['id'] as String? ?? '',
        chatId: j['chatId'] as String? ?? '',
        userId: j['userId'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        reactionType: j['reactionType'] as String? ?? 'like',
        createdAt: j['createdAt'] as String? ?? '',
      );
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final String? mediaUrl;
  final String messageType; // Text, Image, Voice
  final String status; // Sent, Delivered, Read
  final bool isRead;
  final String createdAt;
  final List<ChatReaction> reactions;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.mediaUrl,
    required this.messageType,
    required this.status,
    required this.isRead,
    required this.createdAt,
    this.reactions = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        senderId: j['senderId'] as String,
        receiverId: j['receiverId'] as String,
        message: j['message'] as String? ?? '',
        mediaUrl: j['mediaUrl'] as String?,
        messageType: j['messageType'] as String? ?? 'Text',
        status: j['status'] as String? ?? 'Sent',
        isRead: j['isRead'] as bool? ?? false,
        createdAt: j['createdAt'] as String,
        reactions: (j['reactions'] as List<dynamic>?)
                ?.map((e) => ChatReaction.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  ChatMessage copyWith({
    String? status,
    bool? isRead,
    List<ChatReaction>? reactions,
  }) =>
      ChatMessage(
        id: id,
        senderId: senderId,
        receiverId: receiverId,
        message: message,
        mediaUrl: mediaUrl,
        messageType: messageType,
        status: status ?? this.status,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        reactions: reactions ?? this.reactions,
      );
}

class ContactModel {
  final String userId;
  final String displayName;
  final String? profilePictureUrl;
  final String? lastMessage;
  final String? lastMessageAt;
  final int unreadCount;

  const ContactModel({
    required this.userId,
    required this.displayName,
    this.profilePictureUrl,
    this.lastMessage,
    this.lastMessageAt,
    required this.unreadCount,
  });

  factory ContactModel.fromJson(Map<String, dynamic> j) => ContactModel(
        userId: j['userId'] as String,
        displayName: j['displayName'] as String,
        profilePictureUrl: j['profilePictureUrl'] as String?,
        lastMessage: j['lastMessage'] as String?,
        lastMessageAt: j['lastMessageAt'] as String?,
        unreadCount: j['unreadCount'] as int? ?? 0,
      );
}
