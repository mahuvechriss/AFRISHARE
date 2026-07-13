import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/device_model.dart';
import '../models/transfer_model.dart';
import '../models/chat_message_model.dart';
import '../core/constants/app_constants.dart';
import 'encryption_service.dart';
import 'transfer_service.dart';
import 'discovery_service.dart';
import 'chat_service.dart';
import 'http_transfer_service.dart';
import 'network_discovery_service.dart';
import 'storage_service.dart';
import 'auth_service.dart';

class NearbyConnector {
  NearbyConnector._();
  static final NearbyConnector instance = NearbyConnector._();

  final Uuid _uuid = const Uuid();
  final EncryptionService _encryption = EncryptionService.instance;
  final TransferService _transferService = TransferService.instance;
  late final DiscoveryService _discoveryService = DiscoveryService.instance;
  final ChatService _chatService = ChatService.instance;
  final HttpTransferService _httpTransfer = HttpTransferService.instance;
  final NetworkDiscoveryService _networkDiscovery =
      NetworkDiscoveryService.instance;

  final Set<String> _connectedEndpoints = {};
  final Map<String, String> _endpointDeviceMap = {};

  void Function(String endpointId, String deviceId)? onConnected;
  void Function(String endpointId)? onDisconnected;

  bool get isAdvertising => _isAdvertising;
  bool _isAdvertising = false;

  bool get isDiscovering => _isDiscovering;
  bool _isDiscovering = false;

  bool get isNativeAvailable => _nativeAvailable;
  bool _nativeAvailable = false;

  bool get isHttpServerRunning => _httpTransfer.isRunning;
  String? get localIp => _httpTransfer.localIp;
  int get httpPort => _httpTransfer.port;

  String _localEndpointName = 'AfriShare Device';
  String get localEndpointName => _localEndpointName;

  void initialize({String? deviceName, String? deviceId}) {
    _localEndpointName = deviceName ?? 'AfriShare Device';
    _nativeAvailable = _checkNativeSupport();

    _httpTransfer.initialize(deviceName: _localEndpointName, deviceId: deviceId);
    _networkDiscovery.initialize(deviceName: _localEndpointName, deviceId: deviceId);

    _httpTransfer.onFileReceived?.listen((event) {
      final deviceId = _endpointDeviceMap.entries
          .firstWhere(
            (e) => e.value == event.endpointId,
            orElse: () => const MapEntry('', ''),
          )
          .key;
      if (deviceId.isNotEmpty) {
        _discoveryService.updateDeviceStatus(deviceId, DeviceStatus.paired);
      }
    });

    // Register retry handler so failed sent transfers can be re-sent
    _transferService.onRetryTransfer = (transfer) async {
      final device = _discoveryService.getDeviceByDeviceId(transfer.receiverId);
      if (device?.ipAddress == null || transfer.filePath == null) {
        debugPrint('Nearby: Retry failed — no device or file path for ${transfer.id}');
        return false;
      }
      final fileName = transfer.filePath!.contains(Platform.pathSeparator)
          ? transfer.filePath!.split(Platform.pathSeparator).last
          : transfer.fileName;
      final result = await _httpTransfer.sendFile(
        host: device!.ipAddress!,
        port: device.port ?? AppConstants.discoveryPort,
        filePath: transfer.filePath!,
        fileName: fileName,
        receiverId: device.deviceId,
        receiverName: device.name,
      );
      return result['success'] == true;
    };

    debugPrint(
      'NearbyConnector: initialized on '
      '${_nativeAvailable ? "native" : "http"} mode',
    );
  }

  bool _checkNativeSupport() {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  Future<bool> startAdvertising() async {
    _isAdvertising = true;
    try {
      await _httpTransfer.startServer();
      debugPrint(
        'Nearby: HTTP server started on '
        '${_httpTransfer.localIp}:${_httpTransfer.port}',
      );
    } catch (e) {
      debugPrint('Nearby: Failed to start HTTP server: $e');
    }
    return true;
  }

  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    // Do NOT stop the HTTP server — it was started globally at app launch
    // and is needed by all screens (send, receive, discovery).
    // Stopping it here would break file transfers for the entire app.
    debugPrint('Nearby: Advertising stopped (HTTP server still running)');
  }

  Future<bool> startDiscovery() async {
    _isDiscovering = true;
    await _networkDiscovery.startDiscovery();
    debugPrint('Nearby: Network discovery started');
    return true;
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    await _networkDiscovery.stopDiscovery();
    debugPrint('Nearby: Network discovery stopped');
  }

  Future<bool> requestConnection(String endpointId) async {
    _connectedEndpoints.add(endpointId);
    _discoveryService.updateDeviceStatus(endpointId, DeviceStatus.paired);
    onConnected?.call(endpointId, endpointId);
    debugPrint('Nearby: Connected to $endpointId');
    return true;
  }

  Future<bool> acceptConnection(String endpointId) async {
    _connectedEndpoints.add(endpointId);
    return true;
  }

  Future<void> rejectConnection(String endpointId) async {
    _connectedEndpoints.remove(endpointId);
  }

  Future<void> disconnectFromEndpoint(String endpointId) async {
    _connectedEndpoints.remove(endpointId);
    _endpointDeviceMap.remove(endpointId);
    _discoveryService.updateDeviceStatus(endpointId, DeviceStatus.offline);
    onDisconnected?.call(endpointId);
  }

