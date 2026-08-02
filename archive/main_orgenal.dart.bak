// =================================================================================
// 🚀 Local Social App - The Stable Build (v6.1) - FIXED RECONNECTION
// 🏗 Architecture: UUID Identity + Dynamic IP Directory + Robust Reconnection
// 🧑‍💻 Re-engineered from the ground up for stability by Manus.
// 📝 This code includes all fixes for connection and heartbeat issues.
// =================================================================================

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
// -->> إضافة استيراد badges <<--
import 'package:badges/badges.dart' as badges;

// =================================================================================
// 🏁 App Entry Point
// =================================================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LocalSocialApp());
}

// =================================================================================
// 📦 Data Models
// =================================================================================

class User {
  final String id; // UUID
  final String username;
  User({required this.id, required this.username});
  Map<String, dynamic> toJson() => {'id': id, 'username': username};
  factory User.fromJson(Map<String, dynamic> json) => User(id: json['id'], username: json['username']);
}

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  Message({required this.id, required this.senderId, required this.receiverId, required this.content, required this.timestamp});
  Map<String, dynamic> toJson() => {'id': id, 'senderId': senderId, 'receiverId': receiverId, 'content': content, 'timestamp': timestamp.toIso8601String()};
  factory Message.fromJson(Map<String, dynamic> json) => Message(id: json['id'], senderId: json['senderId'], receiverId: json['receiverId'], content: json['content'], timestamp: DateTime.parse(json['timestamp']));
}

// =================================================================================
// 📦 New Data Models for Phase 1
// =================================================================================
class Group {
  final String id;
  final String name;
  String adminId; // إزالة final
  final List<String> memberIds;
  final DateTime createdAt;

  Group({required this.id, required this.name, required this.adminId, required this.memberIds, required this.createdAt});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'adminId': adminId,
    'memberIds': memberIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'],
    name: json['name'],
    adminId: json['adminId'],
    memberIds: List<String>.from(json['memberIds']),
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final DateTime timestamp;

  GroupMessage({required this.id, required this.groupId, required this.senderId, required this.content, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'senderId': senderId,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
    id: json['id'],
    groupId: json['groupId'],
    senderId: json['senderId'],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class FileMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String fileName;
  final String fileType;
  final int fileSize;
  String filePath; // إزالة final
  final DateTime timestamp;

  FileMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.filePath, // تحديث البارامتر
    required this.timestamp
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'fileName': fileName,
    'fileType': fileType,
    'fileSize': fileSize,
    'filePath': filePath,
    'timestamp': timestamp.toIso8601String(),
  };

  factory FileMessage.fromJson(Map<String, dynamic> json) => FileMessage(
    id: json['id'],
    senderId: json['senderId'],
    receiverId: json['receiverId'],
    fileName: json['fileName'],
    fileType: json['fileType'],
    fileSize: json['fileSize'],
    filePath: json['filePath'], // تحديث هذا السطر
    timestamp: DateTime.parse(json['timestamp']),
  );
}

// =================================================================================
// 📦 New Data Models for Phase 2
// =================================================================================

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'message', 'friend_request', 'group_invite', 'system'
  final Map<String, dynamic>? data; // بيانات إضافية
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'],
    title: json['title'],
    body: json['body'],
    type: json['type'],
    data: json['data'],
    timestamp: DateTime.parse(json['timestamp']),
    isRead: json['isRead'] ?? false,
  );
}

class UserStatus {
  final String userId;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool isTyping;
  final String? currentChatId;

  UserStatus({
    required this.userId,
    required this.isOnline,
    this.lastSeen,
    this.isTyping = false,
    this.currentChatId,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'isOnline': isOnline,
    'lastSeen': lastSeen?.toIso8601String(),
    'isTyping': isTyping,
    'currentChatId': currentChatId,
  };

  factory UserStatus.fromJson(Map<String, dynamic> json) => UserStatus(
    userId: json['userId'],
    isOnline: json['isOnline'],
    lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    isTyping: json['isTyping'] ?? false,
    currentChatId: json['currentChatId'],
  );
}

// =================================================================================
// 🧠 LocalNetworkService - The Mastermind (Re-engineered)
// =================================================================================

class LocalNetworkService {
  static final LocalNetworkService _instance = LocalNetworkService._internal();
  factory LocalNetworkService() => _instance;
  LocalNetworkService._internal();

  // Core Components
  final NetworkInfo _networkInfo = NetworkInfo();
  User? _currentUser;
  RawDatagramSocket? _broadcastSocket;
  ServerSocket? _serverSocket;
  Timer? _announcementTimer;
  Timer? _reconnectTimer;

  // Data Directories & State
  final Map<String, String> _ipDirectory = {}; // [Key: UserID, Value: IP Address]
  final Map<String, String> _userDirectory = {}; // [Key: UserID, Value: Username]
  final Map<String, Socket> _userSockets = {}; // Active TCP connections
  final List<String> _friendIds = [];
  final Map<String, List<Message>> _allMessages = {};
  List<User> _discoveredUsers = [];

  // -->> إضافة جديدة: تتبع محاولات إعادة الاتصال <<--
  final Map<String, DateTime> _reconnectAttempts = {};
  final Map<String, int> _reconnectCounters = {};

  // -->> إضافة جديدة: آلية كول باك لتحديث الواجهة <<--
  VoidCallback? _updateUICallback;

  // -->> إضافة جديدة: لتتبع نبضات القلب <<--
  Timer? _heartbeatTimer;
  final Map<String, Timer> _pongTimers = {}; // لتتبع استجابات PONG
  final Map<String, int> _heartbeatFailCount = {}; // تتبع عدد مرات فشل القلب

  // -->> إضافة جديدة: متغيرات تشخيصية للواجهة <<--
  final StreamController<Map<String, String>> _diagnosticsController = StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get diagnosticsStream => _diagnosticsController.stream;
  Map<String, String> _lastDiagnostics = {};

  // -->> إضافة جديدة: تتبع اتصالات قيد التنفيذ <<--
  final Map<String, bool> _pendingConnections = {};

  // Stream Controllers for UI updates
  final StreamController<List<User>> _discoveryController = StreamController<List<User>>.broadcast();
  final StreamController<List<User>> _connectionController = StreamController<List<User>>.broadcast();
  final StreamController<Map<String, dynamic>> _requestController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Message> _messageController = StreamController<Message>.broadcast();

  // Public Streams
  Stream<List<User>> get discoveryStream => _discoveryController.stream;
  Stream<List<User>> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get connectionRequestStream => _requestController.stream;
  Stream<Message> get messageStream => _messageController.stream;

  // Public Getters
  User? getCurrentUser() => _currentUser;
  List<Message> getMessagesForUser(String userId) => _allMessages[userId] ?? [];
  String getUsernameFromDirectory(String userId) => _userDirectory[userId] ?? 'صديق غير معروف';

  /// يعيد قائمة بالأصدقاء المتصلين حاليًا.
  List<User> getConnectedFriends() {
    return _friendIds
        .where((id) => _userSockets.containsKey(id))
        .map((id) => User(id: id, username: _userDirectory[id] ?? '...'))
        .toList();
  }

  /// يعيد قائمة بالأجهزة المكتشفة التي ليست صديقة بعد.
  List<User> getDiscoveredUsers() {
    return _discoveredUsers;
  }

  /// يعيد قائمة بمعرفات الأصدقاء (UUIDs).
  List<String> getFriendIds() {
    return _friendIds;
  }

  /// يعيد جميع المحادثات المخزنة.
  Map<String, List<Message>> getAllMessages() {
    return _allMessages;
  }
// في قسم Data Directories & State في LocalNetworkService
  final Map<String, Group> _groups = {}; // [Key: GroupID, Value: Group]
  final Map<String, List<GroupMessage>> _groupMessages = {};
  final Map<String, List<FileMessage>> _fileMessages = {};
  final Map<String, List<String>> _userGroups = {}; // [Key: UserID, Value: List of GroupIDs]

// Stream Controllers الجديدة
  final StreamController<List<Group>> _groupsController = StreamController<List<Group>>.broadcast();
  final StreamController<GroupMessage> _groupMessageController = StreamController<GroupMessage>.broadcast();
  final StreamController<FileMessage> _fileMessageController = StreamController<FileMessage>.broadcast();

// Streams الجديدة للعام
  Stream<List<Group>> get groupsStream => _groupsController.stream;
  Stream<GroupMessage> get groupMessageStream => _groupMessageController.stream;
  Stream<FileMessage> get fileMessageStream => _fileMessageController.stream;

// Getters الجديدة
  List<Group> getUserGroups() {
    return _userGroups[_currentUser?.id]?.map((groupId) => _groups[groupId]!).where((group) => group != null).toList() ?? [];
  }

  List<GroupMessage> getGroupMessages(String groupId) {
    return _groupMessages[groupId] ?? [];
  }

  List<FileMessage> getFileMessages(String conversationId) {
    return _fileMessages[conversationId] ?? [];
  }

// في قسم Data Directories & State
  final Map<String, UserStatus> _userStatuses = {}; // حالة المستخدمين
  final List<AppNotification> _notifications = []; // قائمة الإشعارات
  final Map<String, Timer> _typingTimers = {}; // مؤقتات الكتابة

// Stream Controllers الجديدة
  final StreamController<Map<String, UserStatus>> _statusController = StreamController<Map<String, UserStatus>>.broadcast();
  final StreamController<List<AppNotification>> _notificationsController = StreamController<List<AppNotification>>.broadcast();

// Streams الجديدة
  Stream<Map<String, UserStatus>> get statusStream => _statusController.stream;
  Stream<List<AppNotification>> get notificationsStream => _notificationsController.stream;

// Getters الجديدة
  Map<String, UserStatus> getUserStatuses() => Map.from(_userStatuses);
  List<AppNotification> getNotifications() => List.from(_notifications);








  Future<String?> getWifiIP() async {
    try {
      String? ip = await _networkInfo.getWifiIP();
      // [الإصلاح الجوهري] قم دائمًا بتحويل الأرقام قبل إرجاعها
      if (ip != null) {
        return _convertArabicNumbers(ip);
      }
      return null;
    } catch (e) {
      return null;
    }

  }





  // --- Core Service Lifecycle ---

  Future<void> start(User user) async {
    _currentUser = user;
    await stop(); // Ensure a clean start
    await _loadDataFromStorage();
    await _loadGroupsData();
    await _loadUserStatuses(); // ⬅ إضافة تحميل حالة المستخدمين
    await _loadNotifications(); // ⬅ إضافة تحميل الإشعارات
    await _startDiscoveryListener();
    await _startMainServer();
    _startAnnouncing();
    _startReconnectScheduler();
    _startHeartbeatSystem(); // -->> إضافة جديدة: بدء نظام القلب <<--
    // تحديث الحالة إلى متصل
    updateUserStatus(true);
  }

