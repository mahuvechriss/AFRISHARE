import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/transfer_model.dart';
import 'transfer_service.dart';
import 'encryption_service.dart';
import 'storage_service.dart';

class CloudRelayService {
  CloudRelayService._();
  static final CloudRelayService instance = CloudRelayService._();

  final Uuid _uuid = const Uuid();
  final TransferService _transferService = TransferService.instance;
  final EncryptionService _encryption = EncryptionService.instance;

  String _serverUrl = 'http://localhost:3000';
  String _deviceName = 'AfriShare Device';
  String? _lastShareCode;

  String get serverUrl => _serverUrl;
  String? get lastShareCode => _lastShareCode;

  void initialize({String? serverUrl, String? deviceName}) {
    if (serverUrl != null) _serverUrl = serverUrl;
    _deviceName = deviceName ?? 'AfriShare Device';
  }

  void setServerUrl(String url) {
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<Map<String, dynamic>> checkHealth() async {
    if (_serverUrl.contains('localhost') || _serverUrl.contains('127.0.0.1')) {
      return {
        'status': 'error',
        'error': 'Server URL is set to localhost. '
            'The relay server must run on a computer/server, not on this phone. '
            'Go to Settings > Cloud Relay to set the correct server URL.',
      };
    }
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(
          Uri.parse('$_serverUrl/api/health'),
        );
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          return jsonDecode(body) as Map<String, dynamic>;
        }
        return {'status': 'error', 'error': 'Server returned ${response.statusCode}'};
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      return {
        'status': 'error',
        'error': 'Cannot connect to relay server at $_serverUrl. '
            'Make sure the server is running and the URL is correct. '
            'Error: ${e.message}',
      };
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _checkServerReachable() async {
    if (_serverUrl.contains('localhost') || _serverUrl.contains('127.0.0.1')) {
      return {
        'reachable': false,
        'error': 'Server URL is set to localhost.\n'
            'The relay server must run on a computer/server, not on your phone.\n'
            'Go to Settings > Cloud Relay to set the correct server URL.\n\n'
            'Quick setup:\n'
            '1. Run: cd server && node server.js\n'
            '2. Find your computer IP (ipconfig/ifconfig)\n'
            '3. Set URL to http://YOUR_IP:3000 in Settings',
      };
    }
    return {'reachable': true};
  }

  Future<Map<String, dynamic>> uploadFile({
    required String filePath,
    String? senderName,
  }) async {
    final check = await _checkServerReachable();
    if (check['reachable'] != true) return check;

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {'status': 'error', 'error': 'File not found'};
      }

      String? sendPath = filePath;
      try {
        sendPath = await _encryption.encryptFile(filePath);
      } catch (_) {}

      final sendFile = File(sendPath!);
      final fileSize = await sendFile.length();
      final fileName = file.path.split(Platform.pathSeparator).last;

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);

