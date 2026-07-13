import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message_model.dart';
import '../core/database/database_helper.dart';

/// Service for offline chat between connected devices
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final Uuid _uuid = const Uuid();
  final DatabaseHelper _db = DatabaseHelper.instance;

  final List<ChatMessageModel> _messages = [];

  File? _messagesFile;
  bool _fileLoaded = false;

  // Callbacks
  void Function(ChatMessageModel message)? onMessageReceived;
  void Function(ChatMessageModel message)? onMessageSent;
  void Function(String conversationId)? onConversationUpdated;
  Future<bool> Function(ChatMessageModel message, String ip, int port)? onDeliverPending;

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);

  Future<File> _getMessagesFile() async {
    if (_messagesFile != null) return _messagesFile!;
    final dir = await getApplicationDocumentsDirectory();
    _messagesFile = File('${dir.path}/chat_messages.json');
    return _messagesFile!;
  }

  Future<void> _loadFromFile() async {
    if (_fileLoaded) return;
    _fileLoaded = true;
    try {
      final file = await _getMessagesFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        _messages.clear();
        for (final item in list) {
          _messages.add(ChatMessageModel.fromJson(item as Map<String, dynamic>));
        }
        debugPrint('ChatService: Loaded ${_messages.length} messages from file');
      }
    } catch (e) {
      debugPrint('ChatService: Error loading messages file: $e');
    }
  }

  Future<void> _saveToFile() async {
    try {
      final file = await _getMessagesFile();
      final content = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await file.writeAsString(content);
    } catch (e) {
      debugPrint('ChatService: Error saving messages file: $e');
    }
  }

  /// Load chat history for a specific conversation
  Future<List<ChatMessageModel>> loadConversation(
      String userId, String otherUserId) async {
    await _loadFromFile();

    // Collect conversation messages from file cache
    final conversationMessages = _messages.where((m) =>
        (m.senderId == userId && m.receiverId == otherUserId) ||
        (m.senderId == otherUserId && m.receiverId == userId)).toList();

    // Try DB — if it returns results, use those (they include file data + DB data)
    try {
      final results = await _db.query(
        'chat_messages',
        where:
            '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
        whereArgs: [userId, otherUserId, otherUserId, userId],
        orderBy: 'created_at ASC',
      );
      if (results.isNotEmpty) {
        final dbMessages = results
            .map((row) => ChatMessageModel.fromJson(row))
            .toList();
        // Merge: remove duplicates by ID, preferring DB version
        final seenIds = <String>{};
        final merged = <ChatMessageModel>[];
        for (final msg in dbMessages) {
          if (seenIds.add(msg.id)) merged.add(msg);
        }
        for (final msg in conversationMessages) {
          if (seenIds.add(msg.id)) merged.add(msg);
        }
        merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return merged;
      }
    } catch (e) {
      debugPrint('ChatService: DB query failed, using file cache: $e');
    }

    // Fall back to file cache sorted chronologically
    conversationMessages
        .sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return conversationMessages;
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
    await _saveToFile();
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
    await _saveToFile();
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
    await _saveToFile();
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
    await _loadFromFile();
    return _messages.where((m) =>
        m.receiverId == userId && !m.isRead).length;
  }

  /// Get conversations list with last message
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    await _loadFromFile();

    final Map<String, Map<String, dynamic>> conversations = {};
    final Map<String, DateTime> lastTimes = {};

    for (final msg in _messages) {
      final isSentByMe = msg.senderId == userId;
      final otherId = isSentByMe ? msg.receiverId : msg.senderId;

      final existing = lastTimes[otherId];
      if (existing == null || msg.createdAt.isAfter(existing)) {
        lastTimes[otherId] = msg.createdAt;
        final otherName = isSentByMe ? msg.receiverName : msg.senderName;
        conversations[otherId] = {
          'other_user_id': otherId,
          'other_user_name': otherName ?? 'Unknown',
          'last_message_time': msg.createdAt.toIso8601String(),
          'last_message': msg.message ?? '',
          'last_message_type': msg.messageType.name,
        };
      }
    }

    // Count unread separately
    for (final msg in _messages) {
      final isSentByMe = msg.senderId == userId;
      if (!isSentByMe && !msg.isRead) {
        final otherId = msg.senderId;
        if (conversations.containsKey(otherId)) {
          conversations[otherId]!['unread_count'] =
              ((conversations[otherId]!['unread_count'] as int?) ?? 0) + 1;
        }
      }
    }

    // Ensure unread_count exists for all
    for (final entry in conversations.values) {
      entry.putIfAbsent('unread_count', () => 0);
    }

    final result = conversations.values.toList();
    result.sort((a, b) => (b['last_message_time'] as String)
        .compareTo(a['last_message_time'] as String));
    return result;
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    _messages.removeWhere((m) => m.id == messageId);
    await _db.delete('chat_messages', 'id = ?', [messageId]);
    await _saveToFile();
  }

  /// Clear conversation - removes messages from current view only
  /// Keeps messages in DB so the conversation stays visible in the chat list.
  Future<void> clearConversation(String userId, String otherUserId) async {
    _messages.removeWhere((m) =>
        (m.senderId == userId && m.receiverId == otherUserId) ||
        (m.senderId == otherUserId && m.receiverId == userId));
  }

  /// Clear ALL messages from memory, DB, and file backup
  Future<void> clearAllMessages() async {
    _messages.clear();
    // Overwrite the file with an empty array
    try {
      final file = await _getMessagesFile();
      await file.writeAsString('[]');
    } catch (e) {
      debugPrint('ChatService: Error clearing messages file: $e');
    }
  }

  /// Save a message to the pending queue (offline delivery)
  Future<void> savePendingMessage({
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
      isEncrypted: false,
      createdAt: DateTime.now(),
    );
    // Only insert columns that exist in the pending_messages table
    await _db.insert('pending_messages', {
      'id': chatMessage.id,
      'sender_id': chatMessage.senderId,
      'sender_name': chatMessage.senderName,
      'receiver_id': chatMessage.receiverId,
      'receiver_name': chatMessage.receiverName,
      'message': chatMessage.message,
      'message_type': chatMessage.messageType.name,
      'created_at': chatMessage.createdAt.toIso8601String(),
    });
    debugPrint('ChatService: Saved pending message for $receiverName');
  }

  /// Get all pending messages for a device
  Future<List<ChatMessageModel>> getPendingMessages(String deviceId) async {
    final results = await _db.query(
      'pending_messages',
      where: 'receiver_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at ASC',
    );
    return results.map((row) => ChatMessageModel.fromJson(row)).toList();
  }

  /// Delete a pending message after delivery
  Future<void> deletePendingMessage(String messageId) async {
    await _db.delete('pending_messages', 'id = ?', [messageId]);
  }

  /// Deliver pending messages to a newly discovered device
  Future<void> deliverPendingMessages(
    String deviceId,
    String deviceIp,
    int devicePort,
  ) async {
    final pending = await getPendingMessages(deviceId);
    if (pending.isEmpty || onDeliverPending == null) return;

    debugPrint('ChatService: Delivering ${pending.length} pending message(s) to $deviceId');
    for (final msg in pending) {
      try {
        final sent = await onDeliverPending!(msg, deviceIp, devicePort);
        if (sent) {
          await deletePendingMessage(msg.id);
        }
      } catch (e) {
        debugPrint('ChatService: Failed to deliver pending message: $e');
      }
    }
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
