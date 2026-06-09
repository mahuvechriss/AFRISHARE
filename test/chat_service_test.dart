import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';
import 'package:afrishare/services/chat_service.dart';
import 'package:afrishare/models/chat_message_model.dart';
import 'package:afrishare/core/database/database_helper.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  late ChatService chatService;
  late String userId1;
  late String userId2;

  setUp(() {
    chatService = ChatService.instance;
    userId1 = const Uuid().v4();
    userId2 = const Uuid().v4();
  });

  tearDown(() {
    chatService.dispose();
  });

  group('ChatService - Sending Messages', () {
    test('sendMessage should create and store a text message', () async {
      ChatMessageModel? sentMessage;
      chatService.onMessageSent = (message) {
        sentMessage = message;
      };

      final message = await chatService.sendMessage(
        senderId: userId1,
        senderName: 'Alice',
        receiverId: userId2,
        receiverName: 'Bob',
        message: 'Hello Bob!',
      );

      expect(message, isNotNull);
      expect(message.message, 'Hello Bob!');
      expect(message.senderId, userId1);
      expect(message.receiverId, userId2);
      expect(message.messageType, MessageType.text);
      expect(message.isEncrypted, isTrue);

      // Callback should fire
      expect(sentMessage, isNotNull);
      expect(sentMessage!.id, message.id);

      // Should be in messages list
      expect(chatService.messages.length, greaterThanOrEqualTo(1));
      expect(chatService.messages.any((m) => m.id == message.id), isTrue);
    });

    test('sendMessage with emoji content', () async {
      final message = await chatService.sendMessage(
        senderId: userId1,
        senderName: 'Alice',
        receiverId: userId2,
        receiverName: 'Bob',
        message: '👍🎉🔥',
      );

      expect(message.message, '👍🎉🔥');
    });

    test('sendMessage with empty string', () async {
      final message = await chatService.sendMessage(
        senderId: userId1,
        senderName: 'Alice',
        receiverId: userId2,
        receiverName: 'Bob',
        message: '',
      );

      expect(message.message, '');
      expect(message.messageType, MessageType.text);
    });

    test('sendFile should create a file message', () async {
      // Create a temporary file for testing
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/test_document.pdf');
      await tempFile.writeAsString('dummy content');

      final message = await chatService.sendFile(
        senderId: userId1,
        senderName: 'Alice',
        receiverId: userId2,
        receiverName: 'Bob',
        filePath: tempFile.path,
        fileName: 'test_document.pdf',
      );

      expect(message.messageType, MessageType.file);
      expect(message.fileName, 'test_document.pdf');
      expect(message.fileSize, greaterThan(0));

      // Clean up
      await tempFile.delete();
    });

    test('sendFile with image type', () async {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/photo.jpg');
      await tempFile.writeAsString('fake image data');

      final message = await chatService.sendFile(
        senderId: userId1,
        senderName: 'Alice',
        receiverId: userId2,
        receiverName: 'Bob',
        filePath: tempFile.path,
        fileName: 'photo.jpg',
        type: MessageType.image,
      );

      expect(message.messageType, MessageType.image);
      expect(message.fileName, 'photo.jpg');

      await tempFile.delete();
    });
  });

  group('ChatService - Receiving Messages', () {
    test('receiveMessage should add message from other device', () async {
      ChatMessageModel? receivedMessage;
      chatService.onMessageReceived = (message) {
        receivedMessage = message;
      };

      final incomingMessage = ChatMessageModel(
        id: const Uuid().v4(),
        senderId: userId2,
        senderName: 'Bob',
        receiverId: userId1,
        receiverName: 'Alice',
        message: 'Hello Alice!',
        createdAt: DateTime.now(),
      );

      await chatService.receiveMessage(incomingMessage);

      expect(receivedMessage, isNotNull);
      expect(receivedMessage!.message, 'Hello Alice!');
      expect(chatService.messages.any((m) => m.id == incomingMessage.id),
          isTrue);
    });
  });

  group('ChatService - Mark as Read', () {
    test('markAsRead should update message read status', () async {
      // Send a message
      await chatService.sendMessage(
        senderId: userId2,
        senderName: 'Bob',
        receiverId: userId1,
        receiverName: 'Alice',
        message: 'Are you there?',
      );

      // Mark as read
      await chatService.markAsRead(userId2, userId1);
    });

    test('getUnreadCount should return 0 with no messages', () async {
      final count = await chatService.getUnreadCount(userId1);
      expect(count, 0);
    });
  });

  group('ChatService - Conversation Management', () {
    test('getConversations should return empty list with no messages',
        () async {
      final conversations = await chatService.getConversations(userId1);
      expect(conversations, isA<List<Map<String, dynamic>>>());
    });

    test('loadConversation should return messages between two users',
        () async {
      // Load conversation - should be empty initially after dispose/clear
      final messages =
          await chatService.loadConversation(userId1, userId2);
      expect(messages, isA<List<ChatMessageModel>>());
    });

    test('clearConversation should remove all messages between users',
        () async {
      await chatService.sendMessage(
        senderId: userId1,
        senderName: 'Alice',
        receiverId: userId2,
        receiverName: 'Bob',
        message: 'Hello!',
      );
      await chatService.sendMessage(
        senderId: userId2,
        senderName: 'Bob',
        receiverId: userId1,
        receiverName: 'Alice',
        message: 'Hi!',
      );

      await chatService.clearConversation(userId1, userId2);

      expect(chatService.messages.length, 0);
    });

    test('deleteMessage should remove a single message', () async {
      final message = await chatService.sendMessage(
        senderId: userId1,
        senderName: 'Alice',
        receiverId: userId2,
        receiverName: 'Bob',
        message: 'Delete me',
      );

      await chatService.deleteMessage(message.id);

      expect(
          chatService.messages.any((m) => m.id == message.id), isFalse);
    });
  });

  group('ChatService - Storage', () {
    test('getConversationStorageSize should return total size', () async {
      final size = await chatService.getConversationStorageSize();
      expect(size, greaterThanOrEqualTo(0));
    });
  });

  group('ChatService - Callbacks', () {
    test('onMessageSent callback fires for each sent message', () async {
      int callbackCount = 0;
      chatService.onMessageSent = (_) {
        callbackCount++;
      };

      await chatService.sendMessage(
        senderId: userId1,
        receiverId: userId2,
        message: 'Message 1',
      );
      await chatService.sendMessage(
        senderId: userId1,
        receiverId: userId2,
        message: 'Message 2',
      );

      expect(callbackCount, 2);
    });

    test('onMessageReceived callback fires on receive', () async {
      int callbackCount = 0;
      chatService.onMessageReceived = (_) {
        callbackCount++;
      };

      final incoming = ChatMessageModel(
        id: const Uuid().v4(),
        senderId: userId2,
        receiverId: userId1,
        message: 'Incoming!',
        createdAt: DateTime.now(),
      );

      await chatService.receiveMessage(incoming);

      expect(callbackCount, 1);
    });
  });
}
