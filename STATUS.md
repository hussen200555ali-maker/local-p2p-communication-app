# STATUS.md — تتبع التقدم

## المرحلة 11: إصلاح القطر الدوري للمقبس — خريطة المقابس المكسورة 🔧 (9 أغسطس 2026)

### الخلفية
بعد نجاح إصلاح سباق START/CHUNK/END (الملف الصغير 813B وصل مع FILE_ACK)، فشل اختبار الملف الكبير (6,375,939B) مرتين بنفس النمط: قطر TCP دوري كل 75-85 ثانية حتى بدون أي نقل. تشريح الكود أثبت أن السبب ليس كود الإرسال بل آلة PING/PONG وخريطة `_userSockets` المكسورة. الخطة معتمدة من كبير المستشارين (تقييم: الإصلاح 1 = السيف، الإصلاح 2 = الدرع، الإصلاح 3 = العقل، الإصلاح 4 = العين).

### السبب الجذري (مؤكد من الكود)
1. `_finalizeConnection` (سطر 1215) يُنفَّذ مرتين على كل جهاز — مرة للمقبس الخارجي (عند RECONNECT_ACK سطر 1045) ومرة للمقبول (عند RECONNECT سطر 1038). آخر من يكتب يفوز في `_userSockets[peer]`.
2. في سباق إعادة الاتصال الثنائي يفوز **المقبس الخارجي الميت**، بينما التدفق الحي (PING الوارد + PONG الصادر) يمر عبر المقبس المقبول **غير المسجّل** في الخريطة.
3. التأجيل 3 ثوانٍ (سطور 1218-1224) يغلق المقبس القديم — أحياناً يقتل المقبس الحي.
4. الهارتبيت يكتب PING للمقبس الميت → لا PONG → `_lastPongTime` قديم → `_checkFriendStatuses` (70s، سطر 669) و`_startTcpPingPong` (25s، سطر 729) يقتلان دورياً.
5. عدم التماثل المؤكد: ali يستقبل PONG كل 20s (0 فجوات) بينما hussen يستقبل 0 × PONG — التدفق وحيد الاتجاه ali→hussen.

### الإصلاحات المعتمدة (من كبير المستشارين)
| # | الإصلاح | الموقع | الوصف |
|---|---------|--------|-------|
| 1 | **حارس نشاط المقبس** (الجذري) | `_finalizeConnection` 1215-1225 + `_setupSocket` 1531 | خريطة `_socketLastActivity` تُحدَّث عند استقبال أي بيانات. عند الاستبدال: إن كان القديم نشطاً (<10 ثوانٍ) والجديد خاملاً → أغلق الجديد واحتفظ بالحي. الخريطة تتقارب على المقبس الحامل للتدفق الفعلي. |
| 2 | **تحديث `_lastPongTime` عند استقبال PING** (الدرع) | معالجة PING سطر 1062 | `_findUserIdBySocket` + تحديث الوقت + رد PONG. استقبال PING يثبت حياة الطرف ويكسر حلقة 70 ثانية حتى لو ضاعت PONG. |
| 3 | **التحقق قبل القتل** (العقل) | `_checkFriendStatuses` 669-672 | استخراج `_pingAndVerify(userId, socket)` (نمط sendMessage 1703-1711). عند تجاوز مهلة 70s: PING فحص 500ms — إن عاد PONG حدّث الوقت فقط، وإن لم يعد عندها فقط `_quickReconnect`. القطع المدمر يصبح الملاذ الأخير المؤكد. |
| 4 | **تشخيص DEBUG** (العين) | معالجات PING/PONG + `_startTcpPingPong` | طباعة `_userSockets[peerId]` والاتجاه لتأكيد تقارب الخريطة وثنائية التدفق في الاختبار الميداني. |

### القيود
- لا تغيير في البروتوكول ولا في الطابور ولا في تنسيق الرسائل.
- لا مساس بـ `_callSockets` / `_finalizeCallSocket` / `_callProtectedSockets` (المكالمات WebRTC).
- يبقى التأجيل 3 ثوانٍ للإغلاق الحقيقي في الحالات غير المتنازع عليها.
- سجلات DEBUG المؤقتة تُبقى — لا تُزل حتى يطلب المستشار صراحة.

