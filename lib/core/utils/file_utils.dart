import 'dart:io';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import '../constants/app_constants.dart';

class FileUtils {
  FileUtils._();

  /// Format file size to human-readable string
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 100 ? 0 : 1)} ${suffixes[i]}';
  }

  /// Format transfer speed
  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    return '${formatFileSize(bytesPerSecond)}/s';
  }

  /// Format duration from seconds
  static String formatDuration(int seconds) {
    if (seconds <= 0) return 'Calculating...';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  /// Format date
  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return DateFormat('MMM dd, yyyy').format(date);
  }

  /// Format date for chat messages
  static String formatChatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return DateFormat('hh:mm a').format(date);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('hh:mm a').format(date)}';
    } else if (date.year == now.year) {
      return DateFormat('MMM dd, hh:mm a').format(date);
    }
    return DateFormat('MMM dd yyyy, hh:mm a').format(date);
  }

  /// Get file type category
  static FileType getFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();

    if (AppConstants.supportedImageTypes.contains(ext)) {
      return FileType.image;
    } else if (AppConstants.supportedVideoTypes.contains(ext)) {
      return FileType.video;
    } else if (AppConstants.supportedAudioTypes.contains(ext)) {
      return FileType.audio;
    } else if (AppConstants.supportedDocumentTypes.contains(ext)) {
      return FileType.document;
    } else if (AppConstants.supportedArchiveTypes.contains(ext)) {
      return FileType.archive;
    } else if (AppConstants.supportedAppTypes.contains(ext)) {
      return FileType.app;
    }
    return FileType.other;
  }

  /// Get MIME type from file extension
  static String? getMimeType(String fileName) {
    return lookupMimeType(fileName);
  }

  /// Get file icon based on type
  static String getFileIcon(String fileName) {
    final type = getFileType(fileName);
    switch (type) {
      case FileType.image:
        return '🖼️';
      case FileType.video:
        return '🎬';
      case FileType.audio:
        return '🎵';
      case FileType.document:
        return '📄';
      case FileType.archive:
        return '📦';
      case FileType.app:
        return '📱';
      case FileType.other:
        return '📁';
    }
  }

  /// Get file type display name
  static String getFileTypeDisplayName(String fileName) {
    final type = getFileType(fileName);
    switch (type) {
      case FileType.image:
        return 'Image';
      case FileType.video:
        return 'Video';
      case FileType.audio:
        return 'Audio';
      case FileType.document:
        return 'Document';
      case FileType.archive:
        return 'Archive';
      case FileType.app:
        return 'Application';
      case FileType.other:
        return 'File';
    }
  }

  /// Check if file transfer is supported
  static bool isSupportedFileType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return AppConstants.allSupportedTypes.contains(ext);
  }

  /// Generate a unique file name to avoid conflicts
  static String generateUniqueFileName(String directory, String fileName) {
    final file = File('$directory/$fileName');
    if (!file.existsSync()) return fileName;

    final nameWithoutExt = fileName.split('.').first;
    final ext = fileName.contains('.') ? '.${fileName.split('.').last}' : '';
    var counter = 1;

    while (File('$directory/${nameWithoutExt}_($counter)$ext').existsSync()) {
      counter++;
    }

    return '${nameWithoutExt}_($counter)$ext';
  }

  /// Get directory size
  static Future<int> getDirectorySize(Directory directory) async {
    int totalSize = 0;
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (_) {}
    return totalSize;
  }

  /// Clear directory contents
  static Future<void> clearDirectory(Directory directory) async {
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        try {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        } catch (_) {}
      }
    }
  }
}

enum FileType {
  image,
  video,
  audio,
  document,
  archive,
  app,
  other,
}
