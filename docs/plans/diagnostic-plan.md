# خطة تشخيص فشل الكشف بين الأجهزة

## الهدف
تحديد سبب عدم كشف أجهزة Windows و Android لبعضها البعض في تطبيق الشامي.

## الفرضيات (مرتبة حسب الاحتمال)
| # | الفرضية | السبب المحتمل |
|---|---------|---------------|
| H1 | عنوان IP خاطئ | `getWifiIP()` يرجع null أو IP غير صحيح (مثلاً VirtualBox) على Windows |
| H2 | UDP لا يصل | جدار الحماية أو VirtualBox يمنع البث على 8081 |
| H3 | TCP scan مهلة قصيرة | 500ms timeout لا يكفي للأجهزة الحقيقية على WiFi |
| H4 | UI لا يتحدث | `_discoveredUsers` يمتلئ لكن `onDiscoveryChanged` لم يسجل بعد |


## خطة التنفيذ — 3 مراحل

### المرحلة 1: شاشة التشخيص (Diagnostic Screen)
**الملفات الجديدة:**
- `lib/features/diagnostics/screens/diagnostic_screen.dart`
- `lib/features/diagnostics/models/diagnostic_data.dart` (اختياري)

**التعديلات:**
- `lib/features/settings/screens/settings_screen.dart` — إضافة زر "تشخيص الشبكة"

**المكونات:**
1. عرض IP الحالي (`getWifiIP()`)
2. حالة المنافذ: TCP 8080 (خادم), UDP 8081 (بث)
3. قائمة `_sendSockets` (عددها + عنوان كل socket)
4. `_discoveredUsers` (عددهم + أسماؤهم)
5. `_userSockets` (عدد الاتصالات النشطة)
6. `_friendIds` (عدد الأصدقاء المحفوظين)
7. سجل آخر 30 حدث اكتشاف (DISCOVER مستلم/مرسل, DISCOVER_TCP, PING, PONG)

**مؤشرات النجاح:** على كل جهاز، يفتح المستخدم شاشة التشخيص ويرى IP صحيح + منافذ شغالة.

### المرحلة 2: اختبارات يدوية (بدون تعديل كود)
تتضمن:
1. `Test-NetConnection` من Windows إلى Android (TCP 8080)
2. فحص جدار الحماية على Windows (`netsh advfirewall`)

### المرحلة 3: Wireshark (إذا لزم الأمر)
التقاط حزم UDP/TCP على Windows للتحقق من وصول/مغادرة حزم DISCOVER.


## خطة التراجع للطوارئ

### السيناريوهات

| السيناريو | الإجراء |
|-----------|---------|
| شاشة التشخيص تتعطل | حذف `diagnostic_screen.dart` + عكس تعديل `settings_screen.dart` |
| زر التشخيص يسبب تعطل الإعدادات | عكس تعديل `settings_screen.dart` |
| `flutter build` يفشل | التراجع عن كل التغييرات: `git checkout -- lib/features/diagnostics/ lib/features/settings/screens/settings_screen.dart` |
| Android يتعطل | نفس التراجع — شاشة التشخيص لا تمس أي Android-specific code |

### ضمانات الأمان
- شاشة التشخيص **للقراءة فقط** — لا تعدل أي حالة في الخدمة
- لا تلمس `local_network_service.dart` (الخدمة الأساسية)
- لا تلمس أي ملف Android/iOS محدد
- كل التغييرات في `lib/features/diagnostics/` — معزولة تماماً

### أمر التراجع السريع
```bash
git checkout -- lib/features/diagnostics/ 2>nul; if ($?) { Remove-Item -Recurse -Force lib/features/diagnostics/ -ErrorAction SilentlyContinue }
git checkout -- lib/features/settings/screens/settings_screen.dart
flutter clean; flutter pub get; flutter build windows --release; flutter build apk --debug
```


## مصفوفة الاختبار

| من \ إلى | Windows | Android 1 | Android 2 |
|-----------|---------|-----------|-----------|
| Windows | UDP + TCP | UDP + TCP | UDP + TCP |
| Android 1 | UDP + TCP | UDP + TCP | UDP + TCP |
| Android 2 | UDP + TCP | UDP + TCP | UDP + TCP |

كل خلية = اختبر: (1) هل يظهر الجهاز في Discovery؟ (2) هل TCP scan يكتشفه؟ (3) ماذا يقول سجل التشخيص؟


## الجدول الزمني
| الخطوة | المدة | المسؤول |
|--------|-------|---------|
| إنشاء شاشة التشخيص + زر الإعدادات | 1 ساعة | Agent |
| بناء Windows + Android | 15 دقيقة | Agent |
| تثبيت على الأجهزة | 10 دقائق | المستخدم |
| التقاط بيانات التشخيص من كل جهاز | 15 دقيقة | المستخدم |
| تحليل النتائج وتحديد السبب | 30 دقيقة | Agent |
