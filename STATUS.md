# STATUS.md — تتبع التقدم

## المرحلة 6: التدقيق النهائي وإغلاق الفجوات ✅ (29 يونيو 2026)

### الفجوات المكتشفة من داخل الكود الفعلي

| الرمز | المستوى | الموقع | المشكلة | الحل |
|-------|---------|--------|---------|------|
| **G1** 🔴 | Critical | `chat_screen.dart:186` | `Permission.storage.request()` بدون `Platform.isWindows` — تعطل Windows عند "إرسال ملف" | إضافة `if (!Platform.isWindows)` حول كتلة الصلاحية |
| **G3** 🟡 | Medium | `assets/sounds/` + `pubspec.yaml` | مجلد `sounds/` غير معلن في pubspec.yaml + ملف ringtone.mp3 مفقود — فشل صوتي صامت | إضافة `assets/sounds/` إلى pubspec.yaml + إنشاء `ringtone.wav` (69 KB) |
| **G5** 🟢 | Low | `database_service_windows.dart` | كود ميت (241 سطر) بدون أي import | حذف الملف |
| **G6** ✨ | Enhancement | `installer.iss` | لا يوجد تشغيل تلقائي بعد التثبيت | إضافة `[Run]` post-install |
| **G4** ✨ | Enhancement | `.gitignore` | إدخالات Windows مفقودة | إضافة `*.exe`, `*.msi`, `*.pdb` |

### تم التحقق — ليست مشكلة
| الرمز | الادعاء | النتيجة |
|-------|---------|---------|
| **G2** | `PROJECT_BUILD_DIR` بدون `/` في CMakeLists.txt | ❌ **False positive** — القيمة `"${PROJECT_DIR}/build/"` مع `/` في النهاية، قالب Flutter الرسمي |

### التعزيزات (حسب توجيه كبير المستشارين)

| التعزيز | التفاصيل |
|---------|----------|
| G1 موسّع | تدقيق جميع استدعاءات `Permission.*` — موقع واحد فقط (`splash_screen.dart:26`) وكان محمياً بالفعل ✅ |
| G3 موسّع | نغمة رنين WAV حقيقية (نغمات A-C-E-G-E-C-A-C مع هارمونيكس) بدلاً من صامت |
| G7 (جديد) | مراجعة جميع مواقع `Platform.isWindows` — 12 موقعاً، جميعها صحيحة ✅ |

### مؤشرات النجاح

| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | 0 errors, 0 warnings جديدة ✅ |
| `flutter test` | 21/21 passed ✅ |
| `flutter build apk --debug` | BUILD SUCCESSFUL ✅ |
| `flutter build windows --release` | BUILD SUCCESSFUL (Alshami.exe) ✅ |
| ISCC installer.iss | يحتاج Inno Setup (غير مثبت على هذا الجهاز) |

### التقرير الخارجي
- `docs/WPR-2026-001.md` — تقرير شامل للمراجعين الخارجيين ✅
- `STATUS.md` — يبقى للتتبع اليومي الداخلي

---

## الإصدار النهائي: البناء والتوزيع ✅ (30 يونيو 2026)

### ما تم
| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | 0 errors, 1 warning (chunkSize), 19 info ✅ |
| `flutter test` | 21/21 passed ✅ |
| `flutter build windows --release` | BUILD SUCCESSFUL ✅ |
| `flutter build apk --debug` | BUILD SUCCESSFUL ✅ |
| `ISCC installer.iss` | Alshami_Setup.exe (31.30 MB) ✅ |

### المخرجات
| الملف | الحجم | التاريخ |
|-------|-------|---------|
| `Alshami_Setup.exe` | 31.30 MB | 30 يونيو 2026، 5:56 م |
| `build/windows/x64/runner/Release/Alshami.exe` | 345 KB | 27 يونيو 2026 |
| `build/app/outputs/flutter-apk/app-debug.apk` | 255 MB | 30 يونيو 2026، 5:44 م |

### الفجوات المغلقة (G1-G7)
- **G1**: `Permission.storage` محمي بـ `!Platform.isWindows && !Platform.isLinux` ✅
- **G3**: `assets/sounds/ringtone.wav` موجود + معلن في `pubspec.yaml` ✅
- **G5**: `database_service_windows.dart` محذوف ✅
- **G4**: `.gitignore` محدث ✅
- **G6**: `installer.iss` فيه `[Run]` post-install ✅
- **G7**: 12 موقع `Platform.isWindows` جميعها صحيحة ✅

