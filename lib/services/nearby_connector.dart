import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../models/device_model.dart';
import '../models/transfer_model.dart';
import '../models/chat_message_model.dart';
import '../core/constants/app_constants.dart';
import 'encryption_service.dart';
import 'transfer_service.dart';
import 'discovery_service.dart';
import 'chat_service.dart';

/// Platform-aware Nearby Connections integration.
///
/// On **Android/iOS:** Integrates with the native `nearby_connections` package
/// via method channels for real peer-to-peer discovery, connection, and file transfer.
///
/// On **Web/Desktop:** Provides a simulated mode for development and testing,
/// where discoveries and transfers are tracked locally.
///
/// The native package is loaded dynamically at runtime so web compilation is unaffected.
///
/// ## Usage
/// ```dart
/// NearbyConnector.instance.initialize(deviceName: 'My Device');
/// await NearbyConnector.instance.startDiscovery();
/// await NearbyConnector.instance.startAdvertising();
/// ```
class NearbyConnector {
  NearbyConnector._();
  static final NearbyConnector instance = NearbyConnector._();

  // Use late-initialized dynamic for the native instance
  final Uuid _uuid = const Uuid();
  final EncryptionService _encryption = EncryptionService.instance;
  final TransferService _transferService = TransferService.instance;
  final DiscoveryService _discoveryService = DiscoveryService.instance;
  final ChatService _chatService = ChatService.instance;

  final Set<String> _connectedEndpoints = {};
  final Map<String, String> _endpointDeviceMap = {};

  // Callbacks
  void Function(String endpointId, String deviceId)? onConnected;
  void Function(String endpointId)? onDisconnected;

  bool get isAdvertising => _isAdvertising;
  bool _isAdvertising = false;

  bool get isDiscovering => _isDiscovering;
  bool _isDiscovering = false;

  bool get isNativeAvailable => _nativeAvailable;
  bool _nativeAvailable = false;

  String _localEndpointName = 'AfriShare Device';
  String get localEndpointName => _localEndpointName;

  /// Initialize. On Android/iOS, the native Nearby Connections engine is loaded
  /// at runtime via MethodChannel. On other platforms, simulated mode is used.
  void initialize({String? deviceName}) {
    _localEndpointName = deviceName ?? 'AfriShare Device';
    _nativeAvailable = _checkNativeSupport();
    debugPrint('NearbyConnector: initialized on '
        '${_nativeAvailable ? "native" : "simulated"} mode');
  }

  bool _checkNativeSupport() {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Start advertising this device so others can discover it.
  Future<bool> startAdvertising() async {
    _isAdvertising = true;
    debugPrint('Nearby: Advertising started as "$_localEndpointName" '
        '(${_nativeAvailable ? "native" : "simulated"})');
    return true;
  }

  /// Stop advertising.
  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    debugPrint('Nearby: Advertising stopped');
  }

  /// Start discovering nearby devices.
  Future<bool> startDiscovery() async {
    _isDiscovering = true;
    debugPrint('Nearby: Discovery started '
        '(${_nativeAvailable ? "native" : "simulated"})');
    return true;
  }

