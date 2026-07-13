import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/call/call_screen.dart';
import 'screens/transfers/transfer_queue_screen.dart';
import 'services/http_transfer_service.dart';
import 'services/call_service.dart';
import 'services/notification_service.dart';
import 'services/sound_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();
/// Signal the HomeScreen to switch to the transfers tab (index 2) in the bottom nav.
/// Set to true from anywhere, then pop to root — HomeScreen will switch tab and reset it.
final navigateToTransfersNotifier = ValueNotifier<bool>(false);

class AfriShareApp extends ConsumerWidget {
  const AfriShareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'AfriShare',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const _AppWithGlobalListener(),
    );
  }
}

class _AppWithGlobalListener extends StatefulWidget {
  const _AppWithGlobalListener();

  @override
  State<_AppWithGlobalListener> createState() => _AppWithGlobalListenerState();
}

class _AppWithGlobalListenerState extends State<_AppWithGlobalListener> {
  StreamSubscription<TransferRequestEvent>? _transferRequestSub;
  StreamSubscription<HttpTransferEvent>? _fileReceivedSub;
  StreamSubscription<HttpTransferEvent>? _fileSentSub;
  StreamSubscription<TransferStartedEvent>? _transferStartedSub;
  /// Guard against pushing duplicate CallScreens — the Accept button in the
  /// incoming-call dialog used to push a CallScreen immediately AND
  /// onCallStateChanged pushed another when the call connected, causing
  /// two overlapping screens that broke renderers and streams.
  bool _callScreenPushed = false;

  @override
  void initState() {
    super.initState();
    _transferRequestSub =
        HttpTransferService.instance.onTransferRequest?.listen(
      _onTransferRequest,
    );
    _fileReceivedSub =
        HttpTransferService.instance.onFileReceived?.listen(
      _onFileReceived,
    );
    _fileSentSub =
        HttpTransferService.instance.onFileSent?.listen(
      _onFileSent,
    );
    _transferStartedSub =
        HttpTransferService.instance.onTransferStarted?.listen(
      _onTransferStarted,
    );
    CallService.instance.onIncomingCall = (call) async {
      if (!mounted) return;
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;

      // Request microphone permission silently before showing the dialog
      // so the system dialog doesn't overlap our call dialog
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _showMissingPermissionSnackbar();
        CallService.instance.rejectCall();
        return;
      }
      if (call.videoEnabled) {
        final camStatus = await Permission.camera.request();
        if (!camStatus.isGranted) {
          _showMissingPermissionSnackbar();
          CallService.instance.rejectCall();
          return;
        }
      }

      if (!mounted || ctx != navigatorKey.currentContext || !ctx.mounted) return;
      _showIncomingCallDialog(ctx, call);
    };
    CallService.instance.onCallStateChanged = (call) {
      // Push a CallScreen only on connected, and only once. The Accept
      // button in the incoming-call dialog no longer pushes one — we
      // rely entirely on this handler so there's never a duplicate.
      if (call.state == CallState.connected &&
          mounted &&
          !_callScreenPushed) {
        _callScreenPushed = true;
        final ctx = navigatorKey.currentContext;
        if (ctx == null || !ctx.mounted) { _callScreenPushed = false; return; }
        Navigator.push(
          ctx,
          MaterialPageRoute(builder: (context) => const CallScreen()),
        ).then((_) {
          _callScreenPushed = false;
        }).catchError((_) {
          _callScreenPushed = false;
        });
      }
    };
  }

  @override
  void dispose() {
    _transferRequestSub?.cancel();
    _fileReceivedSub?.cancel();
    _fileSentSub?.cancel();
    _transferStartedSub?.cancel();
    CallService.instance.onIncomingCall = null;
    CallService.instance.onCallStateChanged = null;
    _callScreenPushed = false;
    super.dispose();
  }

  void _showIncomingCallDialog(BuildContext ctx, CallSession call) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              call.videoEnabled ? Icons.videocam : Icons.call,
              color: AppColors.primaryGreen,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${call.videoEnabled ? 'Video' : 'Audio'} Call',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primaryGreenSurface,
              child: Text(
                call.remoteName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 28,
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${call.remoteName} is calling...',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              CallService.instance.rejectCall();
              Navigator.pop(dialogCtx);
            },
            child: const Text('Decline',
                style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              CallService.instance.acceptCall();
              // CallScreen is pushed automatically by onCallStateChanged
              // when the call connects — no need to push it here.
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _onTransferRequest(TransferRequestEvent event) {
    if (!mounted) return;

    // Notify in-app notification service
    for (final fileName in event.fileNames) {
      NotificationService.instance.notifyIncomingTransfer(fileName);
    }

    // Auto-accept if enabled
    if (HttpTransferService.instance.autoAcceptTransfers) {
      HttpTransferService.instance.acceptTransferRequest(event.requestId);
      return;
    }

    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person_pin,
                color: AppColors.primaryGreen, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Incoming Transfer',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${event.senderName} wants to send you:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...event.fileNames.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${e.value} (${_formatBytes(event.fileSizes[e.key])})',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HttpTransferService.instance
                  .rejectTransferRequest(event.requestId);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Reject',
                style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => const TransferQueueScreen(),
                ),
              );
            },
            child: const Text('View Transfers'),
          ),
          ElevatedButton(
            onPressed: () {
              HttpTransferService.instance
                  .acceptTransferRequest(event.requestId);
              Navigator.pop(dialogCtx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _onFileReceived(HttpTransferEvent event) {
    NotificationService.instance.notifyTransferCompleted(event.fileName);
    SoundService.instance.playTransferComplete();
    _showTransferSnackbar(
      'Received: ${event.fileName}',
      '${_formatBytes(event.fileSize)} received successfully',
    );
  }

  void _onFileSent(HttpTransferEvent event) {
    NotificationService.instance.notifyTransferCompleted(event.fileName);
    SoundService.instance.playTransferComplete();
    _showTransferSnackbar(
      'Sent: ${event.fileName}',
      '${_formatBytes(event.fileSize)} sent successfully',
    );
  }

  void _onTransferStarted(TransferStartedEvent event) {
    _showTransferSnackbar(
      'Transferring ${event.fileNames.length} file(s)',
      'Sending to ${event.receiverName}...',
    );
  }

  void _showTransferSnackbar(String title, String body) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            navigateToTransfersNotifier.value = true;
            Navigator.of(ctx).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }

  void _showMissingPermissionSnackbar() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Microphone or camera permission required for calls',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
        duration: Duration(seconds: 4),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return const HomeScreen();
  }
}
