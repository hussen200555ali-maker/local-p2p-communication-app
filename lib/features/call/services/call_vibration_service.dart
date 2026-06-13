import "dart:async";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// خدمة الاهتزاز المتخصصة للمكالمات
/// تعمل بدون الاعتماد على مكتبات خارجية
class CallVibrationService {
  static final CallVibrationService _instance = CallVibrationService._internal();
  factory CallVibrationService() => _instance;
  CallVibrationService._internal();

  MethodChannel? _methodChannel;
  Timer? _vibrationTimer;
  bool _isInitialized = false;

  // تهيئة الخدمة
  Future<void> initialize() async {
    if (_isInitialized) return;

    _methodChannel = const MethodChannel("call_vibration_service");

    try {
      await _methodChannel?.invokeMethod("initialize");
      _isInitialized = true;
      debugPrint("CallVibrationService initialized successfully");
    } catch (e) {
      debugPrint("Failed to initialize CallVibrationService: $e");
      // استخدام الطريقة الاحتياطية
      _initializeFallback();
    }
  }

  // طريقة احتياطية للتهيئة
  void _initializeFallback() {
    debugPrint("Using fallback vibration service");
    _isInitialized = true;
  }

  // بدء الاهتزاز المتقطع للمكالمات الواردة
  Future<void> startIncomingCallVibration() async {
    if (!_isInitialized) await initialize();

    try {
      await _methodChannel?.invokeMethod("startIncomingCallVibration");
    } catch (e) {
      debugPrint("Failed to start incoming call vibration: $e");
      _startIncomingCallVibrationFallback();
    }
  }

  // بدء الاهتزاز المتقطع بالطريقة الاحتياطية
  void _startIncomingCallVibrationFallback() {
    debugPrint("Starting incoming call vibration with fallback method");

    // إيقاف أي اهتزاز سابق
    _vibrationTimer?.cancel();

    // بدء اهتزاز متقطع كل ثانية
    _vibrationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _vibrateOnce([500, 500]);
    });
  }

  // إيقاف الاهتزاز المتقطع
  Future<void> stopIncomingCallVibration() async {
    if (!_isInitialized) return;

    // إيقاف المؤقت
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      await _methodChannel?.invokeMethod("stopIncomingCallVibration");
    } catch (e) {
      debugPrint("Failed to stop incoming call vibration: $e");
      // لا حاجة لطريقة احتياطية هنا لأننا أوقفنا المؤقت بالفعل
    }
  }

  // اهتزاز لمرة واحدة
  Future<void> _vibrateOnce(List<int> pattern) async {
    if (!_isInitialized) await initialize();

    try {
      await _methodChannel?.invokeMethod("vibrateOnce", {
        "pattern": pattern,
      });
    } catch (e) {
      debugPrint("Failed to vibrate once: $e");
      // لا يمكن تنفيذ الاهتزاز بالطريقة الاحتياطية
    }
  }

  // اهتزاز عند بدء المكالمة
  Future<void> vibrateCallStart() async {
    if (!_isInitialized) await initialize();

    try {
      await _methodChannel?.invokeMethod("vibrateCallStart");
    } catch (e) {
      debugPrint("Failed to vibrate call start: $e");
      _vibrateOnce([100, 50, 100]);
    }
  }

  // اهتزاز عند انتهاء المكالمة
  Future<void> vibrateCallEnd() async {
    if (!_isInitialized) await initialize();

    try {
      await _methodChannel?.invokeMethod("vibrateCallEnd");
    } catch (e) {
      debugPrint("Failed to vibrate call end: $e");
      _vibrateOnce([100, 50, 100, 50, 100]);
    }
  }

  // التحقق مما إذا كان الاهتزاز مدعوماً
  Future<bool> get hasVibrator async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _methodChannel?.invokeMethod("hasVibrator");
      return result ?? false;
    } catch (e) {
      debugPrint("Failed to check vibrator: $e");
      return false;
    }
  }

  // التحقق مما إذا كانت الخدمة مهيأة
  bool get isInitialized => _isInitialized;

  // التخلص من الموارد
  void dispose() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }
}
