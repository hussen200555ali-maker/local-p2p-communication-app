# خطة إصلاح المكالمات — المرحلة 13

التاريخ: 21 أكتوبر 2026
الحالة: معتمدة من المستخدم — قيد التنفيذ

## الهدف
إعادة المكالمات الصوتية/المرئية إلى العمل: بدء المكالمة، قبولها، وإنهاء المصافحة (WebRTC handshake) بشكل موثوق على Android وWindows.

## تحليل الجذر (Root Cause)

1. **أذونات وقت التشغيل مفقودة (السبب الأرجح لفشل getUserMedia):**
   - `permission_handler` مستخدم فقط لطلبات `location` (splash) و`storage` (chat).
   - لا يوجد أي طلب لـ `Permission.camera` أو `Permission.microphone` قبل `getUserMedia`.
   - على Android 6+ هذه أذونات خطيرة تتطلب موافقة وقت التشغيل. الوصول غير الممنوح يجعل `getUserMedia` يفشل بـ `Failed to create new track` — وهذا مطابق تماماً لسجل Phase 12.
   - iOS: `NSMicrophoneUsageDescription` مفقود من `Info.plist` (الكاميرا موجودة).

2. **تعديل DIAG مؤقت في `call_manager.dart`:**
   - سطر `await _networkService.startCall(receiverId, callType)` محذوف، فلم تُنشأ `CallModel` ولا call socket ولا `call_request` للمستقبل — لذلك "hussen لم يستقبل أي مكالمة".
   - الكود يبحث عن مكالمة نشطة لا وجود لها ثم ينهي العملية بصمت.

3. **انهيار `_peerConnection!` عند الفشل:**
   - `_createPeerConnection` يبتلع الاستثناء ويترك `_peerConnection = null`، ثم يستخدم `startCall` معامل `!` ← crash.
   - `acceptCall` قد يكمل بمصافحة ناقصة عند فشل الوسائط.

4. **قيود الوسائط غير صريحة:**
   - تمرير `'video': false/true` كقيم منطقية سجل عنه الـ plugin `getUserMedia(video): null`; الأفضل استخدام خريطة قيود صريحة.
   - لا يوجد fallback عند فشل مسار الفيديو.

## خطوات الإصلاح

### 1. الأذونات
- إضافة `_ensureMediaPermissions(CallType)` في `CallManager`:
  - Android/iOS فقط: طلب `microphone` (+ `camera` لمكالمة الفيديو).
  - إرجاع false عند الرفض.
- إضافة `NSMicrophoneUsageDescription` إلى `ios/Runner/Info.plist`.

### 2. إعادة مسار البدء
- إرجاع `await _networkService.startCall(receiverId, callType)` في `CallManager.startCall` بعد `setLocalDescription` وقبل إرسال offer.
- في حال فشل لاحق: إنهاء المكالمة عبر `endCall` لتفادي رنين معلّق.
- إزالة أسطر DIAG المؤقتة (أو الإبقاء على التسجيل المفيد فقط عبر LogService).

### 3. تحصين إنشاء اتصال الند
- تحويل `_createPeerConnection` إلى `Future<bool>`.
- عند رفض الأذونات أو فشل الوسائط: تنظيف + إرجاع false.
- `startCall`: إن كان false → إنهاء المكالمة والعودة دون crash.
- `acceptCall`: إن كان false → `rejectCall` والعودة.
- قيود صريحة: `{'audio': true, 'video': {'mandatory': {}, 'optional': [{'facingMode': 'user'}]}}` للفيديو، و`false` للصوت.
- Fallback: عند فشل فيديو، إعادة المحاولة صوتياً فقط مع تسجيل واضح.

### 4. التحقق
- `flutter analyze` نظيف.
- `flutter build apk --debug` ناجح.
- `flutter build windows --release` ناجح.
- اختبار ميداني (يتطلب جهازين): مكالمة صوتية ثم فيديو، وتوثيق النتيجة في `STATUS.md`.

## معايير القبول
- [ ] لا توجد استثناءات null-check أثناء بدء/قبول مكالمة.
- [ ] المستلم يستقبل `call_request` ويظهر إشعار المكالمة.
- [ ] المصافحة تكتمل (ICE connected) في الاختبار الميداني.
- [ ] البناءان (APK + Windows) ناجحان.
