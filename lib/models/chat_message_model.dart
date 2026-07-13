enum MessageType { text, emoji, file, image, audio }

class ChatMessageModel {
  final String id;
  final String senderId;
  final String? senderName;
  final String receiverId;
  final String? receiverName;
  final String? message;
  final MessageType messageType;
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final bool isEncrypted;
  bool isRead;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    this.senderName,
    required this.receiverId,
    this.receiverName,
    this.message,
    this.messageType = MessageType.text,
    this.filePath,
    this.fileName,
    this.fileSize,
    this.isEncrypted = true,
    this.isRead = false,
    required this.createdAt,
  });

  bool isSentByMe(String currentUserId) => senderId == currentUserId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'sender_name': senderName,
        'receiver_id': receiverId,
        'receiver_name': receiverName,
        'message': message,
        'message_type': messageType.name,
        'file_path': filePath,
        'file_name': fileName,
        'file_size': fileSize,
        'is_encrypted': isEncrypted ? 1 : 0,
        'is_read': isRead ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) =>
      ChatMessageModel(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        senderName: json['sender_name'] as String?,
        receiverId: json['receiver_id'] as String,
        receiverName: json['receiver_name'] as String?,
        message: json['message'] as String?,
        messageType: MessageType.values.firstWhere(
            (m) => m.name == json['message_type'],
            orElse: () => MessageType.text),
        filePath: json['file_path'] as String?,
        fileName: json['file_name'] as String?,
        fileSize: json['file_size'] as int?,
        isEncrypted: (json['is_encrypted'] as int?) == 1,
        isRead: (json['is_read'] as int?) == 1,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  ChatMessageModel copyWith({
    bool? isRead,
  }) =>
      ChatMessageModel(
        id: id,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        receiverName: receiverName,
        message: message,
        messageType: messageType,
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
        isEncrypted: isEncrypted,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