  Future<void> stop() async {
    _announcementTimer?.cancel();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _pongTimers.forEach((_, timer) => timer.cancel());
    _pongTimers.clear();
    _reconnectAttempts.clear();
    _reconnectCounters.clear();
    _heartbeatFailCount.clear();
    _pendingConnections.clear();

    _broadcastSocket?.close();
    await _serverSocket?.close();
    for (var socket in _userSockets.values) {
    _safeSocketClose(socket);
    // إضافة تنظيف البيانات الجديدة
    _groups.clear();
    _groupMessages.clear();
    _fileMessages.clear();
    _userGroups.clear();
    }
    _userSockets.clear();
    _ipDirectory.clear();
    _discoveredUsers.clear();
    // تحديث الحالة إلى غير متصل
    if (_currentUser != null) {
      updateUserStatus(false);
    }

    // تنظيف البيانات الجديدة
    _userStatuses.clear();
    _notifications.clear();
    _typingTimers.forEach((_, timer) => timer.cancel());
    _typingTimers.clear();
  }


  // --- Networking Logic ---

  /// تسمح للواجهة بتسجيل دالة ليتم استدعاؤها عند الحاجة للتحديث.
  void setUpdateCallback(VoidCallback callback) {
    _updateUICallback = callback;
  }

  /// تنظيف الكول باك عند إغلاق الواجهة.
  void clearUpdateCallback() {
    _updateUICallback = null;
  }

  void _startAnnouncing() {
    _announcementTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_currentUser == null) return;
      final currentIp = await getWifiIP();
      if (currentIp == null) return;

