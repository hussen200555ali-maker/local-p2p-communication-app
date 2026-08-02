# خطة المرحلة 3: WebRTC Overhaul

**تاريخ البدء:** 24 يونيو 2026

---

## الأهداف

1. تثبيت ICE Restart (حد أقصى 3 محاولات، منع التكرار اللانهائي)
2. إصلاح أصوات الرنين على Windows باستخدام audioplayers
3. تأمين _cleanupCall() وإعادة تعيين جميع الحالات
4. إصلاح أخطاء ringtone path
5. flutter analyze: 0 errors, flutter build windows --release: ناجح

---

## المراحل الفرعية

### 3-1: ICE Restart بحد أقصى 3 محاولات
| الملف | التعديل |
|-------|---------|
| `call_manager.dart` | إضافة `_iceRestartAttempts`، إعادة تعيينها عند `Connected`، إنهاء المكالمة بعد 3 محاولات فاشلة |

### 3-2: أصوات الرنين على Windows
| الملف | التعديل |
|-------|---------|
| `call_audio_service.dart` | استخدام `audioplayers` بدل MethodChannel على Windows — نغمة رنين، ringback، أصوات بدء/إنهاء المكالمة |

### 3-3: _cleanupCall() شامل
| الملف | التعديل |
|-------|---------|
| `call_manager.dart` | إيقاف الرنين والاهتزاز والإشعارات في `_cleanupCall()` + إعادة تعيين `_isAcceptingCall` و `_iceRestartAttempts` |

### 3-4: إصلاح _getDefaultRingtonePath()
| الملف | التعديل |
|-------|---------|
| `call_audio_service.dart` | إصلاح السلسلة النصية المعطوبة وإضافة استيراد `path_provider` |

### 3-5: بناء واختبار
- `flutter analyze`: 0 errors (حافظ على الـ warning الوحيد pre-existing)
- `flutter build windows --release`: ناجح

---

## مؤشر النجاح
```
flutter analyze            ← 0 errors (1 warning pre-existing)
flutter build windows --release ← ✅
```
