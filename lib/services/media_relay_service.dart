import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/constants/app_constants.dart';

/// HTTP-based media relay for calls — works 100% offline, no internet.
///
/// **Video**: Captures local frames from a [RepaintBoundary] (hidden
/// renderer so the visible PiP is not glitched) and sends as PNG via HTTP.
///
/// **Audio**: Captures microphone via [AudioRecorder] and sends raw PCM
/// chunks via HTTP. On the receiver side, chunks are wrapped in WAV headers
/// and played via [AudioPlayer].
///
/// Bypasses the UDP block on Infinix/Transsion devices (libMEOW).
class MediaRelayService {
  MediaRelayService._();
  static final MediaRelayService instance = MediaRelayService._();

  // ---------------------------------------------------------------------------
  // Video relay
  // ---------------------------------------------------------------------------

  /// The latest video frame received from the remote device (PNG bytes)
  Uint8List? _latestRemoteFrame;
  Uint8List? get latestRemoteFrame => _latestRemoteFrame;

  final _frameController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get onFrameReceived => _frameController.stream;

  /// The latest LOCAL captured frame (PNG bytes) — used for the visible PiP
  /// so both local and remote video are regular Flutter Image.memory widgets,
  /// avoiding Android platform view Z-order issues with RTCVideoView.
  Uint8List? _latestLocalFrame;
  Uint8List? get latestLocalFrame => _latestLocalFrame;

  final _localFrameController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get onLocalFrameCaptured => _localFrameController.stream;

  Timer? _videoSendTimer;
  GlobalKey? _captureKey;

  // ---------------------------------------------------------------------------
  // Audio relay
  // ---------------------------------------------------------------------------

  AudioRecorder? _audioRecorder;
  StreamSubscription<Uint8List>? _audioDataSub;
  bool _isAudioSending = false;

  /// Received audio chunks buffered for playback
  final List<Uint8List> _audioPlaybackQueue = [];
  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;

  /// Sequential audio sender — prevents overwhelming the remote HTTP server
  /// with concurrent POST requests (which was causing one-way audio on
  /// slower devices). Chunks are queued and sent one at a time.
  final List<Uint8List> _pendingAudioSendQueue = [];
  bool _isSendingAudioChunk = false;

  /// Buffer at least ~3 seconds of audio before starting playback so short
  /// clip chaining doesn't break (onPlayerComplete fires unreliably for <1s).
  /// Byte rate = 16000 samples/sec × 2 bytes/sample = 32000 bytes/sec.
  static const int _audioBufferTarget = 32000 * 3; // 3 seconds = 96000 bytes

  /// Watchdog timer: if no playback event arrives within 2 seconds after
  /// starting, assume the chain broke and restart playback.
  Timer? _playbackWatchdog;

  final _audioFrameController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get onAudioReceived => _audioFrameController.stream;

  // ---------------------------------------------------------------------------
  // Common state
  // ---------------------------------------------------------------------------

  String? _remoteIp;
  int _remotePort = AppConstants.discoveryPort;
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // ---------------------------------------------------------------------------
  // Start / Stop all
  // ---------------------------------------------------------------------------

  /// Start both video and audio relay.
  void startRelay({
    required GlobalKey captureKey,
    required String remoteIp,
    int remotePort = AppConstants.discoveryPort,
  }) {
    if (_isRunning) return;
    _isRunning = true;
    _captureKey = captureKey;
    _remoteIp = remoteIp;
    _remotePort = remotePort;
    _latestRemoteFrame = null;
    _latestLocalFrame = null;

    debugPrint('MediaRelay: Started relay to $remoteIp:$remotePort');
    _scheduleNextFrame();
    _startAudioCapture();
  }

  /// Stop both video and audio relay.
  void stopRelay() {
    _isRunning = false;
    _videoSendTimer?.cancel();
    _videoSendTimer = null;
    _captureKey = null;
    _latestRemoteFrame = null;
    _latestLocalFrame = null;
    _stopAudioCapture();
    _disposeAudioPlayer();
    debugPrint('MediaRelay: Stopped');
  }

  // ---------------------------------------------------------------------------
  // Video capture and send
  // ---------------------------------------------------------------------------

  void _scheduleNextFrame() {
    _videoSendTimer?.cancel();
    _videoSendTimer = Timer(const Duration(milliseconds: 200), () async {
      if (!_isRunning) return;
      await _sendVideoFrame();
      if (_isRunning) _scheduleNextFrame();
    });
  }

  Future<void> _sendVideoFrame() async {
    if (!_isRunning) return;
    final ip = _remoteIp;
    final key = _captureKey;
    if (ip == null || key == null) return;

    try {
      final boundary = key.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      if (byteData == null) return;

      final frame = byteData.buffer.asUint8List();
      if (frame.isEmpty) return;

      // Save as latest local frame for the visible PiP (Image.memory)
      _latestLocalFrame = frame;
      if (!_localFrameController.isClosed) {
        _localFrameController.add(frame);
      }

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      try {
        final request = await client.postUrl(
          Uri.parse('http://$ip:$_remotePort/call-video'),
        );
        request.headers.contentType = ContentType('image', 'png');
        request.headers.set('content-length', frame.length.toString());
        request.add(frame);
        await request.close();
      } finally {
        client.close();
      }
    } catch (e) {
      // Silently skip failed frames
    }
  }

