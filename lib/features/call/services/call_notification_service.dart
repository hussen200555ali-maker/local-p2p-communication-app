import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/services/system_notification_service.dart';
import '../../auth/models/user_model.dart';
import '../models/call_model.dart';

/// خدمة الإشعارات المتخصصة للمكالمات
class CallNotificationService {
  static final CallNotificationService _instance = CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  int? _activeCallNotificationId;

  Future<void> initialize() async {
    await SystemNotificationService().initialize();
  }

  Future<void> showIncomingCallNotification({
    required CallModel call,
    required User caller,
    required VoidCallback onAccept,
    required VoidCallback onReject,
  }) async {
    try {
      final id = await SystemNotificationService().showNotification(
        title: 'مكالمة واردة',
        body: '${caller.username} - ${call.callType == CallType.video ? "مكالمة فيديو" : "مكالمة صوتية"}',
        type: 'call',
        payload: 'incoming_call:${call.id}',
      );
      if (id > 0) _activeCallNotificationId = id;
    } catch (e) {
      debugPrint('Failed to show incoming call notification: $e');
    }
  }

  Future<void> showActiveCallNotification({
    required CallModel call,
    required User otherUser,
    int duration = 0,
  }) async {
    final minutes = (duration ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration % 60).toString().padLeft(2, '0');
    final durationText = '$minutes:$seconds';

    try {
      if (_activeCallNotificationId != null) {
        await SystemNotificationService().cancel(_activeCallNotificationId!);
      }
      final id = await SystemNotificationService().showNotification(
        title: 'مكالمة نشطة',
        body: '${otherUser.username} - $durationText',
        type: 'call',
        payload: 'active_call:${call.id}',
      );
      if (id > 0) _activeCallNotificationId = id;
    } catch (e) {
      debugPrint('Failed to show active call notification: $e');
    }
  }

  Future<void> showMissedCallNotification({
    required CallModel call,
    required User caller,
  }) async {
    try {
      await SystemNotificationService().showNotification(
        title: 'مكالمة فائتة',
        body: 'مكالمة فائتة من ${caller.username}',
        type: 'call',
        payload: 'missed_call:${call.id}',
      );
    } catch (e) {
      debugPrint('Failed to show missed call notification: $e');
    }
  }

  Future<void> cancelActiveCallNotification() async {
    if (_activeCallNotificationId != null) {
      await SystemNotificationService().cancel(_activeCallNotificationId!);
      _activeCallNotificationId = null;
    }
  }

  bool get isInitialized => true;
  bool get hasActiveNotification => _activeCallNotificationId != null;
}
