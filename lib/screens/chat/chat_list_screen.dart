import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../core/utils/file_utils.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(chatStateProvider.notifier).loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Chat'),
        actions: [
          if (chatState.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${chatState.unreadCount} new',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: chatState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : chatState.conversations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGreenSurface,
                        ),
                        child: const Icon(
                          Icons.chat_rounded,
                          size: 48,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'No conversations yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connect to nearby devices to start chatting',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: chatState.conversations.length,
                  itemBuilder: (context, index) {
                    final conv = chatState.conversations[index];
                    return _ConversationTile(
                      name: conv['other_user_name'] as String? ?? 'Unknown',
                      lastMessage:
                          conv['last_message'] as String? ?? 'No messages',
                      lastMessageType:
                          conv['last_message_type'] as String? ?? 'text',
                      time: conv['last_message_time'] != null
                          ? DateTime.parse(conv['last_message_time'] as String)
                          : DateTime.now(),
                      unreadCount: conv['unread_count'] as int? ?? 0,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              otherUserId:
                                  conv['other_user_id'] as String? ?? '',
                              otherUserName:
                                  conv['other_user_name'] as String? ?? '',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String lastMessageType;
  final DateTime time;
  final int unreadCount;
  final VoidCallback? onTap;

  const _ConversationTile({
    required this.name,
    required this.lastMessage,
    required this.lastMessageType,
    required this.time,
    this.unreadCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primaryGreenSurface,
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Row(
        children: [
          if (lastMessageType != 'text')
            Icon(
              Icons.attach_file,
              size: 14,
              color: Colors.grey.shade500,
            ),
          if (lastMessageType != 'text') const SizedBox(width: 4),
          Expanded(
            child: Text(
              lastMessageType != 'text'
                  ? 'File'
                  : lastMessage,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            FileUtils.formatChatDate(time),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}
