import 'dart:io';
import 'package:flutter/foundation.dart';

class CompressionUtils {
  CompressionUtils._();

  static const int _maxCompressionSize = 500 * 1024 * 1024;
  static const int _minCompressionSize = 1024;

  static bool shouldCompress(String filePath, int fileSize) {
    if (fileSize < _minCompressionSize || fileSize > _maxCompressionSize) {
      return false;
    }
    final ext = filePath.split('.').last.toLowerCase();
    final alreadyCompressed = [
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
      'mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv',
      'mp3', 'wav', 'aac', 'ogg', 'flac', 'wma',
      'zip', 'rar', '7z', 'tar', 'gz',
    ];
    return !alreadyCompressed.contains(ext);
  }

  static Future<String> compressFile(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return sourcePath;

    final compressedPath = '$sourcePath.gz';
    try {
      final bytes = await sourceFile.readAsBytes();
      final compressed = GZipCodec(level: 6).encode(bytes);
      await File(compressedPath).writeAsBytes(compressed);

      if (kReleaseMode == false) {
        final originalSize = bytes.length;
        final compressedSize = compressed.length;
        final ratio = originalSize > 0
            ? ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1)
            : '0.0';
        debugPrint('CompressionUtils: $ratio% reduction '
            '($originalSize -> $compressedSize bytes)');
      }

      return compressedPath;
    } catch (e) {
      debugPrint('CompressionUtils: Compression error: $e');
      return sourcePath;
    }
  }

  static Future<String> decompressFile(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return sourcePath;

    if (!sourcePath.endsWith('.gz')) return sourcePath;

    final decompressedPath = sourcePath.substring(0, sourcePath.length - 3);
    try {
      final bytes = await sourceFile.readAsBytes();
      final decompressed = GZipCodec().decode(bytes);
      await File(decompressedPath).writeAsBytes(decompressed);
      return decompressedPath;
    } catch (e) {
      debugPrint('CompressionUtils: Decompression error: $e');
      return sourcePath;
    }
  }

  static Future<Uint8List> compressBytes(List<int> bytes) async {
    return Uint8List.fromList(GZipCodec(level: 6).encode(bytes));
  }

  static Future<Uint8List> decompressBytes(List<int> bytes) async {
    return Uint8List.fromList(GZipCodec().decode(bytes));
  }
}
