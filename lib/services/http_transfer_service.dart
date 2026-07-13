import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/transfer_model.dart';
import '../models/device_model.dart';
import '../models/chat_message_model.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/compression_utils.dart';
import 'transfer_service.dart';
import 'encryption_service.dart';
import 'discovery_service.dart';
import 'chat_service.dart';
import 'call_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'sound_service.dart';
import 'auth_service.dart';
import 'media_relay_service.dart';

class HttpTransferEvent {
  final String endpointId;
  final String fileName;
  final int fileSize;
  final String filePath;

  HttpTransferEvent({
    required this.endpointId,
    required this.fileName,
    required this.fileSize,
    required this.filePath,
  });
}

class TransferRequestEvent {
  final String requestId;
  final String senderId;
  final String senderName;
  final List<String> fileNames;
  final List<int> fileSizes;
  bool accepted;

  TransferRequestEvent({
    required this.requestId,
    required this.senderId,
    required this.senderName,
    required this.fileNames,
    required this.fileSizes,
    this.accepted = false,
  });
}

class TransferStartedEvent {
  final List<String> fileNames;
  final List<int> fileSizes;
  final String receiverName;

  TransferStartedEvent({
    required this.fileNames,
    required this.fileSizes,
    required this.receiverName,
  });
}

class ChunkedTransferState {
  final String transferId;
  final String fileName;
  final int totalSize;
  final int totalChunks;
  final String outputPath;
  final Set<int> receivedChunks;
  final Map<int, List<int>> chunkData;
  TransferModel? transferModel;

  ChunkedTransferState({
    required this.transferId,
    required this.fileName,
    required this.totalSize,
    required this.totalChunks,
    required this.outputPath,
    Set<int>? receivedChunks,
    Map<int, List<int>>? chunkData,
    this.transferModel,
  }) : receivedChunks = receivedChunks ?? {},
       chunkData = chunkData ?? {};
}

class HttpTransferService {
  HttpTransferService._();
  static final HttpTransferService instance = HttpTransferService._();

  final Uuid _uuid = const Uuid();
  final TransferService _transferService = TransferService.instance;
  final EncryptionService _encryption = EncryptionService.instance;
  final DiscoveryService _discoveryService = DiscoveryService.instance;

  HttpServer? _server;
  bool _isRunning = false;
  int _port = AppConstants.discoveryPort;
  String? _localIp;
  String _deviceName = 'AfriShare Device';
  String _deviceId = '';

  StreamSubscription? _connectivitySub;
  Timer? _networkCheckTimer;
  bool _ipCheckInProgress = false;

  final Map<String, Completer<bool>> _pendingTransferRequests = {};
  final Map<String, TransferRequestEvent> _pendingTransferEvents = {};
  bool autoAcceptTransfers = false;

  final Map<String, ChunkedTransferState> _chunkedTransfers = {};
  static const int _chunkSizeBytes =
      8 * 1024 * 1024; // 8MB chunks for max throughput
  static const int _parallelChunks = 8; // 8 parallel connections for max speed
  static const int _largeFileThreshold =
      20 * 1024 * 1024; // 20MB - use parallel below this
  static const int _maxEncryptionSize =
      300 * 1024 * 1024; // 300MB - skip encryption above this

  StreamController<HttpTransferEvent>? _onFileReceivedController;
  Stream<HttpTransferEvent>? get onFileReceived =>
      _onFileReceivedController?.stream;

  StreamController<HttpTransferEvent>? _onFileSentController;
  Stream<HttpTransferEvent>? get onFileSent => _onFileSentController?.stream;

  StreamController<TransferStartedEvent>? _onTransferStartedController;
  Stream<TransferStartedEvent>? get onTransferStarted =>
      _onTransferStartedController?.stream;

  StreamController<TransferRequestEvent>? _onTransferRequestController;
  Stream<TransferRequestEvent>? get onTransferRequest =>
      _onTransferRequestController?.stream;

  bool get isRunning => _isRunning;
  int get port => _port;
  String? get localIp => _localIp;
  String get deviceId => _deviceId;
  String get deviceName => _deviceName;

  void initialize({String? deviceName, String? deviceId}) {
    _deviceName = deviceName ?? 'AfriShare Device';
    _deviceId = deviceId ?? _uuid.v4();
    _onFileReceivedController = StreamController<HttpTransferEvent>.broadcast();
    _onFileSentController = StreamController<HttpTransferEvent>.broadcast();
    _onTransferStartedController =
        StreamController<TransferStartedEvent>.broadcast();
    _onTransferRequestController =
        StreamController<TransferRequestEvent>.broadcast();
    _startNetworkMonitor();
  }

