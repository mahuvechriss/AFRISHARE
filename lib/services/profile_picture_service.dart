import 'dart:io';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class ProfilePictureService {
  ProfilePictureService._();
  static final ProfilePictureService instance = ProfilePictureService._();

  final Map<String, Uint8List> _cache = {};
  final Map<String, DateTime> _lastFetched = {};
  final Map<String, Future<Uint8List?>> _pendingFetches = {};

  Uint8List? get(String deviceId) => _cache[deviceId];

  bool isCached(String deviceId) => _cache.containsKey(deviceId);

  Future<Uint8List?> fetch(String deviceId, String ip, int port) async {
    if (_pendingFetches.containsKey(deviceId)) {
      return _pendingFetches[deviceId];
    }
    final future = _doFetch(deviceId, ip, port);
    _pendingFetches[deviceId] = future;
    try {
      return await future;
    } finally {
      _pendingFetches.remove(deviceId);
    }
  }

  Future<Uint8List?> _doFetch(String deviceId, String ip, int port) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(
        Uri.parse('http://$ip:$port/profile-picture'),
      );
      final response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final bytes = await consolidateHttpClientResponseBytes(response);
        _cache[deviceId] = bytes;
        _lastFetched[deviceId] = DateTime.now();
        return bytes;
      }
    } catch (_) {
      // Device offline or no picture
    }
    return null;
  }

  void invalidate(String deviceId) {
    _cache.remove(deviceId);
    _lastFetched.remove(deviceId);
  }

  void clear() {
    _cache.clear();
    _lastFetched.clear();
    _pendingFetches.clear();
  }

  /// Check if the local user has a profile picture.
  bool get hasLocalPicture =>
      AuthService.instance.currentUser?.profilePicture != null;

  /// Read the local user's profile picture bytes.
  Uint8List? getLocalPicture() {
    final path = AuthService.instance.currentUser?.profilePicture;
    if (path == null) return null;
    try {
      return File(path).readAsBytesSync();
    } catch (_) {
      return null;
    }
  }
}
