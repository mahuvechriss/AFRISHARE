import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../core/database/database_helper.dart';

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  AudioPlayer? _player;
  bool _initialized = false;

  static const _notifKey = 'notification_sound';
  static const _transferKey = 'transfer_sound';
  static const _ringtoneKey = 'ringtone_sound';

  String _notificationSound = 'notification.wav';
  String _transferSound = 'transfer_complete.wav';
  String _ringtoneSound = 'notification_chime.wav';

  static const List<Map<String, String>> notificationOptions = [
    {'value': 'notification.wav', 'label': 'Default Chime'},
    {'value': 'notification_alt.wav', 'label': 'Soft Tone'},
    {'value': 'notification_chime.wav', 'label': 'Two-Tone'},
  ];

  static const List<Map<String, String>> transferOptions = [
    {'value': 'transfer_complete.wav', 'label': 'Default Ding'},
    {'value': 'transfer_alt.wav', 'label': 'Deep Tone'},
    {'value': 'transfer_ascend.wav', 'label': 'Chriss'},
  ];

  static const List<Map<String, String>> ringtoneOptions = [
    {'value': 'notification_chime.wav', 'label': 'Two-Tone Ring'},
    {'value': 'notification_alt.wav', 'label': 'Soft Ring'},
    {'value': 'notification.wav', 'label': 'Single Chime'},
  ];

  String get notificationSound => _notificationSound;
  String get transferSound => _transferSound;
  String get ringtoneSound => _ringtoneSound;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _player = AudioPlayer();
      final db = DatabaseHelper.instance;
      final savedNotif = await db.getSetting(_notifKey);
      final savedTransfer = await db.getSetting(_transferKey);
      final savedRingtone = await db.getSetting(_ringtoneKey);
      if (savedNotif != null &&
          notificationOptions.any((o) => o['value'] == savedNotif)) {
        _notificationSound = savedNotif;
      }
      if (savedTransfer != null &&
          transferOptions.any((o) => o['value'] == savedTransfer)) {
        _transferSound = savedTransfer;
      }
      if (savedRingtone != null &&
          ringtoneOptions.any((o) => o['value'] == savedRingtone)) {
        _ringtoneSound = savedRingtone;
      }
      _initialized = true;
    } catch (e) {
      debugPrint('SoundService: init error: $e');
    }
  }

  Future<void> setNotificationSound(String name) async {
    _notificationSound = name;
    try {
      await DatabaseHelper.instance.setSetting(_notifKey, name);
    } catch (e) {
      debugPrint('SoundService: save notification_sound error: $e');
    }
  }

  Future<void> setTransferSound(String name) async {
    _transferSound = name;
    try {
      await DatabaseHelper.instance.setSetting(_transferKey, name);
    } catch (e) {
      debugPrint('SoundService: save transfer_sound error: $e');
    }
  }

  Future<void> setRingtoneSound(String name) async {
    _ringtoneSound = name;
    try {
      await DatabaseHelper.instance.setSetting(_ringtoneKey, name);
    } catch (e) {
      debugPrint('SoundService: save ringtone_sound error: $e');
    }
  }

  /// Play a notification chime (non-looping)
  Future<void> playNotification() async {
    await _play('sounds/$_notificationSound');
  }

  Future<void> playTransferComplete() async {
    await _play('sounds/$_transferSound');
  }

  Future<void> playSound(String soundName) async {
    await _play('sounds/$soundName');
  }

  /// Play the call ringtone in a loop
  Future<void> playRingtone() async {
    await initialize();
    if (_player == null) return;
    try {
      await _player!.stop();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.play(AssetSource('sounds/$_ringtoneSound'));
    } catch (e) {
      debugPrint('SoundService: playRingtone error: $e');
    }
  }

  /// Stop any currently playing sound (e.g. ringtone)
  Future<void> stop() async {
    if (_player == null) return;
    try {
      await _player!.stop();
      await _player!.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      debugPrint('SoundService: stop error: $e');
    }
  }

  Future<void> _play(String source) async {
    await initialize();
    if (_player == null) return;
    try {
      await _player!.stop();
      await _player!.setReleaseMode(ReleaseMode.release);
      await _player!.play(AssetSource(source));
    } catch (e) {
      debugPrint('SoundService: play error ($source): $e');
    }
  }

  void dispose() {
    _player?.dispose();
    _player = null;
    _initialized = false;
  }
}
