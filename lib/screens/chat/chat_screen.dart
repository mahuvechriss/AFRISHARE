import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/chat_provider.dart';
import '../../providers/discovery_provider.dart';
import '../../models/device_model.dart';
import '../../services/auth_service.dart';
import '../../services/call_service.dart';
import '../../services/contact_service.dart';
import '../../widgets/chat/chat_bubble.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/profile_avatar.dart';
import '../call/call_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _nickname;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      ref.read(chatStateProvider.notifier).loadConversation(widget.otherUserId);
      _nickname = await ContactService.instance.getNickname(widget.otherUserId);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _displayName => _nickname ?? widget.otherUserName;

  void _editNickname() {
    final controller = TextEditingController(text: _nickname ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Nickname'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter a local nickname',
            prefixIcon: Icon(Icons.edit),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (_nickname != null) {
                ContactService.instance.removeNickname(widget.otherUserId);
                setState(() => _nickname = null);
              }
            },
            child: Text(
              'Remove',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ContactService.instance.setNickname(widget.otherUserId, name);
                setState(() => _nickname = name);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'Delete all messages in this conversation? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(chatStateProvider.notifier)
                  .clearConversation(widget.otherUserId);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref
        .read(chatStateProvider.notifier)
        .sendMessage(
          receiverId: widget.otherUserId,
          receiverName: widget.otherUserName,
          message: text,
        );

    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);
    final discoveryState = ref.watch(discoveryStateProvider);
    final currentUserId = AuthService.instance.currentUser?.deviceId ?? '';
    final otherDevice = discoveryState.devices
        .where((d) => d.deviceId == widget.otherUserId)
        .cast<DeviceModel?>()
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ProfileAvatar(
              deviceId: widget.otherUserId,
              name: _displayName,
              radius: 16,
              fontSize: 14,
              ipAddress: otherDevice?.ipAddress,
              port: otherDevice?.port ?? AppConstants.discoveryPort,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayName,
                    style: const TextStyle(fontSize: 17),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_nickname != null && _nickname != widget.otherUserName)
                    Text(
                      widget.otherUserName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              CallService.instance.startCall(
                remoteId: widget.otherUserId,
                remoteName: widget.otherUserName,
                video: false,
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CallScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              CallService.instance.startCall(
                remoteId: widget.otherUserId,
                remoteName: widget.otherUserName,
                video: true,
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CallScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _confirmClearChat();
              } else if (value == 'nickname') {
                _editNickname();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'nickname',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: AppColors.primaryGreen, size: 20),
                    SizedBox(width: 8),
                    Text('Edit Nickname'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Clear Chat',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Error banner
          if (chatState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: AppColors.error.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatState.error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.error,
                      size: 16,
                    ),
                    onPressed: () =>
                        ref.read(chatStateProvider.notifier).clearError(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          // Messages List
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'No messages yet',
                    subtitle: 'Say hello to start the conversation',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      final isSentByMe = message.senderId == currentUserId;
                      return ChatBubble(
                        message: message,
                        isSentByMe: isSentByMe,
                        onDelete: (msg) {
                          ref
                              .read(chatStateProvider.notifier)
                              .deleteMessage(msg.id);
                        },
                      );
                    },
                  ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceDark
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    // Open emoji picker
                  },
                  icon: const Icon(
                    Icons.emoji_emotions_outlined,
                    color: AppColors.warning,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.cardDark
                          : AppColors.backgroundLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryGreen,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