      try {
        final uri = Uri.parse('$_serverUrl/api/upload');
        final boundary = '----${_uuid.v4()}';
        final request = await client.postUrl(uri);
        request.headers.set('content-type', 'multipart/form-data; boundary=$boundary');

        // Write multipart headers as stream to avoid OOM
        request.write('--$boundary\r\n');
        request.write('Content-Disposition: form-data; name="senderName"\r\n\r\n');
        request.write('${senderName ?? _deviceName}\r\n');
        request.write('--$boundary\r\n');
        request.write('Content-Disposition: form-data; name="file"; filename="$fileName"\r\n');
        request.write('Content-Type: application/octet-stream\r\n\r\n');

        // Stream file contents instead of loading all into memory
        final fileStream = sendFile.openRead();
        await for (final chunk in fileStream) {
          request.add(chunk);
        }

        request.write('\r\n');
        request.write('--$boundary--\r\n');

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();
        final result = jsonDecode(responseBody) as Map<String, dynamic>;

        if (response.statusCode == 200 && result['status'] == 'ok') {
          _lastShareCode = result['shareCode'] as String?;
          final fileType = fileName.contains('.')
              ? fileName.split('.').last
              : 'unknown';

          await _transferService.queueTransfer(
            fileName: fileName,
            fileSize: fileSize,
            fileType: fileType,
            senderId: _deviceName,
            senderName: _deviceName,
            receiverId: 'cloud',
            receiverName: 'Remote Receiver',
            direction: TransferDirection.sent,
            filePath: filePath,
          );

          debugPrint('CloudRelay: Uploaded $fileName -> code ${result['shareCode']}');
        }

        return result;
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      return {
        'status': 'error',
        'error': 'Cannot reach relay server at $_serverUrl.\n'
            '${e.message}\n\n'
            'Check that the server is running and your phone can reach it '
            '(both on same network, or server must be publicly accessible).',
      };
    } catch (e) {
      debugPrint('CloudRelay: Upload error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getFileInfo(String shareCode) async {
    final check = await _checkServerReachable();
    if (check['reachable'] != true) return check;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(
          Uri.parse('$_serverUrl/api/info/$shareCode'),
        );
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          return jsonDecode(body) as Map<String, dynamic>;
        } else {
          final result = jsonDecode(body) as Map<String, dynamic>;
          return result;
        }
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      return {
        'status': 'error',
        'error': 'Cannot connect to relay server.\n'
            '${e.message}\n\n'
            'Verify the server URL in Settings > Cloud Relay.',
      };
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> downloadFile({
    required String shareCode,
    String? receiverName,
  }) async {
    final check = await _checkServerReachable();
    if (check['reachable'] != true) return check;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);

      try {
        final request = await client.getUrl(
          Uri.parse('$_serverUrl/api/download/$shareCode'),
        );
        final response = await request.close();

        if (response.statusCode != 200) {
          final body = await response.transform(utf8.decoder).join();
          return jsonDecode(body) as Map<String, dynamic>;
        }

        final contentDisposition =
            response.headers.value('content-disposition') ?? '';
        String fileName = 'downloaded_file';
        final fileNameMatch = RegExp(r'filename="?(.+?)"?$')
            .firstMatch(contentDisposition);
        if (fileNameMatch != null) {
          fileName = fileNameMatch.group(1)!;
        }

        final contentLength = int.tryParse(
                response.headers.value('content-length') ?? '0') ??
            0;

        final transferDir = StorageService.instance.transferDirectory;
        final destPath = '${transferDir.path}/$fileName';
        final destFile = File(destPath);

        await response.fold(destFile.openWrite(mode: FileMode.write),
            (sink, chunk) {
          sink.add(chunk);
          return sink;
        }).then((sink) => sink.close());

        try {
          final decryptedPath = await _encryption.decryptFile(
            destPath,
            _encryption.currentKey,
            _encryption.currentIv,
          );
          await File(destPath).delete();
          await File(decryptedPath).copy(destPath);
          await File(decryptedPath).delete();
        } catch (_) {}

        final savedFile = File(destPath);
        final actualSize = await savedFile.length();
        final fileType = fileName.contains('.')
            ? fileName.split('.').last
            : 'unknown';

        await _transferService.queueTransfer(
          fileName: fileName,
          fileSize: contentLength > 0 ? contentLength : actualSize,
          fileType: fileType,
          senderId: 'cloud',
          senderName: 'Remote Sender',
          receiverId: _deviceName,
          receiverName: receiverName ?? 'Me',
          direction: TransferDirection.received,
          filePath: destPath,
        );

        debugPrint('CloudRelay: Downloaded $fileName ($shareCode)');

        return {
          'status': 'ok',
          'fileName': fileName,
          'fileSize': actualSize,
          'filePath': destPath,
        };
      } finally {
        client.close();
      }
    } on SocketException catch (e) {
      return {
        'status': 'error',
        'error': 'Download failed - cannot connect.\n'
            '${e.message}\n\n'
            'Check your connection and server URL.',
      };
    } catch (e) {
      debugPrint('CloudRelay: Download error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteFile(String shareCode) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.deleteUrl(
          Uri.parse('$_serverUrl/api/delete/$shareCode'),
        );
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      } finally {
        client.close();
      }
    } catch (e) {
      return {'status': 'error', 'error': e.toString()};
    }
  }
}
