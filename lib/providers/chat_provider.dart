import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService.instance;
});

final chatStateProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final chatService = ref.read(chatServiceProvider);
  debugPrint('ChatProvider: creating notifier');
  return ChatNotifier(chatService);
});

class ChatState {
  final List<ChatMessageModel> messages;
  final List<Map<String, dynamic>> conversations;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.conversations = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessageModel>? messages,
    List<Map<String, dynamic>>? conversations,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) => ChatState(
    messages: messages ?? this.messages,
    conversations: conversations ?? this.conversations,
    unreadCount: unreadCount ?? this.unreadCount,
    isLoading: isLoading ?? this.isLoading,
    error: error ?? this.error,
  );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _chatService;
  String? _activeConversationId;

  String get _currentUserId =>
      AuthService.instance.currentUser?.deviceId ?? '';
  String get _currentUserName =>
      AuthService.instance.currentUser?.username ?? 'Unknown';

  ChatNotifier(this._chatService) : super(const ChatState()) {
    _chatService.onMessageReceived = (message) {
      // Only append message if it belongs to the active conversation
      if (_activeConversationId != null &&
          (message.senderId == _activeConversationId ||
           message.receiverId == _activeConversationId)) {
        state = state.copyWith(messages: [...state.messages, message]);
      }
      loadConversations();
    };
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true);
    try {
      final conversations = await _chatService.getConversations(_currentUserId);
      final unreadCount = await _chatService.getUnreadCount(_currentUserId);
      state = state.copyWith(
        conversations: conversations,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadConversation(String otherUserId) async {
    _activeConversationId = otherUserId;
    state = state.copyWith(isLoading: true);
    try {
      final messages = await _chatService.loadConversation(
        _currentUserId,
        otherUserId,
      );
      state = state.copyWith(messages: messages, isLoading: false);
      await _chatService.markAsRead(otherUserId, _currentUserId);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage({
    required String receiverId,
    String? receiverName,
    required String message,
  }) async {
    final uid = _currentUserId;
    final uname = _currentUserName;

    final optimisticId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = ChatMessageModel(
      id: optimisticId,
      senderId: uid,
      senderName: uname,
      receiverId: receiverId,
      receiverName: receiverName,
      message: message,
      messageType: MessageType.text,
      isEncrypted: true,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(messages: [...state.messages, optimisticMessage]);

    try {
      final chatMessage = await _chatService.sendMessage(
        senderId: uid,
        senderName: uname,
        receiverId: receiverId,
        receiverName: receiverName,
        message: message,
      );
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == optimisticId ? chatMessage : m)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != optimisticId).toList(),
        error: e.toString(),
      );
    }
  }

  Future<void> sendFile({
    required String receiverId,
    String? receiverName,
    required String filePath,
    required String fileName,
  }) async {
    final uid = _currentUserId;
    final uname = _currentUserName;

    final optimisticId = 'opt_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMessage = ChatMessageModel(
      id: optimisticId,
      senderId: uid,
      senderName: uname,
      receiverId: receiverId,
      receiverName: receiverName,
      message: fileName,
      messageType: MessageType.file,
      filePath: filePath,
      fileName: fileName,
      isEncrypted: true,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(messages: [...state.messages, optimisticMessage]);

    try {
      final chatMessage = await _chatService.sendFile(
        senderId: uid,
        senderName: uname,
        receiverId: receiverId,
        receiverName: receiverName,
        filePath: filePath,
        fileName: fileName,
      );
      state = state.copyWith(
        messages: state.messages
            .map((m) => m.id == optimisticId ? chatMessage : m)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != optimisticId).toList(),
        error: e.toString(),
      );
    }
  }

  Future<void> clearConversation(String otherUserId) async {
    try {
      await _chatService.clearConversation(_currentUserId, otherUserId);
      state = state.copyWith(messages: []);
      await loadConversations();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _chatService.deleteMessage(messageId);
      state = state.copyWith(
        messages: state.messages.where((m) => m.id != messageId).toList(),
      );
      await loadConversations();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _chatService.onMessageReceived = null;
    _chatService.dispose();
    super.dispose();
  }
}
