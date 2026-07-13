import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/file_utils.dart';

/// Service managing local storage for transfers, cache, and resources
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  Directory? _appDir;
  Directory? _transferDir;
  Directory? _cacheDir;
  Directory? _resourcesDir;
  Directory? _profileDir;
  File? _configFile;
  String? _customTransferPath;

  /// Initialize storage directories
  Future<void> initialize() async {
    _appDir = await getApplicationDocumentsDirectory();
    _configFile = File('${_appDir!.path}/storage_config.json');
    await _loadCustomPath();

    if (_customTransferPath != null) {
      _transferDir = Directory(_customTransferPath!);
    } else {
      _transferDir = await _resolveTransferDir();
    }

    _cacheDir = Directory('${_appDir!.path}/${AppConstants.cacheDirectory}');
    _resourcesDir = Directory(
      '${_appDir!.path}/${AppConstants.sharedResourcesDirectory}',
    );
    _profileDir = Directory(
      '${_appDir!.path}/${AppConstants.profileImagesDirectory}',
    );

    await _transferDir!.create(recursive: true);
    await _cacheDir!.create(recursive: true);
    await _resourcesDir!.create(recursive: true);
    await _profileDir!.create(recursive: true);
  }

  /// Resolve the best transfer directory: try Downloads first, fall back gracefully
  Future<Directory> _resolveTransferDir() async {
    // Try public Downloads folder (survives uninstall)
    final downloadsPath = await _getDownloadsPath();
    if (downloadsPath != null) {
      try {
        final dir = Directory(downloadsPath);
        await dir.create(recursive: true);
        return dir;
      } catch (_) {
        // Permission denied or other error — fall through to fallback
      }
    }
    // Fallback to app-external storage (also accessible, but deleted on uninstall)
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final fallback = Directory(
          '${extDir.path}/${AppConstants.transferDirectory}',
        );
        await fallback.create(recursive: true);
        return fallback;
      }
    } catch (_) {}
    // Final fallback to app documents directory
    final fallback = Directory(
      '${_appDir!.path}/${AppConstants.transferDirectory}',
    );
    await fallback.create(recursive: true);
    return fallback;
  }

  /// Get public Downloads path that survives app uninstall, or null if not accessible
  Future<String?> _getDownloadsPath() async {
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final path = extDir.path;
        // extDir is like /storage/emulated/0/Android/data/<package>/files
        // We want /storage/emulated/0/Download/AfriShare
        final baseIndex = path.indexOf('/Android');
        if (baseIndex > 0) {
          final storageRoot = path.substring(0, baseIndex);
          return '$storageRoot/Download/AfriShare';
        }
      }
    } catch (_) {}
    return null;
  }

  String get transferPath => _transferDir!.path;
  String get cachePath => _cacheDir!.path;
  String get resourcesPath => _resourcesDir!.path;
  String get profilePath => _profileDir!.path;

  Directory get transferDirectory => _transferDir!;
  Directory get cacheDirectory => _cacheDir!;
  Directory get resourcesDirectory => _resourcesDir!;

  /// Load custom storage path from config file
  Future<void> _loadCustomPath() async {
    try {
      if (_configFile != null && await _configFile!.exists()) {
        final content = await _configFile!.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        _customTransferPath = data['transferPath'] as String?;
      }
    } catch (_) {
      _customTransferPath = null;
    }
  }

  /// Save custom storage path to config file
  Future<void> setCustomPath(String path) async {
    _customTransferPath = path;
    final data = jsonEncode({'transferPath': path});
    if (_configFile != null) {
      await _configFile!.writeAsString(data);
    }
    // Re-create transfer directory at new location
    _transferDir = Directory(path);
    await _transferDir!.create(recursive: true);
  }

  /// Reset to default app storage
  Future<void> resetToDefaultPath() async {
    _customTransferPath = null;
    if (_configFile != null && await _configFile!.exists()) {
      await _configFile!.delete();
    }
    _transferDir = await _resolveTransferDir();
  }

  bool get hasCustomPath => _customTransferPath != null;

  /// Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    final transferSize = await FileUtils.getDirectorySize(_transferDir!);
    final cacheSize = await FileUtils.getDirectorySize(_cacheDir!);
    final resourcesSize = await FileUtils.getDirectorySize(_resourcesDir!);
    final total = transferSize + cacheSize + resourcesSize;

    return {
      'transferSize': transferSize,
      'cacheSize': cacheSize,
      'resourcesSize': resourcesSize,
      'totalSize': total,
      'transferSizeFormatted': FileUtils.formatFileSize(transferSize),
      'cacheSizeFormatted': FileUtils.formatFileSize(cacheSize),
      'resourcesSizeFormatted': FileUtils.formatFileSize(resourcesSize),
      'totalSizeFormatted': FileUtils.formatFileSize(total),
    };
  }

  /// Clear transfer cache
  Future<void> clearCache() async {
    await FileUtils.clearDirectory(_cacheDir!);
  }

  /// Clear all transfers
  Future<void> clearTransfers() async {
    await FileUtils.clearDirectory(_transferDir!);
  }

  /// Clear all data (factory reset)
  Future<void> clearAll() async {
    await clearCache();
    await clearTransfers();

    // Keep resources directory as it contains community content
  }

  /// Auto-cleanup based on storage limits
  Future<void> autoCleanup() async {
    final stats = await getStorageStats();

    // In production, this would check against configured storage limit
    // and remove oldest files if over limit
    const maxStorageBytes = 1024 * 1024 * 1024; // 1GB limit

    if (stats['totalSize'] > maxStorageBytes) {
      await _removeOldestTransfers();
    }
  }

  /// Remove oldest transfer files to free space
  Future<void> _removeOldestTransfers() async {
    final files = _transferDir!.listSync().whereType<File>().toList();
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

    // Remove oldest 20% of files
    final removeCount = (files.length * 0.2).ceil();
    for (var i = 0; i < removeCount && i < files.length; i++) {
      try {
        await files[i].delete();
      } catch (_) {}
    }
  }

  /// Get transferred files list
  Future<List<FileSystemEntity>> getTransferFiles() async {
    return _transferDir!.listSync();
  }

  /// Save profile image
  Future<String?> saveProfileImage(String sourcePath) async {
    try {
      final source = File(sourcePath);
      final ext = sourcePath.split('.').last;
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final destPath = '${_profileDir!.path}/$fileName';
      await source.copy(destPath);
      return destPath;
    } catch (_) {
      return null;
    }
  }

  /// Delete profile image
  Future<void> deleteProfileImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  void dispose() {
    // No cleanup needed for directories
  }
}
