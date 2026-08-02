import "dart:async";
import "dart:io";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:audioplayers/audioplayers.dart";
import "package:path_provider/path_provider.dart";

/// خدمة الصوت المتخصصة للمكالمات
class CallAudioService {
  static final CallAudioService _instance = CallAudioService._internal();
  factory CallAudioService() => _instance;
  CallAudioService._internal();

  MethodChannel? _methodChannel;
  AudioPlayer? _player;
  bool _isInitialized = false;
  String? _currentRingtonePath;

  // تهيئة الخدمة
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (Platform.isWindows || Platform.isLinux) {
      _initializeFallback();
      return;
    }

    _methodChannel = const MethodChannel("call_audio_service");

    try {
      await _methodChannel?.invokeMethod("initialize");
      _isInitialized = true;
      debugPrint("CallAudioService initialized successfully");
    } catch (e) {
      debugPrint("Failed to initialize CallAudioService: $e");
      // استخدام الطريقة الاحتياطية
      _initializeFallback();
    }
  }

  void _initializeFallback() {
    _player = AudioPlayer();
    _isInitialized = true;
  }

  Future<String?> _resolveRingtonePath(String? customPath) async {
    if (customPath != null) return customPath;
    if (_currentRingtonePath != null) return _currentRingtonePath;
    _currentRingtonePath = await _getDefaultRingtonePath();
    return _currentRingtonePath;
  }

  Future<void> _playWithPlayer(String? path, {bool loop = false}) async {
    _player ??= AudioPlayer();
    await _player?.stop();
    await _player?.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    if (path != null && await File(path).exists()) {
      await _player?.play(DeviceFileSource(path));
    } else {
      await _player?.play(AssetSource('sounds/ringtone.wav'));
    }
  }

  Future<void> _stopPlayer() async {
    await _player?.stop();
  }

  Future<void> playRingtone({String? customPath, double volume = 0.8}) async {
    if (!_isInitialized) await initialize();

    _currentRingtonePath = await _resolveRingtonePath(customPath);

    if (Platform.isWindows || Platform.isLinux) {
      await _playWithPlayer(_currentRingtonePath, loop: true);
      return;
    }

    try {
      await _methodChannel?.invokeMethod("playRingtone", {
        "path": _currentRingtonePath,
        "volume": volume,
        "loop": true,
      });
    } catch (e) {
      debugPrint("Failed to play ringtone: $e");
      SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> stopRingtone() async {
    if (!_isInitialized) return;

    if (Platform.isWindows || Platform.isLinux) {
      await _stopPlayer();
      return;
    }

    try {
      await _methodChannel?.invokeMethod("stopRingtone");
    } catch (e) {
      debugPrint("Failed to stop ringtone: $e");
    }
  }

  Future<void> playTapSound() async {
    if (!_isInitialized) await initialize();

    if (Platform.isWindows || Platform.isLinux) {
      await _playWithPlayer(null);
      return;
    }

    try {
      await _methodChannel?.invokeMethod("playSound", {
        "type": "tap",
      });
    } catch (e) {
      debugPrint("Failed to play tap sound: $e");
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> playCallStartSound() async {
    if (!_isInitialized) await initialize();

    if (Platform.isWindows || Platform.isLinux) {
      await _playWithPlayer(null);
      return;
    }

    try {
      await _methodChannel?.invokeMethod("playSound", {
        "type": "call_start",
      });
    } catch (e) {
      debugPrint("Failed to play call start sound: $e");
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> playRingbackTone() async {
    if (!_isInitialized) await initialize();
    if (Platform.isWindows || Platform.isLinux) {
      await _playWithPlayer(_currentRingtonePath, loop: true);
      return;
    }
    try {
      await _methodChannel?.invokeMethod("playSound", {
        "type": "ringback",
        "loop": true,
      });
    } catch (e) {
      debugPrint("Failed to play ringback tone: $e");
    }
  }

  Future<void> stopRingbackTone() async {
    if (!_isInitialized) return;
    if (Platform.isWindows || Platform.isLinux) {
      await _stopPlayer();
      return;
    }
    try {
      await _methodChannel?.invokeMethod("stopSound", {"type": "ringback"});
    } catch (e) {
      debugPrint("Failed to stop ringback tone: $e");
    }
  }

  // تشغيل صوت عند انتهاء المكالمة
  Future<void> playCallEndSound() async {
    if (!_isInitialized) await initialize();

    try {
      await _methodChannel?.invokeMethod("playSound", {
        "type": "call_end",
      });
    } catch (e) {
      debugPrint("Failed to play call end sound: $e");
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<String?> _getDefaultRingtonePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ringtonePath = '${dir.path}/ringtones/default_ringtone.mp3';

      final file = File(ringtonePath);
      if (await file.exists()) {
        return ringtonePath;
      }

      final ringtonesDir = Directory('${dir.path}/ringtones');
      if (!await ringtonesDir.exists()) {
        await ringtonesDir.create(recursive: true);
      }

      return null;
    } catch (e) {
      debugPrint("Error getting default ringtone path: $e");
      return null;
    }
  }

  // تعيين مستوى الصوت
  Future<void> setVolume(double volume) async {
    if (!_isInitialized) await initialize();

    try {
      await _methodChannel?.invokeMethod("setVolume", {
        "volume": volume,
      });
    } catch (e) {
      debugPrint("Failed to set volume: $e");
      // لا يمكن تعيين الصوت بالطريقة الاحتياطية
    }
  }

  // التحقق مما إذا كان الصوت يعمل
  bool get isInitialized => _isInitialized;
}