### مؤشرات النجاح المخطط لها
| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | 0 أخطاء |
| `flutter test` | 24/24 |
| `flutter build apk --debug` | ناجح |
| تراجع صغير | ✅ 813B + FILE_ACK |
| كبير ~6MB | ✅ وصول 6,375,939B + FILE_ACK + `ls -la` على hussen |
| سجلات DEBUG | الخريطة تقاربت على المقبس الحي + PING/PONG في الاتجاهين (انتهاء عدم التماثل) |
| iptables (DROP 8080 من ali ثم `-D`) | catch ← طابور ← reconnect ← flush ← وصول ← ACK |

### نتائج التنفيذ (9 أغسطس 2026)
- **الإصلاح 1 (حارس نشاط المقبس)**: خريطة `_socketLastActivity` تُحدَّث في `_setupSocket` عند استقبال أي بيانات؛ `_finalizeConnection` يرفض فوراً المقبس الجديد إن كان القديم نشطاً (<10 ثوانٍ)، وإلا يؤجل 3 ثوانٍ للإغلاق الحقيقي.
- **الإصلاح 2 (الدرع)**: معالجة PING تحدّث `_lastPongTime` عبر `_findUserIdBySocket` وتُجيب PONG — استقبال PING يثبت الحياة حتى لو ضاعت PONG.
- **الإصلاح 3 (العقل)**: `_checkFriendStatuses` صار async ويستدعي `_pingAndVerify(userId, socket)` (PING فحص 500ms)؛ القتل/`_quickReconnect` أصبح الملاذ الأخير فقط بعد فشل PONG الفحص.
- **الإصلاح 4 (العين)**: سجلات DEBUG في PING/PONG/`_startTcpPingPong` تُظهر الهوية والاتجاه وتقارب الخريطة.

### مؤشرات النجاح المحققة
| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | ✅ 0 errors |
| `flutter test` | ✅ 24/24 |
| `flutter build apk --debug` | ✅ BUILD SUCCESSFUL (218,438,737 بايت) |
| تثبيت الجهازين | ✅ Success (ali 192.168.1.126 / hussen 192.168.1.127) |
| اختبار الاستقرار >4 دقائق | ✅ ثنائية الاتجاه PING/PONG + `lastPongAge` مثبّت (ali 16-19s، hussen 2-3s) + صفر قطر بعد بدء التشغيل |
| تراجع صغير | ✅ 813B + FILE_ACK (msgId `0aafdba1-dcfb-468a-863b-5afb710e3f19`) |
| كبير ~6MB | ✅ 6,375,939B + FILE_ACK + `ls -la` على hussen (msgId `5e670bc2-670f-4e6c-aae8-6c700ddffd88`) |
| صفر قطر أثناء النقل | ✅ لا zombie/PONG TIMEOUT/quickReconnect/WRITE FAILED خلال نافذة الإرسال |
| سجلات DEBUG | ✅ الخريطة تقاربت + PING/PONG في الاتجاهين (انتهاء عدم التماثل) |
| iptables DROP ثم `-D` | ✅ catch ← طابور ← reconnect ← flush ← وصول 813B ← FILE_ACK على ali |

### تفاصيل الاختبار الميداني
- **التحقق من القرص على hussen** عبر `run-as com.example.local_social_app`: `app_flutter/files/5e670bc2-…_scaled_test_media_large.png` = **6,375,939 بايت** (22:24) و`0aafdba1-…_scaled_phase11_small.png` = **813 بايت** (22:23). المسار المباشر `/data/user/0/...` مرفوض بالأذونات — `app_flutter/files` هو الصحيح (getApplicationDocumentsDirectory).
- **قطرتا بدء التشغيل الوحيدتان** (22:14:52 ali / 22:15:12 hussen): تنظيف مقبس قديم عند التقارب الأولي، لا نمط قطر.
- **iptables — مرحلة الإسقاط**: `su` + `iptables` متاحان على ali؛ `iptables -I OUTPUT -p tcp --dport 8080 -j DROP` (مؤكدة في `-L -n -v`). سجل `ali_ipt.log`: **PONG TIMEOUT → إزالة المقبس + الاحتجاز في الطابور** msgId=`76b8978b-8fbb-416b-a69a-4e2742c18f54` → 3 محاولات `_quickReconnect` فشلت كلها بـ `Connection timed out` (القاعدة تمنع حتى SYN — أسوأ حالات القطع).
- **iptables — مرحلة الاسترداد**: `iptables -D OUTPUT -p tcp --dport 8080 -j DROP` + انتظار 25 ثانية. سجل `hus_ipt2.log`: hussen يكشف `TCP PONG timeout` (22:28:11) → `_removeSocket` → `_quickReconnect` attempt 1/3 → `TCP connected` + RECONNECT/RECONNECT_ACK → `SUCCESS`. ثم `ali_ipt2.log`: ali يستقبل RECONNECT (22:27:49) → `flushQueue: sending FILE msgId=76b8978b bytes=813` → hussen يحفظ `76b8978b-…_scaled_test_media.png size=813` → FILE_ACK → وصل على ali. **الملف المحجوز لم يضِع — استرد كاملاً.**
- **فرق ساعات الأجهزة**: hussen يسبق ali بـ ~24 ثانية (أُعيد قياسه عبر تطابق زمن RECONNECT/RECONNECT_ACK 22:27:49 ali ↔ 22:28:13 hussen).