  /// Process a received video frame from the remote device.
  void receiveVideoFrame(Uint8List frameData) {
    _latestRemoteFrame = frameData;
    if (!_frameController.isClosed) {
      _frameController.add(frameData);
    }
  }

  // ---------------------------------------------------------------------------
  // Audio capture and send
  // ---------------------------------------------------------------------------

  Future<void> _startAudioCapture() async {
    if (_isAudioSending) return;
    try {
      _audioRecorder = AudioRecorder();
      final hasPermission = await _audioRecorder!.hasPermission();
      if (!hasPermission) {
        debugPrint('MediaRelay: Audio recording permission not granted');
        return;
      }

      final stream = await _audioRecorder!.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          numChannels: 1,
          sampleRate: 16000,
          // Disable noise suppression & auto-gain: on budget Infinix/Transsion
          // devices these can introduce audible crackling artifacts.
          autoGain: false,
          noiseSuppress: false,
        ),
      );

      _isAudioSending = true;
      debugPrint('MediaRelay: Audio capture started (16kHz 16-bit PCM mono)');

      // Accumulate PCM data and send in 500ms chunks.
      // At 16kHz, 16-bit, mono: 32000 bytes/sec, so 500ms = 16000 bytes.
      final chunkAccumulator = <int>[];
      const chunkTargetSize = 16000; // 500ms of audio at 32000 bytes/sec

