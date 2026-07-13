import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/theme/app_colors.dart';
import '../../services/call_service.dart';
import '../../services/media_relay_service.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen>
    with WidgetsBindingObserver {
  final CallService _callService = CallService.instance;
  final MediaRelayService _relay = MediaRelayService.instance;
  Timer? _durationTimer;
  Duration _callDuration = Duration.zero;
  bool _muted = false;

  // ----- PiP (local video) -----
  // The RTCVideoView (platform view) is shown via an OverlayEntry so it
  // renders above all Flutter widgets in the main tree.  The overlay stays
  // transparent — the contrast against the bright remote video is provided
  // by a dark semi-transparent spot in the main tree behind the PiP.
  RTCVideoRenderer? _localRenderer;
  final GlobalKey _captureKey = GlobalKey();
  OverlayEntry? _pipOverlay;

  // ----- Remote video frame -----
  Uint8List? _remoteFrame;
  StreamSubscription<Uint8List>? _frameSub;

  // ----- PiP drag state -----
  double _pipDx = 16;
  double _pipDy = 16;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initRenderer();
    if (_callService.currentCall?.state == CallState.connected) {
      _startDurationTimer();
    }
    _frameSub = _relay.onFrameReceived.listen((frame) {
      if (mounted) setState(() => _remoteFrame = frame);
    });
    // Sync latest remote frame
    if (_relay.latestRemoteFrame != null) {
      _remoteFrame = _relay.latestRemoteFrame;
    }
  }

  Future<void> _initRenderer() async {
    final call = _callService.currentCall;
    if (call == null || call.localStream == null) return;
    try {
      if (_localRenderer == null) {
        _localRenderer = RTCVideoRenderer();
        await _localRenderer!.initialize();
        _localRenderer!.srcObject = call.localStream;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('CallScreen: _initRenderer error: $e');
    }
  }

  void _startRelay() {
    final call = _callService.currentCall;
    if (call == null) return;
    final ip = _callService.remoteRelayIp;
    if (ip == null) return;
    _relay.startRelay(
      captureKey: _captureKey,
      remoteIp: ip,
      remotePort: _callService.remoteRelayPort,
    );
    debugPrint('CallScreen: Media relay started to $ip');
  }

  /// Show the PiP RTCVideoView in an Overlay so it renders ABOVE
  /// the remote Image.memory (avoids Android platform-view Z-ordering).
  /// The overlay container has NO background — the platform view (TextureView)
  /// renders through the transparent overlay while a dark spot in the main
  /// widget tree (see build → Stack → Positioned dark spot) provides the
  /// contrast needed against the bright remote video.
  void _showPipOverlay() {
    _pipOverlay?.remove();
    _pipOverlay = OverlayEntry(
      builder: (context) {
        final renderer = _localRenderer;
        if (renderer == null) return const SizedBox.shrink();
        return Positioned(
          top: _pipDy,
          right: _pipDx,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _pipDx = (_pipDx - details.delta.dx)
                    .clamp(0, MediaQuery.of(context).size.width - 130);
                _pipDy = (_pipDy + details.delta.dy)
                    .clamp(0, MediaQuery.of(context).size.height - 200);
              });
              // Rebuild overlay in-place without remove+reinsert
              _pipOverlay?.markNeedsBuild();
            },
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24, width: 2),
                // NO color/background here — an opaque Flutter background
                // would cover the platform view on some Android versions.
                // Contrast is provided by the dark spot in the main tree.
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: RepaintBoundary(
                  key: _captureKey,
                  child: RTCVideoView(
                    renderer,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context, rootOverlay: true).insert(_pipOverlay!);
  }

  void _removePipOverlay() {
    _pipOverlay?.remove();
    _pipOverlay = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    _frameSub?.cancel();
    _removePipOverlay();
    _localRenderer?.dispose();
    _localRenderer = null;
    super.dispose();
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_callService.currentCall != null) {
        setState(() {
          _callDuration = DateTime.now()
              .difference(_callService.currentCall!.startedAt);
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours}:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final call = _callService.currentCall;

    // Lazy-init renderer when call connects
    if (call != null &&
        call.state == CallState.connected &&
        call.localStream != null &&
        _localRenderer == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initRenderer());
    }

    // Lazy-start relay + show PiP overlay when renderer is ready
    if (call != null &&
        call.state == CallState.connected &&
        _localRenderer != null &&
        !_relay.isRunning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Insert overlay FIRST so the RepaintBoundary capture key is in the
        // tree before _startRelay() begins capturing frames (every 200ms).
        _showPipOverlay();
        _startRelay();
      });
    }

    if (call == null) {
      _removePipOverlay();
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text('Call ended', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final isConnected = call.state == CallState.connected;
    final isRinging = call.state == CallState.ringing;
    final isIncoming = call.direction == CallDirection.incoming;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Remote video area
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Remote video from HTTP relay — regular Flutter Image.memory
                  if (isConnected && _remoteFrame != null)
                    Image.memory(
                      _remoteFrame!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      gaplessPlayback: true,
                    )
                  else
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: AppColors.primaryGreenSurface,
                            child: Text(
                              call.remoteName[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 40,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            call.remoteName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isRinging
                                ? (isIncoming ? 'Incoming call...' : 'Ringing...')
                                : (isConnected
                                    ? _formatDuration(_callDuration)
                                    : 'Connecting...'),
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Dark spot behind the PiP ──
                  // Darkens the bright remote video area behind the PiP so
                  // the local video has proper contrast. Pure Flutter widget
                  // in the main tree (not the overlay) so it renders
                  // correctly on all Android versions.
                  if (isConnected && _remoteFrame != null)
                    Positioned(
                      top: _pipDy,
                      right: _pipDx,
                      child: Container(
                        width: 120,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Controls
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  if (isConnected) ...[
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (isRinging && isIncoming)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ControlButton(
                          icon: Icons.call_end,
                          color: AppColors.error,
                          label: 'Decline',
                          onTap: () {
                            _callService.rejectCall();
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(width: 48),
                        _ControlButton(
                          icon: Icons.call,
                          color: AppColors.success,
                          label: 'Accept',
                          onTap: () {
                            _callService.acceptCall();
                            setState(() {});
                            _startDurationTimer();
                          },
                        ),
                      ],
                    ),
                  if (isConnected || (!isIncoming && isRinging)) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ControlButton(
                          icon: _muted ? Icons.mic_off : Icons.mic,
                          color: _muted ? AppColors.warning : Colors.white38,
                          label: _muted ? 'Unmute' : 'Mute',
                          onTap: () {
                            setState(() => _muted = !_muted);
                            _callService.toggleMute();
                          },
                        ),
                        _ControlButton(
                          icon: call.videoEnabled
                              ? Icons.videocam
                              : Icons.videocam_off,
                          color: Colors.white38,
                          label: call.videoEnabled ? 'Video' : 'No Video',
                          onTap: call.videoEnabled
                              ? () => _callService.switchCamera()
                              : null,
                        ),
                        _ControlButton(
                          icon: _callService.isSpeakerOn
                              ? Icons.volume_up
                              : Icons.volume_down,
                          color: _callService.isSpeakerOn
                              ? AppColors.primaryGreen
                              : Colors.white38,
                          label: _callService.isSpeakerOn
                              ? 'Speaker'
                              : 'Earpiece',
                          onTap: () {
                            _callService.toggleSpeaker();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _ControlButton(
                      icon: Icons.call_end,
                      color: AppColors.error,
                      label: 'End Call',
                      size: 56,
                      onTap: () {
                        _removePipOverlay();
                        _callService.endCall();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double size;
  final VoidCallback? onTap;

  const _ControlButton({
    required this.icon,
    required this.color,
    required this.label,
    this.size = 48,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.3),
            ),
            child: Icon(icon, color: color, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
