# تواصل محلي (Local Social App)

تطبيق شبكة اجتماعية محلي (P2P) مبني بـ Flutter — يعمل **بدون إنترنت وبدون سيرفر**. أجهزة على نفس شبكة WiFi تكتشف بعضها تلقائياً وتتحدث مباشرة: دردشة، مكالمات، ومشاركة ملفات.

A serverless P2P LAN social app built with Flutter. No internet, no backend — devices on the same WiFi discover each other and communicate directly.

---

## المميزات (Features)

| الميزة | الوصف | الحالة |
|---|---|---|
| اكتشاف الأجهزة | بث UDP تلقائي على المنفذ 8081 داخل الشبكة المحلية | ✅ |
| دردشة خاصة | رسائل نصية مع مؤشر كتابة، شارات غير مقروء، تعديل/حذف | ✅ |
| دردشة جماعية | مجموعات متعددة الأعضاء | ✅ |
| مشاركة الصور والملفات | تقسيم الملفات إلى قطع 32KB مع بروتوكول START/CHUNK/END | ✅ |
| العمل دون اتصال | طابور رسائل في SQLite يُرسل عند عودة الجهاز (store-and-forward) | ✅ |
| مكالمات صوتية/فيديو | WebRTC مع إشارات مشفّرة عبر TCP | 🟡 الصوت منفّذ ومُختبر جزئياً — الفيديو معطّل ميدانياً (انظر Known Issues) |
| سجل المكالمات | تصفية وتجميع حسب التاريخ | ✅ |
| تشفير الرسائل | AES-256-CBC مع IV عشوائي لكل رسالة | ✅ |
| الوضع المظلم | عبر ValueNotifier | ✅ |
| إعدادات الخصوصية | إظهار حالة الاتصال، إيصالات القراءة | ✅ |
| إشعارات النظام | flutter_local_notifications (Android) | ✅ |
| مشاركة الملف الشخصي | عبر رمز QR | ✅ |
| مصادقة بالبصمة | local_auth | ✅ |

---

## التفاصيل التقنية (Tech Stack)

- **Framework:** Flutter 3.38+ / Dart 3.10+
- **Backend:** لا يوجد — تطبيق Offline بالكامل
- **التخزين:**
  - `shared_preferences` — الإعدادات والهوية والأصدقاء
  - `sqflite` (SQLite) — الرسائل وطابور الرسائل المعلّقة (`local_social.db`)، مع `sqflite_common_ffi` على Windows/Linux
  - لا يوجد Hive ولا Firebase ولا أي API خارجي
- **إدارة الحالة:** Provider (لخدمة الشبكة) + setState + نمط تسجيل callbacks على singleton — لا GetX ولا Bloc
- **الشبكة:** UDP broadcast (منفذ 8081) للاكتشاف + TCP (منفذ 8080) للرسائل — رسائل JSON مفصولة بـ `\n`
- **الاتصالات:** WebRTC عبر flutter_webrtc (بدون STUN/TURN — اتصال مباشر محلي)
- **المنصات:** Android ✅ | Windows ✅ | iOS/Ubuntu 🟡

### بروتوكول الشبكة

```
UDP 8081 : DISCOVER:, PING/PONG, DISCOVER_REQUEST
TCP 8080 : MSG:, GROUP_MSG:, CONNECT_REQUEST:, FILE_START:/FILE_CHUNK:,
           CALL_SIGNAL:, STATUS:, PING
```

---

## بنية المشروع (Project Structure)

```
lib/
├── main.dart                        # نقطة الدخول + ThemeData
├── core/services/                   # الخدمات الأساسية
│   ├── local_network_service.dart   # الشبكة P2P (singleton)
│   ├── database_service.dart        # SQLite (singleton)
│   ├── encryption_service.dart      # AES-256-CBC
│   ├── message_queue_service.dart   # طابور الرسائل المعلّقة
│   └── system_notification_service.dart
├── features/
│   ├── auth/        (models/, screens/)     # دخول بالاسم
│   ├── chat/        (models/, screens/)     # دردشة خاصة/جماعية
│   ├── call/        (screens/, services/, widgets/)  # WebRTC
│   ├── notifications/, profile/, settings/, status/
└── shared/widgets/
```

---

## التشغيل والبناء (Build & Run)

### المتطلبات
- Flutter SDK 3.38+
- Android: Android SDK + JDK 17
- Windows: Visual Studio مع CMake و workload "Desktop development with C++"

### Android

```bash
flutter pub get
flutter run                      # للتطوير
flutter build apk --debug        # بناء APK
```

APK الناتج: `build/app/outputs/flutter-apk/app-debug.apk`

### Windows

```bash
flutter build windows --release
```

- النسخة المحمولة: `build\windows\x64\runner\Release\Alshami.exe` (يجب تشغيلها من داخل مجلد `Release`)
- المُثبّت: ببناء مُثبّت Inno Setup من جذر المشروع:
  ```bash
  iscc installer.iss   # ينتج Alshami_Setup.exe
  ```

  ملاحظة: السكربت يتوقع `VC_redist.x64.exe` (من Microsoft) في جذر المشروع — حمّله من موقع Microsoft لأنه غير مُتضمَّن في المستودع.

### أيقونات التطبيق

تُولَّد عبر `flutter_launcher_icons`:

```bash
dart run flutter_launcher_icons
```

الإعدادات في `pubspec.yaml` تحت `flutter_launcher_icons:`، والمصدر `assets/icons/app_icon_1024.png`.

---

## كيفية الاستخدام

1. اتصل بجهازك بنفس شبكة WiFi
2. افتح التطبيق وأنشئ حساباً باسم مستخدم
3. منح أذونات الموقع والكاميرا والميكروفون عند طلبها
4. الأجهزة القريبة تظهر تلقائياً — ابدأ محادثة أو مكالمة

---

## حالات معروفة (Known Issues)

1. **مكالمة الفيديو:** تفشل في `getUserMedia` (مسار الكاميرا) قبل إرسال أي إشارة — موثّقة في `STATUS.md` Phase 12، لم يُطبَّق الإصلاح بعد.
2. **مسار `startCall`:** يوجد تعديل DIAG مؤقت حذف استدعاء `_networkService.startCall()` من `call_manager.dart` — يجب إعادته قبل اختبار المكالمات الصادرة.
3. **Windows:** إشعارات النظام no-op (flutter_local_notifications لا يدعم Windows).
4. التفاصيل الكاملة في `STATUS.md` و`ROADMAP.md`.

---

## التوثيق (Documentation)

| الملف | المحتوى |
|---|---|
| `STATUS.md` | سجل المراحل والتشخيصات وحالة البناء |
| `ROADMAP.md` | خارطة الطريق حسب المنصات |
| `AGENTS.md` | اصطلاحات الكود والدروس المستفادة |
| `docs/` | تقارير تحليل السجلات والاختبارات |

---

## الرخصة (License)

MIT — انظر [LICENSE](LICENSE).