      final announcement = {'id': _currentUser!.id, 'username': _currentUser!.username, 'ip': currentIp};
      final payload = 'DISCOVER:${jsonEncode(announcement)}';
      try {
        _broadcastSocket?.send(utf8.encode(payload), InternetAddress("255.255.255.255"), 8081);
      } catch (e) { /* Ignore broadcast errors */ }
    });
  }

  String _convertArabicNumbers(String input) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const english = '0123456789';
    String result = input;
    for (int i = 0; i < arabic.length; i++) {
      result = result.replaceAll(arabic[i], english[i]);
    }
    return result;
  }

  void _startReconnectScheduler() {
    _reconnectTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final friendsToReconnect = _friendIds.where((id) =>
      !_userSockets.containsKey(id) &&
          _ipDirectory.containsKey(id) &&
          _shouldAttemptReconnect(id)).toList();

      for (final friendId in friendsToReconnect) {
        _improvedReconnectToFriend(friendId);
      }
    });
  }

  // -->> إضافة جديدة: تحديد إذا كان يجب إعادة الاتصال <<--
  bool _shouldAttemptReconnect(String friendId) {
    final lastAttempt = _reconnectAttempts[friendId];
    if (lastAttempt == null) return true;

    final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
    final attemptCount = _reconnectCounters[friendId] ?? 0;

    // تطبيق استراتيجية backoff
    if (attemptCount < 3) return timeSinceLastAttempt.inSeconds >= 10;
    if (attemptCount < 6) return timeSinceLastAttempt.inSeconds >= 30;
    return timeSinceLastAttempt.inSeconds >= 60;
  }

  Future<void> _startDiscoveryListener() async {
    try {
      _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8081);
      _broadcastSocket!.broadcastEnabled = true;
      _broadcastSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _broadcastSocket!.receive();
          if (datagram != null) _improvedHandleDiscoveryMessage(utf8.decode(datagram.data));
        }
      });
    } catch (e) {
      debugPrint('Discovery Listener Error: $e');
    }
  }

  Future<void> _startMainServer() async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8080);
      _serverSocket!.listen(_handleIncomingConnection);
    } catch (e) {
      debugPrint('Main Server Error: $e');
    }
  }

  // -->> إضافة جديدة: معالجة محسنة لرسائل الاكتشاف <<--
  void _improvedHandleDiscoveryMessage(String message) {
    if (!message.startsWith('DISCOVER:')) return;

    try {
      final data = jsonDecode(message.substring(9));

      // التعامل مع أنواع مختلفة من رسائل الاكتشاف
      if (data['type'] == 'REDISCOVER') {
        _handleRediscoverMessage(data);
        return;
      }

      if (data['type'] == 'DISCOVERY_RESPONSE') {
        _handleDiscoveryResponse(data);
        return;
      }

      if (data['type'] == 'CONNECTION_STATUS') {
        _handleConnectionStatusMessage(data);
        return;
      }

      final String id = data['id'];
      if (id == _currentUser?.id) return;

      final String ip = _convertArabicNumbers(data['ip']);
      final String username = data['username'];

      _ipDirectory[id] = ip;

      if (_userDirectory[id] != username) {
        _userDirectory[id] = username;
        _saveFriendsAndDirectory();
      }

      // محاولة إعادة الاتصال فورًا إذا كان صديقًا ومفقودًا
      if (_friendIds.contains(id) && !_userSockets.containsKey(id)) {
        _improvedReconnectToFriend(id);
      }

      if (!_friendIds.contains(id)) {
        if (!_discoveredUsers.any((u) => u.id == id)) {
          _discoveredUsers.add(User(id: id, username: username));
          _discoveryController.add(List.from(_discoveredUsers));
          _updateUICallback?.call();
        }
      }
    } catch (e) {
      // تجاهل الرسائل التالفة
    }
  }

  // -->> إضافة جديدة: معالجة طلبات إعادة الاكتشاف <<--
  void _handleRediscoverMessage(Map<String, dynamic> data) {
    final String targetId = data['targetId'];
    final String senderId = data['senderId'];

    if (targetId == _currentUser?.id) {
      // هذا الطلب موجه لي، أرسل ردًا
      _sendDiscoveryResponse(senderId);
    }
  }

  // -->> إضافة جديدة: معالجة استجابات الاكتشاف <<--
  void _handleDiscoveryResponse(Map<String, dynamic> data) {
    final String id = data['id'];
    final String targetId = data['targetId'];

    if (targetId == _currentUser?.id && _friendIds.contains(id)) {
      // هذا الرد موجه لي، تحديث العنوان ومحاولة الاتصال
      final String ip = _convertArabicNumbers(data['ip']);
      final String username = data['username'];

      _ipDirectory[id] = ip;
      _userDirectory[id] = username;

      _improvedReconnectToFriend(id);
    }
  }

  // -->> إضافة جديدة: معالجة رسائل حالة الاتصال <<--
  void _handleConnectionStatusMessage(Map<String, dynamic> data) {
    final String id = data['id'];
    final String status = data['status'];

    if (id == _currentUser?.id) return;

    if (status == 'ONLINE' && _friendIds.contains(id)) {
      // تحديث حالة الصديق إلى متصل
      final String ip = _convertArabicNumbers(data['ip']);
      _ipDirectory[id] = ip;

      // إذا لم يكن متصلاً، حاول إعادة الاتصال فوراً
      if (!_userSockets.containsKey(id)) {
        _improvedReconnectToFriend(id);
      }
    }
  }

  // -->> إضافة جديدة: إرسال استجابة الاكتشاف <<--
  void _sendDiscoveryResponse(String requesterId) async {
    final currentIp = await getWifiIP();
    if (currentIp != null && _currentUser != null) {
      final response = {
        'type': 'DISCOVERY_RESPONSE',
        'id': _currentUser!.id,
        'username': _currentUser!.username,
        'ip': currentIp,
        'targetId': requesterId
      };
      final payload = 'DISCOVER:${jsonEncode(response)}';
      try {
        _broadcastSocket?.send(utf8.encode(payload), InternetAddress("255.255.255.255"), 8081);
      } catch (e) {}
    }
  }

  // -->> إضافة جديدة: بث حالة الاتصال <<--
  void _sendConnectionStatusBroadcast() async {
    if (_currentUser == null) return;
    final currentIp = await getWifiIP();
    if (currentIp == null) return;

    final statusAnnouncement = {
      'type': 'CONNECTION_STATUS',
      'id': _currentUser!.id,
      'username': _currentUser!.username,
      'ip': currentIp,
      'status': 'ONLINE',
      'timestamp': DateTime.now().toIso8601String()
    };

    final payload = 'DISCOVER:${jsonEncode(statusAnnouncement)}';
    try {
      _broadcastSocket?.send(utf8.encode(payload), InternetAddress("255.255.255.255"), 8081);
      debugPrint('🌐 Broadcast connection status: ONLINE');
    } catch (e) {
      debugPrint('Broadcast status error: $e');
    }
  }

  void _handleIncomingConnection(Socket socket) => _setupSocket(socket);

  void _handleTcpMessage(String message, Socket socket) {
    try {
      if (message.startsWith('CONNECT_REQUEST:')) {
        final user = User.fromJson(jsonDecode(message.substring(16)));
        _requestController.add({'user': user, 'socket': socket});
      } else if (message.startsWith('CONNECT_ACCEPT:')) {
        final user = User.fromJson(jsonDecode(message.substring(15)));
        _finalizeConnection(user, socket);
        socket.write('FINALIZE_CONNECTION:${jsonEncode(_currentUser!.toJson())}');
      } else if (message.startsWith('FINALIZE_CONNECTION:')) {
        final user = User.fromJson(jsonDecode(message.substring(20)));
        _finalizeConnection(user, socket);
      } else if (message.startsWith('RECONNECT:')) {
        final user = User.fromJson(jsonDecode(message.substring(10)));
        _finalizeConnection(user, socket);
        // -->> إضافة جديدة: إرسال تأكيد إعادة الاتصال <<--
        socket.write('RECONNECT_ACK:${jsonEncode(_currentUser!.toJson())}');
        // -->> إضافة جديدة: إعادة تعيين عداد إعادة الاتصال عند النجاح <<--
        _reconnectCounters.remove(user.id);
        _reconnectAttempts.remove(user.id);
        debugPrint("✅ Reconnection finalized with ${user.username}");
      } else if (message.startsWith('RECONNECT_ACK:')) {
        final user = User.fromJson(jsonDecode(message.substring(14)));
        // -->> إضافة جديدة: تأكيد اكتمال إعادة الاتصال <<--
        debugPrint("✅ Reconnection acknowledged by ${user.username}");
        _finalizeConnection(user, socket);
        _reconnectCounters.remove(user.id);
        _reconnectAttempts.remove(user.id);
      } else if (message.startsWith('MSG:')) {
        final msg = Message.fromJson(jsonDecode(message.substring(4)));
        final conversationId = msg.senderId == _currentUser!.id ? msg.receiverId : msg.senderId;
        _allMessages.putIfAbsent(conversationId, () => []).add(msg);
        _saveAllMessages();
        _messageController.add(msg);
      } else if (message.startsWith('UNFRIEND:')) {
        final user = User.fromJson(jsonDecode(message.substring(9)));
        _removeFriend(user.id);
        _removeSocket(socket);
      }
      else if (message == 'PING' || message == 'PONG') {
        _handleHeartbeat(message, socket);
      }
      // إضافة معالجة الرسائل الجديدة
      else if (message.startsWith('GROUP_MSG:')) {
        final data = jsonDecode(message.substring(10));
        if (data['type'] == 'GROUP_MESSAGE') {
          final groupMessage = GroupMessage.fromJson(data['message']);
          _handleIncomingGroupMessage(groupMessage);
        }
      }
      else if (message.startsWith('GROUP_UPDATE:')) {
        final data = jsonDecode(message.substring(13));
        _handleGroupUpdate(data);
      }
      else if (message.startsWith('FILE_MSG:')) {
        final data = jsonDecode(message.substring(9));
        if (data['type'] == 'FILE_MESSAGE') {
          _handleIncomingFileMessage(data);
        }
      }

      // إضافة معالجة الرسائل الجديدة
      else if (message.startsWith('STATUS:')) {
        final data = jsonDecode(message.substring(7));
        final type = data['type'];

        if (type == 'USER_STATUS') {
          _handleUserStatusMessage(data);
        } else if (type == 'TYPING_STATUS') {
          _handleTypingStatusMessage(data);
        }
      }
      // إضافة معالجة الرسائل الجديدة
      else if (message.startsWith('STATUS:')) {
        final data = jsonDecode(message.substring(7));
        final type = data['type'];

        if (type == 'USER_STATUS') {
          _handleUserStatusMessage(data);
        } else if (type == 'TYPING_STATUS') {
          _handleTypingStatusMessage(data);
        }
      }
    } catch (e) {
      debugPrint('Handle TCP Error: $e');
    }
  }

  void _handleIncomingGroupMessage(GroupMessage message) {
    _groupMessages.putIfAbsent(message.groupId, () => []).add(message);
    _saveGroupMessages();
    _groupMessageController.add(message);
  }

  void _handleGroupUpdate(Map<String, dynamic> data) {
    final type = data['type'];

    if (type == 'GROUP_CREATED') {
      final group = Group.fromJson(data['group']);
      _groups[group.id] = group;
      _userGroups.putIfAbsent(_currentUser!.id, () => []).add(group.id);
      _groupsController.add(getUserGroups());
    }
    else if (type == 'MEMBERS_ADDED') {
      final groupId = data['groupId'];
      final newMemberIds = List<String>.from(data['newMemberIds']);

      final group = _groups[groupId];
      if (group != null) {
        group.memberIds.addAll(newMemberIds);
        if (group.memberIds.contains(_currentUser!.id)) {
          _userGroups.putIfAbsent(_currentUser!.id, () => []).add(groupId);
        }
      }
    }
    else if (type == 'MEMBER_LEFT') {
      final groupId = data['groupId'];
      final memberId = data['memberId'];

      if (memberId == _currentUser!.id) {
        _userGroups[_currentUser!.id]?.remove(groupId);
      }
    }

    _saveGroupsData();
    _groupsController.add(getUserGroups());
  }

  void _handleIncomingFileMessage(Map<String, dynamic> data) async {
    try {
      final fileMessageData = data['message'] as Map<String, dynamic>;
      final fileData = base64Decode(data['fileData'] as String);

      // حفظ الملف الوارد محلياً أولاً
      final localPath = await _saveFileLocally(fileData, fileMessageData['fileName'] as String);

      // إنشاء FileMessage مع المسار الصحيح
      final fileMessage = FileMessage(
        id: fileMessageData['id'] as String,
        senderId: fileMessageData['senderId'] as String,
        receiverId: fileMessageData['receiverId'] as String,
        fileName: fileMessageData['fileName'] as String,
        fileType: fileMessageData['fileType'] as String,
        fileSize: fileMessageData['fileSize'] as int,
        filePath: localPath,
        timestamp: DateTime.parse(fileMessageData['timestamp'] as String),
      );

      final conversationId = fileMessage.receiverId;
      _fileMessages.putIfAbsent(conversationId, () => []).add(fileMessage);
      _saveFileMessages();
      _fileMessageController.add(fileMessage);
    } catch (e) {
      debugPrint('❌ Error handling incoming file message: $e');
    }
  }


  // --- Public Actions ---

  Future<void> sendConnectionRequest(User targetUser) async {
    final targetIp = _ipDirectory[targetUser.id];
    if (targetIp == null) {
      debugPrint("❌ Cannot send request: IP for ${targetUser.username} is unknown.");
      _tryRediscoverFriend(targetUser.id);
      return;
    }
    try {
      final socket = await Socket.connect(targetIp, 8080, timeout: const Duration(seconds: 5));
      _setupSocket(socket);
      socket.write('CONNECT_REQUEST:${jsonEncode(_currentUser!.toJson())}');
      debugPrint("✅ Connection request sent to ${targetUser.username} at $targetIp");
    } catch (e) {
      debugPrint('❌ Send Request Error: $e');
      _tryRediscoverFriend(targetUser.id);
    }
  }

  void acceptConnectionRequest(User requestingUser, Socket socket) {
    socket.write('CONNECT_ACCEPT:${jsonEncode(_currentUser!.toJson())}');
    _finalizeConnection(requestingUser, socket);
  }

  void rejectConnectionRequest(Socket socket) => _safeSocketClose(socket);

  void sendMessage(Message message) {
    final socket = _userSockets[message.receiverId];
    if (socket != null) {
      try {
        socket.write('MSG:${jsonEncode(message.toJson())}');
        final conversationId = message.receiverId;
        _allMessages.putIfAbsent(conversationId, () => []).add(message);
        _saveAllMessages();
      } catch (e) {
        debugPrint('❌ Error sending message: $e');
        _removeSocket(socket);
      }
    }
  }

  Future<void> deleteConversation(String friendId) async {
    _allMessages.remove(friendId);
    await _saveAllMessages();
  }

  Future<void> unfriend(String friendId) async {
    final socket = _userSockets[friendId];
    if (socket != null) {
      try {
        socket.write('UNFRIEND:${jsonEncode(_currentUser!.toJson())}');
      } catch (e) {
        debugPrint('❌ Error sending unfriend message: $e');
      }
      _removeSocket(socket);
    }
    _removeFriend(friendId);
  }

  // --- Internal State Management ---

  void _removeFriend(String friendId) {
    _friendIds.remove(friendId);
    _userDirectory.remove(friendId);
    _allMessages.remove(friendId);
    _ipDirectory.remove(friendId);
    _reconnectAttempts.remove(friendId);
    _reconnectCounters.remove(friendId);
    _heartbeatFailCount.remove(friendId);
    _pendingConnections.remove(friendId);
    _saveFriendsAndDirectory();
    _saveAllMessages();
    _updateUiLists();
  }

  void _finalizeConnection(User user, Socket socket) {
    if (!_userSockets.containsKey(user.id)) {
      debugPrint("🔗 Adding socket to _userSockets for ${user.username}");
      _userSockets[user.id] = socket;
      if (!_friendIds.contains(user.id)) {
        _friendIds.add(user.id);
      }
      _userDirectory[user.id] = user.username;
      _discoveredUsers.removeWhere((u) => u.id == user.id);
      _saveFriendsAndDirectory();
      _updateUiLists();
      _updateUICallback?.call();
      debugPrint("✅ Finalized connection with ${user.username}");

      // -->> إضافة جديدة: إعادة تعيين عدادات إعادة الاتصال <<--
      _reconnectCounters.remove(user.id);
      _reconnectAttempts.remove(user.id);
      _heartbeatFailCount.remove(user.id);
      _pendingConnections.remove(user.id);

      // -->> إضافة جديدة: بث حالة الاتصال عند اكتماله <<--
      _sendConnectionStatusBroadcast();
    } else {
      debugPrint("ℹ Connection already exists with ${user.username}");
    }
  }

  void _removeSocket(Socket socket) {
    String? userIdToRemove;
    _userSockets.forEach((id, s) {
      if (s == socket) userIdToRemove = id;
    });
    if (userIdToRemove != null) {
      debugPrint("🔌 Removing socket for $userIdToRemove");
      _userSockets.remove(userIdToRemove);
      _pongTimers[userIdToRemove]?.cancel();
      _pongTimers.remove(userIdToRemove);
      _pendingConnections.remove(userIdToRemove);
      _updateUiLists();
      _updateUICallback?.call();
      debugPrint("🔌 Socket removed for $userIdToRemove");
    }
    _safeSocketClose(socket);
  }

  void _setupSocket(Socket socket) {
    debugPrint("🔄 Setting up socket listener...");

    socket.listen(
          (data) {
        debugPrint("📨 Received data: ${utf8.decode(data).trim()}");
        _handleTcpMessage(utf8.decode(data).trim(), socket);
      },
      onDone: () {
        debugPrint("🔌 Socket onDone called - connection closed");
        _removeSocket(socket);
      },
      onError: (e) {
        debugPrint("🔌 Socket onError: $e");
        _removeSocket(socket);
      },
      cancelOnError: true,
    );

    debugPrint("✅ Socket listener setup complete");
  }

  void _updateUiLists() {
    _connectionController.add(_friendIds.where((id) => _userSockets.containsKey(id)).map((id) => User(id: id, username: _userDirectory[id] ?? '...')).toList());
    _discoveryController.add(List.from(_discoveredUsers));
  }

  // -->> إضافة جديدة: إعادة الاتصال المحسنة بشكل جذري <<--
  Future<void> _improvedReconnectToFriend(String friendId) async {
    if (friendId == _currentUser?.id || _userSockets.containsKey(friendId)) return;

    // منع محاولات إعادة اتصال متعددة في نفس الوقت
    if (_pendingConnections[friendId] == true) {
      debugPrint("⏳ Reconnection already in progress for $friendId");
      return;
    }

    final targetIp = _ipDirectory[friendId];
    if (targetIp == null) {
      debugPrint("❓ Cannot reconnect to $friendId: IP address is unknown.");
      _tryRediscoverFriend(friendId);
      return;
    }

    // تحديث عدادات إعادة الاتصال
    final now = DateTime.now();
    _reconnectAttempts[friendId] = now;
    _reconnectCounters[friendId] = (_reconnectCounters[friendId] ?? 0) + 1;

    _pendingConnections[friendId] = true;

    try {
      debugPrint("🔄 Attempting reconnect to $friendId at $targetIp");
      final socket = await Socket.connect(targetIp, 8080, timeout: const Duration(seconds: 5));

      // ⚡ الإصلاح الجذري: إضافة السوكيت فورًا قبل إرسال أي شيء
      debugPrint("🔗 Immediately adding socket to _userSockets for $friendId");
      _userSockets[friendId] = socket;
      _setupSocket(socket);

      socket.write('RECONNECT:${jsonEncode(_currentUser!.toJson())}');
      debugPrint("🤝 Reconnect successful to $friendId at $targetIp");

      // إعادة تعيين العداد عند النجاح
      _reconnectCounters.remove(friendId);
      _reconnectAttempts.remove(friendId);

    } catch (e) {
      debugPrint("❌ Reconnect failed to $friendId: $e");
      // إزالة السوكيت إذا فشل الاتصال
      _userSockets.remove(friendId);

      // حذف العنوان القديم إذا فشل الاتصال المتكرر
      if (_reconnectCounters[friendId] != null && _reconnectCounters[friendId]! > 5) {
        _ipDirectory.remove(friendId);
        debugPrint("🗑 Removed stale IP for $friendId after multiple failures");
      }
    } finally {
      _pendingConnections.remove(friendId);
    }
  }

  // -->> إضافة جديدة: محاولة إعادة اكتشاف الصديق <<--
  void _tryRediscoverFriend(String friendId) async {
    final currentIp = await getWifiIP();
    if (currentIp != null && _currentUser != null) {
      final rediscoverRequest = {
        'type': 'REDISCOVER',
        'targetId': friendId,
        'senderId': _currentUser!.id,
        'senderIp': currentIp
      };
      final payload = 'DISCOVER:${jsonEncode(rediscoverRequest)}';
      try {
        _broadcastSocket?.send(utf8.encode(payload), InternetAddress("255.255.255.255"), 8081);
        debugPrint("🔍 Sent rediscover request for $friendId");
      } catch (e) {}
    }
  }

  // -->> إضافة جديدة: إغلاق آمن للسوكيت <<--
  void _safeSocketClose(Socket socket) {
    try {
      socket.destroy();
    } catch (e) {
      try {
        socket.close();
      } catch (e2) {
        // تجاهل الأخطاء في الإغلاق
      }
    }
  }

  // --- Data Persistence ---

  Future<void> _saveFriendsAndDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('friend_ids_v3', _friendIds);
    await prefs.setString('user_directory_v3', jsonEncode(_userDirectory));
  }

  Future<void> _saveAllMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, String> messagesJson = _allMessages.map((key, value) => MapEntry(key, jsonEncode(value.map((msg) => msg.toJson()).toList())));
    await prefs.setString('all_user_messages_v3', jsonEncode(messagesJson));
  }
