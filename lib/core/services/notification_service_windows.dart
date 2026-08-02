import 'dart:async';

class NotificationServiceWindows {
  static final NotificationServiceWindows _instance = NotificationServiceWindows._internal();
  factory NotificationServiceWindows() => _instance;
  NotificationServiceWindows._internal();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  void Function(String? payload)? onNotificationTap;

  Future<int> showNotification({
    String? title,
    String? body,
    String? type,
    String? payload,
  }) async {
    return -1;
  }

  Future<void> cancel(int id) async {}

  Future<void> cancelAll() async {}
}