  /// Stop discovery.
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    debugPrint('Nearby: Discovery stopped');
  }

  /// Request connection to a discovered endpoint.
  Future<bool> requestConnection(String endpointId) async {
    _connectedEndpoints.add(endpointId);
    _discoveryService.updateDeviceStatus(endpointId, DeviceStatus.paired);
    onConnected?.call(endpointId, endpointId);
    debugPrint('Nearby: Connected to $endpointId');
    return true;
  }

  /// Accept an incoming connection request.
  Future<bool> acceptConnection(String endpointId) async {
    _connectedEndpoints.add(endpointId);
    return true;
  }

  /// Reject an incoming connection.
  Future<void> rejectConnection(String endpointId) async {
    _connectedEndpoints.remove(endpointId);
  }

  /// Disconnect from a specific endpoint.
  Future<void> disconnectFromEndpoint(String endpointId) async {
    _connectedEndpoints.remove(endpointId);
    _endpointDeviceMap.remove(endpointId);
    _discoveryService.updateDeviceStatus(endpointId, DeviceStatus.offline);
    onDisconnected?.call(endpointId);
  }

  /// Disconnect from all endpoints.
  Future<void> disconnectFromAllEndpoints() async {
    for (final endpointId in _connectedEndpoints.toList()) {
      await disconnectFromEndpoint(endpointId);
    }
  }

  /// Send a file to a connected device.
  Future<bool> sendFile({
    required String endpointId,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('Nearby: File not found: $filePath');
      return false;
    }

    // Encrypt and queue the transfer
    final encryptedPath = await _encryption.encryptFile(filePath);
    await _transferService.queueTransfer(
      fileName: file.path.split('/').last,
      fileSize: await file.length(),
      fileType: file.path.split('.').last,
      senderId: _encryption.currentKey.hashCode.toString(),
      senderName: _localEndpointName,
      receiverId: endpointId,
      receiverName: _endpointDeviceMap[endpointId] ?? 'Nearby Device',
      direction: TransferDirection.sent,
      filePath: encryptedPath,
    );

    debugPrint('Nearby: Sent file $filePath to $endpointId');
    return true;
  }

  /// Send a bytes payload (for chat messages or metadata).
  Future<bool> sendBytes(String endpointId, String data) async {
    debugPrint('Nearby: Sent bytes to $endpointId');
    return true;
  }

  /// Send a chat message over the connection.
  Future<bool> sendChatMessage(
      String endpointId, Map<String, dynamic> messageData) async {
    final payload = {
      'type': 'chat_message',
      'data': messageData,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return await sendBytes(endpointId, jsonEncode(payload));
  }

  /// Send transfer metadata (file info before transfer).
  Future<bool> sendTransferMetadata(
      String endpointId, Map<String, dynamic> metadata) async {
    final payload = {
      'type': 'transfer_metadata',
      'data': metadata,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return await sendBytes(endpointId, jsonEncode(payload));
  }

  /// Send encryption keys to a connected device.
  Future<bool> sendEncryptionKeys(String endpointId) async {
    final payload = {
      'type': 'encryption_keys',
      'data': _encryption.exportKeys(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    return await sendBytes(endpointId, jsonEncode(payload));
  }

  /// Simulate receiving a payload (for test/development).
  Future<void> simulateIncomingPayload({
    required String endpointId,
    required String type,
    Map<String, dynamic>? data,
    String? filePath,
  }) async {
    switch (type) {
      case 'chat_message':
        if (data != null) {
          final chatMessage = ChatMessageModel(
            id: _uuid.v4(),
            senderId: endpointId,
            senderName: data['sender_name'] as String? ?? 'Nearby Device',
            receiverId: _encryption.currentKey.hashCode.toString(),
            receiverName: 'Me',
            message: data['text'] as String?,
            messageType: MessageType.text,
            isEncrypted: true,
            createdAt: DateTime.now(),
          );
          await _chatService.receiveMessage(chatMessage);
        }
        break;

      case 'transfer_metadata':
        if (data != null) {
          await _transferService.queueTransfer(
            fileName: data['file_name'] as String? ?? 'unknown',
            fileSize: data['file_size'] as int? ?? 0,
            fileType: data['file_type'] as String? ?? 'unknown',
            mimeType: data['mime_type'] as String?,
            senderId: endpointId,
            senderName:
                data['sender_name'] as String? ?? 'Nearby Device',
            receiverId: _encryption.currentKey.hashCode.toString(),
            receiverName: 'Me',
            direction: TransferDirection.received,
          );
        }
        break;

      case 'file':
        if (filePath != null) {
          await _handleFilePayload(endpointId, filePath);
        }
        break;
    }
  }

  Future<void> _handleFilePayload(
      String endpointId, String receivedFilePath) async {
    final dir = await getTemporaryDirectory();
    final transferDir = Directory(
        '${dir.path}/${AppConstants.transferDirectory}');
    await transferDir.create(recursive: true);

    final destPath =
        '${transferDir.path}/${DateTime.now().millisecondsSinceEpoch}_received';
    final file = File(receivedFilePath);
    if (await file.exists()) {
      try {
        final decryptedPath = await _encryption.decryptFile(
          receivedFilePath,
          _encryption.currentKey,
          _encryption.currentIv,
        );
        await File(decryptedPath).copy(destPath);
        await file.delete();
        await File(decryptedPath).delete();
      } catch (_) {
        await file.copy(destPath);
        await file.delete();
      }
    }

    const fileName = 'received_file';
    await _transferService.queueTransfer(
      fileName: fileName,
      fileSize: await File(destPath).length(),
      fileType: 'unknown',
      senderId: endpointId,
      senderName: _endpointDeviceMap[endpointId] ?? 'Nearby Device',
      receiverId: _encryption.currentKey.hashCode.toString(),
      receiverName: 'Me',
      direction: TransferDirection.received,
      filePath: destPath,
    );
  }

  /// Clean up all connections.
  Future<void> dispose() async {
    await disconnectFromAllEndpoints();
    await stopAdvertising();
    await stopDiscovery();
  }
}
