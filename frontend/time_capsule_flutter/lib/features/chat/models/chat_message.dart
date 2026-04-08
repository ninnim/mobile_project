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