      _audioDataSub = stream.listen(
        (data) {
          if (!_isRunning) return;
          chunkAccumulator.addAll(data);

          if (chunkAccumulator.length >= chunkTargetSize) {
            final chunk = Uint8List.fromList(chunkAccumulator.take(chunkTargetSize).toList());
            chunkAccumulator.removeRange(0, chunkTargetSize);
            _pendingAudioSendQueue.add(chunk);
            _processNextAudioSend();
          }
        },
        onError: (e) {
          debugPrint('MediaRelay: Audio stream error: $e');
        },
        onDone: () {
          debugPrint('MediaRelay: Audio stream ended');
          // Send any remaining data
          if (chunkAccumulator.isNotEmpty) {
            _pendingAudioSendQueue.add(Uint8List.fromList(chunkAccumulator));
            chunkAccumulator.clear();
            _processNextAudioSend();
          }
        },
      );
    } catch (e) {
      debugPrint('MediaRelay: Failed to start audio capture: $e');
    }
  }

  Future<void> _sendAudioChunk(Uint8List pcmData) async {
    if (!_isRunning) return;
    final ip = _remoteIp;
    if (ip == null) return;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      try {
        final request = await client.postUrl(
          Uri.parse('http://$ip:$_remotePort/call-audio'),
        );
        request.headers.contentType = ContentType('audio', 'L16');
        request.headers.set('x-sample-rate', '16000');
        request.headers.set('x-sample-format', 's16le');
        request.headers.set('content-length', pcmData.length.toString());
        request.add(pcmData);
        await request.close();
      } finally {
        client.close();
      }
    } catch (e) {
      // Silently skip failed audio chunks
    }
  }

  /// Process the next audio chunk from the pending send queue.
  /// Ensures chunks are sent sequentially (one at a time) to prevent
  /// overwhelming the remote HTTP server with concurrent POSTs.
  Future<void> _processNextAudioSend() async {
    if (_isSendingAudioChunk || _pendingAudioSendQueue.isEmpty) return;
    _isSendingAudioChunk = true;
    final chunk = _pendingAudioSendQueue.removeAt(0);
    await _sendAudioChunk(chunk);
    _isSendingAudioChunk = false;
    if (_pendingAudioSendQueue.isNotEmpty) {
      _processNextAudioSend();
    }
  }

  void _stopAudioCapture() {
    _isAudioSending = false;
    _audioDataSub?.cancel();
    _audioDataSub = null;
    _pendingAudioSendQueue.clear();
    _isSendingAudioChunk = false;
    try {
      _audioRecorder?.stop();
    } catch (_) {}
    _audioRecorder?.dispose();
    _audioRecorder = null;
  }

  // ---------------------------------------------------------------------------
  // Audio receive and playback
  // ---------------------------------------------------------------------------

  /// Process a received audio chunk from the remote device.
  void receiveAudioChunk(Uint8List pcmData) {
    if (!_isRunning) return;

    // Wrap raw PCM in a WAV header for audioplayers
    final wavBytes = _wrapPcmInWav(pcmData, 16000, 1);
    _audioPlaybackQueue.add(wavBytes);

    if (!_audioFrameController.isClosed) {
      _audioFrameController.add(pcmData);
    }

    // Buffer at least ~3 seconds of audio before starting playback.
    // This avoids the fragile onPlayerComplete chaining for very short clips.
    if (!_isAudioPlaying) {
      // Check total buffered PCM size (not WAV size, since WAV adds 44 bytes)
      int totalPcm = _audioPlaybackQueue.fold<int>(0, (sum, wav) => sum + (wav.length - 44));
      if (totalPcm >= _audioBufferTarget) {
        _playNextAudio();
      }
    }
  }

  /// Wrap raw PCM data in a proper WAV file header, with fade-in/fade-out
  /// applied to eliminate boundary clicks/pops between consecutive chunks.
  Uint8List _wrapPcmInWav(Uint8List pcmData, int sampleRate, int numChannels) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);

    // Ensure PCM data is sample-aligned (even number of bytes for 16-bit)
    int dataSize = pcmData.length;
    if (dataSize % 2 != 0) {
      dataSize -= 1; // drop trailing byte to keep alignment
    }

    // Create a copy so we can apply fades without mutating the original
    final pcmCopy = Uint8List(dataSize);
    pcmCopy.setRange(0, dataSize, pcmData.take(dataSize));

    // Apply crossfade: ~10ms fade-in at start, ~10ms fade-out at end
    // 10ms at 16kHz = 160 samples = 320 bytes (16-bit stereo... but mono)
    const fadeSamples = 160; // ~10ms
    final fadeBytes = fadeSamples * 2; // 2 bytes per 16-bit sample

    if (dataSize >= fadeBytes * 2) {
      // Fade-in: ramp samples from 0.0 to 1.0
      for (int i = 0; i < fadeBytes; i += 2) {
        int raw = (pcmCopy[i + 1] << 8) | pcmCopy[i];
        int sample = raw >= 32768 ? raw - 65536 : raw; // sign-extend
        final factor = i / fadeBytes; // 0.0 → 1.0
        final faded = (sample * factor).round().clamp(-32768, 32767);
        pcmCopy[i] = faded & 0xFF;
        pcmCopy[i + 1] = (faded >> 8) & 0xFF;
      }

      // Fade-out: ramp samples from 1.0 to 0.0
      final fadeStart = dataSize - fadeBytes;
      for (int i = 0; i < fadeBytes; i += 2) {
        final idx = fadeStart + i;
        int raw = (pcmCopy[idx + 1] << 8) | pcmCopy[idx];
        int sample = raw >= 32768 ? raw - 65536 : raw; // sign-extend
        final factor = 1.0 - (i / fadeBytes); // 1.0 → 0.0
        final faded = (sample * factor).round().clamp(-32768, 32767);
        pcmCopy[idx] = faded & 0xFF;
        pcmCopy[idx + 1] = (faded >> 8) & 0xFF;
      }
    }

    // Build WAV header
    final header = ByteData(44);
    // RIFF
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, 36 + dataSize, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E
    // fmt
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // 
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);          // PCM
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final wav = Uint8List(44 + dataSize);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + dataSize, pcmCopy);
    return wav;
  }

  /// Play the next audio chunk from the queue.
  Future<void> _playNextAudio() async {
    if (_audioPlaybackQueue.isEmpty || !_isRunning) {
      _isAudioPlaying = false;
      return;
    }

    _isAudioPlaying = true;
    final wavBytes = _audioPlaybackQueue.removeAt(0);

    try {
      if (_audioPlayer == null) {
        _audioPlayer = AudioPlayer();
        _audioPlayer!.onPlayerComplete.listen((_) {
          _scheduleNextAudio();
        });
      }

      // setSourceBytes + seek(0) + resume is the correct API for 6.x.
      // Do NOT call stop() — it can interfere with the next playback
      // and cause onPlayerComplete to not fire for short clips.
      // Set volume to 1.0 to ensure the audio player doesn't apply its
      // own gain which could introduce artifacts on budget devices.
      await _audioPlayer!.setVolume(1.0);
      await _audioPlayer!.setSourceBytes(wavBytes);
      await _audioPlayer!.seek(Duration.zero);
      await _audioPlayer!.resume();

      // Start watchdog: if no next audio plays within 2.5s, assume
      // onPlayerComplete was missed and force the next chunk.
      _playbackWatchdog?.cancel();
      _playbackWatchdog = Timer(const Duration(milliseconds: 2500), () {
        if (_isRunning && _audioPlaybackQueue.isNotEmpty) {
          debugPrint('MediaRelay: Audio watchdog fired — chaining next chunk');
          _scheduleNextAudio();
        }
      });
    } catch (e) {
      debugPrint('MediaRelay: Audio playback start error: $e');
      // Try next chunk immediately on error
      _scheduleNextAudio();
    }
  }

  /// Schedules the next audio chunk to play. Uses a microtask delay to
  /// prevent stack overflows from rapid chaining.
  void _scheduleNextAudio() {
    Future.microtask(() {
      if (_isRunning) {
        _playNextAudio();
      }
    });
  }

  void _disposeAudioPlayer() {
    _isAudioPlaying = false;
    _audioPlaybackQueue.clear();
    _playbackWatchdog?.cancel();
    _playbackWatchdog = null;
    try {
      _audioPlayer?.stop();
    } catch (_) {}
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void dispose() {
    stopRelay();
    _frameController.close();
    _localFrameController.close();
    _audioFrameController.close();
  }
}