  void _startNetworkMonitor() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      debugPrint('HttpTransfer: Network change detected: $result');
      _recheckIpAndRestart();
    });
    _networkCheckTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _recheckIpAndRestart(),
    );
  }

  Future<void> _recheckIpAndRestart() async {
    if (_ipCheckInProgress) return;
    _ipCheckInProgress = true;
    try {
      final currentIp = await resolveLocalIp();
      if (currentIp != null && currentIp != _localIp && _isRunning) {
        debugPrint(
          'HttpTransfer: IP changed from $_localIp to $currentIp — restarting server',
        );
        final wasRunning = _isRunning;
        await stopServer();
        if (wasRunning) {
          await startServer(port: _port);
        }
      }
    } finally {
      _ipCheckInProgress = false;
    }
  }

  Future<String?> resolveLocalIp() async {
    // Try network_info_plus first (most reliable on mobile)
    try {
      final wifiIp = await NetworkInfo().getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty) return wifiIp;
    } catch (_) {}

    // Try NetworkInterface.list() - prioritize non-VPN interfaces
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      // First pass: prefer common WiFi/Ethernet interfaces
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        // Skip common VPN/virtual/USB tethering interfaces
        // Don't skip hotspot/tethering interfaces - they're valid for transfers
        if (name.contains('tun') ||
            name.contains('tap') ||
            name.contains('docker') ||
            name.contains('veth') ||
            name.contains('loopback')) {
          continue;
        }

        for (final addr in iface.addresses) {
          if (addr.address.startsWith('192.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            debugPrint('HttpTransfer: resolveLocalIp picked $addr on $name');
            return addr.address;
          }
        }
      }

      // Second pass: fallback to any private IP
      for (final iface in interfaces) {
        if (iface.name.toLowerCase().contains('loopback')) continue;
        for (final addr in iface.addresses) {
          if (addr.address.startsWith('192.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
    } catch (_) {}

    // Final fallback: open a TCP connection to determine the local address.
    // This works when the device has a route to the internet.
    try {
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(seconds: 2),
      );
      final localAddr = socket.address.address;
      await socket.close();
      if (localAddr.isNotEmpty &&
          (localAddr.startsWith('192.') ||
              localAddr.startsWith('10.') ||
              localAddr.startsWith('172.'))) {
        return localAddr;
      }
    } catch (_) {}

    return null;
  }

  Future<void> startServer({int? port}) async {
    if (_isRunning) return;

    _port = port ?? _port;

    // Retry IP resolution up to 3 times with 1s delay (network may not be ready)
    for (int i = 0; i < 3; i++) {
      _localIp = await resolveLocalIp();
      if (_localIp != null && _localIp != '0.0.0.0') break;
      if (i < 2) await Future.delayed(const Duration(seconds: 1));
    }

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _port,
        shared: true,
      );
      _isRunning = true;
      debugPrint('HttpTransfer: Server started on $_localIp:$_port');

      _server!.listen(
        _handleRequest,
        onError: (error) {
          debugPrint('HttpTransfer: Server error: $error');
        },
      );
    } catch (e) {
      debugPrint('HttpTransfer: Failed to start server: $e');
      rethrow;
    }
  }

  Future<void> stopServer() async {
    _isRunning = false;
    try {
      await _server?.close(force: true);
      _server = null;
    } catch (_) {}
    debugPrint('HttpTransfer: Server stopped');
  }

  void _handleRequest(HttpRequest request) {
    try {
      final uri = Uri.parse(request.uri.toString());
      final path = uri.path;

      switch (request.method) {
        case 'GET':
          _handleGetRequest(request, path);
          break;
        case 'POST':
          _handlePostRequest(request, path);
          break;
        default:
          request.response.statusCode = HttpStatus.methodNotAllowed;
          request.response.close();
      }
    } catch (e) {
      debugPrint('HttpTransfer: _handleRequest error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.close();
      } catch (_) {}
    }
  }

  void _handleGetRequest(HttpRequest request, String path) {
    switch (path) {
      case '/info':
        _sendDeviceInfo(request);
        break;
      case '/health':
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'status': 'ok'}));
        request.response.close();
        break;
      case '/profile-picture':
        _sendProfilePicture(request);
        break;
      default:
        request.response.statusCode = HttpStatus.notFound;
        request.response.close();
    }
  }

  void _sendProfilePicture(HttpRequest request) {
    final profilePath = AuthService.instance.currentUser?.profilePicture;
    if (profilePath == null || !File(profilePath).existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.close();
      return;
    }
    try {
      final file = File(profilePath);
      final bytes = file.readAsBytesSync();
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType('image', 'jpeg');
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      request.response.close();
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.close();
    }
  }

  void _sendDeviceInfo(HttpRequest request) {
    final info = {
      'type': 'afrishare_device',
      'device_id': _deviceId,
      'device_name': _deviceName,
      'version': AppConstants.appVersion,
      'timestamp': DateTime.now().toIso8601String(),
    };
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(info));
    request.response.close();
  }

  Future<void> _handlePostRequest(HttpRequest request, String path) async {
    switch (path) {
      case '/receive':
        await _handleFileReceive(request);
        break;
      case '/chunk':
        await _handleChunkReceive(request);
        break;
      case '/chunk-complete':
        await _handleChunkComplete(request);
        break;
      case '/pair':
        await _handlePairRequest(request);
        break;
      case '/transfer-request':
        await _handleTransferRequest(request);
        break;
      case '/chat-message':
        await _handleChatMessage(request);
        break;
      case '/call-offer':
        await _handleCallOffer(request);
        break;
      case '/call-answer':
        await _handleCallAnswer(request);
        break;
      case '/call-ice-candidate':
        await _handleIceCandidate(request);
        break;
      case '/call-end':
        await _handleCallEnd(request);
        break;
      case '/call-video':
        await _handleCallVideo(request);
        break;
      case '/call-audio':
        await _handleCallAudio(request);
        break;
      default:
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
    }
  }

  Future<void> _handleFileReceive(HttpRequest request) async {
    TransferModel? transfer;
    String? destPath;
    try {
      final contentDisposition =
          request.headers.value('content-disposition') ?? '';

      String fileName = 'received_file';
      if (contentDisposition.isNotEmpty) {
        final fileNameMatch = RegExp(
          r'filename=\"?(.+?)\"?$',
        ).firstMatch(contentDisposition);
        if (fileNameMatch != null) {
          fileName = fileNameMatch.group(1)!;
        }
      }

      final senderId = request.headers.value('x-device-id') ?? _uuid.v4();
      final senderName =
          request.headers.value('x-device-name') ?? 'Nearby Device';
      final isCompressed = request.headers.value('x-compressed') == 'gzip';
      final isEncrypted = request.headers.value('x-encrypted') == 'aes256';
      final streamSize = request.headers.contentLength;

      final transferDir = StorageService.instance.transferDirectory;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      destPath = '${transferDir.path}/${timestamp}_$fileName';

      final fileType = fileName.contains('.')
          ? fileName.split('.').last
          : 'unknown';

      // Create transfer record before receiving so receiver sees it immediately
      transfer = await _transferService.queueTransfer(
        fileName: fileName,
        fileSize: streamSize > 0 ? streamSize : 0,
        fileType: fileType,
        senderId: senderId,
        senderName: senderName,
        receiverId: _deviceId,
        receiverName: 'Me',
        direction: TransferDirection.received,
      );

      // Update status to transferring immediately
      await _transferService.updateProgress(transfer.id, 0, 0);

      // Stream file with progress tracking
      final destSink = File(destPath).openWrite();
      int receivedBytes = 0;
      int lastProgressUpdate = 0;
      final stopwatch = Stopwatch()..start();
      await for (final chunk in request) {
        destSink.add(chunk);
        receivedBytes += chunk.length;
        if (streamSize > 0) {
          final progress = ((receivedBytes / streamSize) * 100).clamp(
            0.0,
            100.0,
          );
          if (progress.toInt() > lastProgressUpdate + 5 || progress >= 100) {
            lastProgressUpdate = progress.toInt();
            final elapsed = stopwatch.elapsedMilliseconds ~/ 1000;
            final speed = elapsed > 0
                ? (receivedBytes / elapsed).toDouble()
                : 0.0;
            try {
              await _transferService.updateProgress(
                transfer.id,
                progress,
                speed,
              );
            } catch (_) {}
          }
        }
      }
      await destSink.close();

      // Decrypt if the sender encrypted with our key (sender uses our keys to encrypt)
      if (isEncrypted) {
        try {
          final decryptedPath = await _encryption.decryptFile(
            destPath,
            _encryption.currentKey,
            _encryption.currentIv,
          );
          await File(destPath).delete();
          await File(decryptedPath).copy(destPath);
          await File(decryptedPath).delete();
          debugPrint('HttpTransfer: Decrypted received file from $senderName');
        } catch (e) {
          debugPrint('HttpTransfer: Decryption failed for $fileName: $e');
          try {
            await File(destPath).delete();
          } catch (_) {}
          await _transferService.markFailed(
            transfer.id,
            errorMessage: 'Decryption failed',
          );
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': 'Decryption failed'}));
          await request.response.close();
          return;
        }
      }

      // Decompress if the sender compressed before sending
      if (isCompressed) {
        try {
          final decompressedPath = await CompressionUtils.decompressFile(
            destPath,
          );
          if (decompressedPath != destPath) {
            await File(destPath).delete();
            await File(decompressedPath).copy(destPath);
            await File(decompressedPath).delete();
          }
        } catch (_) {}
      }

      final savedFile = File(destPath);
      final actualSize = await savedFile.length();

      // Update the transfer with the final file path and size
      await _transferService.updateProgress(transfer.id, 100, 0);
      await _transferService.markCompleted(transfer.id, filePath: destPath);

      _onFileReceivedController?.add(
        HttpTransferEvent(
          endpointId: senderId,
          fileName: fileName,
          fileSize: actualSize,
          filePath: destPath,
        ),
      );

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'status': 'received',
          'file_name': fileName,
          'file_size': actualSize,
        }),
      );
      await request.response.close();
    } catch (e) {
      debugPrint('HttpTransfer: Error receiving file: $e');
      if (transfer != null && destPath != null) {
        try {
          await _transferService.markFailed(
            transfer.id,
            errorMessage: e.toString(),
          );
        } catch (_) {}
      }
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleChunkReceive(HttpRequest request) async {
    try {
      final transferId = request.headers.value('x-transfer-id') ?? '';
      final chunkIndex =
          int.tryParse(request.headers.value('x-chunk-index') ?? '0') ?? 0;
      final totalChunks =
          int.tryParse(request.headers.value('x-total-chunks') ?? '1') ?? 1;
      final fileName = request.headers.value('x-file-name') ?? 'received_file';
      final fileSize =
          int.tryParse(request.headers.value('x-file-size') ?? '0') ?? 0;
      final senderId = request.headers.value('x-device-id') ?? '';
      final senderName =
          request.headers.value('x-device-name') ?? 'Nearby Device';

      if (transferId.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }

      final transferDir = StorageService.instance.transferDirectory;

      // Read chunk data
      final chunkBytes = <int>[];
      await for (final chunk in request) {
        chunkBytes.addAll(chunk);
      }

      // Store chunk
      final chunkDir = Directory('${transferDir.path}/chunks_$transferId');
      await chunkDir.create(recursive: true);
      await File('${chunkDir.path}/chunk_$chunkIndex').writeAsBytes(chunkBytes);

      // Track state and create/update transfer record
      if (!_chunkedTransfers.containsKey(transferId)) {
        _chunkedTransfers[transferId] = ChunkedTransferState(
          transferId: transferId,
          fileName: fileName,
          totalSize: fileSize,
          totalChunks: totalChunks,
          outputPath:
              '${transferDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName',
        );

        // Create transfer record so receiver sees it immediately
        final fileType = fileName.contains('.')
            ? fileName.split('.').last
            : 'unknown';
        final transfer = await _transferService.queueTransfer(
          fileName: fileName,
          fileSize: fileSize,
          fileType: fileType,
          senderId: senderId,
          senderName: senderName,
          receiverId: _deviceId,
          receiverName: 'Me',
          direction: TransferDirection.received,
        );
        _chunkedTransfers[transferId]!.transferModel = transfer;
      }

      final state = _chunkedTransfers[transferId]!;
      state.receivedChunks.add(chunkIndex);

      // Update progress
      if (state.transferModel != null) {
        final progress = ((state.receivedChunks.length / totalChunks) * 100)
            .clamp(0.0, 100.0);
        await _transferService.updateProgress(
          state.transferModel!.id,
          progress,
          0,
        );
      }

      debugPrint(
        'HttpTransfer: Chunk $chunkIndex/$totalChunks received for $transferId',
      );

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'status': 'chunk_received', 'chunk_index': chunkIndex}),
      );
      await request.response.close();
    } catch (e) {
      debugPrint('HttpTransfer: Chunk receive error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleChunkComplete(HttpRequest request) async {
    try {
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes);
      final decodedData = jsonDecode(body) as Map<String, dynamic>;

      final transferId = decodedData['transfer_id'] as String? ?? '';
      final isCompressed = decodedData['compressed'] == true;
      final isEncrypted = decodedData['encrypted'] == true;

      if (transferId.isEmpty || !_chunkedTransfers.containsKey(transferId)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }

      final state = _chunkedTransfers[transferId]!;
      final chunkDir = Directory(
        '${StorageService.instance.transferPath}/chunks_$transferId',
      );

      // Reassemble chunks
      final outputFile = File(state.outputPath);
      final sink = outputFile.openWrite();
      int chunksAssembled = 0;
      for (var i = 0; i < state.totalChunks; i++) {
        final chunkFile = File('${chunkDir.path}/chunk_$i');
        if (await chunkFile.exists()) {
          sink.add(await chunkFile.readAsBytes());
          await chunkFile.delete();
          chunksAssembled++;
        }
      }
      await sink.close();

      // Cleanup chunk directory
      try {
        await chunkDir.delete(recursive: true);
      } catch (_) {}

      // Fail if any chunks were missing
      if (chunksAssembled != state.totalChunks) {
        try {
          await outputFile.delete();
        } catch (_) {}
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error':
                'Missing chunks: got $chunksAssembled/${state.totalChunks}',
          }),
        );
        await request.response.close();
        _chunkedTransfers.remove(transferId);
        return;
      }

      // Decrypt if the sender encrypted with our key
      if (isEncrypted) {
        try {
          final decryptedPath = await _encryption.decryptFile(
            state.outputPath,
            _encryption.currentKey,
            _encryption.currentIv,
          );
          await File(state.outputPath).delete();
          await File(decryptedPath).copy(state.outputPath);
          await File(decryptedPath).delete();
          debugPrint('HttpTransfer: Decrypted reassembled file');
        } catch (e) {
          debugPrint(
            'HttpTransfer: Decryption failed for reassembled file: $e',
          );
          try {
            await File(state.outputPath).delete();
          } catch (_) {}
          request.response.statusCode = HttpStatus.internalServerError;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': 'Decryption failed'}));
          await request.response.close();
          _chunkedTransfers.remove(transferId);
          return;
        }
      }

      // Decompress if needed
      if (isCompressed) {
        try {
          final decompressedPath = await CompressionUtils.decompressFile(
            state.outputPath,
          );
          if (decompressedPath != state.outputPath) {
            await File(state.outputPath).delete();
            await File(decompressedPath).copy(state.outputPath);
            await File(decompressedPath).delete();
          }
        } catch (_) {}
      }

      final actualSize = await outputFile.length();

      if (state.transferModel != null) {
        await _transferService.updateProgress(state.transferModel!.id, 100, 0);
        await _transferService.markCompleted(
          state.transferModel!.id,
          filePath: state.outputPath,
        );
      } else {
        await _transferService.queueTransfer(
          fileName: state.fileName,
          fileSize: actualSize,
          fileType: state.fileName.contains('.')
              ? state.fileName.split('.').last
              : 'unknown',
          senderId: decodedData['sender_id'] as String? ?? '',
          senderName: decodedData['sender_name'] as String? ?? 'Nearby Device',
          receiverId: _deviceId,
          receiverName: 'Me',
          direction: TransferDirection.received,
          filePath: state.outputPath,
        );
      }

      _onFileReceivedController?.add(
        HttpTransferEvent(
          endpointId: decodedData['sender_id'] as String? ?? '',
          fileName: state.fileName,
          fileSize: state.totalSize,
          filePath: state.outputPath,
        ),
      );

      _chunkedTransfers.remove(transferId);

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'completed'}));
      await request.response.close();
    } catch (e) {
      debugPrint('HttpTransfer: Chunk complete error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handlePairRequest(HttpRequest request) async {
    try {
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes);
      final data = jsonDecode(body) as Map<String, dynamic>;

      final remoteDeviceId = data['device_id'] as String?;
      final remoteDeviceName = data['device_name'] as String? ?? 'Unknown';
      final remoteIp =
          data['ip'] as String? ??
          request.connectionInfo?.remoteAddress.address ??
          '';
      final remotePort = data['port'] as int? ?? AppConstants.discoveryPort;
      final remoteKey = data['encryption_key'] as String?;
      final remoteIv = data['encryption_iv'] as String?;

      if (remoteDeviceId != null && remoteDeviceId != _deviceId) {
        // Store the remote device's encryption keys via EncryptionService
        if (remoteKey != null && remoteIv != null) {
          await _encryption.importKeys(
            {'key': remoteKey, 'iv': remoteIv},
            deviceId: remoteDeviceId,
            deviceName: remoteDeviceName,
          );
          debugPrint(
            'HttpTransfer: Stored encryption keys for $remoteDeviceName',
          );
        }

        final existing = _discoveryService.getDeviceByDeviceId(remoteDeviceId);
        if (existing == null) {
          final device = DeviceModel(
            id: _uuid.v4(),
            name: remoteDeviceName,
            deviceId: remoteDeviceId,
            deviceType: DeviceType.android,
            status: DeviceStatus.paired,
            lastSeen: DateTime.now(),
            isPaired: true,
            isBlocked: false,
            isHidden: false,
            ipAddress: remoteIp,
            port: remotePort,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _discoveryService.addDevice(device);
        } else {
          _discoveryService.pairDevice(remoteDeviceId);
          _discoveryService.updateDeviceIp(
            remoteDeviceId,
            remoteIp,
            remotePort,
          );
        }
        debugPrint(
          'HttpTransfer: Paired with $remoteDeviceName ($remoteIp:$remotePort)',
        );
      }

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'status': 'paired',
          'device_id': _deviceId,
          'device_name': _deviceName,
          'encryption_key': _encryption.currentKey,
          'encryption_iv': _encryption.currentIv,
        }),
      );
      await request.response.close();
    } catch (e) {
      debugPrint('HttpTransfer: Pair request error: $e');
      try {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleTransferRequest(HttpRequest request) async {
    try {
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes);
      final data = jsonDecode(body) as Map<String, dynamic>;

      final requestId = _uuid.v4();
      final event = TransferRequestEvent(
        requestId: requestId,
        senderId: data['sender_id'] as String? ?? '',
        senderName: data['sender_name'] as String? ?? 'Unknown',
        fileNames: (data['file_names'] as List?)?.cast<String>() ?? [],
        fileSizes: (data['file_sizes'] as List?)?.cast<int>() ?? [],
      );

      final completer = Completer<bool>();
      _pendingTransferRequests[requestId] = completer;
      _pendingTransferEvents[requestId] = event;

      _onTransferRequestController?.add(event);

      final accepted = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () => false,
      );

      _pendingTransferRequests.remove(requestId);
      _pendingTransferEvents.remove(requestId);

      if (accepted) {
        event.accepted = true;
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'status': 'accepted',
            'request_id': requestId,
            'device_name': _deviceName,
          }),
        );
      } else {
        request.response.statusCode = HttpStatus.forbidden;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'status': 'rejected',
            'reason': 'Transfer rejected by user',
          }),
        );
      }
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': e.toString()}));
      } catch (_) {}
    } finally {
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Accept a pending transfer request
  void acceptTransferRequest(String requestId) {
    final completer = _pendingTransferRequests[requestId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
    }
  }

  /// Reject a pending transfer request
  void rejectTransferRequest(String requestId) {
    final completer = _pendingTransferRequests[requestId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
  }

  /// Handle incoming chat message
  Future<void> _handleChatMessage(HttpRequest request) async {
    try {
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes);
      final data = jsonDecode(body) as Map<String, dynamic>;

      final message = data['message'] as String? ?? '';
      final senderId = data['sender_id'] as String? ?? '';
      final senderName = data['sender_name'] as String? ?? 'Unknown';
      final timestampStr = data['timestamp'] as String?;

      debugPrint('HttpTransfer: chat msg senderId=$senderId messageLen=${message.length}');

      if (message.isEmpty || senderId.isEmpty) {
        debugPrint('HttpTransfer: Rejecting chat message: senderId=$senderId message=$message');
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }

      // Use AuthService device ID for receiver so messages are found by loadConversation()
      final myDeviceId = AuthService.instance.currentUser?.deviceId ?? _deviceId;

      final chatMessage = ChatMessageModel(
        id: _uuid.v4(),
        senderId: senderId,
        senderName: senderName,
        receiverId: myDeviceId,
        receiverName: 'Me',
        message: message,
        messageType: MessageType.text,
        isEncrypted: false,
        createdAt: timestampStr != null
            ? DateTime.parse(timestampStr)
            : DateTime.now(),
      );

      await ChatService.instance.receiveMessage(chatMessage);

      // Notify user of new message
      NotificationService.instance.notifyNewMessage(senderName);
      SoundService.instance.playNotification();

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'delivered'}));
      await request.response.close();

      debugPrint('HttpTransfer: Chat message received from $senderName');
    } catch (e) {
      debugPrint('HttpTransfer: Chat receive error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Update the device name used in broadcasts and headers
  void updateDeviceName(String name) {
    _deviceName = name;
  }

  /// Send a chat message to a remote device
  Future<bool> sendChatMessage({
    required String host,
    int port = AppConstants.discoveryPort,
    required ChatMessageModel message,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.postUrl(
          Uri.parse('http://$host:$port/chat-message'),
        );
        request.headers.contentType = ContentType.json;
        final payload = jsonEncode({
          'message': message.message,
          'sender_id': message.senderId,
          'sender_name': message.senderName,
          'timestamp': message.createdAt.toIso8601String(),
        });
        debugPrint('HttpTransfer: Sending chat payload senderId="${message.senderId}" senderName="${message.senderName}"');
        request.write(payload);
        final response = await request.close();
        debugPrint('HttpTransfer: Chat message response ${response.statusCode} to $host:$port');
        if (response.statusCode == HttpStatus.ok) {
          return true;
        }
        return false;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('HttpTransfer: Error sending chat message: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Call signaling
  // ---------------------------------------------------------------------------

  Future<void> _handleCallOffer(HttpRequest request) async {
    try {
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes);
      final data = jsonDecode(body) as Map<String, dynamic>;

      final callId = data['call_id'] as String? ?? '';
      final sdp = data['sdp'] as String? ?? '';
      final video = data['video'] as bool? ?? false;
      final callerName = data['caller_name'] as String? ?? 'Unknown';
      final remoteId = data['sender_id'] as String? ?? '';

      if (callId.isEmpty) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }

      await CallService.instance.handleIncomingOffer(
        callId: callId,
        sdp: sdp,
        video: video,
        callerName: callerName,
        remoteId: remoteId,
      );

      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'status': 'ringing'}));
      await request.response.close();
    } catch (e) {
      debugPrint('HttpTransfer: Call offer error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleCallAnswer(HttpRequest request) async {
    try {
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes);
      final data = jsonDecode(body) as Map<String, dynamic>;

      final sdp = data['sdp'] as String? ?? '';

      await CallService.instance.handleRemoteAnswer(sdp);

      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } catch (e) {
      debugPrint('HttpTransfer: Call answer error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleIceCandidate(HttpRequest request) async {
    try {
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }
      final body = utf8.decode(bytes);
      final data = jsonDecode(body) as Map<String, dynamic>;

      final candidateStr = data['candidate'] as String? ?? '';
      debugPrint('HttpTransfer: ICE candidate received (len=${candidateStr.length})');
      final candidate = jsonDecode(candidateStr) as Map<String, dynamic>;

      await CallService.instance.handleIceCandidate(candidate);

      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } catch (e) {
      debugPrint('HttpTransfer: ICE candidate error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _handleCallEnd(HttpRequest request) async {
    try {
      final bytes = <int>[];
      await for (final chunk in request) {
        bytes.addAll(chunk);
      }

      debugPrint('HttpTransfer: Call ended by remote device');
      await CallService.instance.handleRemoteHangup();

      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } catch (e) {
      debugPrint('HttpTransfer: Call end error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Receive an audio chunk sent via the HTTP relay
  Future<void> _handleCallAudio(HttpRequest request) async {
    try {
      final audioBytes = <int>[];
      await for (final chunk in request) {
        audioBytes.addAll(chunk);
      }

      if (audioBytes.isNotEmpty) {
        MediaRelayService.instance.receiveAudioChunk(
          Uint8List.fromList(audioBytes),
        );
      }

      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } catch (e) {
      debugPrint('HttpTransfer: Call audio error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Receive a video frame sent via the HTTP relay (no internet needed)
  Future<void> _handleCallVideo(HttpRequest request) async {
    try {
      final frameBytes = <int>[];
      await for (final chunk in request) {
        frameBytes.addAll(chunk);
      }

      if (frameBytes.isNotEmpty) {
        MediaRelayService.instance.receiveVideoFrame(
          Uint8List.fromList(frameBytes),
        );
      }

      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
    } catch (e) {
      debugPrint('HttpTransfer: Call video frame error: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<bool> sendCallOffer({
    required String host,
    int port = AppConstants.discoveryPort,
    required String callId,
    required String sdp,
    required bool video,
    required String callerName,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.postUrl(
          Uri.parse('http://$host:$port/call-offer'),
        );
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({
            'call_id': callId,
            'sdp': sdp,
            'video': video,
            'caller_name': callerName,
            'sender_id': _deviceId,
          }),
        );
        final response = await request.close();
        return response.statusCode == HttpStatus.ok;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('HttpTransfer: Error sending call offer: $e');
      return false;
    }
  }

  Future<bool> sendCallAnswer({
    required String host,
    int port = AppConstants.discoveryPort,
    required String callId,
    required String sdp,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.postUrl(
          Uri.parse('http://$host:$port/call-answer'),
        );
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'call_id': callId, 'sdp': sdp}));
        final response = await request.close();
        return response.statusCode == HttpStatus.ok;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('HttpTransfer: Error sending call answer: $e');
      return false;
    }
  }

  Future<bool> sendIceCandidate({
    required String host,
    int port = AppConstants.discoveryPort,
    required String callId,
    required String candidate,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.postUrl(
          Uri.parse('http://$host:$port/call-ice-candidate'),
        );
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'call_id': callId, 'candidate': candidate}));
        final response = await request.close();
        return response.statusCode == HttpStatus.ok;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('HttpTransfer: Error sending ICE candidate: $e');
      return false;
    }
  }

  Future<bool> sendCallEnd({
    required String host,
    int port = AppConstants.discoveryPort,
    required String callId,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.postUrl(
          Uri.parse('http://$host:$port/call-end'),
        );
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'call_id': callId}));
        final response = await request.close();
        return response.statusCode == HttpStatus.ok;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('HttpTransfer: Error sending call end: $e');
      return false;
    }
  }

  /// Send a transfer request to a remote device and wait for acceptance
  Future<bool> requestTransfer({
    required String host,
    int port = AppConstants.discoveryPort,
    required List<String> fileNames,
    required List<int> fileSizes,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.postUrl(
          Uri.parse('http://$host:$port/transfer-request'),
        );
        request.headers.contentType = ContentType.json;
        request.write(
          jsonEncode({
            'sender_id': _deviceId,
            'sender_name': _deviceName,
            'file_names': fileNames,
            'file_sizes': fileSizes,
          }),
        );
        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == HttpStatus.ok) {
          final respData = jsonDecode(responseBody) as Map<String, dynamic>;
          _onTransferStartedController?.add(
            TransferStartedEvent(
              fileNames: fileNames,
              fileSizes: fileSizes,
              receiverName:
                  respData['device_name'] as String? ?? 'Nearby Device',
            ),
          );
          return true;
        }
        debugPrint('HttpTransfer: Transfer request rejected: $responseBody');
        return false;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('HttpTransfer: Error requesting transfer: $e');
      return false;
    }
  }

  bool _isMediaFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return [
      'jpg',
      'jpeg',
      'png',
      'gif',
      'bmp',
      'webp',
      'mp4',
      'avi',
      'mkv',
      'mov',
      'wmv',
      'flv',
      'mp3',
      'wav',
      'aac',
      'ogg',
      'flac',
      'wma',
    ].contains(ext);
  }

  Future<Map<String, dynamic>> sendFile({
    required String host,
    int port = AppConstants.discoveryPort,
    required String filePath,
    required String fileName,
    String? receiverId,
    String? receiverName,
    bool useCompression = true,
  }) async {
    TransferModel? transfer;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {'success': false, 'error': 'File not found'};
      }

      final originalSize = await file.length();

      // For large files, use parallel chunked transfer
      if (originalSize >= _largeFileThreshold) {
        return await _sendFileParallel(
          host: host,
          port: port,
          filePath: filePath,
          fileName: fileName,
          receiverId: receiverId,
          receiverName: receiverName,
          useCompression: useCompression,
        );
      }

      // Compress before encryption for compressible file types
      bool wasCompressed = false;
      bool wasEncrypted = false;
      String preppedPath = filePath;
      if (useCompression &&
          CompressionUtils.shouldCompress(filePath, originalSize)) {
        try {
          final compressed = await CompressionUtils.compressFile(filePath);
          if (compressed != filePath) {
            preppedPath = compressed;
            wasCompressed = true;
          }
        } catch (_) {}
      }

      // Skip encryption for large media files to avoid OOM from full-file reads
      bool skipEncryption = false;
      if (originalSize > _maxEncryptionSize && _isMediaFile(fileName)) {
        skipEncryption = true;
      }

      // Encrypt with receiver's key if we have it
      if (!skipEncryption && receiverId != null) {
        final pairedKeys = _encryption.getPairedKeys(receiverId);
        if (pairedKeys != null) {
          try {
            final encryptedPath = await _encryption.encryptFileWithKey(
              preppedPath,
              pairedKeys['key']!,
              pairedKeys['iv']!,
            );
            if (encryptedPath != preppedPath) {
              if (wasCompressed) {
                try {
                  await File(preppedPath).delete();
                } catch (_) {}
              }
              preppedPath = encryptedPath;
              wasEncrypted = true;
            }
          } catch (_) {}
        }
      }

      final sendFile = File(preppedPath);
      final sendSize = await sendFile.length();
      final fileType = fileName.contains('.')
          ? fileName.split('.').last
          : 'unknown';

      transfer = await _transferService.queueTransfer(
        fileName: fileName,
        fileSize: originalSize,
        fileType: fileType,
        senderId: _deviceId,
        senderName: _deviceName,
        receiverId: receiverId ?? '',
        receiverName: receiverName ?? 'Nearby Device',
        direction: TransferDirection.sent,
        filePath: filePath,
      );

      const maxRetries = 2;
      const retryDelay = Duration(seconds: 3);
      Map<String, dynamic>? lastError;

      for (int attempt = 0; attempt <= maxRetries; attempt++) {
        final client = HttpClient();
        client.connectionTimeout = Duration(
          seconds: originalSize > 10485760 ? 60 : 15,
        );
        client.idleTimeout = const Duration(seconds: 300);

        try {
          final request = await client.postUrl(
            Uri.parse('http://$host:$port/receive'),
          );

          request.headers.set('content-type', 'application/octet-stream');
          request.headers.set(
            'content-disposition',
            'attachment; filename="$fileName"',
          );
          request.headers.set('x-device-id', _deviceId);
          request.headers.set('x-device-name', _deviceName);
          request.headers.set('content-length', sendSize.toString());
          if (wasCompressed) {
            request.headers.set('x-compressed', 'gzip');
          }
          if (wasEncrypted) {
            request.headers.set('x-encrypted', 'aes256');
          }

          final fileStream = sendFile.openRead();
          int bytesSent = 0;
          int lastProgressUpdate = 0;
          final stopwatch = Stopwatch()..start();
          await for (final chunk in fileStream) {
            request.add(chunk);
            bytesSent += chunk.length;
            final progress = ((bytesSent / sendSize) * 100)
                .clamp(0, 100)
                .toInt();
            if (progress > lastProgressUpdate + 5 || progress >= 100) {
              lastProgressUpdate = progress;
              final elapsed = stopwatch.elapsedMilliseconds ~/ 1000;
              final speed = elapsed > 0
                  ? (bytesSent / elapsed).toDouble()
                  : 0.0;
              await _transferService.updateProgress(
                transfer.id,
                progress.toDouble(),
                speed,
              );
            }
          }
          final response = await request.close();

          if (response.statusCode == HttpStatus.ok) {
            await _transferService.markCompleted(transfer.id);
            _onFileSentController?.add(
              HttpTransferEvent(
                endpointId: receiverId ?? '',
                fileName: fileName,
                fileSize: originalSize,
                filePath: filePath,
              ),
            );
            debugPrint('HttpTransfer: Sent $fileName to $host:$port');
            return {'success': true};
          } else {
            final errBody = await response.transform(utf8.decoder).join();
            lastError = {
              'success': false,
              'error': 'Server returned ${response.statusCode}',
            };
            debugPrint(
              'HttpTransfer: Send attempt ${attempt + 1} failed: ${response.statusCode} - $errBody',
            );
          }
        } catch (e) {
          lastError = {'success': false, 'error': e.toString()};
          debugPrint('HttpTransfer: Send attempt ${attempt + 1} error: $e');
        } finally {
          client.close();
        }

        if (attempt < maxRetries) {
          await Future.delayed(retryDelay);
        }
      }

      await _transferService.markFailed(
        transfer.id,
        errorMessage: lastError?['error'] ?? 'Unknown error after retries',
      );
      return lastError ?? {'success': false, 'error': 'Unknown error'};
    } catch (e) {
      final errMsg = e.toString();
      debugPrint('HttpTransfer: Error sending file: $errMsg');
      if (transfer != null) {
        try {
          await _transferService.markFailed(transfer.id, errorMessage: errMsg);
        } catch (_) {}
      }
      return {'success': false, 'error': errMsg};
    }
  }

  Future<Map<String, dynamic>> _sendFileParallel({
    required String host,
    int port = AppConstants.discoveryPort,
    required String filePath,
    required String fileName,
    String? receiverId,
    String? receiverName,
    bool useCompression = true,
  }) async {
    TransferModel? transfer;
    String? sendPath;

    try {
      final file = File(filePath);
      final originalSize = await file.length();

      // Compress if beneficial
      bool wasCompressed = false;
      bool wasEncrypted = false;
      String preppedPath = filePath;
      if (useCompression &&
          CompressionUtils.shouldCompress(filePath, originalSize)) {
        try {
          final compressed = await CompressionUtils.compressFile(filePath);
          if (compressed != filePath) {
            preppedPath = compressed;
            wasCompressed = true;
          }
        } catch (_) {}
      }

      // Skip encryption for large media files to avoid OOM from full-file reads
      bool skipEncryption = false;
      if (originalSize > _maxEncryptionSize && _isMediaFile(fileName)) {
        skipEncryption = true;
      }

      // Encrypt with receiver's key if available
      if (!skipEncryption && receiverId != null) {
        final pairedKeys = _encryption.getPairedKeys(receiverId);
        if (pairedKeys != null) {
          try {
            final encryptedPath = await _encryption.encryptFileWithKey(
              preppedPath,
              pairedKeys['key']!,
              pairedKeys['iv']!,
            );
            if (encryptedPath != preppedPath) {
              if (wasCompressed) {
                try {
                  await File(preppedPath).delete();
                } catch (_) {}
              }
              preppedPath = encryptedPath;
              wasEncrypted = true;
            }
          } catch (_) {}
        }
      }

      sendPath = preppedPath;
      final totalSize = await File(sendPath).length();
      final int totalChunks =
          ((totalSize + _chunkSizeBytes - 1) ~/ _chunkSizeBytes).clamp(1, 100);
      final transferId = _uuid.v4();
      final fileType = fileName.contains('.')
          ? fileName.split('.').last
          : 'unknown';

      transfer = await _transferService.queueTransfer(
        fileName: fileName,
        fileSize: originalSize,
        fileType: fileType,
        senderId: _deviceId,
        senderName: _deviceName,
        receiverId: receiverId ?? '',
        receiverName: receiverName ?? 'Nearby Device',
        direction: TransferDirection.sent,
        filePath: filePath,
      );

      // Send chunks in parallel batches
      int completedChunks = 0;
      final totalChunksInt = totalChunks;
      final sendFile = File(sendPath);
      final chunkStopwatch = Stopwatch()..start();

      for (var offset = 0; offset < totalChunksInt; offset += _parallelChunks) {
        final batchSize = min(_parallelChunks, totalChunksInt - offset);
        final futures = <Future<bool>>[];

        for (var i = 0; i < batchSize; i++) {
          final chunkIndex = offset + i;
          futures.add(
            _sendSingleChunk(
              host: host,
              port: port,
              transferId: transferId,
              chunkIndex: chunkIndex,
              totalChunks: totalChunksInt,
              fileName: fileName,
              fileSize: originalSize,
              sendFile: sendFile,
              wasCompressed: wasCompressed,
              chunkSize: _chunkSizeBytes,
            ),
          );
        }

        final results = await Future.wait(futures);
        completedChunks += results.where((r) => r).length;

        final progress = ((completedChunks / totalChunksInt) * 100).clamp(
          0.0,
          100.0,
        );
        final elapsed = chunkStopwatch.elapsedMilliseconds ~/ 1000;
        final bytesDone = completedChunks * _chunkSizeBytes;
        final speed = elapsed > 0 ? (bytesDone / elapsed).toDouble() : 0.0;
        await _transferService.updateProgress(transfer.id, progress, speed);
      }

      // Notify receiver that all chunks are sent
      final completeResult = await _sendChunkComplete(
        host: host,
        port: port,
        transferId: transferId,
        fileName: fileName,
        fileSize: originalSize,
        senderId: _deviceId,
        senderName: _deviceName,
        wasCompressed: wasCompressed,
        wasEncrypted: wasEncrypted,
      );

      if (completeResult) {
        await _transferService.markCompleted(transfer.id);
        _onFileSentController?.add(
          HttpTransferEvent(
            endpointId: receiverId ?? '',
            fileName: fileName,
            fileSize: originalSize,
            filePath: filePath,
          ),
        );
        debugPrint('HttpTransfer: Sent $fileName (parallel) to $host:$port');
        return {'success': true};
      } else {
        await _transferService.markFailed(
          transfer.id,
          errorMessage: 'Chunk assembly failed on receiver',
        );
        return {'success': false, 'error': 'Chunk assembly failed'};
      }
    } catch (e) {
      final errMsg = e.toString();
      debugPrint('HttpTransfer: Parallel send error: $errMsg');
      if (transfer != null) {
        try {
          await _transferService.markFailed(transfer.id, errorMessage: errMsg);
        } catch (_) {}
      }
      return {'success': false, 'error': errMsg};
    }
  }

  Future<bool> _sendSingleChunk({
    required String host,
    required int port,
    required String transferId,
    required int chunkIndex,
    required int totalChunks,
    required String fileName,
    required int fileSize,
    required File sendFile,
    required bool wasCompressed,
    required int chunkSize,
  }) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final start = chunkIndex * chunkSize;
        final fileLength = await sendFile.length();
        final end = min(start + chunkSize, fileLength);
        final actualChunkSize = end - start;

        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 60);

        try {
          final request = await client.postUrl(
            Uri.parse('http://$host:$port/chunk'),
          );

          request.headers.set('content-type', 'application/octet-stream');
          request.headers.set('x-transfer-id', transferId);
          request.headers.set('x-chunk-index', chunkIndex.toString());
          request.headers.set('x-total-chunks', totalChunks.toString());
          request.headers.set('x-chunk-size', actualChunkSize.toString());
          request.headers.set('x-file-name', fileName);
          request.headers.set('x-file-size', fileSize.toString());
          request.headers.set('x-device-id', _deviceId);
          request.headers.set('x-device-name', _deviceName);
          if (wasCompressed) {
            request.headers.set('x-compressed', 'gzip');
          }

          final randomAccessFile = await sendFile.open(mode: FileMode.read);
          await randomAccessFile.setPosition(start);
          final chunkData = await randomAccessFile.read(actualChunkSize);
          await randomAccessFile.close();

          request.add(chunkData);
          final response = await request.close();

          if (response.statusCode == HttpStatus.ok) {
            return true;
          }

          debugPrint(
            'HttpTransfer: Chunk $chunkIndex attempt ${attempt + 1} failed with status ${response.statusCode}',
          );
        } finally {
          client.close();
        }
      } catch (e) {
        debugPrint(
          'HttpTransfer: Chunk $chunkIndex attempt ${attempt + 1} error: $e',
        );
      }

      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }

    debugPrint(
      'HttpTransfer: Chunk $chunkIndex failed after ${maxRetries + 1} attempts',
    );
    return false;
  }

  Future<bool> _sendChunkComplete({
    required String host,
    required int port,
    required String transferId,
    required String fileName,
    required int fileSize,
    required String senderId,
    required String senderName,
    required bool wasCompressed,
    required bool wasEncrypted,
  }) async {
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 2);

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 30);

        try {
          final request = await client.postUrl(
            Uri.parse('http://$host:$port/chunk-complete'),
          );
          request.headers.contentType = ContentType.json;
          request.write(
            jsonEncode({
              'transfer_id': transferId,
              'file_name': fileName,
              'file_size': fileSize,
              'sender_id': senderId,
              'sender_name': senderName,
              'compressed': wasCompressed,
              'encrypted': wasEncrypted,
            }),
          );
          final response = await request.close();

          if (response.statusCode == HttpStatus.ok) {
            return true;
          }

          debugPrint(
            'HttpTransfer: Chunk complete attempt ${attempt + 1} failed with status ${response.statusCode}',
          );
        } finally {
          client.close();
        }
      } catch (e) {
        debugPrint(
          'HttpTransfer: Chunk complete attempt ${attempt + 1} error: $e',
        );
      }

      if (attempt < maxRetries) {
        await Future.delayed(retryDelay);
      }
    }

    debugPrint(
      'HttpTransfer: Chunk complete failed after ${maxRetries + 1} attempts',
    );
    return false;
  }

  Future<Map<String, dynamic>> testConnection(
    String host, {
    int port = AppConstants.discoveryPort,
  }) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.getUrl(
          Uri.parse('http://$host:$port/health'),
        );
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        return {
          'success': response.statusCode == HttpStatus.ok,
          'statusCode': response.statusCode,
          'body': body,
        };
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      return {
        'success': false,
        'error': 'Cannot reach $host:$port - ${e.message}',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> fetchDeviceInfo(String host) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.getUrl(
          Uri.parse('http://$host:$_port/info'),
        );
        final response = await request.close();
        if (response.statusCode == HttpStatus.ok) {
          final body = await response.transform(utf8.decoder).join();
          return jsonDecode(body) as Map<String, dynamic>;
        }
      } finally {
        client.close();
      }
    } catch (_) {}
    return null;
  }

  Future<bool> sendPairRequest(
    String host,
    Map<String, dynamic> pairData, {
    int? port,
  }) async {
    final targetPort = port ?? _port;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.postUrl(
          Uri.parse('http://$host:$targetPort/pair'),
        );
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(pairData));
        final response = await request.close();
        if (response.statusCode == HttpStatus.ok) {
          final body = await response.transform(utf8.decoder).join();
          final result = jsonDecode(body) as Map<String, dynamic>;
          final remoteDeviceId = result['device_id'] as String?;
          final remoteKey = result['encryption_key'] as String?;
          final remoteIv = result['encryption_iv'] as String?;
          if (remoteDeviceId != null && remoteKey != null && remoteIv != null) {
            await _encryption.importKeys({
              'key': remoteKey,
              'iv': remoteIv,
            }, deviceId: remoteDeviceId);
            debugPrint(
              'HttpTransfer: Stored encryption keys for $remoteDeviceId from pair response',
            );
          }
          return true;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint(
        'HttpTransfer: sendPairRequest to $host:$targetPort failed: $e',
      );
    }
    return false;
  }

  Future<void> dispose() async {
    _connectivitySub?.cancel();
    _networkCheckTimer?.cancel();
    _onFileReceivedController?.close();
    _onFileSentController?.close();
    _onTransferStartedController?.close();
    _onTransferRequestController?.close();
    _pendingTransferRequests.clear();
    _pendingTransferEvents.clear();
    await stopServer();
  }
}