### تحسين كشف الأجهزة — TCP Unicast Discovery ✅
- **المشكلة**: UDP broadcast يخرج من واجهة VirtualBox على Windows
- **الحل**: مسح TCP لشبكة `/24` المحلية (مجموعات 20 متوازي، مهلة 500 مللي)
- **البروتوكول**: `DISCOVER_TCP:` / `DISCOVER_TCP_RESPONSE:` عبر TCP 8080
- **التغطية**: `start()` + `triggerRescan()` يستدعيان UDP announcement + TCP scan
- **UDP محتفظ به**: كخيار احتياطي — لم يُحذف

### الخطوة التالية
قم بتثبيت `Alshami_Setup.exe` على كلا جهازي Windows وتحقق من كشف الجهازين لبعضهما (سحب لإعادة البحث في تبويب Discovery).

---

## إصلاح قاعدة بيانات SQLite — مسار AppData ✅ (30 يونيو 2026)

### المشكلة
عند تثبيت التطبيق عبر `Alshami_Setup.exe` في `C:\Program Files\Alshami\`، يتجمد التطبيق بعد إدخال اسم المستخدم ولا يتنقل إلى الشاشة الرئيسية.

### السبب الجذري
`sqflite_common_ffi` (الإصدار 2.4.0+3) يحدد مسار قاعدة البيانات بشكل ثابت كـ `.dart_tool/sqflite_common_ffi/databases/` نسبة إلى **مجلد العمل** (حيث يوجد الـ EXE). هذا يُحل إلى `C:\Program Files\Alshami\.dart_tool\...` — وهو مجلد محمي ضد الكتابة.

فشل قاعدة البيانات يسبب:
1. `_loadDataFromStorage()` يمسك الاستثناء (سطر 1595-1605)
2. `resetStuckPendingMessages()` (سطر 184) **بدون try-catch** يرمي استثناءً آخر
3. `start()` يفشل — والـ 15 ثانية timeout تنتهي
4. التطبيق يتجمد ولا يتنقل

### الإصلاح
- **الملف:** `lib/core/services/database_service.dart`
- **التعديل:** `_initDbFfi()` يستخدم `getApplicationDocumentsDirectory()` بدلاً من `ffi.databaseFactoryFfi.getDatabasesPath()`
- **المسار الجديد:** `%LOCALAPPDATA%\Alshami\databases\local_social.db` (قابل للكتابة دائماً)
- Android/iOS غير متأثر — `_initDb()` لم يتغير

### الأدوات التشخيصية المضافة
- **`diagnostic_screen.dart`** — شاشة تشخيص جديدة تظهر IP الحالي، حالة المنافذ، قائمة Sockets الإرسال، المستخدمين المكتشفين، وسجل آخر 100 حدث
- **`_logEvent()`** — 15 نقطة تسجيل في `local_network_service.dart` (بدء الخدمة، ربط المنافذ، إرسال/استقبال DISCOVER، فحص TCP، اتصالات TCP الواردة)
- **زر "تشخيص الشبكة"** — في شاشة الإعدادات (`settings_screen.dart`)
- الوصول من: الإعدادات ← تشخيص الشبكة

### مؤشرات النجاح
| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | 0 errors, 1 warning (chunkSize), 19 info ✅ |
| `flutter build apk --debug` | BUILD SUCCESSFUL ✅ |
| `flutter build windows --release` | BUILD SUCCESSFUL ✅ |
| `ISCC installer.iss` | Alshami_Setup.exe (31.31 MB) ✅ |

### أمر التراجع
```bash
git checkout -- lib/core/services/database_service.dart lib/features/diagnostics/ lib/features/settings/screens/settings_screen.dart
```

---

## المرحلة 0: تثبيت الأساس ✅ (22 يونيو 2026)

### تم الإنجاز
- إصلاح C-1 (الوضع المظلم): ValueNotifier + listener في main.dart
- إصلاح C-2 (الخصوصية): public getters + gates في واجهة الدردشة
- إصلاح C-3 (استمرارية الرسائل): try-catch لكل JSON section + SQLite reconciliation
- إصلاح C-4 (WebRTC handshake): _processSignal يعالج offer/answer
- إصلاح C-5 (toggleSpeaker): Helper.setSpeakerphoneOn()
- إصلاح H-4 (ترتيب سجل المكالمات): Map<String, DateTime> groupDates + DateTime.compareTo
- إزالة 13 حقلاً/ملفاً مهجوراً
- _discoveredUsers ← final
- _formatDateTime أضيفت إلى group_chat_screen.dart
- _readReceipts مربوط: MSG_ACK مكبوت عندما false
- main_orgenal.dart → archive/main_orgenal.dart.bak
- اختباران جديدان لمتانة JSON التالف
- flutter analyze: 0 errors, 1 warning, 19 info
- flutter test: 21/21 passed

### الأخطاء المكتشفة حديثاً
- C-6: cancelActiveCallNotification race — لا يزال قائماً (غير محلول)
- M-8: iOS DarwinInitializationSettings — بحاجة إكمال
- M-10: cancelOnError: false لمستمعي UDP/TCP — بحاجة إضافة

### دروس جديدة (24 يونيو 2026 — إصلاح انقطاع TCP)
- **L-13 (TCP PING/PONG حتمي)**: PING عبر UDP وحده لا يكفي. TCP يموت بصمت. أرسل `PING` عبر TCP لكل socket في `_userSockets` كل 20 ثانية في `_startHeartbeatSystem()`.
- **L-14 (لا تكتب على socket ميت)**: استخدم `_safeWrite()` الذي يلف `socket.write()` في try-catch ويدعو `_removeSocket()` عند الفشل — بدلاً من bare `_userSockets.remove()` الذي يسرّب الـ socket.
- **L-15 (_finalizeConnection يطرد الجثث)**: قبل تخزين socket جديد، أغلق أي socket موجود مسبقاً للمستخدم نفسه. لا تترك جثة تحتل المكان.

---

## المرحلة 1: منفذ Windows ✅ (24 يونيو 2026)

| المرحلة الفرعية | الهدف | الحالة |
|-----------------|-------|--------|
| 1-1 | ملفات Windows الجديدة (3 ملفات) | ✅ منجزة |
| 1-2 | حراسات المنصة (4 ملفات) | ✅ منجزة |
| 1-3 | تعديلات local_network_service.dart | ✅ منجزة |
| 1-4 | بناء Windows + APK | ✅ منجزة |

### إنجازات 1-1
- `lib/core/services/network_helper.dart` — getLocalIP() باستخدام NetworkInterface.list() + فلترة 192.168/10/172.16
- `lib/core/services/database_service_windows.dart` — غلاف كامل لقاعدة SQLite عبر sqflite_common_ffi
- `lib/core/services/notification_service_windows.dart` — no-op للإشعارات على Windows
- إضافة `sqflite_common_ffi: ^2.3.0` إلى pubspec.yaml
- flutter analyze: 0 errors
- flutter test: 21/21 passed

### إنجازات 1-2
- `splash_screen.dart`: لف `Permission.location.request()` بـ `if (!Platform.isWindows)`
- `system_notification_service.dart`: early return `if (Platform.isWindows)` في `initialize()`
- `call_audio_service.dart`: early return `if (Platform.isWindows)` → `_initializeFallback()`
- `call_vibration_service.dart`: early return `if (Platform.isWindows)` → `_initializeFallback()`
- flutter analyze: 0 errors
- flutter test: 21/21 passed

### إنجازات 1-3
- `getWifiIP()`: مسار Windows ← `NetworkHelper().getLocalIP()`، مسار موبايل ← `_networkInfo.getWifiIP()`
- `file.path.split('/').last` ×4 ← `p.basename(file.path)`
- إضافة `import 'package:path/path.dart' as p;`
- إضافة `import 'network_helper.dart';`
- flutter analyze: 0 errors
- flutter test: 21/21 passed

### إنجازات 1-4
- `flutter build windows --debug` ✅ → `local_social_app.exe` (1,029,632 بايت)
- `NuGet.config` fix: أضيف `<package pattern="Microsoft.*" />` إلى `<packageSourceMapping>`
- إصلاح عطل SQLite على Windows: `database_service.dart` أصبح platform-aware (sqflite للجوال + sqflite_common_ffi لويندوز)
- flutter analyze: 0 errors
- flutter test: 21/21 passed

### مؤشر النجاح
- `flutter build windows --debug` ✅ ناجح
- `flutter build apk --debug` ✅ ناجح (zero impact on mobile)

---

## المرحلة 1-5: مثبت Windows (Alshami_Setup.exe) ✅ (24 يونيو 2026)

### تم الإنجاز
- **الأيقونة**: استبدال `windows/runner/resources/app_icon.ico` و `assets/icons/app_icon.ico` بأيقونة الحمامة البيضاء + "الشامي" بالعربية.
- **استخراج PNG للأندرويد**: `assets/icons/app_icon.png` (270 ك.ب) من ملف ICO.
- **Runner.rc**: `ProductName=Alshami`, `FileDescription=الشامي - تطبيق تواصل اجتماعي محلي بدون إنترنت`, `OriginalFilename=Alshami.exe`, `CompanyName` فارغ.
- **بناء الإصدار النهائي**: `flutter build windows --release` ✅ → `local_social_app.exe` (344 ك.ب).
- **تثبيت Inno Setup 6.7.3**: عبر `winget install JRSoftware.InnoSetup`.
- **سكريبت المثبت** (`installer.iss`):
  - اسم البرنامج: `الشامي (Alshami)`
  - مجلد التثبيت: `C:\Program Files\Alshami`
  - اختصارات: `الشامي` (سطح المكتب + قائمة ابدأ)
  - قاعدتا جدار ناري عند التنصيب:
    - `Alshami-TCP-8080` (TCP, 8080, Allow, All profiles)
    - `Alshami-UDP-8081` (UDP, 8081, Allow, All profiles)
  - إلغاء التثبيت: يحذف القاعدتين تلقائياً
  - دعم العربية والإنجليزية في واجهة المثبت
- **بناء المثبت**: `ISCC installer.iss` ✅ → `Alshami_Setup.exe` (29.82 MB).

### التوزيع النهائي
- ملف المثبت: `C:\Users\IT\local_social_app\Alshami_Setup.exe`
- سكريبت المثبت: `C:\Users\IT\local_social_app\installer.iss`

---

## إصلاحات الاسم والتطبيق الخفي (24 يونيو 2026)

### تغيير اسم التطبيق في كل مكان
| الموقع | القديم | الجديد |
|--------|--------|--------|
| `AndroidManifest.xml` | `local_social_app` | `الشامي` |
| `ios/Runner/Info.plist` (CFBundleDisplayName) | `Local Social App` | `الشامي` |
| `ios/Runner/Info.plist` (CFBundleName) | `local_social_app` | `Alshami` |
| `windows/CMakeLists.txt` (BINARY_NAME) | `local_social_app` | `Alshami` |
| `windows/runner/main.cpp` (window title) | `local_social_app` | `Alshami` |
| `web/manifest.json` | `local_social_app` | `الشامي` |
| `settings_screen.dart` | `Local Social App Team` | `فريق الشامي` |
| `installer.iss` (MyAppExeName) | `local_social_app.exe` | `Alshami.exe` |
| `Runner.rc` (ProductName/FileDescription) | `local_social_app` | `Alshami` (سابقاً) |

### إصلاح مشكلة التطبيق الخفي (zombie process)
- **السبب**: عند إغلاق النافذة، لا يتم استدعاء `LocalNetworkService.stop()`، فتبقى المقابس (sockets) والمؤقتات (timers) قيد التشغيل مما يمنع خروج العملية.
- **الموقع**: `main.dart:63-67` — إضافة `WidgetsBindingObserver` للاستماع إلى دورة حياة التطبيق واستدعاء `stop()` عند `detached`.
- **الموقع**: `main.dart:64` — استدعاء `LocalNetworkService().stop()` في `dispose()` كشبكة أمان.
- **الموقع**: `flutter_window.cpp:66-68` — معالجة `WM_CLOSE` مباشرة لمنع Flutter من اعتراض الرسالة ومنع إغلاق النافذة.
- **النتيجة**: `flutter analyze`: 0 errors (كما كان).

---

## المرحلة 3: WebRTC Overhaul ✅ (24 يونيو 2026)

### 3-1: ICE Restart بحد أقصى 3 محاولات
- **الملف**: `call_manager.dart`
- **التعديل**: إضافة `_iceRestartAttempts` مع حد أقصى 3 محاولات. إعادة التعيين عند `Connected`. إنهاء المكالمة بعد 3 محاولات فاشلة.

### 3-2: إصلاح أصوات الرنين على Windows
- **الملف**: `call_audio_service.dart`
- **التعديل**: استخدام `audioplayers` (`AudioPlayer` مع `ReleaseMode.loop`) بدل MethodChannel على Windows.
- **المسار**: كل دوال الصوت (`playRingtone`, `stopRingtone`, `playRingbackTone`, `stopRingbackTone`, `playCallStartSound`, `playTapSound`) لها مسار Windows منفصل.

### 3-3: إصلاح `_cleanupCall()`
- **الملف**: `call_manager.dart`
- **التعديل**: إضافة إيقاف الرنين والاهتزاز والإشعارات في `_cleanupCall()`. إعادة تعيين `_isAcceptingCall` و `_iceRestartAttempts`.

### 3-4: إصلاح `_getDefaultRingtonePath()`
- **الملف**: `call_audio_service.dart`
- **التعديل**: إصلاح السلسلة النصية المعطوبة (`"\${...}"` → `'${dir.path}/...'`). إضافة استيراد `path_provider`.

### مؤشر النجاح
- `flutter analyze`: 0 errors ✅ (1 warning pre-existing)
- `flutter build windows --release`: ✅ ناجح

---

## المرحلة 4: إصلاح مشكلة "لا نافذة بعد الإغلاق" (Zombie Process) ✅ (24 يونيو 2026)

### التشخيص
المشكلة: بعد إغلاق النافذة، العملية تبقى حية (zombie) في Task Manager وتحمل المنفذين 8080/8081. عند التشغيل التالي، `await start()` لا يكتمل أبداً → `runApp()` لا يُستدعى → لا نافذة.

السبب الجذري: Flutter engine يعترض `WM_CLOSE` قبل أن يصل إلى `DestroyWindow` و `PostQuitMessage(0)`. في بعض الإصدارات، الـ engine لا يدمر النافذة ولا يرسل رسالة الخروج.

### الحل — 5 أجزاء

| الجزء | الملفات | التعديل |
|-------|---------|---------|
| A | `main.dart` | نقل `start()` إلى بعد `runApp()` — النافذة تظهر دائماً بغض النظر عن الشبكة |
| B | `flutter_window.cpp` | معالجة `WM_CLOSE` و `WM_DESTROY` **قبل** Flutter engine لضمان `DestroyWindow` + `PostQuitMessage(0)` |
| C | `win32_window.cpp` | تغيير `DefWindowProc(window_handle_, ...)` إلى `DefWindowProc(hwnd, ...)` — منع استعمال مؤشر `nullptr` |
| D | `main.cpp` | إضافة `CreateMutexW` — منع تشغيل نسختين + إحضار النافذة الحالية للأمام |
| E | `local_network_service.dart` | إعادة محاولة ربط المنافذ (3 محاولات) + مهلة 15 ثانية للـ `start()` |

### نتائج الاختبار
- ✅ 3 دورات متتالية من الإطلاق/الإغلاق/إعادة الإطلاق — النجاح في كل مرة
- ✅ mutex يمنع نسخة ثانية (تخرج فوراً مع `EXIT_SUCCESS`)
- ✅ `flutter analyze`: 0 errors
- ✅ `flutter build windows --release`: ناجح
- ✅ `Alshami_Setup.exe` أعيد بناؤه

---

## المرحلة 5: إصلاح كشف Windows↔Windows — البث يخرج من الواجهة الخطأ ✅ (27 يونيو 2026)

### التشخيص
- **الجهاز الأول**: `192.168.0.41` + `192.168.56.1` (VirtualBox)
- **الجهاز الثاني**: `192.168.0.185`
- **كلاهما على `192.168.0.0/24`** — IP صحيح لكل جهاز
- **السبب الجذري**: `_broadcastSocket.bind(InternetAddress.anyIPv4, 8081)` مربوط بكل الواجهات. لكن `send()` على Windows يختار الواجهة ذات الـ metric الأقل → VirtualBox → البث يضيع في الشبكة الافتراضية.

### الحل — 4 طبقات أمان

| # | الطبقة | الملف | التعديل |
|---|--------|-------|---------|
| 1 | **Socket منفصل للإرسال** | `local_network_service.dart` | `_startSendSocket()` ينشئ `RawDatagramSocket` مربوطاً بالـ IP الحقيقي (مثلاً `192.168.0.41`) للإرسال فقط |
| 2 | **Subnet broadcast** | `local_network_service.dart` | `_sendDiscoveryPacket()` تُرسل إلى `255.255.255.255` + `192.168.x.255` |
| 3 | **جدار حماية `dir=out`** | `installer.iss` | إضافة `Alshami-UDP-8081-Out` للسماح بخروج UDP 8081 |
| 4 | **`_isVirtualNetwork()` أقل عدوانية** | `network_helper.dart` | استبعاد نطاقات VirtualBox المعروفة فقط (`56.x`, `57.x`, `99.x`, `100.x`) بدلاً من `192.168.2.0/16` كله |

### أمان إضافي
- جميع `/* Ignore */` في محاولات الإرسال أزيلت — الأخطاء تُطبع الآن في debug log
- `triggerRescan()` — دالة عامة لإعادة البحث يدوياً
- `RefreshIndicator` في تبويب Discovery — سحب لإعادة البحث
- Fallback آمن: إذا فشل `_sendSocket`، يُستخدم `_broadcastSocket` كالمعتاد — لا خسارة

### مؤشر النجاح
- `dart analyze`: 0 errors ✅
- `flutter test`: 21/21 passed ✅
- `flutter build apk --debug`: ✅ ناجح (Android سليم)
- `flutter build windows --release`: ✅ ناجح
- `Alshami_Setup.exe` (31.28 MB): ✅ أعيد بناؤه في 27 يونيو 2026، 4:42 م

### كيف تعمل الآن

```
الجهاز الأول (192.168.0.41 + VirtualBox 192.168.56.1):

