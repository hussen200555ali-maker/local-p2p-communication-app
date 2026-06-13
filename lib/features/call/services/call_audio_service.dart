import "dart:async";
import "dart:io";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:path_provider/path_provider.dart";

/// خدمة الصوت المتخصصة للمكالمات
/// تعمل بدون الاعتماد على مكتبات خارجية
class CallAudioService {
  static final CallAudioService _instance = CallAudioService._internal();
  factory CallAudioService() => _instance;
  CallAudioService._internal();

  MethodChannel? _methodChannel;
  bool _isInitialized = false;
  String? _currentRingtonePath;

  // تهيئة الخدمة
  Future<void> initialize() async {
    if (_isInitialized) return;

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

  // طريقة احتياطية للتهيئة
  void _initializeFallback() {
    debugPrint("Using fallback audio service");
    _isInitialized = true;
  }

  // تشغيل نغمة الرنين
  Future<void> playRingtone({String? customPath, double volume = 0.8}) async {
    if (!_isInitialized) await initialize();

    if (customPath != null) {
      _currentRingtonePath = customPath;
    } else {
      _currentRingtonePath = await _getDefaultRingtonePath();
    }

    try {
      await _methodChannel?.invokeMethod("playRingtone", {
        "path": _currentRingtonePath,
        "volume": volume,
        "loop": true,
      });
    } catch (e) {
      debugPrint("Failed to play ringtone: $e");
      _playRingtoneFallback(volume);
    }
  }

  // تشغيل نغمة الرنين بالطريقة الاحتياطية
  void _playRingtoneFallback(double volume) {
    debugPrint("Playing ringtone with fallback method");
    // استخدام SystemSound للنغمة الافتراضية
    SystemSound.play(SystemSoundType.alert);
  }

  // إيقاف نغمة الرنين
  Future<void> stopRingtone() async {
    if (!_isInitialized) return;

    try {
      await _methodChannel?.invokeMethod("stopRingtone");
    } catch (e) {
      debugPrint("Failed to stop ringtone: $e");
      // لا حاجة لطريقة احتياطية هنا
    }
  }

  // تشغيل صوت عند الضغط على زر
  Future<void> playTapSound() async {
    if (!_isInitialized) await initialize();

    try {
      await _methodChannel?.invokeMethod("playSound", {
        "type": "tap",
      });
    } catch (e) {
      debugPrint("Failed to play tap sound: $e");
      SystemSound.play(SystemSoundType.click);
    }
  }

  // تشغيل صوت عند بدء المكالمة
  Future<void> playCallStartSound() async {
    if (!_isInitialized) await initialize();

    try {
      await _methodChannel?.invokeMethod("playSound", {
        "type": "call_start",
      });
    } catch (e) {
      debugPrint("Failed to play call start sound: $e");
      SystemSound.play(SystemSoundType.click);
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

  // الحصول على مسار النغمة الافتراضية
  Future<String?> _getDefaultRingtonePath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final ringtonePath = "\${directory.path}/ringtones/default_ringtone.mp3";

      // التحقق من وجود الملف
      final file = File(ringtonePath);
      if (await file.exists()) {
        return ringtonePath;
      }

      // إنشاء مجلد النغمات إذا لم يكن موجوداً
      final ringtonesDir = Directory("\${directory.path}/ringtones");
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