  Future<void> disconnectFromAllEndpoints() async {
    for (final endpointId in _connectedEndpoints.toList()) {
      await disconnectFromEndpoint(endpointId);
    }
  }

  Future<bool> sendFile({
    required String endpointId,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('Nearby: File not found: $filePath');
      return false;
    }

    // Try to find device by deviceId first
    DeviceModel? device = _discoveryService.getDeviceByDeviceId(endpointId);

    // Fallback: try to find by IP if endpointId looks like an IP
    if (device == null && endpointId.contains('.')) {
      device = _discoveryService.getDeviceByIp(endpointId);
    }

    // Fallback: try to find any paired device
    if (device == null) {
      final pairedDevices = _discoveryService.discoveredDevices
          .where((d) => d.isPaired && d.ipAddress != null)
          .toList();
      if (pairedDevices.isNotEmpty) {
        device = pairedDevices.first;
      }
    }

    if (device?.ipAddress == null) {
      debugPrint('Nearby: No IP address for device $endpointId');
      return false;
    }

    final fileName = file.path.split(Platform.pathSeparator).last;
    final result = await _httpTransfer.sendFile(
      host: device!.ipAddress!,
      port: device.port ?? AppConstants.discoveryPort,
      filePath: filePath,
      fileName: fileName,
      receiverId: device.deviceId,
      receiverName: device.name,
    );

    final success = result['success'] == true;
    if (success) {
      _endpointDeviceMap[device.deviceId] = device.deviceId;
      debugPrint('Nearby: Sent file $fileName to ${device.ipAddress}');
    }

    return success;
  }

  Future<bool> sendBytes(String endpointId, String data) async {
    debugPrint('Nearby: Sent bytes to $endpointId');
    return true;
  }

  Future<Map<String, dynamic>> connectManually(
    String ip,
    int port,
    String name,
  ) async {
    debugPrint('Nearby: Attempting manual connection to $ip:$port ($name)');

    final test = await _httpTransfer.testConnection(ip, port: port);
    if (test['success'] == true) {
      final deviceInfo = await _httpTransfer.fetchDeviceInfo(ip);
      final deviceName = deviceInfo?['device_name'] as String? ?? name;
      _discoveryService.addDeviceByIp(ip, port, deviceName);
      debugPrint(
        'Nearby: Manual connection successful to $deviceName at $ip:$port',
      );
      return {'success': true, 'deviceName': deviceName};
    } else {
      debugPrint(
        'Nearby: Manual connection failed to $ip:$port - ${test['error']}',
      );
      return test;
    }
  }

  Future<Map<String, dynamic>> testConnection(
    String ip, {
    int port = AppConstants.discoveryPort,
  }) async {
    return await _httpTransfer.testConnection(ip, port: port);
  }

  Future<bool> requestTransfer({
    required String host,
    int port = AppConstants.discoveryPort,
    required List<String> fileNames,
    required List<int> fileSizes,
  }) async {
    return await _httpTransfer.requestTransfer(
      host: host,
      port: port,
      fileNames: fileNames,
      fileSizes: fileSizes,
    );
  }

  Future<bool> sendChatMessage(
    String endpointId,
    Map<String, dynamic> messageData,
  ) async {
    final payload = {
      'type': 'chat_message',
      'data': messageData,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return await sendBytes(endpointId, jsonEncode(payload));
  }

  Future<bool> sendTransferMetadata(
    String endpointId,
    Map<String, dynamic> metadata,
  ) async {
    final payload = {
      'type': 'transfer_metadata',
      'data': metadata,
      'timestamp': DateTime.now().toIso8601String(),
    };
    return await sendBytes(endpointId, jsonEncode(payload));
  }

  Future<bool> sendEncryptionKeys(String endpointId) async {
    final payload = {
      'type': 'encryption_keys',
      'data': _encryption.exportKeys(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    return await sendBytes(endpointId, jsonEncode(payload));
  }

  Future<void> simulateIncomingPayload({
    required String endpointId,
    required String type,
    Map<String, dynamic>? data,
    String? filePath,
  }) async {
    switch (type) {
      case 'chat_message':
        if (data != null) {
          final myDeviceId = AuthService.instance.currentUser?.deviceId ??
              _encryption.currentKey.hashCode.toString();
          final chatMessage = ChatMessageModel(
            id: _uuid.v4(),
            senderId: endpointId,
            senderName: data['sender_name'] as String? ?? 'Nearby Device',
            receiverId: myDeviceId,
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
            senderName: data['sender_name'] as String? ?? 'Nearby Device',
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
    String endpointId,
    String receivedFilePath,
  ) async {
    final transferDir = StorageService.instance.transferDirectory;
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

  /// Update the device name across all services
  void updateDeviceName(String name) {
    _localEndpointName = name;
    _httpTransfer.updateDeviceName(name);
    _networkDiscovery.updateDeviceName(name);
    debugPrint('NearbyConnector: Device name updated to "$name"');
  }

  Future<void> dispose() async {
    await disconnectFromAllEndpoints();
    await stopAdvertising();
    await stopDiscovery();
    await _httpTransfer.dispose();
    await _networkDiscovery.dispose();
  }
}