### خطوات الإنجاز
1. [x] توثيق هذه الجولة في STATUS.md (هذا القسم) — **قبل أي كود**
2. [x] الإصلاحات 1-4 في `local_network_service.dart`
3. [x] `flutter analyze` + `flutter test` + `flutter build apk --debug`
4. [x] تثبيت على ali (192.168.1.126:5555) و hussen (192.168.1.127:5555)
5. [x] اختبارات ميدانية: صغير ← كبير ← iptables + فحص DEBUG
6. [ ] تحديث هذا القسم بالنتائج + الارتكاب الكامل

---

## المرحلة 10: الجولة الختامية — وسائط + بنود كبير المستشارين 📋 (4 أغسطس 2026)

### الخلفية
بعد اكتمال تشخيص الوسائط (المرحلة 9) تبيّن أن الملفات بلا شبكة أمان: لا PING-verify قبل الإرسال، ولا طابور/إعادة عند سقوط منتصف الإرسال، ولا ACK عند المستقبل. تعتمد الجولة الختامية إصلاحين معتمدين للوسائط + بنود كبير المستشارين (C-2, C-3, H-2, H-3, H-4, H-7, H-8, H-10, M-1, H-5, C-1).

### الإصلاحان المعتمدان للوسائط (من المستشار)
| # | الإصلاح | الموقع | الوصف |
|---|---------|--------|-------|
| 1 | **PING-verify قبل إرسال الملف** | `sendFileMessage` (1903-2004) | نسخ آلية `sendMessage` (1694-1714): `_pingCompleters` + `_safeWrite('PING\n')` + مهلة 500ms قبل قراءة الملف. فشل PONG → حذف المقبس بحارس هوية + `_lastPongTime.remove` + `_quickReconnect` + النزول لمسار الطابور. |
| 2 | **شبكة أمان طابور/ACK للملفات** | `sendFileMessage` catch + `_handleFileTransfer` + `_handleTcpMessage` + `flushQueue` | (أ) catch → `_enqueueMessage(msg,'file',fileMetadata)` ثم `_removeSocket` — الاسترداد موجود أصلاً (`_flushPendingQueue` بعد reconnect، و`flushQueue` في `_finalizeConnection`). (ب) `_handleFileTransfer` FILE_END → `FILE_ACK` عبر `_userSockets[state.message.senderId]` + حارس عدم تكرار `_fileMessages`. (ج) `_handleTcpMessage` بعد 1075 → معالجة `FILE_ACK:` (نسخة MSG_ACK 1071-1075). (د) `flushQueue` file path 199-203 → `waitForAck` قبل `markSent` (نسخة مسار النص 218-230). |

### بنود كبير المستشارين (مستوى التصحيح حسب السياق)
| البند | الموقع | الإصلاح |
|-------|--------|---------|
| C-2 | `leaveGroup` 2774+ / `clearChatMessages` 2808 | استخدام `_currentUser!.id` |
| C-3 | `_saveGroups` 2748-2752 | مفتاح `'groups'` ← `'user_groups_v1'` |
| H-2 | text | النص `'التاريخ والوقت'` |
| H-3 | `call_history_screen.dart` 84 | جلب `User` حقيقي عبر `getUserById` بدل الكائن الوهمي |
| H-4 | `call_manager.dart` 165-183 | إزالة `getActiveCalls().first.id` |
| H-7 | edit/delete | تحديث `_allMessages` للمرسل أيضاً |
| H-8 | `insertMessage` 974/1682 | `await` قبل الاستمرار |
| H-10 | `call_manager.dart` `_configuration` 51-57 | تعطيل STUN — `iceServers` فارغة |
| M-1 | `stop()` 220-253 | تنظيف `_typingTimers` (نموذج إلغاء المؤقتات من `stop()` القائم) |
| H-5 | `_handleTcpMessage` فك التشفير | `LogService.e` عند فشل فك التشفير |
| C-1 | `registerCallbacks`/`unregisterCallbacks` 255-331 | إعادة بناء نظام callbacks (كتلة call-callbacks موجودة 321-325) |