قبل التعديل:
  _broadcastSocket.bind(anyIPv4, 8081)
  → send() يخرج من واجهة VirtualBox → البث يضيع

بعد التعديل:
  _broadcastSocket.bind(anyIPv4, 8081)    ← للاستقبال (يستقبل من الجهاز الثاني)
  _sendSocket.bind(192.168.0.41, منفذ عشوائي)  ← للإرسال (يخرج من Wi-Fi)
  → send() يخرج من Wi-Fi → البث يصل إلى الجهاز الثاني ✓
```

---

## المرحلة 7: Kali Linux Port + تشفير WebRTC Signaling ✅ (30 يونيو 2026)

### 7-1: تشفير WebRTC Signaling
| الوصف | الموقع | الحالة |
|-------|--------|--------|
| تشفير `CALL_SIGNAL` عند الإرسال | `local_network_service.dart:1756` | ✅ |
| تشفير `CALL_SIGNAL` عند تصريف الطابور | `local_network_service.dart:784` | ✅ |
| فك تشفير `CALL_SIGNAL` عند الاستقبال | `local_network_service.dart:654-656` | ✅ |

### 7-2: نقل Kali Linux (21 تعديلاً في 12 ملفاً)
| # | الملف | التعديل |
|---|-------|---------|
| 1 | `chat_screen.dart:186` | `!Platform.isWindows` ← `!Platform.isWindows && !Platform.isLinux` |
| 2 | `chat_screen.dart:465` | لف `OpenFilex.open()` بـ `if (!Platform.isLinux)` |
| 3 | `group_chat_screen.dart:538` | لف `OpenFilex.open()` بـ `if (!Platform.isLinux)` |
| 4 | `splash_screen.dart:26` | `!Platform.isWindows` ← `!Platform.isWindows && !Platform.isLinux` |
| 5 | `database_service.dart:23` | `Platform.isWindows` ← `Platform.isWindows \|\| Platform.isLinux` |
| 6 | `local_network_service.dart:275` | `Platform.isWindows` ← `Platform.isWindows \|\| Platform.isLinux` |
| 7-13 | `call_audio_service.dart` (×7) | `Platform.isWindows` ← `Platform.isWindows \|\| Platform.isLinux` |
| 14 | `call_vibration_service.dart:20` | `Platform.isWindows` ← `Platform.isWindows \|\| Platform.isLinux` |
| 15 | `system_notification_service.dart` | إضافة `LinuxInitializationSettings` |
| 16-17 | `linux/CMakeLists.txt` | `BINARY_NAME=Alshami`, `APPLICATION_ID=com.alshami.app` |
| 18-19 | `linux/runner/my_application.cc` | عنوان النافذة "الشامي" + أيقونة GTK |
| 20 | `linux/runner/resources/` | نسخ `app_icon.png` |
| 21 | `settings_screen.dart` | إضافة تحذير أمني لمستخدمي Linux |

## التحديث 1 يوليو 2026 — إصلاح مشكلة عدم ظهور النافذة على أجهزة Windows الأخرى

### المشكلة
التطبيق يظهر فقط في Task Manager ولا تظهر نافذة للمستخدم بعد التثبيت على Windows نضيف.

### الأسباب المُشخّصة
1. **طلب VC++ Redistributable** — `flutter_windows.dll` يحتاج `vcruntime140.dll`. لو ناقصة، العملية تبدأ لكن Flutter Engine يفشل تحميله
2. **`.dart_tool` ملحوق مع المثبّت** — `sqflite_common_ffi` ينشئ قاعدة بيانات في `.dart_tool/` أثناء البناء، وهذا المجال يُنسخ إلى المثبّت ويسبب تضارب مسارات
3. **النافذة تبقى مخفية** — `Show()` فقط بعد أول Frame. لو First Frame يفشل، النافذة لا تظهر أبداً
4. **لا يوجد Logging** — `debugPrint` لا يعمل في Release build، ولا توجد وسيلة لمعرفة الخطأ

### الإصلاحات المُطبّقة

| الخطوة | الملف | ماذا تغير |
|--------|-------|-----------|
| أ | `installer.iss` | إضافة `Excludes: ".dart_tool"` إلى `[Files]` لمنع تضارب قاعدة البيانات |
| ب | `installer.iss` | إضافة `VC_redist.x64.exe` إلى `[Files]` (25.6 MB, من Microsoft الرسمي) |
| ج | `installer.iss` | إضافة `[Run]` → `taskkill /f /im Alshami.exe` لقتل أي عملية قديمة قبل التثبيت |
| د | `installer.iss` | إضافة `[Run]` → `VC_redist.x64.exe /install /quiet /norestart` للتثبيت الصامت |
| هـ | `flutter_window.cpp` + `flutter_window.h` | إضافة `SetTimer(GetHandle(), kShowTimerId, 5000, ...)` + `WM_TIMER` → `Show()` إذا لم تظهر النافذة خلال 5 ثوانٍ |
| و | `main.dart` | إضافة `_writeCrashLog()` يكتب إلى `%TEMP%\Alshami_crash_*.log` |
| ز | `main.dart` | إضافة `FlutterError.onError` + `PlatformDispatcher.instance.onError` لالتقاط أي استثناء |

### ملاحظات
- `VC_redist.x64.exe` يُحذف بعد التثبيت (`Flags: deleteafterinstall`)
- إذا VC++ Redist مثبّت مسبقاً، المثبّت يكتشفه ويخرج فوراً (≈1 ثانية)
- Force Show بعد 5 ثوانٍ يضمن ظهور النافذة حتى لو First Frame فشل (النافذة تظهر بيضاء ثم المحتوى)
- Alshami_Setup.exe الحجم النهائي: 55 MB (31 MB تطبيق + 13 MB VC++ Redist مضغوط)

### مؤشرات النجاح
| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | 0 errors ✅ |
| `flutter test` | 24/24 passed ✅ |
| `flutter build apk --debug` | BUILD SUCCESSFUL ✅ |
| `flutter build windows --release` | BUILD SUCCESSFUL ✅ (335s) |
| `ISCC installer.iss` | BUILD SUCCESSFUL ✅ (76s) |

### الإصدارات
- `docs/KP-2026-001.md` — تقرير نقل Kali Linux ✅
- `docs/plans/kali-port.md` — خطة النقل (معتمدة مسبقاً) ✅
- WebRTC Signaling مشفر — لم يعد `CALL_SIGNAL` نصاً صريحاً

⚠️ الإطلاق العام على Kali معلق لحين إكمال تشفير البيانات الوصفية. حفظ EncryptionService يستخدم مفتاح AES-256-CBC ثابت `'LocalSocialApp2024!@#EncKey_v1'` — ترقية إلى مفتاح لكل جلسة مستقبلاً.

---

## إصلاح عاصفة إعادة الاتصال (Socket Storm Fix) ✅ (5 يوليو 2026)

### التشخيص
بعد تحليل سجلي Windows (`alshami_2026-07-04.log`) و Android (`هذه سجل الاندرو.docx`)، تم اكتشاف عاصفة TCP دورية:

```
Finalized → onDone → Socket removed → Finalized → onDone → Socket removed → Finalized → ...
```

**السبب الجذري**: Android و Windows كلاهما يشغّل `_improvedReconnectToFriend` عند استقبال DISCOVER، مما يخلق حلقة تغذية راجعة إيجابية:

1. Android يفتح TCP → يرسل `RECONNECT` → Windows يُنهي الاتصال
2. Android يغلق TCP → `onDone` → `_removeSocket` → `_quickReconnect`
3. Windows يفتح TCP جديد لـ Android
4. Android يستقبل DISCOVER → `_improvedReconnectToFriend` → Android يفتح TCP جديد
5. كلا الاتصالين يصلان معاً → تنافس → socket "خاسر" يُغلق → `onDone` → دورة جديدة

### التعديلات الأربعة المُطبّقة

| # | التعديل | الموقع (local_network_service.dart) | السطر | الوصف |
|---|---------|-------------------------------------|-------|-------|
| 1 | **onDone guard** | `_setupSocket` | 1078-1085 | onDone لا يزيل userId إلا إذا كان الـ socket لا يزال نشطاً في `_userSockets` |
| 2 | **تسجيل قبل الإغلاق** | `_finalizeConnection` | 889-905 | استبدال `_userSockets[user.id]` قبل `_safeSocketClose(existingSocket)` |
| 3 | **تحقق أمان** | `_removeSocket` | 947-951 | لا تمسح userId إذا كان هناك socket نشط بديل (`_userSockets[foundId] != socket`) |
| 4 | **تبريد cooldown** | `_quickReconnect` | 964-972 | عدم إعادة اتصال أكثر من مرة كل 5 ثوانٍ للـ userId نفسه |

### اكتشافات إضافية من سجل Android

| الاكتشاف | الوصف |
|----------|-------|
| **SQLite error** | `type 'int' is not a subtype of type 'bool'` عند تحميل الرسائل — خطأ قائم لم يُصلح بعد |
| **CALL_SIGNAL يزيد العاصفة** | أثناء المكالمة، `_sendCallSignal` يفشل (`WRITE FAILED`) ويكرر `NO SOCKET, QUEUING` عدة مرات |
| **Android نفس المشكلة** | Android يعاني من نفس العاصفة — يحتاج نفس التعديلات الأربعة |
| **TCP Scan يسبب 5 اتصالات متزامنة** | Android أحياناً يفتح 5 TCP connections في 11ms (00:58:58.746) |

### مؤشرات النجاح

| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | No issues found ✅ |
| `flutter build apk --debug` | BUILD SUCCESSFUL ✅ |

### الإصلاحات الإضافية (5 يوليو 2026)

| # | الإصلاح | الملف | الوصف |
|---|---------|-------|-------|
| 5 | **SQLite int→bool** | `message_model.dart:39-40` | `fromJson` يتعامل مع `int` (0/1 من SQLite) و `bool` (`true`/`false` من JSON) للحقلين `read` و `edited` |
| 6 | **DISCOVER debounce** | `local_network_service.dart` | إضافة `_lastDiscoverReconnect` — عدم إعادة اتصال عند استقبال DISCOVER أكثر من مرة كل 8 ثوانٍ لكل صديق |

### مؤشرات النجاح

| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | 0 errors, 0 warnings جديدة ✅ |
| `flutter build apk --debug` | BUILD SUCCESSFUL ✅ |

### الخطوات التالية

- [ ] اختبار السيناريو العكسي: إغلاق Android فجأة وملاحظة استجابة Windows
- [ ] منع `_improvedReconnectToFriend` من التشغيل عند كل DISCOVER (debounce) — ✅ تم (5 يوليو)
- [ ] إصلاح SQLite error عند بدء التشغيل — ✅ تم (5 يوليو)
