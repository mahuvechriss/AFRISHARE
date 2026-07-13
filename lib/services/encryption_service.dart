import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/utils/encryption_utils.dart';
import '../core/database/database_helper.dart';

class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  String? _currentKey;
  String? _currentIv;
  bool _explicitlyInitialized = false;
  final Map<String, Map<String, String>> _pairedDeviceKeys = {};
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Initialize encryption with a new key pair and load paired keys
  Future<void> initialize() async {
    _currentKey = EncryptionUtils.generateKey();
    _currentIv = EncryptionUtils.generateIV();
    _explicitlyInitialized = true;

    // Load paired device keys from database
    await _loadPairedKeys();
  }

  /// Load paired device keys from database
  Future<void> _loadPairedKeys() async {
    try {
      final keys = await _db.getAllPairedKeys();
      for (final row in keys) {
        final deviceId = row['device_id'] as String;
        _pairedDeviceKeys[deviceId] = {
          'key': row['encryption_key'] as String,
          'iv': row['encryption_iv'] as String,
        };
      }
      debugPrint(
        'EncryptionService: Loaded ${_pairedDeviceKeys.length} paired device keys',
      );
    } catch (e) {
      debugPrint('EncryptionService: Failed to load paired keys: $e');
    }
  }

  /// Get current encryption key (never regenerates if keys were imported)
  String get currentKey {
    if (_currentKey == null) _ensureInitialized();
    return _currentKey!;
  }

  String get currentIv {
    if (_currentIv == null) _ensureInitialized();
    return _currentIv!;
  }

  void _ensureInitialized() {
    if (!_explicitlyInitialized &&
        (_currentKey == null || _currentIv == null)) {
      initialize();
    }
  }

  /// Get keys for a paired device
  Map<String, String>? getPairedKeys(String deviceId) {
    return _pairedDeviceKeys[deviceId];
  }

  /// Encrypt file and return encrypted file path
  Future<String> encryptFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found: $filePath');

    final bytes = await file.readAsBytes();
    final encryptedBytes = EncryptionUtils.encryptFileBytes(
      bytes,
      currentKey,
      currentIv,
    );

    final dir = await getTemporaryDirectory();
    final encryptedPath =
        '${dir.path}/enc_${DateTime.now().millisecondsSinceEpoch}.enc';
    await File(encryptedPath).writeAsBytes(encryptedBytes);

    return encryptedPath;
  }

  /// Decrypt file and return decrypted file path
  Future<String> decryptFile(
    String encryptedPath,
    String key,
    String iv,
  ) async {
    final file = File(encryptedPath);
    if (!await file.exists()) {
      throw Exception('Encrypted file not found: $encryptedPath');
    }

    final bytes = await file.readAsBytes();
    final decryptedBytes = EncryptionUtils.decryptFileBytes(bytes, key, iv);

    final dir = await getTemporaryDirectory();
    final decryptedPath =
        '${dir.path}/dec_${DateTime.now().millisecondsSinceEpoch}.tmp';
    await File(decryptedPath).writeAsBytes(decryptedBytes);

    return decryptedPath;
  }

  /// Encrypt file with a specific key/IV (e.g. a paired device's key)
  Future<String> encryptFileWithKey(
    String filePath,
    String key,
    String iv,
  ) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found: $filePath');

    final bytes = await file.readAsBytes();
    final encryptedBytes = EncryptionUtils.encryptFileBytes(bytes, key, iv);

    final dir = await getTemporaryDirectory();
    final encryptedPath =
        '${dir.path}/enc_${DateTime.now().millisecondsSinceEpoch}.enc';
    await File(encryptedPath).writeAsBytes(encryptedBytes);
    return encryptedPath;
  }

  /// Encrypt text message
  String encryptMessage(String message) {
    final result = EncryptionUtils.encryptData(message, currentKey, currentIv);
    return result.encrypted;
  }

  /// Decrypt text message
  String decryptMessage(String encryptedMessage, String key, String iv) {
    return EncryptionUtils.decryptData(encryptedMessage, key, iv);
  }

  /// Generate verification token for device pairing
  String generateVerificationToken() {
    return EncryptionUtils.generateVerificationToken();
  }

  /// Create a secure connection hash
  String createConnectionHash(String deviceId) {
    return EncryptionUtils.createConnectionHash(deviceId, currentKey);
  }

  /// Export encryption keys for sharing
  Map<String, String> exportKeys() {
    return {'key': currentKey, 'iv': currentIv};
  }

  /// Import encryption keys from a paired device
  Future<void> importKeys(
    Map<String, String> keys, {
    String? deviceId,
    String? deviceName,
  }) async {
    if (keys.containsKey('key') &&
        keys.containsKey('iv') &&
        keys['key'] != null &&
        keys['iv'] != null) {
      if (deviceId != null) {
        _pairedDeviceKeys[deviceId] = {'key': keys['key']!, 'iv': keys['iv']!};
        // Persist to database
        await _db.savePairedKeys(
          deviceId,
          deviceName ?? 'Unknown',
          keys['key']!,
          keys['iv']!,
        );
        debugPrint('EncryptionService: Saved paired keys for $deviceId');
      } else {
        _currentKey = keys['key'];
        _currentIv = keys['iv'];
        _explicitlyInitialized = true;
      }
    }
  }

  /// Remove paired device keys
  Future<void> removePairedKeys(String deviceId) async {
    _pairedDeviceKeys.remove(deviceId);
    await _db.deletePairedKeys(deviceId);
    debugPrint('EncryptionService: Removed paired keys for $deviceId');
  }

  /// Get all paired device keys
  Map<String, Map<String, String>> getAllPairedKeys() {
    return Map.unmodifiable(_pairedDeviceKeys);
  }
}