### القيود
- لا تغيير في آلية PING/PONG (25s) ولا حجم الحزم (32KB)؛ لا ACK في مسار النجاح المباشر.
- سجلات DEBUG المؤقتة تُبقى — لا تُزل حتى يطلب المستشار صراحة.
- لا تُلمس شفرات مُصلحة سابقاً أو غير مخطئة.
- `flutter analyze` قبل/بعد كل مرحلة؛ `flutter build apk --debug` قبل أي اختبار.

### مؤشرات النجاح المخطط لها
| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | ✅ نظيف قبل وبعد كل مرحلة |
| `flutter build apk --debug` | ✅ قبل الاختبار |
| تراجع صغير | ✅ FILE_ACK عند المرسل |
| كبير ~6MB | ✅ وصول + FILE_ACK |
| iptables (إسقاط 8080 من .124 ثم `-D` فوراً) | ✅ catch ← طابور ← reconnect ← flush ← وصول ← ACK |

### نتائج التنفيذ (4 أغسطس 2026)
- **الإصلاح 1 (PING-verify)**: أُدرج في `sendFileMessage` بعد فحص المقبس (نفس نمط `sendMessage`: `_pingCompleters` + PING + مهلة 500ms)؛ فشل PONG → إزالة المقبس بحارس هوية + `_lastPongTime.remove` + `_enqueueMessage` + `_quickReconnect`.
- **الإصلاح 2 (أ)**: catch في `sendFileMessage` → `_enqueueMessage(msg,'file',fileMetadata)` ثم `_removeSocket(badSocket)` (الملف لم يعد يضيع؛ يسترد تلقائياً بعد reconnect).
- **الإصلاح 2 (ب)**: `_handleFileTransfer` FILE_END → `FILE_ACK` عبر `_userSockets[senderId]` + حارس عدم تكرار الإضافة لـ `_fileMessages`.
- **الإصلاح 2 (ج)**: `_handleTcpMessage` يعالج `FILE_ACK:` (نسخة MSG_ACK → `_queueService.handleAck` + حالة `sent`).
- **الإصلاح 2 (د)**: `flushQueue` مسار الملف → `waitForAck` قبل `markSent` (نسخة مسار النص).
- **بنود كبير المستشارين**:
  - C-2: `leaveGroup`/`clearChatMessages` تنظيف كتلة `{}` الزائدة (تبقى null-safe عبر `_currentUser?.id`).
  - C-3: `_saveGroups` → مفتاح `'user_groups_v1'` (مطابق لمسار التحميل 2229).
  - H-2: `'التاريخ和时间'` ← `'التاريخ والوقت'` (call_history_screen.dart:340).
  - H-3: `_startCall` يبحث `getUserById` ثم fallback (call_history_screen.dart:84).
  - H-4: `startCall` بلا `getActiveCalls().first.id` — بحث محدد بالمستلم (call_manager.dart).
  - H-7: `editMessage`/`deleteMessage` تحدّث `_allMessages` للمرسل + `_saveAllMessages`.
  - H-8: `await _dbService.insertMessage` في `sendMessage` + `_handleTcpMessage` (صار `Future<void>`).
  - H-10: `iceServers` فارغة — STUN معطّل (call_manager.dart `_configuration`).
  - M-1: `stop()` يلغي ويمسح `_typingTimers`.
  - H-5: `decryptText` يسجّل `LogService.e` عند فشل فك التشفير.
  - C-1: call-callbacks صارت دائمة — `unregisterCallbacks` لم تعد تمسحها (كانت تُقتل نهائياً بعد أي screen dispose)؛ `onIncomingCall` تحوّلت لقائمة مستمعين multicast (ملكية مشتركة: CallManager + home_screen).