// --- New Data Persistence Functions ---

  Future<void> _saveGroupsData() async {
    final prefs = await SharedPreferences.getInstance();

    final groupsJson = _groups.map((key, value) => MapEntry(key, jsonEncode(value.toJson())));
    await prefs.setString('user_groups_v1', jsonEncode(groupsJson));

    final userGroupsJson = _userGroups.map((key, value) => MapEntry(key, value));
    await prefs.setString('user_groups_mapping_v1', jsonEncode(userGroupsJson));
  }

  Future<void> _saveGroupMessages() async {
    final prefs = await SharedPreferences.getInstance();

    final groupMessagesJson = _groupMessages.map((key, value) =>
        MapEntry(key, jsonEncode(value.map((msg) => msg.toJson()).toList())));
    await prefs.setString('group_messages_v1', jsonEncode(groupMessagesJson));
  }

  Future<void> _saveFileMessages() async {
    final prefs = await SharedPreferences.getInstance();

    final fileMessagesJson = _fileMessages.map((key, value) =>
        MapEntry(key, jsonEncode(value.map((msg) => msg.toJson()).toList())));
    await prefs.setString('file_messages_v1', jsonEncode(fileMessagesJson));
  }

  Future<void> _loadGroupsData() async {
    final prefs = await SharedPreferences.getInstance();

    // تحميل المجموعات
    final groupsString = prefs.getString('user_groups_v1');
    if (groupsString != null) {
      final groupsJson = jsonDecode(groupsString) as Map<String, dynamic>;
      groupsJson.forEach((key, value) {
        _groups[key] = Group.fromJson(jsonDecode(value));
      });
    }

    // تحميل تخطيط مجموعات المستخدم
    final userGroupsString = prefs.getString('user_groups_mapping_v1');
    if (userGroupsString != null) {
      final userGroupsJson = jsonDecode(userGroupsString) as Map<String, dynamic>;
      userGroupsJson.forEach((key, value) {
        _userGroups[key] = List<String>.from(value);
      });
    }

    // تحميل رسائل المجموعات
    final groupMessagesString = prefs.getString('group_messages_v1');
    if (groupMessagesString != null) {
      final groupMessagesJson = jsonDecode(groupMessagesString) as Map<String, dynamic>;
      groupMessagesJson.forEach((key, value) {
        _groupMessages[key] = (jsonDecode(value) as List).map((item) => GroupMessage.fromJson(item)).toList();
      });
    }

    // تحميل رسائل الملفات
    final fileMessagesString = prefs.getString('file_messages_v1');
    if (fileMessagesString != null) {
      final fileMessagesJson = jsonDecode(fileMessagesString) as Map<String, dynamic>;
      fileMessagesJson.forEach((key, value) {
        _fileMessages[key] = (jsonDecode(value) as List).map((item) => FileMessage.fromJson(item)).toList();
      });
    }
  }

 /* Future<void> _loadMessagesData() async {
    final prefs = await SharedPreferences.getInstance();
    _friendIds.clear();
    _userDirectory.clear();
    _allMessages.clear();

    _friendIds.addAll(prefs.getStringList('friend_ids_v3') ?? []);

    final directoryString = prefs.getString('user_directory_v3');
    if (directoryString != null) {
      (jsonDecode(directoryString) as Map<String, dynamic>).forEach((key, value) {
        _userDirectory[key] = value as String;
      });
    }

    final messagesString = prefs.getString('all_user_messages_v3');
    if (messagesString != null) {
      (jsonDecode(messagesString) as Map<String, dynamic>).forEach((key, value) {
        _allMessages[key] = (jsonDecode(value) as List).map((item) => Message.fromJson(item)).toList();
      });
    }
  }
*/
  Future<void> _loadMessagesData() async {
    // نقل الكود القديم من _loadDataFromStorage هنا
    final prefs = await SharedPreferences.getInstance();
    _friendIds.clear();
    _userDirectory.clear();
    _allMessages.clear();

    _friendIds.addAll(prefs.getStringList('friend_ids_v3') ?? []);

    final directoryString = prefs.getString('user_directory_v3');
    if (directoryString != null) {
      (jsonDecode(directoryString) as Map<String, dynamic>).forEach((key, value) {
        _userDirectory[key] = value as String;
      });
    }

    final messagesString = prefs.getString('all_user_messages_v3');
    if (messagesString != null) {
      (jsonDecode(messagesString) as Map<String, dynamic>).forEach((key, value) {
        _allMessages[key] = (jsonDecode(value) as List).map((item) => Message.fromJson(item)).toList();
      });
    }
  }
  Future<void> _loadDataFromStorage() async {
    await _loadMessagesData();
    await _loadUserStatuses();
    await _loadNotifications();
  }
  // -->> إضافة جديدة: مجموعة دوال نبضات القلب <<--

  /// يبدأ نظام إرسال نبضات القلب بشكل دوري.
  void _startHeartbeatSystem() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      // أرسل PING فقط للأصدقاء المتصلين حاليًا
      _userSockets.keys.forEach(_sendPing);
    });
  }

  void _sendPing(String friendId) {
    final socket = _userSockets[friendId];
    if (socket == null) return;

    try {
      socket.write('PING\n');
      _updateDiagnostic(friendId, "PING sent...");

      _pongTimers[friendId]?.cancel();
      _pongTimers[friendId] = Timer(const Duration(seconds: 10), () {
        // زيادة عداد الفشل
        int count = (_heartbeatFailCount[friendId] ?? 0) + 1;
        _heartbeatFailCount[friendId] = count;

        if (count >= 2) {
          _updateDiagnostic(friendId, "PONG Timeout! Disconnecting.");
          debugPrint("💔 Heartbeat failed for $friendId. Disconnecting.");
          _removeSocket(socket);
          _heartbeatFailCount.remove(friendId);
        } else {
          _updateDiagnostic(friendId, "PONG Timeout! Retry ${count}/2");
          // لا نقطع الاتصال بعد، ننتظر المحاولة التالية
        }
      });
    } catch (e) {
      _updateDiagnostic(friendId, "PING Error!");
      debugPrint("💔 Error sending PING to $friendId. Disconnecting.");
      _removeSocket(socket);
      _heartbeatFailCount.remove(friendId);
    }
  }

  /// يعالج رسائل PING و PONG الواردة.
  void _handleHeartbeat(String message, Socket socket) {
    String? friendId;
    _userSockets.forEach((id, s) {
      if (s == socket) friendId = id;
    });
    if (friendId == null) return;

    if (message == 'PING') {
      try {
        socket.write('PONG\n');
        _updateDiagnostic(friendId!, "PONG sent back");
      } catch (e) { /* Ignore */ }
    } else if (message == 'PONG') {
      _updateDiagnostic(friendId!, "PONG received!");
      _pongTimers[friendId]?.cancel();
      // إعادة تعيين عداد الفشل
      _heartbeatFailCount.remove(friendId);
    }
  }

  // -->> إضافة جديدة: دوال التشخيص والزر اليدوي <<--

  /// دالة لتحديث معلومات التشخيص وإرسالها للواجهة.
  void _updateDiagnostic(String friendId, String status) {
    _lastDiagnostics[friendId] = status;
    _diagnosticsController.add(Map.from(_lastDiagnostics));
  }

  /// دالة عامة لتشغيل نبضة حياة يدوية من الزر.
  void forceHeartbeat() {
    debugPrint("❤ Manually forcing heartbeat for all connected friends...");
    if (_userSockets.isEmpty) {
      debugPrint("... but no one is connected.");
      return;
    }
    _userSockets.keys.forEach(_sendPing);
  }

  // --- Group Management Functions ---

  Future<void> createGroup(String groupName, List<String> memberIds) async {
    if (_currentUser == null) return;

    final groupId = const Uuid().v4();
    final group = Group(
      id: groupId,
      name: groupName,
      adminId: _currentUser!.id,
      memberIds: [...memberIds, _currentUser!.id], // إضافة المنشئ كعضو
      createdAt: DateTime.now(),
    );

    _groups[groupId] = group;

    // تحديث مجموعات المستخدمين
    for (final memberId in group.memberIds) {
      _userGroups.putIfAbsent(memberId, () => []).add(groupId);
    }

    _saveGroupsData();
    _groupsController.add(getUserGroups());

    // إرسال إشعار للمستخدمين المضافين
    _broadcastGroupCreation(group);
  }

  void _broadcastGroupCreation(Group group) {
    final announcement = {
      'type': 'GROUP_CREATED',
      'group': group.toJson(),
      'creatorId': _currentUser!.id,
    };

    _sendToGroupMembers(group.id, 'GROUP_UPDATE:${jsonEncode(announcement)}');
  }

  void sendGroupMessage(String groupId, String content) {
    if (_currentUser == null) return;

    final message = GroupMessage(
      id: const Uuid().v4(),
      groupId: groupId,
      senderId: _currentUser!.id,
      content: content,
      timestamp: DateTime.now(),
    );

    _groupMessages.putIfAbsent(groupId, () => []).add(message);
    _saveGroupMessages();
    _groupMessageController.add(message);

    // إرسال الرسالة لأعضاء المجموعة
    final messageData = {
      'type': 'GROUP_MESSAGE',
      'message': message.toJson(),
    };

    _sendToGroupMembers(groupId, 'GROUP_MSG:${jsonEncode(messageData)}');
  }

  void _sendToGroupMembers(String groupId, String message) {
    final group = _groups[groupId];
    if (group == null) return;

    for (final memberId in group.memberIds) {
      if (memberId != _currentUser!.id) {
        final socket = _userSockets[memberId];
        if (socket != null) {
          try {
            socket.write(message);
          } catch (e) {
            debugPrint('❌ Error sending group message to $memberId: $e');
          }
        }
      }
    }
  }
  /*void _sendToGroupMembers(String groupId, String message) {
    final group = _groups[groupId];
    if (group == null) return;

    for (final memberId in group.memberIds) {
      if (memberId != _currentUser!.id) {
        _sendToUser(memberId, message); // استخدام _sendToUser
      }
    }
  }*/
  Future<void> addMembersToGroup(String groupId, List<String> newMemberIds) async {
    final group = _groups[groupId];
    if (group == null || group.adminId != _currentUser?.id) return;

    group.memberIds.addAll(newMemberIds);

    // تحديث مجموعات المستخدمين الجدد
    for (final memberId in newMemberIds) {
      _userGroups.putIfAbsent(memberId, () => []).add(groupId);
    }

    _saveGroupsData();

    // إرسال إشعار للأعضاء الجدد
    final update = {
      'type': 'MEMBERS_ADDED',
      'groupId': groupId,
      'newMemberIds': newMemberIds,
      'addedBy': _currentUser!.id,
    };

    _sendToGroupMembers(groupId, 'GROUP_UPDATE:${jsonEncode(update)}');
  }

  void leaveGroup(String groupId) {
    if (_currentUser == null) return;

    final group = _groups[groupId];
    if (group == null) return;

    group.memberIds.remove(_currentUser!.id);
    _userGroups[_currentUser!.id]?.remove(groupId);

    // إذا كان المنشئ يغادر، نقل الإدارة أو حذف المجموعة
    if (group.adminId == _currentUser!.id) {
      if (group.memberIds.isNotEmpty) {
        // إنشاء مجموعة جديدة مع الإدارة الجديدة
        final newGroup = Group(
          id: group.id,
          name: group.name,
          adminId: group.memberIds.first, // أول عضو يصبح مديراً
          memberIds: List.from(group.memberIds),
          createdAt: group.createdAt,
        );
        _groups[groupId] = newGroup;
      } else {
        // إذا لم يتبقى أعضاء، حذف المجموعة
        _groups.remove(groupId);
      }
    }

    _saveGroupsData();
    _groupsController.add(getUserGroups());

    // إرسال إشعار بخروج العضو
    final update = {
      'type': 'MEMBER_LEFT',
      'groupId': groupId,
      'memberId': _currentUser!.id,
    };

    _sendToGroupMembers(groupId, 'GROUP_UPDATE:${jsonEncode(update)}');
  }

  // --- File Sharing Functions ---

  Future<void> sendFileMessage(String receiverId, File file, String fileType) async {
    if (_currentUser == null) return;

    try {
      final fileBytes = await file.readAsBytes();
      final fileName = file.uri.pathSegments.last;

      // حفظ الملف محلياً أولاً للحصول على المسار
      final localPath = await _saveFileLocally(fileBytes, fileName);

      final fileMessage = FileMessage(
        id: const Uuid().v4(),
        senderId: _currentUser!.id,
        receiverId: receiverId,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileBytes.length,
        filePath: localPath, // تعيين المسار مباشرة
        timestamp: DateTime.now(),
      );

      _fileMessages.putIfAbsent(receiverId, () => []).add(fileMessage);
      _saveFileMessages();
      _fileMessageController.add(fileMessage);

      // إرسال الرسالة للمستقبل
      final socket = _userSockets[receiverId];
      if (socket != null) {
        final messageData = {
          'type': 'FILE_MESSAGE',
          'message': fileMessage.toJson(),
          'fileData': base64Encode(fileBytes),
        };

        socket.write('FILE_MSG:${jsonEncode(messageData)}');
      }

    } catch (e) {
      debugPrint('❌ Error sending file: $e');
    }
  }


  Future<String> _saveFileLocally(List<int> fileBytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filesDir = Directory('${directory.path}/files');

      if (!await filesDir.exists()) {
        await filesDir.create(recursive: true);
      }

      final filePath = '${filesDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(fileBytes);

      return filePath;
    } catch (e) {
      debugPrint('❌ Error saving file locally: $e');
      return ''; // إرجاع مسار فارغ في حالة الخطأ
    }
  }
