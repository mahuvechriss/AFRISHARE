import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService.instance;
});

final chatStateProvider =
    StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final chatService = ref.read(chatServiceProvider);
  final authState = ref.read(authStateProvider);
  return ChatNotifier(chatService, authState.user?.id ?? '');
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
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        conversations: conversations ?? this.conversations,
        unreadCount: unreadCount ?? this.unreadCount,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatService _chatService;
  final String _currentUserId;

  ChatNotifier(this._chatService, this._currentUserId)
      : super(const ChatState());

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
    state = state.copyWith(isLoading: true);
    try {
      final messages =
          await _chatService.loadConversation(_currentUserId, otherUserId);
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
    try {
      await _chatService.sendMessage(
        senderId: _currentUserId,
        receiverId: receiverId,
        receiverName: receiverName,
        message: message,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> sendFile({
    required String receiverId,
    String? receiverName,
    required String filePath,
    required String fileName,
  }) async {
    try {
      await _chatService.sendFile(
        senderId: _currentUserId,
        receiverId: receiverId,
        receiverName: receiverName,
        filePath: filePath,
        fileName: fileName,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}
