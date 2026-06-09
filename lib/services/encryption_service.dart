import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../core/utils/encryption_utils.dart';

class EncryptionService {
  EncryptionService._();
  static final EncryptionService instance = EncryptionService._();

  String? _currentKey;
  String? _currentIv;

  /// Initialize encryption with a new key pair
  void initialize() {
    _currentKey = EncryptionUtils.generateKey();
    _currentIv = EncryptionUtils.generateIV();
  }

  /// Get current encryption key
  String get currentKey => _currentKey ?? _generateAndCache();
  String get currentIv => _currentIv ?? _generateAndCache();

  String _generateAndCache() {
    initialize();
    return _currentKey!;
  }

  /// Encrypt file and return encrypted file path
  Future<String> encryptFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found: $filePath');

    final bytes = await file.readAsBytes();
    final encryptedBytes =
        EncryptionUtils.encryptFileBytes(bytes, currentKey, currentIv);

    final dir = await getTemporaryDirectory();
    final encryptedPath =
        '${dir.path}/enc_${DateTime.now().millisecondsSinceEpoch}.enc';
    await File(encryptedPath).writeAsBytes(encryptedBytes);

    return encryptedPath;
  }

  /// Decrypt file and return decrypted file path
  Future<String> decryptFile(
      String encryptedPath, String key, String iv) async {
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

  /// Encrypt text message
  String encryptMessage(String message) {
    final result =
        EncryptionUtils.encryptData(message, currentKey, currentIv);
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
    return {
      'key': currentKey,
      'iv': currentIv,
    };
  }

  /// Import encryption keys from a paired device
  void importKeys(Map<String, String> keys) {
    _currentKey = keys['key'];
    _currentIv = keys['iv'];
  }
}
