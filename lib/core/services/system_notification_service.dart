import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// خدمة الإشعارات الحقيقية للنظام
/// تستخدم flutter_local_notifications لعرض إشعارات في شريط الإشعارات الحقيقي
class SystemNotificationService {
  static final SystemNotificationService _instance =
      SystemNotificationService._internal();
  factory SystemNotificationService() => _instance;
  SystemNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _notificationIdCounter = 1000;

  static const String _channelMessages = 'chat_messages';
  static const String _channelFriends = 'friend_requests';
  static const String _channelSystem = 'system_notifications';
  static const String _channelCalls = 'call_notifications';

  Completer<void>? _initCompleter;

  void Function(String? payload)? onNotificationTap;

  Future<void> initialize() async {
    if (_initialized) return;
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: androidSettings);

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _requestNotificationPermission();
      await _createNotificationChannels();

      _initialized = true;
      debugPrint('SystemNotificationService initialized');
    } catch (e) {
      debugPrint('SystemNotificationService init error: $e');
    } finally {
      _initCompleter!.complete();
      _initCompleter = null;
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await android?.requestNotificationsPermission();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await ios?.requestPermissions(alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('requestNotificationPermission error: $e');
    }
  }

  Future<void> _createNotificationChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    try {
      await android.createNotificationChannel(AndroidNotificationChannel(
        _channelMessages,
        'رسائل الدردشة',
        description: 'إشعارات الرسائل الجديدة من جهات الاتصال والمجموعات',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));

      await android.createNotificationChannel(AndroidNotificationChannel(
        _channelFriends,
        'طلبات الصداقة',
        description: 'إشعارات طلبات الصداقة الجديدة',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ));

      await android.createNotificationChannel(AndroidNotificationChannel(
        _channelSystem,
        'إشعارات النظام',
        description: 'إشعارات النظام والتحديثات',
        importance: Importance.defaultImportance,
        playSound: true,
        enableVibration: true,
      ));

      await android.createNotificationChannel(AndroidNotificationChannel(
        _channelCalls,
        'المكالمات',
        description: 'إشعارات المكالمات الفائتة والواردة',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
    } catch (e) {
      debugPrint('createNotificationChannels error: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('System notification tapped: $payload');
    onNotificationTap?.call(payload);
  }

  Future<int> showNotification({
    required String title,
    required String body,
    String? type,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    try {
      final channelId = _getChannelId(type);
      final androidDetails = AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        channelDescription: _getChannelDescription(channelId),
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      final details = NotificationDetails(android: androidDetails);
      final id = _notificationIdCounter++;

      await _plugin.show(id, title, body, details, payload: payload);
      return id;
    } catch (e) {
      debugPrint('showNotification error: $e');
      return -1;
    }
  }

  String _getChannelId(String? type) {
    switch (type) {
      case 'message':
      case 'group_message':
        return _channelMessages;
      case 'friend_request':
        return _channelFriends;
      case 'call':
        return _channelCalls;
      default:
        return _channelSystem;
    }
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case _channelMessages:
        return 'رسائل الدردشة';
      case _channelFriends:
        return 'طلبات الصداقة';
      case _channelCalls:
        return 'المكالمات';
      default:
        return 'إشعارات النظام';
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case _channelMessages:
        return 'إشعارات الرسائل الجديدة من جهات الاتصال والمجموعات';
      case _channelFriends:
        return 'إشعارات طلبات الصداقة الجديدة';
      case _channelCalls:
        return 'إشعارات المكالمات الفائتة والواردة';
      default:
        return 'إشعارات النظام والتحديثات';
    }
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}
