import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/chat_message_model.dart';
import '../core/database/database_helper.dart';

/// Service for offline chat between connected devices
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final Uuid _uuid = const Uuid();
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<ChatMessageModel> _messages = [];

  // Callbacks
  void Function(ChatMessageModel message)? onMessageReceived;
  void Function(ChatMessageModel message)? onMessageSent;
  void Function(String conversationId)? onConversationUpdated;

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);

  /// Load chat history for a specific conversation
  Future<List<ChatMessageModel>> loadConversation(
      String userId, String otherUserId) async {
    final results = await _db.query(
      'chat_messages',
      where:
          '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      whereArgs: [userId, otherUserId, otherUserId, userId],
      orderBy: 'created_at ASC',
    );

    _messages.clear();
    for (final row in results) {
      _messages.add(ChatMessageModel.fromJson(row));
    }
    return List.unmodifiable(_messages);
  }

  /// Send a text message
  Future<ChatMessageModel> sendMessage({
    required String senderId,
    String? senderName,
    required String receiverId,
    String? receiverName,
    required String message,
  }) async {
    final chatMessage = ChatMessageModel(
      id: _uuid.v4(),
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      receiverName: receiverName,
      message: message,
      messageType: MessageType.text,
      isEncrypted: true,
      createdAt: DateTime.now(),
    );

    _messages.add(chatMessage);
    await _db.insert('chat_messages', chatMessage.toJson());
    onMessageSent?.call(chatMessage);

    // In production, send via Nearby Connections
    // _sendMessageViaConnection(chatMessage);

    return chatMessage;
  }

  /// Send a file message
  Future<ChatMessageModel> sendFile({
    required String senderId,
    String? senderName,
    required String receiverId,
    String? receiverName,
    required String filePath,
    required String fileName,
    MessageType type = MessageType.file,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();

    final chatMessage = ChatMessageModel(
      id: _uuid.v4(),
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      receiverName: receiverName,
      message: fileName,
      messageType: type,
      filePath: filePath,
      fileName: fileName,
      fileSize: fileSize,
      isEncrypted: true,
      createdAt: DateTime.now(),
    );

    _messages.add(chatMessage);
    await _db.insert('chat_messages', chatMessage.toJson());
    onMessageSent?.call(chatMessage);

    return chatMessage;
  }

  /// Receive a message from a connected device
  Future<void> receiveMessage(ChatMessageModel message) async {
    // Decrypt if needed
    ChatMessageModel receivedMessage;
    if (message.isEncrypted && message.message != null) {
      // In production, decrypt using shared encryption keys
      receivedMessage = message;
    } else {
      receivedMessage = message;
    }

    _messages.add(receivedMessage);
    await _db.insert('chat_messages', receivedMessage.toJson());
    onMessageReceived?.call(receivedMessage);
  }

  /// Mark messages as read
  Future<void> markAsRead(String conversationId, String userId) async {
    final unreadMessages = _messages.where(
      (m) =>
          m.receiverId == userId &&
          !m.isRead &&
          (m.senderId == conversationId || m.receiverId == conversationId),
    );

    for (final message in unreadMessages) {
      final index = _messages.indexWhere((m) => m.id == message.id);
      if (index >= 0) {
        _messages[index] = message.copyWith(isRead: true);
        await _db.update(
          'chat_messages',
          {'is_read': 1},
          'id = ?',
          [message.id],
        );
      }
    }
  }

  /// Get unread message count for a user
  Future<int> getUnreadCount(String userId) async {
    final result = await _db.query(
      'chat_messages',
      where: 'receiver_id = ? AND is_read = 0',
      whereArgs: [userId],
    );
    return result.length;
  }

  /// Get conversations list with last message
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT 
        CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END as other_user_id,
        CASE WHEN sender_id = ? THEN receiver_name ELSE sender_name END as other_user_name,
        MAX(created_at) as last_message_time,
        (SELECT message FROM chat_messages cm2 
         WHERE (cm2.sender_id = chat_messages.sender_id AND cm2.receiver_id = chat_messages.receiver_id)
            OR (cm2.sender_id = chat_messages.receiver_id AND cm2.receiver_id = chat_messages.sender_id)
         ORDER BY cm2.created_at DESC LIMIT 1) as last_message,
        (SELECT message_type FROM chat_messages cm3
         WHERE (cm3.sender_id = chat_messages.sender_id AND cm3.receiver_id = chat_messages.receiver_id)
            OR (cm3.sender_id = chat_messages.receiver_id AND cm3.receiver_id = chat_messages.sender_id)
         ORDER BY cm3.created_at DESC LIMIT 1) as last_message_type,
        (SELECT COUNT(*) FROM chat_messages cm4
         WHERE cm4.receiver_id = ? AND cm4.is_read = 0
         AND cm4.sender_id = CASE WHEN chat_messages.sender_id = ? 
              THEN chat_messages.receiver_id ELSE chat_messages.sender_id END) as unread_count
      FROM chat_messages
      WHERE sender_id = ? OR receiver_id = ?
      GROUP BY other_user_id
      ORDER BY last_message_time DESC
    ''', [userId, userId, userId, userId, userId, userId]);

    return result;
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    _messages.removeWhere((m) => m.id == messageId);
    await _db.delete('chat_messages', 'id = ?', [messageId]);
  }

  /// Clear conversation
  Future<void> clearConversation(String userId, String otherUserId) async {
    _messages.removeWhere((m) =>
        (m.senderId == userId && m.receiverId == otherUserId) ||
        (m.senderId == otherUserId && m.receiverId == userId));

    await _db.delete(
      'chat_messages',
      '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      [userId, otherUserId, otherUserId, userId],
    );
  }

  /// Get conversation storage size
  Future<int> getConversationStorageSize() async {
    int total = 0;
    for (final message in _messages) {
      if (message.fileSize != null) {
        total += message.fileSize!;
      }
      if (message.message != null) {
        total += message.message!.length;
      }
    }
    return total;
  }

  void dispose() {
    _messages.clear();
  }
}