### مؤشرات النجاح المحققة
| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | ✅ 0 errors — 33 issues (نفس خط الأساس: 4 warnings + 29 infos، لا جديد) |
| `flutter test` | ✅ 24/24 passed |
| `flutter build apk --debug` | ✅ BUILD SUCCESSFUL — app-debug.apk (218MB) |

### الحالة
- [x] توثيق هذه الجولة في STATUS.md (هذا القسم)
- [x] الإصلاح 1 (PING-verify) + الإصلاح 2 (أ/ب/ج/د)
- [x] بنود C (C-2, C-3) ثم H (H-2, H-3, H-4, H-7, H-8, H-10) ثم M-1/H-5/C-1
- [x] `flutter analyze` + `flutter test` + `flutter build apk --debug`
- [ ] تثبيت push/`pm install -r` على الجهازين — **مؤجل**: الجهازان (192.168.1.124/.125) غير قابلين للوصول (ping و `adb connect` يفشلان) — قرار المستخدم: اكتفِ بالتعديلات والبناء الناجح
- [ ] اختبارات التحقق (صغير، كبير، iptables) — **مؤجل** بنفس السبب
- [ ] تقرير النتائج النهائية للمستشار — يسبقه إنجاز الاختبارات الميدانية

---

## المرحلة 8: إصلاح فشل تسليم الرسائل TCP (0/10) ✅ (4 أغسطس 2026)

### الخلفية
اختبار 10 رسائل متتالية بين المحاكيين (ali=.124 يرسل إلى hussen=.125) عبر uiautomator: **0/10 وصلت**. كل رسالة تصل إلى `sendMessage` وعلى الفور يفشل `socket.write('PING\n')` رمياً استثناءً متزامناً لأن المقبس في `_userSockets[receiverId]` ميت بالفعل.

### السبب الجذري (موثّق بالكامل من السجلين)
1. **المقبس يموت بصمت قبل كل إرسال**: المستلم يرى `Socket onDone (remote closed)` قبل 300-500ms من محاولة الإرسال (مثال: `15:52:20.338` عند المستقبل مقابل `sendMessage: attempting` عند `15:52:20.803`).
2. **لا يوجد كود تطبيق يعمل لحظة الموت**: المرسل صامت تماماً 7 ثوانٍ بين `SUCCESS, new socket` (13.687) والإرسال التالي (20.803) — لا PING/PONG ولا مؤقت ولا onDone/onError قبل فشل الكتابة.
3. **العاصفة الحقيقية**: `_finalizeConnection` يغلق المقبس السابق فوراً عند كل RECONNECT/RECONNECT_ACK (السطر 1205) → FIN للطرف الآخر → `onDone` → `_removeSocket` → `_quickReconnect` → اتصال جديد → إغلاق جديد. شوهد في سجل المستقبل: `Finalized connection` مرتين + `onDone` مرتين في 200ms.
4. **ميكانيزمان متزامنان لإعادة الاتصال** (`_quickReconnect` و `_improvedReconnectToFriend`) لا يحرس أحدهما الآخر → اتصالات متوازية تنافسية.
5. **sendMessage يستسلم**: عند فشل PING يحذف المقبس ويُدخل الرسالة في الطابور ويتوقف — بدون إعادة اتصال فورية وإعادة إرسال.

### الإصلاح المعتمد (من المستشار الأعلى — الخيار أ)
| # | الإصلاح | الموقع | الوصف |
|---|---------|--------|-------|
| 1 | **Single-flight reconnect** | `_quickReconnect` (1306) + `_improvedReconnectToFriend` (1612) | حارس متقاطع: `_quickReconnect` يخرج مبكراً إذا `_pendingConnections[userId]==true`، و `_improvedReconnectToFriend` يخرج مبكراً إذا `_quickReconnecting.contains(friendId)`. لا محاولتان لنفس الصديق في وقت واحد. |
| 2 | **لا إغلاق مبكر للمقبس السابق** | `_finalizeConnection` (1201) | استبدال `_safeSocketClose(existingSocket)` الفوري بإغلاق مؤجل (3 ثوانٍ) عبر `_pendingOldSocketClosers` مع فحص هوية: يُغلق فقط إذا لم يعد في الخريطة. يمنع FIN المبكر الذي يشعل العاصفة. |
| 3 | **إعادة اتصال + إعادة إرسال عند فشل PING** | `sendMessage` (1665) | عند فشل PING/PONG (أو مقبس `done`): أزل المقبس، أدخل الرسالة في الطابور، انتظر `_quickReconnect`، ثم `_flushPendingQueue` للرسائل غير المؤكدة. |

