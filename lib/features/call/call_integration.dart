import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/services/local_network_service.dart';
import '../../../features/auth/models/user_model.dart';
import 'models/call_model.dart';
import 'screens/call_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'screens/call_history_screen.dart';
import 'screens/call_settings_screen.dart';
import 'services/call_manager.dart';

/// تكامل نظام المكالمات الاحترافي مع بقية التطبيق
/// يوفر واجهة بسيطة لاستخدام جميع ميزات نظام المكالمات
class CallIntegration {
  static final CallIntegration _instance = CallIntegration._internal();
  factory CallIntegration() => _instance;
  CallIntegration._internal();

  final CallManager _callManager = CallManager();
  bool _isInitialized = false;

  /// تهيئة نظام المكالمات
  Future<void> initialize() async {
    if (_isInitialized) return;

    // **الإصلاح**: التأكد من انتظار اكتمال التهيئة بشكل صحيح
    await _callManager.initialize();
    _isInitialized = true;
  }

  /// بدء مكالمة جديدة
  Future<void> startCall(BuildContext context, User friend, CallType callType) async {
    if (!context.mounted) return;
    await initialize();
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          friend: friend,
          isCaller: true,
          callType: callType,
        ),
      ),
    );
  }

  /// عرض شاشة المكالمات الواردة
  void showIncomingCall(BuildContext context, CallModel call, User caller) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingCallScreen(
          call: call,
          caller: caller,
          onAccept: () => _callManager.acceptCall(call.id),
          onReject: () => _callManager.rejectCall(call.id),
        ),
      ),
    );
  }

  /// عرض شاشة سجل المكالمات
  void showCallHistory(BuildContext context) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CallHistoryScreen(),
      ),
    );
  }

  /// عرض شاشة إعدادات المكالمات
  void showCallSettings(BuildContext context) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CallSettingsScreen(),
      ),
    );
  }

  /// إنشاء أزرار المكالمات لواجهة المستخدم
  Widget buildCallButtons(BuildContext context, User friend) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // زر المكالمة الصوتية
        FloatingActionButton(
          heroTag: "audio_call",
          onPressed: () => startCall(context, friend, CallType.audio),
          backgroundColor: Colors.green,
          child: const Icon(Iconsax.call),
        ),

        // زر المكالمة المرئية
        FloatingActionButton(
          heroTag: "video_call",
          onPressed: () => startCall(context, friend, CallType.video),
          backgroundColor: Colors.blue,
          child: const Icon(Iconsax.video),
        ),
      ],
    );
  }

  /// إنشاء قائمة خيارات المكالمات
  List<PopupMenuEntry<String>> buildCallMenuOptions(BuildContext context, User friend) {
    return [
      PopupMenuItem<String>(
        value: 'audio_call',
        child: ListTile(
          leading: const Icon(Iconsax.call, color: Colors.green),
          title: const Text('مكالمة صوتية'),
          onTap: () => startCall(context, friend, CallType.audio),
        ),
      ),
      PopupMenuItem<String>(
        value: 'video_call',
        child: ListTile(
          leading: const Icon(Iconsax.video, color: Colors.blue),
          title: const Text('مكالمة فيديو'),
          onTap: () => startCall(context, friend, CallType.video),
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'call_history',
        child: ListTile(
          leading: const Icon(Iconsax.clock),
          title: const Text('سجل المكالمات'),
          onTap: () => showCallHistory(context),
        ),
      ),
      PopupMenuItem<String>(
        value: 'call_settings',
        child: ListTile(
          leading: const Icon(Iconsax.setting_2),
          title: const Text('إعدادات المكالمات'),
          onTap: () => showCallSettings(context),
        ),
      ),
    ];
  }

  /// التحقق مما إذا كان المستخدم متصل قبل بدء المكالمة
  Future<bool> canStartCall(BuildContext context, String userId) async {
    final networkService = LocalNetworkService();
    final isConnected = networkService.getConnectedFriends().any((u) => u.id == userId);

    if (networkService.isFriendDoubtful(userId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جارٍ التحقق من الاتصال. يرجى الانتظار...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    if (!isConnected && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن إجراء مكالمة. المستخدم غير متصل.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  /// بدء مكالمة مع التحقق من الاتصال
  Future<void> startCallWithCheck(BuildContext context, User friend, CallType callType) async {
    final canCall = await canStartCall(context, friend.id);
    if (canCall && context.mounted) {
      await startCall(context, friend, callType);
    }
  }

  /// إنشاء أزرار المكالمات مع التحقق من الاتصال
  Widget buildCallButtonsWithCheck(BuildContext context, User friend) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // زر المكالمة الصوتية
        FloatingActionButton(
          heroTag: "audio_call",
          onPressed: () => startCallWithCheck(context, friend, CallType.audio),
          backgroundColor: Colors.green,
          child: const Icon(Iconsax.call),
        ),

        // زر المكالمة المرئية
        FloatingActionButton(
          heroTag: "video_call",
          onPressed: () => startCallWithCheck(context, friend, CallType.video),
          backgroundColor: Colors.blue,
          child: const Icon(Iconsax.video),
        ),
      ],
    );
  }
}

/// امتداد لاستخدام نظام المكالمات بسهولة
extension CallIntegrationExtension on BuildContext {
  /// الوصول إلى تكامل المكالمات
  CallIntegration get callIntegration => CallIntegration();

  /// بدء مكالمة صوتية
  Future<void> startAudioCall(User friend) async {
    await callIntegration.startCallWithCheck(this, friend, CallType.audio);
  }

  /// بدء مكالمة مرئية
  Future<void> startVideoCall(User friend) async {
    await callIntegration.startCallWithCheck(this, friend, CallType.video);
  }

  /// عرض شاشة سجل المكالمات
  void showCallHistory() {
    callIntegration.showCallHistory(this);
  }

  /// عرض شاشة إعدادات المكالمات
  void showCallSettings() {
    callIntegration.showCallSettings(this);
  }
}