// --- دوال التخزين الجديدة ---

  Future<void> _saveUserStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final statusesJson = _userStatuses.map((key, value) => MapEntry(key, jsonEncode(value.toJson())));
    await prefs.setString('user_statuses_v1', jsonEncode(statusesJson));
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = _notifications.map((n) => n.toJson()).toList();
    await prefs.setString('notifications_v1', jsonEncode(notificationsJson));
  }

  Future<void> _loadUserStatuses() async {
    final prefs = await SharedPreferences.getInstance();
    final statusesString = prefs.getString('user_statuses_v1');

    if (statusesString != null) {
      final statusesJson = jsonDecode(statusesString) as Map<String, dynamic>;
      statusesJson.forEach((key, value) {
        _userStatuses[key] = UserStatus.fromJson(jsonDecode(value));
      });
    }
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsString = prefs.getString('notifications_v1');

    if (notificationsString != null) {
      final notificationsJson = jsonDecode(notificationsString) as List;
      _notifications.clear();
      _notifications.addAll(notificationsJson.map((json) => AppNotification.fromJson(json)).toList());
    }
  }
  Future<File> _getLocalFile(String filePath) async {
    return File(filePath);
  }


  // --- نظام الحالة والكتابة ---

  void updateUserStatus(bool isOnline, {String? currentChatId}) {
    if (_currentUser == null) return;

    final status = UserStatus(
      userId: _currentUser!.id,
      isOnline: isOnline,
      lastSeen: isOnline ? null : DateTime.now(),
      isTyping: false,
      currentChatId: currentChatId,
    );

    _userStatuses[_currentUser!.id] = status;
    _broadcastUserStatus(status);
    _saveUserStatuses();
  }
/*
  void sendTypingStatus(String receiverId, bool isTyping, {String? chatType = 'private'}) {
    if (_currentUser == null) return;

    // إلغاء المؤقت السابق
    _typingTimers[receiverId]?.cancel();

    if (isTyping) {
      // إرسال حالة الكتابة
      final typingStatus = {
        'type': 'TYPING_STATUS',
        'senderId': _currentUser!.id,
        'receiverId': receiverId,
        'isTyping': true,
        'chatType': chatType,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _sendToUser(receiverId, 'STATUS:${jsonEncode(typingStatus)}');

      // تعيين مؤقت لإيقاف حالة الكتابة بعد 3 ثواني
      _typingTimers[receiverId] = Timer(const Duration(seconds: 3), () {
        sendTypingStatus(receiverId, false, chatType: chatType);
      });
    } else {
      // إرسال إيقاف الكتابة
      final typingStatus = {
        'type': 'TYPING_STATUS',
        'senderId': _currentUser!.id,
        'receiverId': receiverId,
        'isTyping': false,
        'chatType': chatType,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _sendToUser(receiverId, 'STATUS:${jsonEncode(typingStatus)}');
    }
  }

  void _broadcastUserStatus(UserStatus status) {
    final statusMessage = {
      'type': 'USER_STATUS',
      'status': status.toJson(),
    };

    _sendBroadcastMessage(statusMessage);
  }*/
  void sendTypingStatus(String receiverId, bool isTyping, {String? chatType = 'private'}) {
    if (_currentUser == null) return;

    // إلغاء المؤقت السابق
    _typingTimers[receiverId]?.cancel();

    if (isTyping) {
      // إرسال حالة الكتابة
      final typingStatus = {
        'type': 'TYPING_STATUS',
        'senderId': _currentUser!.id,
        'receiverId': receiverId,
        'isTyping': true,
        'chatType': chatType,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _sendToUser(receiverId, 'STATUS:${jsonEncode(typingStatus)}'); // استخدام _sendToUser

      // تعيين مؤقت لإيقاف حالة الكتابة بعد 3 ثواني
      _typingTimers[receiverId] = Timer(const Duration(seconds: 3), () {
        sendTypingStatus(receiverId, false, chatType: chatType);
      });
    } else {
      // إرسال إيقاف الكتابة
      final typingStatus = {
        'type': 'TYPING_STATUS',
        'senderId': _currentUser!.id,
        'receiverId': receiverId,
        'isTyping': false,
        'chatType': chatType,
        'timestamp': DateTime.now().toIso8601String(),
      };

      _sendToUser(receiverId, 'STATUS:${jsonEncode(typingStatus)}'); // استخدام _sendToUser
    }
  }

// في دالة _broadcastUserStatus
  void _broadcastUserStatus(UserStatus status) {
    final statusMessage = {
      'type': 'USER_STATUS',
      'status': status.toJson(),
    };

    _sendBroadcastMessage(statusMessage); // استخدام _sendBroadcastMessage
  }

  void _handleUserStatusMessage(Map<String, dynamic> data) {
    final status = UserStatus.fromJson(data['status']);
    _userStatuses[status.userId] = status;
    _statusController.add(Map.from(_userStatuses));
  }

  void _handleTypingStatusMessage(Map<String, dynamic> data) {
    final String senderId = data['senderId'];
    final bool isTyping = data['isTyping'];
    final String chatType = data['chatType'] ?? 'private';

    // تحديث حالة الكتابة للمستخدم
    if (_userStatuses.containsKey(senderId)) {
      _userStatuses[senderId] = UserStatus(
        userId: senderId,
        isOnline: _userStatuses[senderId]!.isOnline,
        lastSeen: _userStatuses[senderId]!.lastSeen,
        isTyping: isTyping,
        currentChatId: data['currentChatId'],
      );
    } else {
      _userStatuses[senderId] = UserStatus(
        userId: senderId,
        isOnline: true,
        isTyping: isTyping,
        currentChatId: data['currentChatId'],
      );
    }

    _statusController.add(Map.from(_userStatuses));
  }
// --- نظام الإشعارات ---

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification); // إضافة في البداية
    _saveNotifications();
    _notificationsController.add(List.from(_notifications));

    // إرسال إشعار محلي (سوف نضيف الإشعارات المحلية لاحقاً)
    _showLocalNotification(notification);
  }

  void markNotificationAsRead(String notificationId) {
    final notification = _notifications.firstWhere(
          (n) => n.id == notificationId,
      orElse: () => AppNotification(
        id: '',
        title: '',
        body: '',
        type: '',
        timestamp: DateTime.now(),
      ),
    );

    if (notification.id.isNotEmpty) {
      notification.isRead = true;
      _saveNotifications();
      _notificationsController.add(List.from(_notifications));
    }
  }

  void markAllNotificationsAsRead() {
    for (final notification in _notifications) {
      notification.isRead = true;
    }
    _saveNotifications();
    _notificationsController.add(List.from(_notifications));
  }

  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _saveNotifications();
    _notificationsController.add(List.from(_notifications));
  }

  void _showLocalNotification(AppNotification notification) {
    // هذا سيكون تنفيذ الإشعارات المحلية (سنضيفه لاحقاً)
    debugPrint('🔔 New Notification: ${notification.title} - ${notification.body}');
  }

// إنشاء إشعارات تلقائية
  void _createAutoNotification(String type, String title, String body, {Map<String, dynamic>? data}) {
    final notification = AppNotification(
      id: const Uuid().v4(),
      title: title,
      body: body,
      type: type,
      data: data,
      timestamp: DateTime.now(),
    );

    addNotification(notification);
  }

// إشعارات للأحداث المختلفة
  void notifyFriendRequest(User fromUser) {
    _createAutoNotification(
      'friend_request',
      'طلب صداقة جديد',
      '${fromUser.username} يريد إضافتك كصديق',
      data: {'fromUserId': fromUser.id},
    );
  }

  void notifyNewMessage(Message message, String senderName) {
    _createAutoNotification(
      'message',
      'رسالة جديدة من $senderName',
      message.content,
      data: {
        'senderId': message.senderId,
        'messageId': message.id,
        'conversationId': message.receiverId == _currentUser?.id ? message.senderId : message.receiverId,
      },
    );
  }

  void notifyGroupMessage(GroupMessage message, String groupName, String senderName) {
    _createAutoNotification(
      'group_message',
      'رسالة جديدة في $groupName',
      '$senderName: ${message.content}',
      data: {
        'groupId': message.groupId,
        'messageId': message.id,
        'senderId': message.senderId,
      },
    );
  }
  // --- دوال مساعدة للبث والإرسال ---

  void _sendToUser(String userId, String message) {
    final socket = _userSockets[userId];
    if (socket != null) {
      try {
        socket.write(message);
      } catch (e) {
        debugPrint('❌ Error sending message to $userId: $e');
        _removeSocket(socket);
      }
    }
  }

  void _sendBroadcastMessage(Map<String, dynamic> message) {
    final payload = 'DISCOVER:${jsonEncode(message)}';
    try {
      _broadcastSocket?.send(utf8.encode(payload), InternetAddress("255.255.255.255"), 8081);
    } catch (e) {
      debugPrint('Broadcast message error: $e');
    }
  }
}

