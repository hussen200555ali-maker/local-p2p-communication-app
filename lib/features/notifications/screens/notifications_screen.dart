import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../core/services/local_network_service.dart';
import '../models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final LocalNetworkService _networkService = LocalNetworkService();
  List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _notifications = _networkService.getNotifications();

    // **الإصلاح**: تسجيل دالة رد النداء للإشعارات
    _networkService.onNotificationsChanged = () {
      if (mounted) {
        setState(() {
          // إعادة تحميل الإشعارات من الخدمة عند حدوث تغيير
          _notifications = _networkService.getNotifications();
        });
      }
    };

    // تعليم الكل كمقروء عند فتح الشاشة
    _networkService.markAllNotificationsAsRead();
  }

  @override
  void dispose() {
    // **الإصلاح**: إلغاء تسجيل دالة رد النداء عند إغلاق الشاشة
    _networkService.onNotificationsChanged = null;
    super.dispose();
  }

  IconData _getIconForNotificationType(String type) {
    switch (type) {
      case 'message': return Iconsax.message;
      case 'group_message': return Iconsax.messages_2;
      case 'friend_request': return Iconsax.user_add;
      case 'system': return Iconsax.info_circle;
      default: return Iconsax.notification;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.trash),
            tooltip: 'حذف كل الإشعارات',
            onPressed: _notifications.isEmpty ? null : () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('تأكيد الحذف'),
                  content: const Text('هل أنت متأكد من رغبتك في حذف جميع الإشعارات؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () {
                        // استخدام نسخة من القائمة لتجنب التعديل أثناء التكرار
                        final idsToRemove = _notifications.map((n) => n.id).toList();
                        for (var id in idsToRemove) {
                          _networkService.removeNotification(id);
                        }
                        Navigator.of(context).pop();
                      },
                      child: const Text('حذف', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.notification_bing, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد إشعارات لعرضها', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return ListTile(
            leading: Icon(
              _getIconForNotificationType(notification.type),
              color: notification.isRead ? Colors.grey : Theme.of(context).primaryColor,
            ),
            title: Text(
              notification.title,
              style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold),
            ),
            subtitle: Text(notification.body),
            onTap: () {
              _networkService.markNotificationAsRead(notification.id);
              // TODO: Implement navigation based on notification type
            },
          );
        },
      ),
    );
  }
}
