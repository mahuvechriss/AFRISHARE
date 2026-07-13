import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import 'discovery_service.dart';
import 'http_transfer_service.dart';
import 'auth_service.dart';
import 'sound_service.dart';
import 'media_relay_service.dart';

enum CallState { idle, ringing, connecting, connected, ended }
enum CallDirection { incoming, outgoing }

class CallSession {
  final String callId;
  final String remoteId;
  final String remoteName;
  final CallDirection direction;
  final bool videoEnabled;
  RTCPeerConnection? pc;
  MediaStream? localStream;
  MediaStream? remoteStream;
  CallState state;
  DateTime startedAt;
  String? pendingOfferSdp;

  CallSession({
    required this.callId,
    required this.remoteId,
    required this.remoteName,
    required this.direction,
    this.videoEnabled = false,
    this.state = CallState.idle,
    DateTime? startedAt,
    this.pendingOfferSdp,
  }) : startedAt = startedAt ?? DateTime.now();
}

class CallService {
  CallService._();
  static final CallService instance = CallService._();

  final Uuid _uuid = const Uuid();

  CallSession? _currentCall;
  bool _speakerOn = false;
  /// Buffer ICE candidates that arrive before the PC is ready
  final List<Map<String, dynamic>> _pendingIceCandidates = [];

  void Function(CallSession call)? onIncomingCall;
  void Function(CallSession call)? onCallStateChanged;
  void Function(String callId)? onCallEnded;

  CallSession? get currentCall => _currentCall;
  bool get isInCall => _currentCall != null;
  bool get isSpeakerOn => _speakerOn;