// =================================================================================
// 📱 App UI
// =================================================================================

class LocalSocialApp extends StatelessWidget {
  const LocalSocialApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تواصل محلي',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Cairo',
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF075E54), foregroundColor: Colors.white),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkPermissionsAndAuth();
  }

  Future<void> _checkPermissionsAndAuth() async {
    await Permission.location.request();
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('isLoggedIn_v3') ?? false) {
      final userId = prefs.getString('user_uuid');
      final username = prefs.getString('username');

      if (userId == null || username == null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
        return;
      }

      final user = User(id: userId, username: username);
      await LocalNetworkService().start(user);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      }
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF075E54),
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Iconsax.wifi, size: 80, color: Colors.white), SizedBox(height: 24), Text('تواصل محلي', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)), SizedBox(height: 30), CircularProgressIndicator(color: Colors.white)])),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم المستخدم')));
      return;
    }
    setState(() { _isLoading = true; });

    String? currentIp;
    int attempts = 0;
    while (currentIp == null && attempts < 5) {
      currentIp = await LocalNetworkService().getWifiIP();
      if (currentIp == null) await Future.delayed(const Duration(seconds: 1));
      attempts++;
    }

    if (currentIp == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الاتصال بالشبكة. تأكد من اتصالك بالـ WiFi.'), backgroundColor: Colors.red));
      setState(() { _isLoading = false; });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = const Uuid().v4();
    final user = User(id: userId, username: _usernameController.text);

    await prefs.setBool('isLoggedIn_v3', true);
    await prefs.setString('username', user.username);
    await prefs.setString('user_uuid', user.id);

    await LocalNetworkService().start(user);

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('تسجيل الدخول', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          TextField(controller: _usernameController, decoration: InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Iconsax.user))),
          const SizedBox(height: 30),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _isLoading ? null : _login, style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('دخول'))),
        ]),
      ),
    );
  }
}

// في HomeScreen، قم بتحديث الـ screens و bottomNavigationBar
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription<Map<String, dynamic>>? _requestSubscription;
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _requestSubscription = LocalNetworkService().connectionRequestStream.listen((request) {
      if (mounted) {
        _showConnectionRequestDialog(request['user'] as User, request['socket'] as Socket);
      }
    });

    // متابعة عدد الإشعارات غير المقروءة
    LocalNetworkService().notificationsStream.listen((notifications) {
      if (mounted) {
        setState(() {
          _unreadNotificationsCount = notifications.where((n) => !n.isRead).length;
        });
      }
    });
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }

  void _showConnectionRequestDialog(User requestingUser, Socket socket) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('طلب صداقة'),
        content: Text('${requestingUser.username} يريد إضافتك كصديق.'),
        actions: [
          TextButton(
              onPressed: () {
                LocalNetworkService().rejectConnectionRequest(socket);
                Navigator.pop(context);
              },
              child: const Text('رفض', style: TextStyle(color: Colors.red))
          ),
          ElevatedButton(
              onPressed: () {
                LocalNetworkService().acceptConnectionRequest(requestingUser, socket);
                Navigator.pop(context);
              },
              child: const Text('قبول')
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تحديث screens لتشمل شاشة الإشعارات
    final screens = [
      const FeedScreen(),
      const NetworkScreen(),
      const ChatListScreen(),
      const GroupsScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('تواصل محلي')),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(icon: Icon(Iconsax.home_2), label: 'الرئيسية'),
          const BottomNavigationBarItem(icon: Icon(Iconsax.people), label: 'الشبكة'),
          const BottomNavigationBarItem(icon: Icon(Iconsax.message), label: 'المحادثات'),
          const BottomNavigationBarItem(icon: Icon(Iconsax.people), label: 'المجموعات'),
          BottomNavigationBarItem(
            icon: _unreadNotificationsCount > 0
                ? badges.Badge(
              badgeContent: Text(
                _unreadNotificationsCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
              child: const Icon(Iconsax.notification),
            )
                : const Icon(Iconsax.notification),
            label: 'الإشعارات',
          ),
          const BottomNavigationBarItem(icon: Icon(Iconsax.user), label: 'الملف الشخصي'),
        ],
      ),
    );
  }
}

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});
  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final StreamController<void> _updateController = StreamController.broadcast();
  List<StreamSubscription> _subscriptions = [];

  Map<String, String> _diagnostics = {};

  @override
  void initState() {
    super.initState();
    _subscriptions.add(LocalNetworkService().diagnosticsStream.listen((diag) {
      if (mounted) {
        setState(() {
          _diagnostics = diag;
        });
      }
    }));

    LocalNetworkService().setUpdateCallback(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _updateController.close();
    LocalNetworkService().clearUpdateCallback();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectedFriends = LocalNetworkService().getConnectedFriends();
    final nearby = LocalNetworkService().getDiscoveredUsers();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            icon: const Icon(Iconsax.heart_tick),
            label: const Text('إرسال نبضة حياة يدوية'),
            onPressed: () {
              LocalNetworkService().forceHeartbeat();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('تم إرسال نبضة حياة لجميع الأصدقاء المتصلين...'),
                duration: Duration(seconds: 2),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('الأصدقاء المتصلون (${connectedFriends.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                ),
                if (connectedFriends.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('لا يوجد أصدقاء متصلون حاليًا.', style: TextStyle(color: Colors.grey))),

                ...connectedFriends.map((user) {
                  final status = _diagnostics[user.id] ?? '...';
                  return UserListItem(user: user, isFriend: true, diagnosticStatus: status);
                }),

                const Divider(height: 32, thickness: 1, indent: 16, endIndent: 16),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('أجهزة قريبة (${nearby.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ),
                if (nearby.isEmpty)
                  const Padding(padding: EdgeInsets.all(16), child: Text('لا توجد أجهزة جديدة قريبة.', style: TextStyle(color: Colors.grey))),
                ...nearby.map((user) => UserListItem(user: user, isFriend: false, diagnosticStatus: null)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class UserListItem extends StatelessWidget {
  final User user;
  final bool isFriend;
  final String? diagnosticStatus;

  const UserListItem({
    super.key,
    required this.user,
    required this.isFriend,
    this.diagnosticStatus,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.grey.shade200, child: Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U')),
      title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(user.id, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (isFriend && diagnosticStatus != null)
            Text(
              'Status: $diagnosticStatus',
              style: TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.bold),
            ),
        ],
      ),
      trailing: isFriend
          ? ElevatedButton.icon(
        icon: const Icon(Iconsax.message, size: 18),
        label: const Text('محادثة'),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(partnerId: user.id, partnerUsername: user.username))),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
      )
          : OutlinedButton.icon(
        icon: const Icon(Iconsax.user_add, size: 18),
        label: const Text('إضافة'),
        onPressed: () {
          LocalNetworkService().sendConnectionRequest(user);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال طلب صداقة إلى ${user.username}')));
        },
      ),
    );
  }
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<List<User>>? _connectionSubscription;
  List<String> _conversationPartnerIds = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _messageSubscription = LocalNetworkService().messageStream.listen((Message message) {
      _loadConversations();
    });
    _connectionSubscription = LocalNetworkService().connectionStream.listen((List<User> users) {
      _loadConversations();
    });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  void _loadConversations() {
    final allMessages = LocalNetworkService().getAllMessages();
    final friendIds = LocalNetworkService().getFriendIds();
    final partnerIds = <String>{...allMessages.keys, ...friendIds}.toList();
    partnerIds.sort((a, b) {
      final lastMsgA = LocalNetworkService().getMessagesForUser(a).lastOrNull;
      final lastMsgB = LocalNetworkService().getMessagesForUser(b).lastOrNull;
      if (lastMsgB == null) return -1;
      if (lastMsgA == null) return 1;
      return lastMsgB.timestamp.compareTo(lastMsgA.timestamp);
    });

    if (mounted) {
      setState(() {
        _conversationPartnerIds = partnerIds;
      });
    }
  }

  void _showConversationOptions(BuildContext context, String friendId, String username) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Iconsax.trash, color: Colors.red),
              title: const Text('حذف المحادثة', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await _showConfirmationDialog(
                  context,
                  title: 'تأكيد حذف المحادثة',
                  content: 'هل أنت متأكد؟ سيتم حذف جميع الرسائل مع $username بشكل نهائي.',
                  confirmText: 'حذف',
                );
                if (confirm == true) {
                  await LocalNetworkService().deleteConversation(friendId);
                  _loadConversations();
                }
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.user_remove, color: Colors.orange),
              title: const Text('إلغاء الصداقة', style: TextStyle(color: Colors.orange)),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await _showConfirmationDialog(
                  context,
                  title: 'تأكيد إلغاء الصداقة',
                  content: 'سيؤدي هذا إلى إزالة $username من قائمة أصدقائك وحذف المحادثة.',
                  confirmText: 'إلغاء الصداقة',
                );
                if (confirm == true) {
                  await LocalNetworkService().unfriend(friendId);
                  _loadConversations();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('إلغاء'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showConfirmationDialog(BuildContext context, {required String title, required String content, required String confirmText}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_conversationPartnerIds.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Iconsax.message_remove, size: 64, color: Colors.grey), SizedBox(height: 16), Text('لا توجد محادثات بعد', style: TextStyle(fontSize: 18, color: Colors.grey)), Text('أضف أصدقاء من تبويب "الشبكة" لبدء المحادثة', style: TextStyle(color: Colors.grey))]));
    }

    final connectedFriends = LocalNetworkService().getConnectedFriends();

    return ListView.builder(
      itemCount: _conversationPartnerIds.length,
      itemBuilder: (context, index) {
        final partnerId = _conversationPartnerIds[index];
        final username = LocalNetworkService().getUsernameFromDirectory(partnerId);
        final lastMessage = LocalNetworkService().getMessagesForUser(partnerId).lastOrNull;
        final isOnline = connectedFriends.any((c) => c.id == partnerId);

        return ListTile(
          leading: Stack(children: [
            CircleAvatar(radius: 25, backgroundColor: Colors.grey.shade200, child: Text(username.isNotEmpty ? username[0] : '?')),
            if (isOnline) Positioned(bottom: 0, right: 0, child: Container(width: 15, height: 15, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))),
          ]),
          title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(lastMessage?.content ?? 'لا توجد رسائل', maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: lastMessage != null ? Text('${lastMessage.timestamp.hour}:${lastMessage.timestamp.minute.toString().padLeft(2, '0')}') : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(partnerId: partnerId, partnerUsername: username))),
          onLongPress: () => _showConversationOptions(context, partnerId, username),
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String partnerId;
  final String partnerUsername;
  const ChatScreen({super.key, required this.partnerId, required this.partnerUsername});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<Message> _messages = [];
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<Map<String, UserStatus>>? _statusSubscription;
  final User? currentUser = LocalNetworkService().getCurrentUser();
  bool _isPartnerTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
    _messageSubscription = LocalNetworkService().messageStream.listen((message) {
      if ((message.senderId == widget.partnerId && message.receiverId == currentUser?.id) ||
          (message.senderId == currentUser?.id && message.receiverId == widget.partnerId)) {
        if (mounted) {
          setState(() => _messages.insert(0, message));
        }
      }
    });

    // متابعة حالة الشريك
    _statusSubscription = LocalNetworkService().statusStream.listen((statuses) {
      if (mounted && statuses.containsKey(widget.partnerId)) {
        final partnerStatus = statuses[widget.partnerId]!;
        setState(() {
          _isPartnerTyping = partnerStatus.isTyping;
        });

        // إعادة تعيين حالة الكتابة بعد 3 ثواني
        _typingTimer?.cancel();
        if (partnerStatus.isTyping) {
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isPartnerTyping = false;
              });
            }
          });
        }
      }
    });
  }

  void _loadInitialMessages() {
    final initialMessages = LocalNetworkService().getMessagesForUser(widget.partnerId);
    setState(() {
      _messages = initialMessages.reversed.toList();
    });
  }

  void _onTextChanged(String text) {
    // إرسال حالة الكتابة عندما يبدأ المستخدم بالكتابة
    if (text.isNotEmpty) {
      LocalNetworkService().sendTypingStatus(widget.partnerId, true);
    } else {
      LocalNetworkService().sendTypingStatus(widget.partnerId, false);
    }
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty || currentUser == null) return;

    // إيقاف حالة الكتابة
    LocalNetworkService().sendTypingStatus(widget.partnerId, false);

    final message = Message(
      id: const Uuid().v4(),
      senderId: currentUser!.id,
      receiverId: widget.partnerId,
      content: _messageController.text,
      timestamp: DateTime.now(),
    );
    LocalNetworkService().sendMessage(message);
    setState(() => _messages.insert(0, message));
    _messageController.clear();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    _typingTimer?.cancel();
    // إيقاف حالة الكتابة عند الخروج
    if (currentUser != null) {
      LocalNetworkService().sendTypingStatus(widget.partnerId, false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.partnerUsername),
            if (_isPartnerTyping)
              const Text(
                'يكتب الآن...',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.green),
              ),
          ],
        ),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            reverse: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isMe = message.senderId == currentUser?.id;
              return MessageBubble(
                text: message.content,
                isMe: isMe,
                time: '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                onChanged: _onTextChanged,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: IconButton(
                icon: const Icon(Iconsax.send_1, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  const MessageBubble({super.key, required this.text, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: isMe ? const Color(0xFFDCF8C6) : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey.shade200, spreadRadius: 1, blurRadius: 1)]),
        child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [Text(text, style: const TextStyle(color: Colors.black87)), const SizedBox(height: 4), Text(time, style: TextStyle(color: Colors.grey.shade600, fontSize: 10))]),
      ),
    );
  }
}

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة المنشورات (قيد التطوير)'));
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    if (mounted) {
      setState(() {
        _currentUser = LocalNetworkService().getCurrentUser();
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد تسجيل الخروج'),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج؟ سيتم مسح جميع بياناتك المحفوظة على هذا الجهاز.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await LocalNetworkService().stop();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      _loadUserData();
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Iconsax.user, size: 50)),
            const SizedBox(height: 20),
            Text(_currentUser!.username, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_currentUser!.id, style: const TextStyle(fontSize: 14, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Iconsax.logout),
              label: const Text('تسجيل الخروج'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  StreamSubscription<List<Group>>? _groupsSubscription;
  List<Group> _groups = [];

  @override
  void initState() {
    super.initState();
    _groupsSubscription = LocalNetworkService().groupsStream.listen((groups) {
      if (mounted) {
        setState(() {
          _groups = groups;
        });
      }
    });
    // تحميل المجموعات الحالية
    _loadGroups();
  }

  void _loadGroups() {
    setState(() {
      _groups = LocalNetworkService().getUserGroups();
    });
  }

  @override
  void dispose() {
    _groupsSubscription?.cancel();
    super.dispose();
  }

  void _navigateToCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
    );
  }

  void _navigateToGroupChat(Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupChatScreen(
          group: group,
        ),
      ),
    );
  }

  void _showGroupOptions(BuildContext context, Group group) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Iconsax.people, color: Colors.blue),
              title: const Text('عرض الأعضاء'),
              onTap: () {
                Navigator.pop(context);
                _showGroupMembers(context, group);
              },
            ),
            if (group.adminId == LocalNetworkService().getCurrentUser()?.id)
              ListTile(
                leading: const Icon(Iconsax.user_add, color: Colors.green),
                title: const Text('إضافة أعضاء'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToAddMembers(group);
                },
              ),
            ListTile(
              leading: const Icon(Iconsax.logout, color: Colors.orange),
              title: const Text('مغادرة المجموعة'),
              onTap: () {
                Navigator.pop(context);
                _showLeaveGroupConfirmation(context, group);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined),
              title: const Text('إلغاء'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void _showGroupMembers(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('أعضاء ${group.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: group.memberIds.length,
            itemBuilder: (context, index) {
              final memberId = group.memberIds[index];
              final username = LocalNetworkService().getUsernameFromDirectory(memberId);
              final isAdmin = memberId == group.adminId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey.shade200,
                  child: Text(username.isNotEmpty ? username[0].toUpperCase() : '?'),
                ),
                title: Text(username),
                trailing: isAdmin
                    ? const Chip(label: Text('مدير'), backgroundColor: Colors.amber)
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _navigateToAddMembers(Group group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMembersScreen(group: group),
      ),
    );
  }

  void _showLeaveGroupConfirmation(BuildContext context, Group group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مغادرة المجموعة'),
        content: Text('هل أنت متأكد أنك تريد مغادرة مجموعة "${group.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              LocalNetworkService().leaveGroup(group.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('لقد غادرت مجموعة "${group.name}"')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('مغادرة'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المجموعات'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add),
            onPressed: _navigateToCreateGroup,
          ),
        ],
      ),
      body: _groups.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.people, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد مجموعات بعد', style: TextStyle(fontSize: 18, color: Colors.grey)),
            Text('أنشئ مجموعة جديدة لبدء المحادثة الجماعية', style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          _loadGroups();
          return Future.delayed(const Duration(seconds: 1));
        },
        child: ListView.builder(
          itemCount: _groups.length,
          itemBuilder: (context, index) {
            final group = _groups[index];
            final isAdmin = group.adminId == LocalNetworkService().getCurrentUser()?.id;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // إضافة margin
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.shade100,
                  child: Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  group.name,
                  overflow: TextOverflow.ellipsis, // منع تجاوز النص
                  maxLines: 1, // تحديد سطر واحد
                ),
                subtitle: Text(
                  '${group.memberIds.length} أعضاء ${isAdmin ? ' • مدير' : ''}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                trailing: const Icon(Iconsax.arrow_left_2, size: 18), // تصغير الحجم
                onTap: () => _navigateToGroupChat(group),
                onLongPress: () => _showGroupOptions(context, group),
              ),
            );
          },
        ),
      ),

    );
  }
}



