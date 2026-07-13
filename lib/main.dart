import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'app.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/transfer_service.dart';
import 'services/resource_service.dart';
import 'services/notification_service.dart';
import 'services/encryption_service.dart';
import 'services/nearby_connector.dart';
import 'services/http_transfer_service.dart';
import 'services/network_discovery_service.dart';
import 'services/chat_service.dart';
import 'services/call_service.dart';
import 'services/discovery_service.dart';
import 'services/sound_service.dart';
import 'models/chat_message_model.dart';
import 'models/device_model.dart';
import 'core/constants/app_constants.dart';
import 'core/database/database_helper.dart';
import 'core/database/init_stub.dart'
    if (dart.library.html) 'core/database/init_web.dart';

void main() {
  // Show widget build errors on screen instead of white screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Builder(
                builder: (context) => ElevatedButton.icon(
                  onPressed: () {
                    try {
                      final nav = Navigator.of(context, rootNavigator: true);
                      if (nav.canPop()) {
                        nav.pop();
                        return;
                      }
                    } catch (_) {}
                    SystemNavigator.pop();
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Lock orientation to portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Set system UI overlay style
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // Initialize core services
      await _initializeServices();

      runApp(const ProviderScope(child: AfriShareApp()));
    },
    (Object error, StackTrace stack) {
      // Log any unhandled errors during app initialization
      debugPrint('AfriShare UNHANDLED ERROR: $error');
      debugPrint('Stack trace: $stack');
    },
  );
}

Future<String> _getDeviceModelName() async {
  try {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return '${androidInfo.brand} ${androidInfo.model}';
    } else if (Platform.isIOS) {
      final iosInfo = await DeviceInfoPlugin().iosInfo;
      return iosInfo.model;
    }
  } catch (_) {}
  return 'My Device';
}

Future<void> _initializeServices() async {
  try {
    // Initialize database factory for web
    initDatabaseFactory();
    // Initialize database
    await DatabaseHelper.instance.database;
    debugPrint('AfriShare: Database initialized');

    // Initialize storage
    await StorageService.instance.initialize();
    debugPrint('AfriShare: Storage initialized');

    // Initialize encryption
    await EncryptionService.instance.initialize();
    debugPrint('AfriShare: Encryption initialized');

    // Get real device model name
    final deviceModelName = await _getDeviceModelName();
    debugPrint('AfriShare: Device model: $deviceModelName');

    // Initialize authentication
    await AuthService.instance.initialize(deviceModelName: deviceModelName);
    debugPrint('AfriShare: Auth initialized');

    // Initialize services
    await TransferService.instance.initialize();
    debugPrint('AfriShare: Transfer service initialized');
    await ResourceService.instance.initialize();
    debugPrint('AfriShare: Resource service initialized');
    await NotificationService.instance.initialize();
    debugPrint('AfriShare: Notification service initialized');

    // Initialize HTTP Transfer & Network Discovery
    final authService = AuthService.instance;
    final deviceName = authService.currentUser?.deviceName ?? deviceModelName;
    final deviceId = authService.deviceId;

    HttpTransferService.instance.initialize(
      deviceName: deviceName,
      deviceId: deviceId,
    );
    debugPrint('AfriShare: HttpTransferService initialized');

    NetworkDiscoveryService.instance.initialize(
      deviceName: deviceName,
      deviceId: deviceId,
    );
    debugPrint('AfriShare: NetworkDiscoveryService initialized');

    // Start background network discovery so devices are found immediately
    // and pending messages can be delivered as soon as a friend comes online.
    try {
      await NetworkDiscoveryService.instance.startDiscovery();
      debugPrint('AfriShare: Network discovery started');
    } catch (e) {
      debugPrint('AfriShare: Network discovery start failed (non-fatal): $e');
    }

    // Initialize Call Service (WebRTC)
    await CallService.instance.initialize();
    debugPrint('AfriShare: CallService initialized');

    // Initialize Nearby Connections
    NearbyConnector.instance.initialize(deviceName: deviceName, deviceId: deviceId);
    debugPrint('AfriShare: NearbyConnector initialized');

    // Start HTTP server so the device is always reachable for pairing
    // and file transfers from other devices
    try {
      await HttpTransferService.instance.startServer();
      debugPrint(
        'AfriShare: HTTP server started on ${HttpTransferService.instance.localIp}:${HttpTransferService.instance.port}',
      );
    } catch (e) {
      debugPrint('AfriShare: HTTP server start failed (non-fatal): $e');
    }

    // Wire up chat message sending over LAN
    ChatService.instance.onMessageSent = (ChatMessageModel message) async {
      try {
        final device = DiscoveryService.instance.getDeviceByDeviceId(
          message.receiverId,
        );
        if (device != null &&
            device.ipAddress != null &&
            device.ipAddress!.isNotEmpty) {
          final host = device.ipAddress!;
          final port = device.port ?? AppConstants.discoveryPort;
          debugPrint(
            'AfriShare: Sending message to ${device.name} at $host:$port',
          );
          final sent = await HttpTransferService.instance.sendChatMessage(
            host: host,
            port: port,
            message: message,
          );
          if (!sent) {
            debugPrint(
              'AfriShare: sendChatMessage returned false (non-200 response)',
            );
            await ChatService.instance.savePendingMessage(
              senderId: message.senderId,
              senderName: message.senderName,
              receiverId: message.receiverId,
              receiverName: message.receiverName,
              message: message.message ?? '',
            );
          }
        } else {
          debugPrint(
            'AfriShare: Device ${message.receiverId} not found, saving as pending',
          );
          await ChatService.instance.savePendingMessage(
            senderId: message.senderId,
            senderName: message.senderName,
            receiverId: message.receiverId,
            receiverName: message.receiverName,
            message: message.message ?? '',
          );
        }
      } catch (e) {
        debugPrint('AfriShare: onMessageSent error: $e');
      }
    };

    // Wire up pending message delivery callback
    ChatService.instance.onDeliverPending = (message, ip, port) async {
      try {
        final result = await HttpTransferService.instance.sendChatMessage(
          host: ip,
          port: port,
          message: message,
        );
        return result;
      } catch (e) {
        debugPrint('AfriShare: onDeliverPending error: $e');
        return false;
      }
    };

    // Deliver pending messages when a device is discovered
    DiscoveryService.instance.onDeviceDiscovered = (DeviceModel device) async {
      try {
        if (device.ipAddress != null && device.ipAddress!.isNotEmpty) {
          await ChatService.instance.deliverPendingMessages(
            device.deviceId,
            device.ipAddress!,
            device.port ?? AppConstants.discoveryPort,
          );
        }
      } catch (e) {
        debugPrint('AfriShare: onDeviceDiscovered error: $e');
      }
    };

    // Initialize sound service for notification sounds
    await SoundService.instance.initialize();
    debugPrint('AfriShare: Sound service initialized');
  } catch (e, stack) {
    debugPrint('AfriShare INIT ERROR: $e');
    debugPrint('Stack trace: $stack');
    rethrow;
  }
}
