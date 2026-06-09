import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/transfer_service.dart';
import 'services/resource_service.dart';
import 'services/notification_service.dart';
import 'services/encryption_service.dart';
import 'services/nearby_connector.dart';
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
            ],
          ),
        ),
      ),
    );
  };

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Lock orientation to portrait
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    // Initialize core services
    await _initializeServices();

    runApp(
      const ProviderScope(
        child: AfriShareApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    // Log any unhandled errors during app initialization
    debugPrint('AfriShare UNHANDLED ERROR: $error');
    debugPrint('Stack trace: $stack');
  });
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
    EncryptionService.instance.initialize();
    debugPrint('AfriShare: Encryption initialized');

    // Initialize authentication
    await AuthService.instance.initialize();
    debugPrint('AfriShare: Auth initialized');

    // Initialize services
    await TransferService.instance.initialize();
    debugPrint('AfriShare: Transfer service initialized');
    await ResourceService.instance.initialize();
    debugPrint('AfriShare: Resource service initialized');
    await NotificationService.instance.initialize();
    debugPrint('AfriShare: Notification service initialized');

    // Initialize Nearby Connections
    NearbyConnector.instance.initialize(
      deviceName: AuthService.instance.currentUser?.deviceName ?? 'AfriShare Device',
    );
    debugPrint('AfriShare: NearbyConnector initialized');
  } catch (e, stack) {
    debugPrint('AfriShare INIT ERROR: $e');
    debugPrint('Stack trace: $stack');
    rethrow;
  }
}
