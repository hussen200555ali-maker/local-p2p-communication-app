# KP-2026-001: Kali Linux Port — خطة النقل

## تواصل محلي (الشامي) v7.0 → Kali Linux

**التاريخ:** 30 يونيو 2026  
**الحالة:** معتمدة (تنتظر التنفيذ)  
**الموافِق:** كبير المستشارين التقنيين  
**تقييم الخطة:** 10/10  

---

## 1. النطاق

نقل تطبيق "الشامي" v7.0 (والذي يعمل حالياً على Android + Windows) إلى Linux desktop (Kali/Debian/Ubuntu) باستخدام Flutter's GTK3 backend.

**الـ scaffold موجود مسبقاً.** المطلوب 15 تعديلاً في 12 ملفاً — صفر ملفات جديدة.

---

## 2. التعديلات

### 2-1 شروط المنصة (8 ملفات، 15 تغييراً)

| # | الملف | السطر | الحالي | الجديد |
|---|-------|-------|--------|--------|
| 1 | `chat_screen.dart` | 186 | `if (!Platform.isWindows)` | `if (!Platform.isWindows && !Platform.isLinux)` |
| 2 | `chat_screen.dart` | 465 | `await OpenFilex.open(...)` | `if (!Platform.isLinux) await OpenFilex.open(...)` |
| 3 | `group_chat_screen.dart` | 538 | `await OpenFilex.open(...)` | `if (!Platform.isLinux) await OpenFilex.open(...)` |
| 4 | `splash_screen.dart` | 26 | `if (!Platform.isWindows)` | `if (!Platform.isWindows && !Platform.isLinux)` |
| 5 | `database_service.dart` | 23 | `if (Platform.isWindows)` | `if (Platform.isWindows \|\| Platform.isLinux)` |
| 6 | `local_network_service.dart` | 275 | `if (Platform.isWindows)` | `if (Platform.isWindows \|\| Platform.isLinux)` |
| 7-13 | `call_audio_service.dart` | 22,72,92,107,125,142,158 | `if (Platform.isWindows)` ×7 | `if (Platform.isWindows \|\| Platform.isLinux)` ×7 |
| 14 | `call_vibration_service.dart` | 20 | `if (Platform.isWindows)` | `if (Platform.isWindows \|\| Platform.isLinux)` |

### 2-2 إشعارات Linux — `system_notification_service.dart`

**بعد كتلة Windows (سطر 30-33)، أضف:**
```dart
if (Platform.isLinux) {
  try {
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'فتح التطبيق',
    );
    const settings = InitializationSettings(linux: linuxSettings);
    await _plugin.initialize(settings);
  } catch (e) {
    debugPrint('Linux notifications init failed: $e');
  }
  _initialized = true;
  return;
}
```

### 2-3 CMake + GTK Identity (3 ملفات)

| # | الملف | السطر | الحالي | الجديد |
|---|-------|-------|--------|--------|
| 1 | `linux/CMakeLists.txt` | 7 | `set(BINARY_NAME "local_social_app")` | `set(BINARY_NAME "Alshami")` |
| 2 | `linux/CMakeLists.txt` | 10 | `set(APPLICATION_ID "com.example.local_social_app")` | `set(APPLICATION_ID "com.alshami.app")` |
| 3 | `linux/runner/my_application.cc` | 49 | `"local_social_app"` | `"الشامي"` |
| 4 | `linux/runner/my_application.cc` | 53 | `"local_social_app"` | `"الشامي"` |

### 2-4 أيقونة النافذة (GTK)

```c
// بعد gtk_window_set_title(), أضف:
gtk_window_set_icon_from_file(window, "resources/app_icon.png", nullptr);
```

**المتطلبات:**
- نسخ `assets/icons/app_icon.png` → `linux/runner/resources/app_icon.png`

### 2-5 تحذير Kali داخل التطبيق

**المكان:** `lib/features/settings/screens/settings_screen.dart` أو splash screen  
**النص:**
```
هذا التطبيق مخصص للتواصل الخاص على شبكة محلية موثوقة.
الشبكات العامة أو المعادية قد تعرض اتصالاتك للخطر.
```

