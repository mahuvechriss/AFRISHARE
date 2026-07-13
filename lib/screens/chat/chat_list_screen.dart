import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/chat_provider.dart';
import '../../providers/discovery_provider.dart';
import '../../services/auth_service.dart';
import '../../services/contact_service.dart';
import '../../services/chat_service.dart';
import '../../models/device_model.dart';
import '../../core/utils/file_utils.dart';
import '../../core/database/database_helper.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/common/profile_avatar.dart';
import '../discovery/discovery_screen.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  Map<String, String> _nicknames = {};
  bool _showOnline = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      ref.read(chatStateProvider.notifier).loadConversations();
      _nicknames = await ContactService.instance.getAllNicknames();
      if (mounted) setState(() {});
      ref.read(discoveryStateProvider.notifier).searchDevices();
    });
  }

  void _confirmClearAllChats() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Chats'),
        content: const Text(
          'Delete all conversations and messages? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DatabaseHelper.instance.delete('chat_messages', '1=1', []);
              // Also clear the in-memory cache and file backup
              await ChatService.instance.clearAllMessages();
              ref.read(chatStateProvider.notifier).loadConversations();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(
              'Clear All',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatStateProvider);
    final discoveryState = ref.watch(discoveryStateProvider);
    final devices = discoveryState.devices
        .where(
          (d) => d.isConnectable && d.deviceId != AuthService.instance.deviceId,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Chat'),
        actions: [
          if (chatState.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_all') {
                _confirmClearAllChats();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Clear All Chats',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showOnline = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _showOnline
                            ? AppColors.primaryGreen
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Online (${devices.length})',
                          style: TextStyle(
                            color: _showOnline ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showOnline = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_showOnline
                            ? AppColors.primaryGreen
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Chats (${chatState.conversations.length})',
                          style: TextStyle(
                            color: !_showOnline ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _showOnline ? _buildOnlineView(devices, discoveryState.isScanning) : _buildChatsView(chatState, discoveryState),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineView(List<DeviceModel> devices, bool isScanning) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Available Devices',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  if (isScanning)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  if (isScanning) const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      ref.read(discoveryStateProvider.notifier).searchDevices();
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.devices_rounded,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No devices found',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Make sure both devices are on the same WiFi\nand discovery is enabled',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DiscoveryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Open Discovery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: devices.length,
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      leading: ProfileAvatar(
                        deviceId: device.deviceId,
                        name: device.name,
                        radius: 20,
                        fontSize: 16,
                        ipAddress: device.ipAddress,
                        port: device.port ?? AppConstants.discoveryPort,
                      ),
                      title: Text(
                        device.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: device.isPaired
                                  ? AppColors.primaryGreen
                                  : Colors.green,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            device.isPaired ? 'Paired' : 'Online',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.primaryGreen,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              otherUserId: device.deviceId,
                              otherUserName: device.name,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChatsView(ChatState chatState, DiscoveryState discoveryState) {
    if (chatState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (chatState.conversations.isEmpty) {
      return Center(
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Start chatting with a nearby device from the Online tab',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: chatState.conversations.length,
      itemBuilder: (context, index) {
        final conv = chatState.conversations[index];
        final otherId = conv['other_user_id'] as String? ?? '';
        final isOnline = discoveryState.devices.any(
          (d) => d.deviceId == otherId && d.isConnectable,
        );
        final otherName = conv['other_user_name'] as String? ?? 'Unknown';
        final displayName = _nicknames[otherId] ?? otherName;
        final otherDevice = discoveryState.devices
            .where((d) => d.deviceId == otherId)
            .cast<DeviceModel?>()
            .firstOrNull;
        return _ConversationTile(
          name: displayName,
          originalName: _nicknames.containsKey(otherId) ? otherName : null,
          deviceId: otherId,
          ipAddress: otherDevice?.ipAddress,
          port: otherDevice?.port ?? AppConstants.discoveryPort,
          lastMessage: conv['last_message'] as String? ?? 'No messages',
          lastMessageType: conv['last_message_type'] as String? ?? 'text',
          time: conv['last_message_time'] != null
              ? DateTime.parse(conv['last_message_time'] as String)
              : DateTime.now(),
          unreadCount: conv['unread_count'] as int? ?? 0,
          isOnline: isOnline,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  otherUserId: otherId,
                  otherUserName: conv['other_user_name'] as String? ?? '',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final String name;
  final String? originalName;
  final String lastMessage;
  final String lastMessageType;
  final DateTime time;
  final int unreadCount;
  final bool isOnline;
  final VoidCallback? onTap;
  final String? deviceId;
  final String? ipAddress;
  final int? port;

  const _ConversationTile({
    required this.name,
    this.originalName,
    required this.lastMessage,
    required this.lastMessageType,
    required this.time,
    this.unreadCount = 0,
    this.isOnline = false,
    this.onTap,
    this.deviceId,
    this.ipAddress,
    this.port,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          ProfileAvatar(
            deviceId: deviceId ?? '',
            name: name,
            radius: 24,
            fontSize: 18,
            ipAddress: ipAddress,
            port: port,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline
                    ? AppColors.deviceOnline
                    : AppColors.deviceOffline,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          if (originalName != null)
            Text(
              originalName!,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      subtitle: Row(
        children: [
          if (lastMessageType != 'text')
            Icon(Icons.attach_file, size: 14, color: Colors.grey.shade500),
          if (lastMessageType != 'text') const SizedBox(width: 4),
          Expanded(
            child: Text(
              lastMessageType != 'text' ? 'File' : lastMessage,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
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
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
