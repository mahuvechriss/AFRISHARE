import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';

class EncryptionUtils {
  EncryptionUtils._();

  static final Random _random = Random.secure();

  /// Generate a secure random key
  static String generateKey() {
    final keyBytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Encode(keyBytes);
  }

  /// Generate a secure random IV
  static String generateIV() {
    final ivBytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return base64Encode(ivBytes);
  }

  /// Encrypt data using AES-256-CBC
  static EncryptedData encryptData(String plainText, String key, String iv) {
    final encKey = encrypt.Key.fromBase64(key);
    final encIV = encrypt.IV.fromBase64(iv);
    final encrypter = encrypt.Encrypter(encrypt.AES(encKey, mode: encrypt.AESMode.cbc));

    final encrypted = encrypter.encrypt(plainText, iv: encIV);
    return EncryptedData(
      encrypted: encrypted.base64,
      key: key,
      iv: iv,
    );
  }

  /// Decrypt data using AES-256-CBC
  static String decryptData(String encryptedText, String key, String iv) {
    final encKey = encrypt.Key.fromBase64(key);
    final encIV = encrypt.IV.fromBase64(iv);
    final encrypter = encrypt.Encrypter(encrypt.AES(encKey, mode: encrypt.AESMode.cbc));

    final encrypted = encrypt.Encrypted.fromBase64(encryptedText);
    return encrypter.decrypt(encrypted, iv: encIV);
  }

  /// Encrypt file bytes using standard AES-256-CBC with PKCS7 padding
  static List<int> encryptFileBytes(List<int> bytes, String key, String iv) {
    final encKey = encrypt.Key.fromBase64(key);
    final encIV = encrypt.IV.fromBase64(iv);
    final encrypter = encrypt.Encrypter(encrypt.AES(encKey, mode: encrypt.AESMode.cbc));

    final encrypted = encrypter.encryptBytes(bytes, iv: encIV);
    return encrypted.bytes;
  }

  /// Decrypt file bytes using standard AES-256-CBC with PKCS7 padding
  static List<int> decryptFileBytes(List<int> encryptedBytes, String key, String iv) {
    final encKey = encrypt.Key.fromBase64(key);
    final encIV = encrypt.IV.fromBase64(iv);
    final encrypter = encrypt.Encrypter(encrypt.AES(encKey, mode: encrypt.AESMode.cbc));

    final encrypted = encrypt.Encrypted(Uint8List.fromList(encryptedBytes));
    return encrypter.decryptBytes(encrypted, iv: encIV);
  }

  /// Hash a string using SHA-256
  static String hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generate a device verification token
  static String generateVerificationToken() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Create a secure connection hash
  static String createConnectionHash(String deviceId, String key) {
    final combined = '$deviceId:$key';
    return hashString(combined);
  }
}

class EncryptedData {
  final String encrypted;
  final String key;
  final String iv;

  EncryptedData({
    required this.encrypted,
    required this.key,
    required this.iv,
  });

  Map<String, dynamic> toJson() => {
        'encrypted': encrypted,
        'key': key,
        'iv': iv,
      };

  factory EncryptedData.fromJson(Map<String, dynamic> json) => EncryptedData(
        encrypted: json['encrypted'] as String,
        key: json['key'] as String,
        iv: json['iv'] as String,
      );
}