### ما لم يُفعل (حسب التوجيه)
- لا تعديل على VirtualBox أو الشبكة.
- لا سجلات هوية مقبس (فقط إذا فشل الإصلاح أ).

### مؤشرات النجاح
| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | ✅ نظيف — لا أخطاء (تحذيرات/ملاحظات سابقة فقط) |
| `flutter build apk --debug` | ✅ نجح (Gradle assembleDebug 542.9s) |
| إعادة اختبار 10 رسائل | ✅ **10/10** — تأكيد ثلاثي: 10 ACK عند المرسل + 10 "MSG saved and delivered" عند المستقبل + test1..test10 مطابقة بالمعرّف في قاعدة بيانات المستقبل (SQLite). |

### ملاحظات التنفيذ (4 أغسطس 2026)
- تم تثبيت APK على الجهازين عبر push + `pm install -r` (الأمر المباشر `adb install` يتجمد).
- عند كل إرسال يسقط المقبس أثناء `PING` (البيئة)، لكن الإصلاحات تلتقطه: PONG TIMEOUT → إعادة اتصال → `Flushed 1 pending` → ACK. التسليم أصبح موثوقاً رغم سقوط المقبس المتكرر.
- ملاحظة: يظهر في السجلات ازدواج `Finalized connection` (RECONNECT + RECONNECT_ACK على نفس المقبس) وسقوط دوري ~3 ثوانٍ بعد إعادة الاتصال بسبب سباق التوصيل المزدوج (كلا الطرفين يبدأ إعادة الاتصال) — لم يمنع التسليم، ويستحق المراجعة لاحقاً.

### الحسم
- ✅ **مشكلة "الرسائل تعلق بعد السابعة" حُلّت.** اختبار 10 رسائل متتالية (test1..test10) بين ali=.124 و hussen=.125 أُعيد بعد الإصلاحات ووُصّلت الرسائل العشر بالكامل (10/10) بتأكيد ثلاثي: 10 ACK عند المرسل + 10 "MSG saved and delivered" عند المستقبل + مطابقة المعرّفات في SQLite.
- **ملاحظة مؤجلة بقرار المستشار**: تحسين الازدواج (سباق التوصيل المزدوج والسقوط الدوري) لا يُلمس الآن — يُعالج في جولة تحسينات لاحقة.

### حالة ختامية
الجولة منتهية — ملف "الرسائل لا تصل" مغلق.

---

## المرحلة 9: تشخيص فشل إرسال الوسائط (الصور والملفات) 🔍 (4 أغسطس 2026)

### المشكلة
الوسائط تظهر "فشل" للمرسل ولا تصل للمستقبل. النص يعمل (10/10) لأن له شبكة أمان (PING-verify + طابور + إعادة إرسال)، بينما الملفات **لا تملكها**.

### الفرضيات المعتمدة (من فحص الكود)
| # | الفرضية | الموقع |
|---|---------|--------|
| H1 🔴 | المقبس يموت أثناء الإرسال المباشر → `_safeWrite` يرمي → catch → حذف المقبس → الملف يضيع نهائياً (لا طابور ولا إعادة) | `sendFileMessage` (1903-1990) |
| H2 🟡 | لا يوجد PING-verify قبل إرسال الملف (بخلاف `sendMessage`) | 1903 مقابل 1680 |
| H3 🟡 | لا يوجد ACK للملفات — `flushQueue` يستخدم `markSent` بلا تأكيد | `message_queue_service.dart` 148-204 |
| H4 ⚪ | `utf8.decode(data)` لكل حزمة — انقسام حرف عربي عبر حزمتين يرمي استثناء | `_setupSocket` 1523 |
| H5 ⚪ | مصدر أيقونة "فشل": `_messageStatuses[file.id]` لا يُضبط للإرسال المباشر | `chat_screen.dart` 581 |

### أجهزة القياس المؤقتة (تُزال بعد التقرير)
- `sendFileMessage`: بعد `exists()` + نتيجة كل `_safeWrite` (START/حزم/END) + في `catch` (هل دخل الطابور؟ هل أُبلغ المرسل؟) + مسار الطابور عند غياب المقبس.
- `_handleFileTransfer`: عدد الحزم/بايت كل حزمة + نتيجة FILE_END + "حزمة بلا نقل نشط".
- `flushQueue` (file): محاولة الإرسال + `markSent`/`markFailed`.