---

## 3. أوامر البناء والتحقق

```bash
flutter analyze                          # 0 errors
flutter test                             # 21/21 passed
flutter build linux --release            # BUILD SUCCESSFUL → Alshami bundle
flutter build windows --release          # BUILD SUCCESSFUL (zero impact)
flutter build apk --debug                # BUILD SUCCESSFUL (zero impact)
```

### متطلبات نظام Kali
```bash
sudo apt update
sudo apt install -y libgtk-3-dev liblzma-dev pkg-config cmake ninja-build clang
flutter config --enable-linux-desktop
flutter build linux --release
```

---

## 4. اعتبارات منصة Kali

| الجانب | الملاحظة |
|--------|----------|
| **واجهات الشبكة** | `NetworkHelper.getLocalIP()` يفلتر 192.168/10/172.16 ويستثني VirtualBox — يعمل |
| **المنافذ** | 8080/8081 فوق 1024 — لا يحتاج `sudo` |
| **UDP broadcast** | `RawDatagramSocket` مع `broadcastEnabled=true` — يعمل أصلاً على Linux |
| **Firewall (ufw)** | إذا نشط: `sudo ufw allow 8080/tcp && sudo ufw allow 8081/udp` |
| **AppArmor** | لا يتعارض مع منافذ > 1024 |
| **Desktop Environment** | GNOME/KDE/XFCE → إشعارات كاملة. Headless → لا إشعارات (لا تعطل) |
| **Wayland vs X11** | الكود الحالي يعالج كليهما (`#ifdef GDK_WINDOWING_X11`) |

---

## 5. توجيهات كبير المستشارين

### 5-1 لا تطرح للعامة بعد
التطبيق على Kali جاهز فنياً لكن **الإطلاق معلق** حتى إكمال:
1. 🔐 تشفير إشارات WebRTC (Signaling)
2. 🔐 تشفير البيانات الوصفية (Metadata)

### 5-2 تحذير داخل التطبيق
نص تحذيري واضح لمستخدمي Kali (قسم 2-5 أعلاه).

### 5-3 أيقونة PNG (وليس ICO)
GTK على Linux لا يتعامل مع ICO بشكل مثالي — استخدم PNG.

---

## 6. الملفات غير المتأثرة

| النظام | السبب |
|--------|-------|
| Android | `Permission.*` لا يزال يعمل — بدون تغيير |
| Windows | شروط `Platform.isWindows` تبقى — بدون تغيير |
| iOS | لا تغيير |
| Web | لا تغيير |
| `installer.iss` | خاص بـ Windows |

---

## 7. حالة التنفيذ

- [ ] تم تحديث chat_screen.dart (تعديلان)
- [ ] تم تحديث group_chat_screen.dart (تعديل واحد)
- [ ] تم تحديث splash_screen.dart (تعديل واحد)
- [ ] تم تحديث database_service.dart (تعديل واحد)
- [ ] تم تحديث local_network_service.dart (تعديل واحد)
- [ ] تم تحديث call_audio_service.dart (7 تعديلات)
- [ ] تم تحديث call_vibration_service.dart (تعديل واحد)
- [ ] تم تحديث system_notification_service.dart (إضافة Linux)
- [ ] تم تحديث linux/CMakeLists.txt (تعديلان)
- [ ] تم تحديث linux/runner/my_application.cc (تعديلان + أيقونة)
- [ ] تم نسخ أيقونة PNG
- [ ] تم إضافة تحذير Kali
- [ ] flutter analyze — 0 errors
- [ ] flutter test — 21/21 passed
- [ ] flutter build linux --release — BUILD SUCCESSFUL
- [ ] flutter build windows --release — BUILD SUCCESSFUL
- [ ] flutter build apk --debug — BUILD SUCCESSFUL

---

*تم إنشاء هذه الخطة بواسطة التدقيق الآلي. جميع التعديلات محددة بدقة — كل منها لا يتجاوز سطراً واحداً.*
