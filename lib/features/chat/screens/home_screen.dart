import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:badges/badges.dart' as badges;
import 'package:local_social_app/features/call/models/call_model.dart';
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

// استيراد الخدمات والنماذج والشاشات الأخرى
import '../../../core/services/local_network_service.dart';
import '../../../core/services/log_service.dart';
import '../../auth/models/user_model.dart';
import '../../auth/screens/login_screen.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../call/call_integration.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final LocalNetworkService _networkService = LocalNetworkService();
  late TabController _tabController;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentUser = _networkService.getCurrentUser();

    WidgetsBinding.instance.addObserver(this);
    _registerServiceCallbacks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _networkService.unregisterCallbacks();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (_currentUser != null) {
        _networkService.start(_currentUser!);
      }
    }
  }

  void _registerServiceCallbacks() {
    _networkService.registerCallbacks(
      onFriendsChanged: () { if (mounted) setState(() {}); },
      onDiscoveryChanged: () { if (mounted) setState(() {}); },
      onGroupsChanged: () { if (mounted) setState(() {}); },
      onNotificationsChanged: () { if (mounted) setState(() {}); },
      onStatusChanged: () { if (mounted) setState(() {}); },
      onConnectionRequestReceived: (user, socket) {
        if (mounted) _showConnectionRequestDialog(user, socket);
      }, onMessageDeleted: (conversationId, messageId) {  },
      // دعم المكالمات الواردة
      onIncomingCall: (call) {
        LogService.d('DIAG UI onIncomingCall fired callType=${call.callType} callerFound=${_networkService.getUserById(call.callerId) != null}');
        if (mounted) {
          final caller = _networkService.getUserById(call.callerId);
          if (caller != null) {
            _showIncomingCallDialog(call, caller);
          }
        }
      },
    );
  }

  void _showConnectionRequestDialog(User requestingUser, dynamic socket) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('طلب صداقة جديد'),
        content: Text('${requestingUser.username} يريد إضافتك كصديق.'),
        actions: [
          TextButton(
            onPressed: () {
              _networkService.rejectConnectionRequest(socket);
              Navigator.of(context).pop();
            },
            child: const Text('رفض'),
          ),
          ElevatedButton(
            onPressed: () {
              _networkService.acceptConnectionRequest(requestingUser, socket);
              Navigator.of(context).pop();
            },
            child: const Text('قبول'),
          ),
        ],
      ),
    );
  }

  void _showIncomingCallDialog(CallModel call, User caller) {
    // استخدم تكامل المكالمات لعرض الشاشة
    context.callIntegration.showIncomingCall(context, call, caller);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('أهلاً، ${_currentUser?.username ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh),
            tooltip: 'بحث عن أصدقاء',
            onPressed: () {
              _networkService.sendDiscoverRequest();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جارٍ البحث...'), duration: Duration(seconds: 2)),
              );
            },
          ),
          IconButton(
            icon: badges.Badge(
              badgeContent: Text(
                _networkService.getNotifications().where((n) => !n.isRead).length.toString(),
                style: const TextStyle(color: Colors.white),
              ),
              showBadge: _networkService.getNotifications().where((n) => !n.isRead).isNotEmpty,
              child: const Icon(Iconsax.notification),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ).then((_) => setState(() {}));
            },
          ),
          IconButton(
            icon: const Icon(Iconsax.profile_circle),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ).then((_) => setState(() {}));
            },
          ),
          // استبدل أيقونة الإعدادات بهذا الويدجت
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                // استدعاء دالة تسجيل الخروج عند اختيارها
                _logout();
              } else if (value == 'call_history') {
                context.callIntegration.showCallHistory(context);
              } else if (value == 'call_settings') {
                context.callIntegration.showCallSettings(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'call_history',
                child: ListTile(
                  leading: Icon(Iconsax.call),
                  title: Text('سجل المكالمات'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'call_settings',
                child: ListTile(
                  leading: Icon(Iconsax.setting_2),
                  title: Text('إعدادات المكالمات'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Iconsax.logout),
                  title: Text('تسجيل الخروج'),
                ),
              ),
            ],
            icon: const Icon(Iconsax.more), // تغيير الأيقونة إلى "المزيد"
          ),

        ],
        bottom: TabBar(

          controller: _tabController,
          labelColor: Colors.white, // <-- لون التبويب النشط
          unselectedLabelColor: Colors.white70, // <-- لون التبويبات غير النشطة
          indicatorColor: Colors.white, // <-- لون المؤشر
          indicatorWeight: 3.0, // <-- زيادة سماكة المؤشر لمظهر أفضل
          tabs: const [
            Tab(icon: Icon(Iconsax.message), text: 'المحادثات'),
            Tab(icon: Icon(Iconsax.people), text: 'المجموعات'),
            Tab(icon: Icon(Iconsax.discover), text: 'استكشاف'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConversationsTab(),
          _buildGroupsTab(),
          _buildDiscoveryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
        backgroundColor: Colors.teal,
        child: const Icon(Iconsax.add, color: Colors.white),
      ),
    );
  }

  Widget _buildConversationsTab() {
    final allFriendIds = _networkService.getFriendIds();
    if (allFriendIds.isEmpty) return const Center(child: Text('ليس لديك أصدقاء بعد.'));

    final userStatuses = _networkService.getUserStatuses();
    return ListView.builder(
      itemCount: allFriendIds.length,
      itemBuilder: (context, index) {
        final friendId = allFriendIds[index];
        final friend = User(id: friendId, username: _networkService.getUsernameFromDirectory(friendId));
        final status = userStatuses[friendId];

        Color avatarColor;
        Color statusDotColor;
        String statusText;

        if (status != null && status.isOnline) {
          // متصل
          avatarColor = Colors.teal;
          statusDotColor = Colors.green;
          statusText = 'متصل';
        } else if (status != null && !status.isOnline && status.lastSeen != null) {
          // غير متصل - تحقق مما إذا كان "جارٍ التحقق" (آخر رؤية حديثة)
          final timeSinceLastSeen = DateTime.now().difference(status.lastSeen!);
          if (timeSinceLastSeen.inSeconds < 70) {
            // جارٍ التحقق
            avatarColor = Colors.orange;
            statusDotColor = Colors.orange;
            statusText = 'جارٍ التحقق...';
          } else {
            // غير متصل
            avatarColor = Colors.grey;
            statusDotColor = Colors.grey.shade400;
            statusText = 'غير متصل';
          }
        } else {
          // لا توجد حالة - غير متصل
          avatarColor = Colors.grey;
          statusDotColor = Colors.grey.shade400;
          statusText = 'غير متصل';
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarColor,
                  child: Text(
                    friend.username.isNotEmpty ? friend.username.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: statusDotColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).cardColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(friend.username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Text(statusText, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            trailing: Icon(Iconsax.arrow_left_2, size: 18, color: Colors.grey.shade400),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(friend: friend))),
          ),
        );
      },
    );
  }

  Widget _buildGroupsTab() {
    final userGroups = _networkService.getUserGroups();
    if (userGroups.isEmpty) return const Center(child: Text('أنت لست عضواً في أي مجموعة بعد.'));

    return ListView.builder(
      itemCount: userGroups.length,
      itemBuilder: (context, index) {
        final group = userGroups[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.cyan.shade600,
              child: Text(
                group.name.isNotEmpty ? group.name.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
            title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Text('${group.memberIds.length} أعضاء', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            trailing: Icon(Iconsax.arrow_left_2, size: 18, color: Colors.grey.shade400),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(group: group))),
          ),
        );
      },
    );
  }

  Widget _buildDiscoveryTab() {
    final discoveredUsers = _networkService.getDiscoveredUsers();
    return RefreshIndicator(
      onRefresh: () async {
        _networkService.triggerRescan();
        await Future.delayed(const Duration(seconds: 2));
      },
      child: discoveredUsers.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Column(
                    children: [
                      Icon(Iconsax.wifi, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('جاري البحث عن مستخدمين آخرين...'),
                    ],
                  ),
                ),
              ],
            )
          : ListView.builder(
              itemCount: discoveredUsers.length,
              itemBuilder: (context, index) {
                final user = discoveredUsers[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(user.username.isNotEmpty ? user.username.substring(0, 1) : '?')),
                  title: Text(user.username),
                  subtitle: const Text('متاح على الشبكة'),
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Iconsax.add),
                    label: const Text('إضافة'),
                    onPressed: () {
                      _networkService.sendConnectionRequest(user);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال طلب صداقة إلى ${user.username}')));
                    },
                  ),
                );
              },
            ),
    );
  }
  // أضف هذه الدالة داخل كلاس _HomeScreenState
  Future<void> _logout() async {
    // إيقاف الخدمة
    await _networkService.stop();

    // مسح البيانات المحفوظة
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // مسح كل شيء

    // التأكد من أن الواجهة لا تزال موجودة قبل الانتقال
    if (mounted) {
      // الانتقال إلى شاشة تسجيل الدخول ومنع العودة للخلف
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

}