### إعادة الإنتاج (خطة)
صورة صغيرة واحدة أولاً (دفع + media-scan على .124) → إرسال عبر المعرض → فحص سجل المُستقبِل + `files/` + SQLite → صورة أكبر ثانياً.

### نتائج التشخيص (فُضِّلت وأُنجزت 4 أغسطس 2026)
- **لم يتكرر الفشل في البناء الحالي.** كلا الاختبارين نجحا طرف-لطرف:
  - صورة صغيرة `scaled_test_media.png` (813 B): START → chunk واحد → END، حُفظت عند المستقبل، ظهرت في واجهته.
  - صورة كبيرة `scaled_test_media_large.png` (6,375,939 B، 195 حزمة 32KB): الإرسال استغرق ~51 ثانية، اكتمل، حُفظت كاملة عند المستقبل، ظهرت في الواجهتين.
- **المقبس يموت أثناء/بعد الإرسال الطويل**: بسبب انشغال المقبس في حلقة إرسال 195 حزمة، تأخر PONG >25 ثانية → `TCP PONG timeout` → حذف المقبس → إعادة اتصال (`_quickReconnect`). في هذين الاختبارين سقط المقبس **بعد** FILE_END فلم يضِع الملف.
- **H1 مؤكَّد كمخاطرة كامنة (لم تُفعَّل هذه المرة)**: لو سقط المقبس في منتصف الحزم لرمى `_safeWrite` → catch في `sendFileMessage` يحذف المقبس فقط (لا طابور، لا إعادة، لا حالة فشل) → الملف يضيع نهائياً. دليل: ملفات `temp_*` يتيمة عند المستقبل من إرسالات فاشلة سابقة (`temp_562c3b41…` 3.5MB بتاريخ 31/7، و`temp_8cc66099…` 0 بايت بتاريخ 1/8).
- **H5 مؤكَّد جزئياً**: الإرسال المباشر لا يضبط `_messageStatuses[file.id]` أبداً → لا يمكن أن تظهر أيقونة "فشل" من هذا المسار؛ أي "فشل" ظهر سابقاً هو من سقوط منتصف الإرسال قبل إصلاح A (الملف كان يختفي صامتاً).
- **H3 مؤكَّد**: `_handleFileTransfer` لا يرسل ACK أبداً — `flushQueue` يعتمد `markSent` بلا تأكيد (يؤثر على مسار الطابور فقط).
- لا تحذيرات "حزمة بلا نقل نشط" ولا أي فشل FILE_TRANSFER في الجولة (التحقق: `grep` كامل السجلين).

### القيد
**لا إصلاح** — تشخيص فقط. تقرير يحدد "في أي سطر يختفي الملف" قبل أي تعديل. (إجابة التقرير: في السطر الحالي لا يختفي؛ نقطة الخطر هي catch في `sendFileMessage` مع سقوط منتصف الإرسال.)

---

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

---

## إعادة تصميم نظام الاستكشاف - المرحلة 1 ✅ (1 أغسطس 2026)

### ما تم
| الفحص | النتيجة |
|-------|---------|
| `flutter analyze` | 0 errors ✅ |
| `flutter build apk --debug` | BUILD SUCCESSFUL ✅ |
| تثبيت على hussen (192.168.1.124) | SUCCESS ✅ |
| تثبيت على ali (192.168.1.125) | SUCCESS ✅ |
| كشف USER_ONLINE | يعمل على الجهازين ✅ |
| اتصال TCP بعد USER_ONLINE | يعمل ✅ |
| خادم TCP 8080 | يعمل على الجهازين ✅ |
| TCP Scan | يعمل ✅ |

### التعديلات المطبقة