class CreateGroupScreen extends StatefulWidget {
const CreateGroupScreen({super.key});

@override
State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
final TextEditingController _groupNameController = TextEditingController();
final List<User> _selectedFriends = [];
 List<User> _availableFriends = [];

@override
void initState() {
super.initState();
_loadAvailableFriends();
}

void _loadAvailableFriends() {
final friends = LocalNetworkService().getConnectedFriends();
setState(() {
_availableFriends = friends;
});
}

void _createGroup() {
if (_groupNameController.text.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('يرجى إدخال اسم المجموعة')),
);
return;
}

if (_selectedFriends.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('يرجى اختيار أصدقاء للمجموعة')),
);
return;
}

final memberIds = _selectedFriends.map((user) => user.id).toList();
LocalNetworkService().createGroup(_groupNameController.text, memberIds);

ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('تم إنشاء المجموعة بنجاح')),
);

Navigator.pop(context);
}

void _toggleFriendSelection(User friend) {
setState(() {
if (_selectedFriends.contains(friend)) {
_selectedFriends.remove(friend);
} else {
_selectedFriends.add(friend);
}
});
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: const Text('إنشاء مجموعة جديدة')),
body: Padding(
padding: const EdgeInsets.all(16),
child: Column(
children: [
TextField(
controller: _groupNameController,
decoration: const InputDecoration(
labelText: 'اسم المجموعة',
hintText: 'أدخل اسم المجموعة...',
border: OutlineInputBorder(),
prefixIcon: Icon(Iconsax.people),
),
),
const SizedBox(height: 20),
Row(
children: [
const Text('الأعضاء المحددون:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
const SizedBox(width: 8),
Chip(
label: Text('${_selectedFriends.length} عضو'),
backgroundColor: Colors.teal.shade100,
),
],
),
const SizedBox(height: 10),
if (_selectedFriends.isNotEmpty)
SizedBox(
height: 60,
child: ListView.builder(
scrollDirection: Axis.horizontal,
itemCount: _selectedFriends.length,
itemBuilder: (context, index) {
final friend = _selectedFriends[index];
return Container(
margin: const EdgeInsets.only(right: 8),
child: Chip(
label: Text(friend.username),
onDeleted: () => _toggleFriendSelection(friend),
),
);
},
),
),
const SizedBox(height: 20),
const Text('اختر الأصدقاء:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
const SizedBox(height: 10),
  Expanded(
    child: _availableFriends.isEmpty
        ? const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.people, size: 48, color: Colors.grey), // تصغير الأيقونة
          SizedBox(height: 12),
          Text('لا توجد أصدقاء متصلين',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          Text('أضف أصدقاء من تبويب "الشبكة" أولاً',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(0), // إزالة padding إضافي
      itemCount: _availableFriends.length,
      itemBuilder: (context, index) {
        final friend = _availableFriends[index];
        final isSelected = _selectedFriends.contains(friend);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 2), // تقليل المسافة
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8), // تقليل padding
            title: Text(
              friend.username,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Text(
              friend.id,
              style: const TextStyle(fontSize: 10), // تصغير الخط
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            value: isSelected,
            onChanged: (value) => _toggleFriendSelection(friend),
            secondary: CircleAvatar(
              radius: 16, // تصغير حجم الصورة
              backgroundColor: Colors.grey.shade200,
              child: Text(
                friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        );
      },
    ),
  ),

  const SizedBox(height: 20),
SizedBox(
width: double.infinity,
height: 50,
child: ElevatedButton.icon(
onPressed: _createGroup,
icon: const Icon(Iconsax.people),
label: const Text('إنشاء المجموعة'),
style: ElevatedButton.styleFrom(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
),
),
],
),
),
);
}
}


class AddMembersScreen extends StatefulWidget {
final Group group;

const AddMembersScreen({super.key, required this.group});

@override
State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
final List<User> _selectedFriends = [];
 List<User> _availableFriends = [];

@override
void initState() {
super.initState();
_loadAvailableFriends();
}

void _loadAvailableFriends() {
final allFriends = LocalNetworkService().getConnectedFriends();
// استبعاد الأعضاء الحاليين في المجموعة
final currentMemberIds = widget.group.memberIds.toSet();
setState(() {
_availableFriends = allFriends.where((friend) => !currentMemberIds.contains(friend.id)).toList();
});
}

void _addMembers() {
if (_selectedFriends.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(content: Text('يرجى اختيار أصدقاء للإضافة')),
);
return;
}

final newMemberIds = _selectedFriends.map((user) => user.id).toList();
LocalNetworkService().addMembersToGroup(widget.group.id, newMemberIds);

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('تم إضافة ${_selectedFriends.length} عضو للمجموعة')),
);