  // ICE config — only a STUN server for host candidate gathering.
  // No TURN: that needs internet + uses your data bundle.
  //
  // KNOWN ISSUE: Some Android ROMs (Infinix/Transsion w/ libMEOW)
  // block P2P UDP between apps. ICE candidates ARE exchanged
  // (confirmed in logs) but UDP connectivity checks fail.
  // The real fix is to relay media through the local HTTP server
  // (port 47808) which uses TCP and works without internet.
  // This is planned — see the HTTP media relay implementation.
  static final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'iceTransportPolicy': 'all',
  };

  // PC constraints favouring low-latency over max quality
  static final Map<String, dynamic> _pcConstraints = {
    'sdpSemantics': 'unified-plan',
  };

  Future<void> initialize() async {
    await WebRTC.initialize();
  }

  Future<bool> _requestMediaPermissions(bool video) async {
    // Use permission_handler for proper OS-level permission requests
    // Do NOT call getUserMedia here — a test stream can lock audio hardware
    // on Android, preventing the real _getLocalStream() from working.
    final audioStatus = await Permission.microphone.request();
    if (!audioStatus.isGranted) {
      debugPrint('CallService: Microphone permission denied');
      return false;
    }

    if (video) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        debugPrint('CallService: Camera permission denied');
        return false;
      }
    }

    return true;
  }

  Future<MediaStream?> _getLocalStream(bool video) async {
    // flutter_webrtc on Android MediaConstraintsUtils warns
    // "mandatory constraints are not a map" for nested audio object
    // format — the plugin expects {audio: bool} or {"audio": {"mandatory": {...}, "optional": [...]}}.
    // Using simple {audio: true, video: ...} avoids the parse warning
    // and works reliably on all devices.
    try {
      return await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': true,
        'video': video
            ? <String, dynamic>{
                'facingMode': 'user',
                'width': 320,
                'height': 240,
                'frameRate': 20,
              }
            : false,
      });
    } catch (e) {
      debugPrint('CallService: getLocalStream error: $e');
      // Fallback: video-only or audio-only if full constraints fail
      try {
        return await navigator.mediaDevices.getUserMedia(<String, dynamic>{
          'audio': true,
          'video': video,
        });
      } catch (_) {
        return null;
      }
    }
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    return await createPeerConnection(_iceServers, _pcConstraints);
  }

  Future<void> startCall({
    required String remoteId,
    required String remoteName,
    bool video = false,
  }) async {
    if (isInCall) {
      debugPrint('CallService: Already in a call');
      return;
    }

    final device = DiscoveryService.instance.getDeviceByDeviceId(remoteId);
    if (device == null || device.ipAddress == null) {
      debugPrint('CallService: Remote device not found');
      return;
    }
    final remoteIp = device.ipAddress!;
    final remotePort = device.port ?? AppConstants.discoveryPort;

    if (!await _requestMediaPermissions(video)) return;

    final call = CallSession(
      callId: _uuid.v4(),
      remoteId: remoteId,
      remoteName: remoteName,
      direction: CallDirection.outgoing,
      videoEnabled: video,
      state: CallState.ringing,
    );
    _currentCall = call;
    onCallStateChanged?.call(call);

    // Play ringing sound while waiting for the other side to answer
    SoundService.instance.playRingtone();

    try {
      call.localStream = await _getLocalStream(video);
      call.pc = await _createPeerConnection();

      if (call.localStream != null) {
        for (final track in call.localStream!.getTracks()) {
          await call.pc!.addTrack(track, call.localStream!);
        }
      }

      call.pc!.onIceCandidate = (candidate) {
        // Skip localhost candidates (127.0.0.1, ::1) — they waste
        // negotiation time on loopback pairs that can never connect
        // to the remote device. Only host candidates on the real LAN
        // IP (e.g. 10.x, 192.168.x) and relay candidates are useful.
        final c = candidate.candidate ?? '';
        if (c.contains('127.0.0.1') || c.contains('::1')) return;
        _sendIceCandidate(call.callId, candidate.toMap(), remoteIp, remotePort);
      };

      call.pc!.onIceConnectionState = (state) {
        debugPrint('CallService: ICE state: $state');
        // Don't end call on ICE failure when HTTP relay is active.
        // The relay keeps video streaming even when P2P UDP is blocked.
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          if (!MediaRelayService.instance.isRunning) {
            endCall();
          } else {
            debugPrint('CallService: ICE failed but HTTP relay is active — keeping call');
          }
        }
      };

      call.pc!.onTrack = (event) {
        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          call.remoteStream = event.streams[0];
          call.state = CallState.connected;
          SoundService.instance.stop();
          // Enable speakerphone so audio plays through loudspeaker, not earpiece
          _speakerOn = true;
          try { Helper.setSpeakerphoneOn(true); } catch (_) {}
          onCallStateChanged?.call(call);
        }
      };

      final offer = await call.pc!.createOffer();
      await call.pc!.setLocalDescription(offer);

      await HttpTransferService.instance.sendCallOffer(
        host: remoteIp,
        port: remotePort,
        callId: call.callId,
        sdp: offer.toMap()['sdp'] as String,
        video: video,
        callerName: AuthService.instance.currentUser?.deviceName ?? 'Unknown',
      );

      // Apply any ICE candidates that arrived while we were setting up
      await _flushPendingIceCandidates();
    } catch (e) {
      debugPrint('CallService: startCall error: $e');
      endCall();
    }
  }

  Future<void> handleIncomingOffer({
    required String callId,
    required String sdp,
    required bool video,
    required String callerName,
    required String remoteId,
  }) async {
    final call = CallSession(
      callId: callId,
      remoteId: remoteId,
      remoteName: callerName,
      direction: CallDirection.incoming,
      videoEnabled: video,
      state: CallState.ringing,
      pendingOfferSdp: sdp,
    );
    _currentCall = call;
    // Play ringtone for incoming call
    SoundService.instance.playRingtone();
    onIncomingCall?.call(call);
  }

  Future<void> acceptCall() async {
    if (_currentCall == null || _currentCall!.state != CallState.ringing) {
      return;
    }

    if (!await _requestMediaPermissions(_currentCall!.videoEnabled)) return;

    final call = _currentCall!;
    // Stop ringing sound when accepting
    SoundService.instance.stop();

    call.state = CallState.connecting;
    onCallStateChanged?.call(call);

    final device = DiscoveryService.instance.getDeviceByDeviceId(call.remoteId);
    if (device == null || device.ipAddress == null) {
      debugPrint('CallService: Remote device not found for answer');
      return;
    }
    final remoteIp = device.ipAddress!;
    final remotePort = device.port ?? AppConstants.discoveryPort;

    try {
      call.localStream = await _getLocalStream(call.videoEnabled);
      call.pc = await _createPeerConnection();

      if (call.localStream != null) {
        for (final track in call.localStream!.getTracks()) {
          await call.pc!.addTrack(track, call.localStream!);
        }
      }

      call.pc!.onIceCandidate = (candidate) {
        // Skip localhost candidates (127.0.0.1, ::1) — they waste
        // negotiation time on loopback pairs that can never connect
        // to the remote device.
        final c = candidate.candidate ?? '';
        if (c.contains('127.0.0.1') || c.contains('::1')) return;
        _sendIceCandidate(call.callId, candidate.toMap(), remoteIp, remotePort);
      };

      call.pc!.onIceConnectionState = (state) {
        debugPrint('CallService: ICE state: $state');
        // Don't end call on ICE failure when HTTP relay is active.
        // The relay keeps video streaming even when P2P UDP is blocked.
        if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          if (!MediaRelayService.instance.isRunning) {
            endCall();
          } else {
            debugPrint('CallService: ICE failed but HTTP relay is active — keeping call');
          }
        }
      };

      call.pc!.onTrack = (event) {
        if (event.track.kind == 'video' || event.track.kind == 'audio') {
          call.remoteStream = event.streams[0];
          call.state = CallState.connected;
          SoundService.instance.stop();
          // Enable speakerphone so audio plays through loudspeaker, not earpiece
          _speakerOn = true;
          try { Helper.setSpeakerphoneOn(true); } catch (_) {}
          onCallStateChanged?.call(call);
        }
      };

      final offerSdp = call.pendingOfferSdp;
      if (offerSdp == null || offerSdp.isEmpty) {
        debugPrint('CallService: No pending offer SDP');
        endCall();
        return;
      }
      await call.pc!.setRemoteDescription(
        RTCSessionDescription(offerSdp, 'offer'),
      );

      final answer = await call.pc!.createAnswer();
      await call.pc!.setLocalDescription(answer);

      await HttpTransferService.instance.sendCallAnswer(
        host: remoteIp,
        port: remotePort,
        callId: call.callId,
        sdp: answer.toMap()['sdp'] as String,
      );
      debugPrint('CallService: Answer sent, flushing pending ICE candidates...');

      // Apply any ICE candidates that arrived while we were setting up
      await _flushPendingIceCandidates();
      debugPrint('CallService: acceptCall() setup complete');
    } catch (e) {
      debugPrint('CallService: acceptCall error: $e');
      endCall();
    }
  }

  Future<void> rejectCall() async {
    if (_currentCall == null) return;
    // Stop ringing sound when rejecting
    SoundService.instance.stop();
    _currentCall!.state = CallState.ended;
    onCallEnded?.call(_currentCall!.callId);
    _cleanup();
  }

  Future<void> endCall() async {
    if (_currentCall == null) return;
    // Stop ringing sound when call ends
    SoundService.instance.stop();

    // Notify the remote device that the call ended
    final call = _currentCall!;
    await _sendCallEnd(call);

    call.state = CallState.ended;
    onCallStateChanged?.call(call);
    onCallEnded?.call(call.callId);
    _cleanup();
  }

  Future<void> _sendCallEnd(CallSession call) async {
    final device = DiscoveryService.instance.getDeviceByDeviceId(call.remoteId);
    if (device == null || device.ipAddress == null) return;
    try {
      await HttpTransferService.instance.sendCallEnd(
        host: device.ipAddress!,
        port: device.port ?? AppConstants.discoveryPort,
        callId: call.callId,
      );
    } catch (e) {
      debugPrint('CallService: sendCallEnd error: $e');
    }
  }

  /// Handle a hangup signal from the remote device
  Future<void> handleRemoteHangup() async {
    if (_currentCall == null) return;
    debugPrint('CallService: Remote device hung up');
    SoundService.instance.stop();
    _currentCall!.state = CallState.ended;
    onCallStateChanged?.call(_currentCall!);
    onCallEnded?.call(_currentCall!.callId);
    _cleanup();
  }

  Future<void> _sendIceCandidate(
    String callId,
    Map<String, dynamic> candidate,
    String host,
    int port,
  ) async {
    final sdp = candidate['candidate'] as String? ?? '';
    debugPrint('CallService: Sending ICE candidate to $host:$port (${sdp.length > 80 ? '${sdp.substring(0, 80)}...' : sdp})');
    try {
      final ok = await HttpTransferService.instance.sendIceCandidate(
        host: host,
        port: port,
        callId: callId,
        candidate: jsonEncode(candidate),
      );
      debugPrint('CallService: ICE candidate send ${ok ? "OK" : "FAILED"}');
    } catch (e) {
      debugPrint('CallService: Error sending ICE candidate: $e');
    }
  }

  Future<void> handleRemoteSdp(String sdp) async {
    if (_currentCall?.pc == null) return;
    try {
      final desc = RTCSessionDescription(sdp, 'offer');
      await _currentCall!.pc!.setRemoteDescription(desc);
    } catch (e) {
      debugPrint('CallService: handleRemoteSdp error: $e');
    }
  }

  Future<void> handleRemoteAnswer(String sdp) async {
    if (_currentCall?.pc == null) return;
    try {
      final desc = RTCSessionDescription(sdp, 'answer');
      await _currentCall!.pc!.setRemoteDescription(desc);
    } catch (e) {
      debugPrint('CallService: handleRemoteAnswer error: $e');
    }
  }

  Future<void> handleIceCandidate(Map<String, dynamic> candidate) async {
    if (_currentCall?.pc == null) {
      // PC not ready yet — buffer the candidate for later
      _pendingIceCandidates.add(candidate);
      debugPrint('CallService: Buffered ICE candidate (PC not ready)');
      return;
    }
    final sdp = candidate['candidate'] as String? ?? '';
    final mid = candidate['sdpMid'] as String? ?? '';
    final mline = candidate['sdpMLineIndex'] as int? ?? 0;
    debugPrint('CallService: Adding remote ICE candidate (${sdp.length > 80 ? '${sdp.substring(0, 80)}...' : sdp})');
    try {
      await _currentCall!.pc!.addCandidate(
        RTCIceCandidate(sdp, mid, mline),
      );
      debugPrint('CallService: Remote ICE candidate added successfully');
    } catch (e) {
      debugPrint('CallService: handleIceCandidate error: $e');
    }
  }

  /// Apply any buffered ICE candidates after PC + remote description are set
  Future<void> _flushPendingIceCandidates() async {
    if (_currentCall?.pc == null) return;
    final pending = List<Map<String, dynamic>>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    for (final candidate in pending) {
      try {
        await _currentCall!.pc!.addCandidate(
          RTCIceCandidate(candidate['candidate'], candidate['sdpMid'], candidate['sdpMLineIndex']),
        );
      } catch (e) {
        debugPrint('CallService: flushCandidate error: $e');
      }
    }
    debugPrint('CallService: Flushed ${pending.length} buffered ICE candidates');
  }

  void toggleMute() {
    _currentCall?.localStream?.getAudioTracks().forEach((track) {
      track.enabled = !track.enabled;
    });
  }

  void toggleSpeaker() {
    try {
      _speakerOn = !_speakerOn;
      Helper.setSpeakerphoneOn(_speakerOn);
    } catch (e) {
      debugPrint('CallService: toggleSpeaker error: $e');
    }
  }

  Future<void> switchCamera() async {
    if (_currentCall?.localStream == null) return;
    try {
      await Helper.switchCamera(_currentCall!.localStream!.getVideoTracks().first);
    } catch (e) {
      debugPrint('CallService: switchCamera error: $e');
    }
  }

  /// Remote device address for the media relay (CallScreen needs this
  /// to start the HTTP-based video relay)
  String? get remoteRelayIp {
    final call = _currentCall;
    if (call == null) return null;
    final device = DiscoveryService.instance.getDeviceByDeviceId(call.remoteId);
    return device?.ipAddress;
  }

  int get remoteRelayPort => AppConstants.discoveryPort;

  void _cleanup() {
    _speakerOn = false;
    _pendingIceCandidates.clear();
    MediaRelayService.instance.stopRelay();
    _currentCall?.pc?.close();
    _currentCall?.localStream?.getTracks().forEach((t) => t.stop());
    _currentCall?.localStream?.dispose();
    _currentCall?.remoteStream?.dispose();
    _currentCall = null;
  }

  void dispose() {
    if (isInCall) {
      _cleanup();
    }
  }
}