| # | التعديل | الموقع | الوصف |
|---|---------|--------|-------|
| 1 | **إصلاح duplicate _performAnnouncement()** | `local_network_service.dart:532` | حذف النسخة القديمة والاحتفاظ بالجديدة التي تستدعي `_broadcastOnlineStatus()` |
| 2 | **_startAnnouncing() → _sendInitialOnlineAnnouncement()** | `local_network_service.dart:537-544` | إرسال 3 إعلانات USER_ONLINE عند بدء التشغيل مع 500ms بين كل واحدة |
| 3 | **_sendOfflineAnnouncement()** | `local_network_service.dart:546-558` | إرسال USER_OFFLINE عند إيقاف الخدمة |
| 4 | **_broadcastOnlineStatus()** | `local_network_service.dart:560-578` | إرسال USER_ONLINE للحفاظ على الاتصال (كل 60 ثانية) |
| 5 | **sendDiscoverRequest()** | `local_network_service.dart:580-593` | إرسال DISCOVER_REQUEST يدوياً (زر التحديث) |
| 6 | **_handleDiscoveryMessage()** | `local_network_service.dart:770-817` | توجيه الرسائل حسب النوع: USER_ONLINE, USER_OFFLINE, DISCOVER_REQUEST, LEGACY |
| 7 | **_handleUserOnline()** | `local_network_service.dart:836-868` | معالجة USER_ONLINE: تحديث الدليل، تحديث الحالة، محاولة اتصال TCP |
| 8 | **_handleUserOffline()** | `local_network_service.dart:870-891` | معالجة USER_OFFLINE: تحديث الحالة، إغلاق TCP |
| 9 | **_handleDiscoverRequest()** | `local_network_service.dart:893-903` | معالجة DISCOVER_REQUEST: الرد بـ USER_ONLINE |
| 10 | **_handleLegacyDiscover()** | `local_network_service.dart:905-933` | للتوافق مع الإصدارات القديمة |
| 11 | **_startHeartbeatSystem()** | `local_network_service.dart:620-641` | نظام جديد: USER_ONLINE كل 60 ثانية + TCP PING/PONG كل 20 ثانية |
| 12 | **_checkFriendStatuses()** | `local_network_service.dart:644-670` | فحص حالة الأصدقاء وتحديثها (مهلة 70 ثانية) |
| 13 | **_updateFriendStatus()** | `local_network_service.dart:673-683` | تحديث حالة صديق معين |
| 14 | **_startTcpPingPong()** | `local_network_service.dart:686-711` | TCP PING/PONG كل 20 ثانية للحفاظ على الاتصالات حية |
| 15 | **_handleFriendDisconnected()** | `local_network_service.dart:713-723` | معالجة انقطاع صديق (بدون إرسال UDP) |

### النتائج من السجلات

**hussen (192.168.1.124):**
- ✅ تلقى USER_ONLINE من ali
- ✅ حاول اتصال TCP بعد USER_ONLINE
- ✅ خادم TCP 8080 يعمل
- ✅ TCP Scan مكتمل (192.168.1.x)
- ✅ اتصال TCP مع ali (192.168.1.125) ناجح
- ✅ الخدمة بدأت كـ v7.1

**ali (192.168.1.125):**
- ✅ تلقى USER_ONLINE من hussen
- ✅ حاول اتصال TCP بعد USER_ONLINE
- ✅ خادم TCP 8080 يعمل
- ✅ TCP Scan مكتمل (192.168.1.x)
- ✅ اتصال TCP مع hussen (192.168.1.124) ناجح
- ✅ أرسل 3 إعلانات USER_ONLINE عند بدء التشغيل

### البروتوكول الجديد (v7.1)

| الرمز | النوع | الوصف |
|-------|-------|-------|
| `USER_ONLINE` | UDP | إرسال عند بدء التشغيل + كل 60 ثانية (Keep-Alive) |
| `USER_OFFLINE` | UDP | إرسال عند إيقاف الخدمة |
| `DISCOVER_REQUEST` | UDP | إرسال يدوياً (زر التحديث) |
| `PING` | TCP | إرسال كل 20 ثانية للحفاظ على الاتصال |
| `PONG` | TCP | رد على PING |
| `DISCOVER_TCP` | TCP | كشف عبر TCP (بدلاً من UDP broadcast) |
| `DISCOVER_TCP_RESPONSE` | TCP | رد على DISCOVER_TCP |

### الخطوات التالية

- [ ] المرحلة 2: اختبار timeout 70 ثانية وتحديث الحالة
- [ ] المرحلة 3: إضافة زر التحديث في home_screen.dart
- [ ] المرحلة 4: تحديث نقاط الحالة (أخضر/برتقالي/رمادي)
- [ ] المرحلة 5: اختبار 8 سيناريوهات
