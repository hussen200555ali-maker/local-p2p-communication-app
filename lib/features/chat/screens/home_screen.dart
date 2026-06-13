import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:badges/badges.dart' as badges;
import 'package:local_social_app/features/call/models/call_model.dart';
import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

// استيراد الخدمات والنماذج والشاشات الأخرى
import '../../../core/services/local_network_service.dart';
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
      onConnectionRequestReceived: (user, socket) {
        if (mounted) _showConnectionRequestDialog(user, socket);
      }, onMessageDeleted: (conversationId, messageId) {  },
      // دعم المكالمات الواردة
      onIncomingCall: (call) {
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

    final connectedFriends = _networkService.getConnectedFriends();
    return ListView.builder(
      itemCount: allFriendIds.length,
      itemBuilder: (context, index) {
        final friendId = allFriendIds[index];
        final friend = User(id: friendId, username: _networkService.getUsernameFromDirectory(friendId));
        final isConnected = connectedFriends.any((u) => u.id == friend.id);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isConnected ? Colors.teal : Colors.grey,
            child: Text(friend.username.isNotEmpty ? friend.username.substring(0, 1).toUpperCase() : '?'),
          ),
          title: Text(friend.username),
          subtitle: Text(isConnected ? 'متصل' : 'غير متصل'),
          trailing: isConnected ? const Icon(Icons.circle, color: Colors.green, size: 14) : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(friend: friend))),
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
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.cyan,
            child: Text(group.name.isNotEmpty ? group.name.substring(0, 1).toUpperCase() : '?'),
          ),
          title: Text(group.name),
          subtitle: Text('${group.memberIds.length} أعضاء'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatScreen(group: group))),
        );
      },
    );
  }

  Widget _buildDiscoveryTab() {
    final discoveredUsers = _networkService.getDiscoveredUsers();
    if (discoveredUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.wifi, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text('جاري البحث عن مستخدمين آخرين...'),
          ],
        ),
      );
    }
    return ListView.builder(
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