Navigator.pop(context);
}

void _toggleFriendSelection(User friend) {
setState(() {
if (_selectedFriends.contains(friend)) {
_selectedFriends.remove(friend);
} else {
_selectedFriends.add(friend);
}
});
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(title: Text('إضافة أعضاء لـ ${widget.group.name}')),
body: Padding(
padding: const EdgeInsets.all(16),
child: Column(
children: [
Row(
children: [
const Text('الأعضاء المحددون:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
const SizedBox(width: 8),
Chip(
label: Text('${_selectedFriends.length} عضو'),
backgroundColor: Colors.teal.shade100,
),
],
),
const SizedBox(height: 10),
if (_selectedFriends.isNotEmpty)
SizedBox(
height: 60,
child: ListView.builder(
scrollDirection: Axis.horizontal,
itemCount: _selectedFriends.length,
itemBuilder: (context, index) {
final friend = _selectedFriends[index];
return Container(
margin: const EdgeInsets.only(right: 8),
child: Chip(
label: Text(friend.username),
onDeleted: () => _toggleFriendSelection(friend),
),
);
},
),
),
const SizedBox(height: 20),
const Text('الأصدقاء المتاحون:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
const SizedBox(height: 10),
Expanded(
child: _availableFriends.isEmpty
? const Center(
child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Iconsax.people, size: 64, color: Colors.grey),
SizedBox(height: 16),
Text('لا توجد أصدقاء متاحين للإضافة', style: TextStyle(color: Colors.grey)),
Text('جميع أصدقائك موجودين بالفعل في المجموعة', style: TextStyle(color: Colors.grey)),
],
),
)
    : ListView.builder(
itemCount: _availableFriends.length,
itemBuilder: (context, index) {
final friend = _availableFriends[index];
final isSelected = _selectedFriends.contains(friend);
return CheckboxListTile(
title: Text(friend.username),
subtitle: Text(friend.id, style: const TextStyle(fontSize: 12)),
value: isSelected,
onChanged: (value) => _toggleFriendSelection(friend),
secondary: CircleAvatar(
backgroundColor: Colors.grey.shade200,
child: Text(friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?'),
),
);
},
),
),
const SizedBox(height: 20),
SizedBox(
width: double.infinity,
height: 50,
child: ElevatedButton.icon(
onPressed: _addMembers,
icon: const Icon(Iconsax.user_add),
label: const Text('إضافة الأعضاء المحددين'),
style: ElevatedButton.styleFrom(
shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
),
),
),
],
),
),
);
}
}



class GroupChatScreen extends StatefulWidget {
final Group group;

const GroupChatScreen({super.key, required this.group});

@override
State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
final TextEditingController _messageController = TextEditingController();
List<GroupMessage> _messages = [];
StreamSubscription<GroupMessage>? _groupMessageSubscription;

@override
void initState() {
super.initState();
_loadInitialMessages();
_groupMessageSubscription = LocalNetworkService().groupMessageStream.listen((message) {
if (message.groupId == widget.group.id && mounted) {
setState(() => _messages.insert(0, message));
}
});
}

void _loadInitialMessages() {
final initialMessages = LocalNetworkService().getGroupMessages(widget.group.id);
setState(() {
_messages = initialMessages.reversed.toList();
});
}

void _sendMessage() {
if (_messageController.text.isEmpty) return;
LocalNetworkService().sendGroupMessage(widget.group.id, _messageController.text);
_messageController.clear();
}

void _showGroupInfo() {
showDialog(
context: context,
builder: (context) => AlertDialog(
title: Text('معلومات المجموعة: ${widget.group.name}'),
content: SizedBox(
width: double.maxFinite,
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text('عدد الأعضاء: ${widget.group.memberIds.length}'),
const SizedBox(height: 10),
const Text('الأعضاء:', style: TextStyle(fontWeight: FontWeight.bold)),
const SizedBox(height: 5),
...widget.group.memberIds.map((memberId) {
final username = LocalNetworkService().getUsernameFromDirectory(memberId);
final isAdmin = memberId == widget.group.adminId;
return ListTile(
dense: true,
contentPadding: EdgeInsets.zero,
leading: CircleAvatar(
radius: 16,
backgroundColor: Colors.grey.shade200,
child: Text(
username.isNotEmpty ? username[0].toUpperCase() : '?',
style: const TextStyle(fontSize: 12),
),
),
title: Text(username, style: const TextStyle(fontSize: 14)),
trailing: isAdmin
? const Chip(
label: Text('مدير', style: TextStyle(fontSize: 10)),
backgroundColor: Colors.amber,
padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
)
    : null,
);
}).toList(),
],
),
),
actions: [
TextButton(
onPressed: () => Navigator.pop(context),
child: const Text('إغلاق'),
),
],
),
);
}

@override
void dispose() {
_groupMessageSubscription?.cancel();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(widget.group.name),
Text(
'${widget.group.memberIds.length} أعضاء',
style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
),
],
),
actions: [
IconButton(
icon: const Icon(Iconsax.info_circle),
onPressed: _showGroupInfo,
),
],
),
body: Column(
children: [
Expanded(
child: _messages.isEmpty

    ? const Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Iconsax.message, size: 64, color: Colors.grey),
      SizedBox(height: 16),
      Text('لا توجد رسائل بعد', style: TextStyle(fontSize: 18, color: Colors.grey)),
      Text('ابدأ المحادثة مع المجموعة', style: TextStyle(color: Colors.grey)),
    ],
  ),
)
    : ListView.builder(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16), // تقليل padding
  reverse: true,
  itemCount: _messages.length,
  itemBuilder: (context, index) {
    final message = _messages[index];
    final isMe = message.senderId == LocalNetworkService().getCurrentUser()?.id;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2), // تقليل المسافة
      child: GroupMessageBubble(
        text: message.content,
        isMe: isMe,
        time: '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
        senderName: LocalNetworkService().getUsernameFromDirectory(message.senderId),
      ),
    );
  },
),
),

Container(
padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
color: Colors.grey.shade100,
child: Row(
children: [
Expanded(
child: TextField(
controller: _messageController,
decoration: InputDecoration(
hintText: 'اكتب رسالة للمجموعة...',
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(24),
borderSide: BorderSide.none,
),
filled: true,
fillColor: Colors.white,
contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
),
onSubmitted: (_) => _sendMessage(),
),
),
const SizedBox(width: 8),
CircleAvatar(
backgroundColor: Theme.of(context).primaryColor,
child: IconButton(
icon: const Icon(Iconsax.send_1, color: Colors.white, size: 20),
onPressed: _sendMessage,
),
),
],
),
),
],
),
);
}
}
class GroupMessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String time;
  final String senderName;

  const GroupMessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    required this.time,
    required this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75, // تحديد عرض أقصى
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // تقليل padding
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                spreadRadius: 0.5,
                blurRadius: 0.5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // مهم لمنع التجاوز
            children: [
              if (!isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    senderName,
                    style: const TextStyle(
                      fontSize: 11, // تصغير الخط
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14, // حجم خط مناسب
                ),
                overflow: TextOverflow.visible, // السماح بتجاوز النص مع التحكم بالعرض
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 9, // تصغير حجم وقت الرسالة
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  StreamSubscription<List<AppNotification>>? _notificationsSubscription;
  List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _notificationsSubscription = LocalNetworkService().notificationsStream.listen((notifications) {
      if (mounted) {
        setState(() {
          _notifications = notifications;
        });
      }
    });
    _loadNotifications();
  }

  void _loadNotifications() {
    setState(() {
      _notifications = LocalNetworkService().getNotifications();
    });
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    super.dispose();
  }

  void _markAllAsRead() {
    LocalNetworkService().markAllNotificationsAsRead();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديد جميع الإشعارات كمقروءة')),
    );
  }

  void _clearAllNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح جميع الإشعارات'),
        content: const Text('هل أنت متأكد أنك تريد مسح جميع الإشعارات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              // سنضيف دالة مسح الإشعارات لاحقاً
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم إضافة هذه الميزة قريباً')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('مسح الكل'),
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'friend_request':
        return Iconsax.user_add;
      case 'message':
        return Iconsax.message;
      case 'group_message':
        return Iconsax.people;
      case 'system':
        return Iconsax.info_circle;
      default:
        return Iconsax.notification;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'friend_request':
        return Colors.blue;
      case 'message':
        return Colors.green;
      case 'group_message':
        return Colors.purple;
      case 'system':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _handleNotificationTap(AppNotification notification) {
    // وضع علامة مقروء
    LocalNetworkService().markNotificationAsRead(notification.id);

    // التنقل حسب نوع الإشعار
    switch (notification.type) {
      case 'friend_request':
      // التنقل لشاشة طلبات الصداقة
        break;
      case 'message':
        final conversationId = notification.data?['conversationId'];
        if (conversationId != null) {
          final username = LocalNetworkService().getUsernameFromDirectory(conversationId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                partnerId: conversationId,
                partnerUsername: username,
              ),
            ),
          );
        }
        break;
      case 'group_message':
        final groupId = notification.data?['groupId'];
        if (groupId != null) {
          final group = LocalNetworkService().getUserGroups().firstWhere(
                (g) => g.id == groupId,
            orElse: () => Group(
              id: '',
              name: 'مجموعة',
              adminId: '',
              memberIds: [],
              createdAt: DateTime.now(),
            ),
          );
          if (group.id.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupChatScreen(group: group),
              ),
            );
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          if (_notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Iconsax.tick_circle),
              onPressed: _markAllAsRead,
              tooltip: 'تحديد الكل كمقروء',
            ),
            IconButton(
              icon: const Icon(Iconsax.trash),
              onPressed: _clearAllNotifications,
              tooltip: 'مسح الكل',
            ),
          ],
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.notification, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('لا توجد إشعارات', style: TextStyle(fontSize: 18, color: Colors.grey)),
            Text('سيظهر هنا جميع الإشعارات والتنبيهات', style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: () async {
          _loadNotifications();
          return Future.delayed(const Duration(seconds: 1));
        },
        child: ListView.builder(
          itemCount: _notifications.length,
          itemBuilder: (context, index) {
            final notification = _notifications[index];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Card(
                color: notification.isRead ? Colors.white : Colors.blue.shade50,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getNotificationColor(notification.type),
                    child: Icon(
                      _getNotificationIcon(notification.type),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification.body),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(notification.timestamp),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: notification.isRead
                      ? null
                      : const Icon(Iconsax.eye, size: 16, color: Colors.blue),
                  onTap: () => _handleNotificationTap(notification),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inHours < 1) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inDays < 1) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
