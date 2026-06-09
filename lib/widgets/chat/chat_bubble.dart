import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/chat_message_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/file_utils.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isSentByMe;

  const ChatBubble({
    super.key,
    required this.message,
    this.isSentByMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          left: isSentByMe ? 60 : 16,
          right: isSentByMe ? 16 : 60,
          top: 4,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment:
              isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.senderName != null && !isSentByMe) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  message.senderName!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
            ],
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSentByMe
                    ? AppColors.primaryGreen
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(
                    isSentByMe ? 16 : 4,
                  ),
                  bottomRight: Radius.circular(
                    isSentByMe ? 4 : 16,
                  ),
                ),
              ),
              child: _buildContent(),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    FileUtils.formatChatDate(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  if (isSentByMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: message.isRead
                          ? AppColors.primaryBlue
                          : Colors.grey.shade500,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (message.messageType == MessageType.text ||
        message.messageType == MessageType.emoji) {
      return Text(
        message.message ?? '',
        style: TextStyle(
          fontSize: 15,
          color: isSentByMe ? Colors.white : Colors.black87,
        ),
      );
    }

    if (message.messageType == MessageType.image) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.filePath != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(message.filePath!),
                height: 150,
                width: 150,
                fit: BoxFit.cover,
              ),
            ),
          if (message.message != null) ...[
            const SizedBox(height: 4),
            Text(
              message.message!,
              style: TextStyle(
                fontSize: 13,
                color: isSentByMe ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ],
      );
    }

    // File attachment
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.attach_file,
          size: 20,
          color: isSentByMe ? Colors.white70 : Colors.black54,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.fileName ?? 'File',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSentByMe ? Colors.white : Colors.black87,
                ),
              ),
              if (message.fileSize != null)
                Text(
                  FileUtils.formatFileSize(message.fileSize!),
                  style: TextStyle(
                    fontSize: 11,
                    color: isSentByMe ? Colors.white60 : Colors.black54,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
