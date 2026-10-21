// استيراد الحزم الأساسية والمكتبات الضرورية
import 'dart:async'; // للتعامل مع العمليات غير المتزامنة والمؤقتات (Timers)
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart'; // لاستخدام `debugPrint` وأدوات فلاتر الأساسية
import 'package:network_info_plus/network_info_plus.dart'; // للحصول على معلومات الشبكة مثل IP
import 'package:path/path.dart' as p; // للتعامل مع مسارات الملفات
import 'package:path_provider/path_provider.dart'; // للحصول على مسارات تخزين الملفات في الجهاز
import 'package:shared_preferences/shared_preferences.dart'; // لتخزين البيانات البسيطة بشكل دائم
import 'package:uuid/uuid.dart'; // لإنشاء معرفات فريدة عالمية (UUIDs)

import 'system_notification_service.dart';
import 'encryption_service.dart';
import 'log_service.dart';

// استيراد نماذج البيانات (Data Models) من مواقعها الجديدة في المشروع
import '../../features/auth/models/user_model.dart';
import '../../features/chat/models/file_message_model.dart';
import '../../features/chat/models/group_message_model.dart';
import '../../features/chat/models/group_model.dart';
import '../../features/chat/models/message_model.dart';
import '../../features/notifications/models/notification_model.dart';
import '../../features/status/models/user_status_model.dart';
import '../../features/call/models/call_model.dart';
import '../../features/chat/models/pending_message_model.dart';
import 'database_service.dart';
import 'message_queue_service.dart';
import 'network_helper.dart';

// =================================================================================
// 🧠 LocalNetworkService - The Definitive Build (v7.0) - Callback-Based
// =================================================================================
class LocalNetworkService {
  // --- Singleton Pattern ---
  static final LocalNetworkService _instance = LocalNetworkService._internal();
  factory LocalNetworkService() => _instance;
  LocalNetworkService._internal();

  // --- Core Components ---
  final DatabaseService _dbService = DatabaseService();
  final MessageQueueService _queueService = MessageQueueService();
  final NetworkInfo _networkInfo = NetworkInfo();
  User? _currentUser;
  RawDatagramSocket? _broadcastSocket;
  final List<RawDatagramSocket> _sendSockets = [];
  ServerSocket? _serverSocket;
  Timer? _announcementTimer;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _statusCheckTimer;

  // --- Data Directories & State ---
  final Map<String, String> _ipDirectory = {};
  final Map<String, String> _userDirectory = {};
  final Map<String, Socket> _userSockets = {};
  final List<String> _friendIds = [];
  final Map<String, List<Message>> _allMessages = {};
  final List<User> _discoveredUsers = [];
  final Map<String, Group> _groups = {};
  final Map<String, List<GroupMessage>> _groupMessages = {};
  final Map<String, List<FileMessage>> _fileMessages = {};
  final Map<String, List<String>> _userGroups = {};
  final Map<String, UserStatus> _userStatuses = {};
  final List<AppNotification> _notifications = [];
  final Map<String, Timer> _typingTimers = {};
  final Map<String, DateTime> _reconnectAttempts = {};
  final Map<String, int> _reconnectCounters = {};
  final Map<String, bool> _pendingConnections = {};
  final Map<String, List<Map<String, dynamic>>> _pendingCallSignals = {};
  final List<Map<String, dynamic>> _pendingWebRtcSignals = [];
  final Map<String, DateTime> _lastPongTime = {};
  final Set<String> _doubtfulConnections = {};
  final Set<String> _quickReconnecting = {};
  final Map<String, DateTime> _lastQuickReconnect = {};
  final Map<String, Completer<bool>> _pingCompleters = {};
  final Set<String> _callProtectedSockets = {};
  final Map<String, DateTime> _lastDiscoverReconnect = {};
  final Map<String, Timer> _pendingOldSocketClosers = {};
  final Map<Socket, DateTime> _socketLastActivity = {};

  // --- File Transfer State ---
  final Map<String, _FileTransferState> _incomingFileTransfers = {};
  final Map<String, List<List<int>>> _pendingFileChunks = {};
  final Map<String, bool> _pendingFileEnds = {};

  // --- Settings ---
  bool _showOnlineStatus = true;
  bool _readReceipts = true;
  final ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

  // --- Call Socket Channel (isolated from _userSockets) ---
  final Map<String, Socket> _callSockets = {};
  final Map<String, DateTime> _callLastPongTime = {};
  final Map<String, Completer<bool>> _callPingCompleters = {};
  final Set<String> _callQuickReconnecting = {};
  final Map<String, DateTime> _lastCallQuickReconnect = {};
  final Map<String, bool> _pendingCallConnections = {};
  Timer? _callHeartbeatTimer;

  // --- Call Management ---
  final Map<String, CallModel> _activeCalls = {};
  final Map<String, Timer> _callTimers = {};
  CallHistory _callHistory = CallHistory(calls: []);
  bool _isCallActive = false;

  // --- UI Callbacks ---
  VoidCallback? onFriendsChanged;
  VoidCallback? onDiscoveryChanged;
  VoidCallback? onGroupsChanged;
  VoidCallback? onNotificationsChanged;
  VoidCallback? onStatusChanged;
  Function(Message)? onPrivateMessageReceived;
  Function(GroupMessage)? onGroupMessageReceived;
  Function(FileMessage)? onFileMessageReceived;
  Function(User, dynamic)? onConnectionRequestReceived;
// ...
  Function(String, String)? onMessageDeleted; // conversationId, messageId
// ...
// ...
  Function(String, String, String)? onMessageEdited; // conversationId, messageId, newContent
  Function(String, String, String)? onGroupMessageEdited;
  Function(String, String)? onGroupMessageDeleted;

  // --- Call Callbacks ---
  final Set<Function(CallModel)> _incomingCallListeners = {};
  Function(CallModel)? onCallStatusChanged;
  Function(String)? onCallEnded;
  Function(String, Map<String, dynamic>)? onCallSignalReceived;

  // --- Queue Callbacks ---
  Function(String, DeliveryStatus)? onMessageDeliveryStatusChanged;
  VoidCallback? onQueueChanged;

  // --- Lifecycle State ---
  bool _isServiceRunning = false;

  List<String> getDiagnosticLog() => LogService().getBuffer();

  String? getDiagnosticSendSocketsInfo() {
    if (_sendSockets.isEmpty) return 'لا يوجد';
    try {
      return _sendSockets.map((s) => '${s.address.address}:${s.port}').join(', ');
    } catch (_) {
      return 'بعض المقابس مغلقة';
    }
  }

  int getDiagnosticSendSocketCount() => _sendSockets.length;
  bool getDiagnosticBroadcastSocketAlive() => _broadcastSocket != null;
  bool getDiagnosticServerSocketAlive() => _serverSocket != null;
  int getDiagnosticDiscoveredUserCount() => _discoveredUsers.length;
  int getDiagnosticConnectedFriendsCount() => _userSockets.length;
  int getDiagnosticFriendIdsCount() => _friendIds.length;
  Map<String, String> getDiagnosticIpDirectory() => Map.unmodifiable(_ipDirectory);
  List<String> getDiagnosticDiscoveredUserNames() =>
      _discoveredUsers.map((u) => '${u.username} (${u.id.substring(0, 8)}...)').toList();

  // --- Public Getters ---
  bool get isRunning => _isServiceRunning;
  bool isFriendDoubtful(String userId) => _doubtfulConnections.contains(userId);
  User? getCurrentUser() => _currentUser;
  void updateCurrentUser(User updatedUser) {
    _currentUser = updatedUser;
    unawaited(_persistCurrentUser());
  }
  Future<void> _persistCurrentUser() async {
    if (_currentUser == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', _currentUser!.username);
    await prefs.setString('user_uuid', _currentUser!.id);
    if (_currentUser!.bio != null) await prefs.setString('user_bio', _currentUser!.bio!);
    if (_currentUser!.profileImage != null) await prefs.setString('user_avatar', _currentUser!.profileImage!);
  }
  List<Message> getMessagesForUser(String userId) => _allMessages[userId] ?? [];
  String getUsernameFromDirectory(String userId) => _userDirectory[userId] ?? 'صديق غير معروف';
  List<User> getConnectedFriends() => _friendIds.where((id) => _userSockets.containsKey(id)).map((id) => User(id: id, username: _userDirectory[id] ?? '...')).toList();
  bool get showOnlineStatus => _showOnlineStatus;
  bool get readReceipts => _readReceipts;
  List<User> getDiscoveredUsers() => _discoveredUsers;
  List<String> getFriendIds() => _friendIds;
  List<Group> getUserGroups() => _userGroups[_currentUser?.id]?.map((groupId) => _groups[groupId]!).toList() ?? [];
  List<GroupMessage> getGroupMessages(String groupId) => _groupMessages[groupId] ?? [];
  List<FileMessage> getFileMessages(String conversationId) => _fileMessages[conversationId] ?? [];
  List<AppNotification> getNotifications() => _notifications;
  Map<String, UserStatus> getUserStatuses() => _userStatuses;

  // --- Queue Status Getters ---
  Future<int> getPendingMessageCount() => _queueService.getPendingCount();
  Future<int> getPendingMessageCountForPeer(String peerId) => _queueService.getPendingCountForPeer(peerId);
  Future<DeliveryStatus?> getMessageStatus(String messageId) => _queueService.getMessageDeliveryStatus(messageId);

  // --- Core Service Lifecycle ---
  Future<void> start(User user) async {
    if (_isServiceRunning) return;
    _isServiceRunning = true;
    LogService.i('بدء الخدمة');
    LogService.i("🚀 Starting LocalNetworkService v7.1 (Event-Driven)...");
    await EncryptionService().init();
    _currentUser = user;
    await _loadDataFromStorage();
    await _dbService.resetStuckPendingMessages();
    await _queueService.loadPendingIntoMemory();
    await _startDiscoveryListener();
    await _initSendSockets();
    await _startMainServer();

    // === النظام الجديد (v7.1) ===
    // 1. إرسال 3 إعلانات USER_ONLINE عند الدخول
    await _sendInitialOnlineAnnouncement();

    // 2. بدء Keep-Alive (كل 60 ثانية)
    _startReconnectScheduler();
    _startHeartbeatSystem();

    // 3. مسح TCP لاكتشاف الأجهزة (مرة واحدة عند التشغيل)
    _scanSubnets();

    final statusEmoji = (_broadcastSocket != null && _serverSocket != null) ? "✅" : "⚠️";
    LogService.i('الخدمة بدأت (v7.1): UDP=${_broadcastSocket != null}, Sends=${_sendSockets.length}, TCP=${_serverSocket != null}');
    LogService.i("$statusEmoji LocalNetworkService v7.1 started (recv=${_broadcastSocket != null}, send=${_sendSockets.length}, tcp=${_serverSocket != null})");
  }

  Future<void> stop() async {
    if (!_isServiceRunning) return;
    _isServiceRunning = false;
    LogService.i("🛑 Stopping LocalNetworkService...");

    // إرسال USER_OFFLINE قبل الإغلاق
    await _sendOfflineAnnouncement();

    _announcementTimer?.cancel();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _statusCheckTimer?.cancel();
    _callHeartbeatTimer?.cancel();
    _callSignalDrainTimer?.cancel();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    _broadcastSocket?.close();
    for (final s in _sendSockets) { s.close(); }
    _sendSockets.clear();
    await _serverSocket?.close();
    // Create a copy of the sockets to avoid concurrent modification
    final socketsToClose = List<Socket>.from(_userSockets.values);
    socketsToClose.forEach(_safeSocketClose);
    _userSockets.clear();
    final callSocketsToClose = List<Socket>.from(_callSockets.values);
    callSocketsToClose.forEach(_safeSocketClose);
    _callSockets.clear();
    _callLastPongTime.clear();
    _callPingCompleters.clear();
    for (final timer in _pendingOldSocketClosers.values) {
      timer.cancel();
    }
    _pendingOldSocketClosers.clear();
    onFriendsChanged?.call();
    LogService.i("🗑️ LocalNetworkService stopped.");
  }

  // --- Callback Registration ---
  void registerCallbacks({
    VoidCallback? onFriendsChanged,
    VoidCallback? onDiscoveryChanged,
    VoidCallback? onGroupsChanged,
    VoidCallback? onNotificationsChanged,
    VoidCallback? onStatusChanged,
    Function(Message)? onPrivateMessageReceived,
    Function(GroupMessage)? onGroupMessageReceived,
    Function(FileMessage)? onFileMessageReceived,
    Function(String, String, String)? onMessageEdited,
    Function(String, String, String)? onGroupMessageEdited,
    Function(String, String)? onGroupMessageDeleted,
    Function(User, dynamic)? onConnectionRequestReceived,
    Function(String, String)? onMessageDeleted,
    Function(CallModel)? onIncomingCall,
    Function(CallModel)? onCallStatusChanged,
    Function(String)? onCallEnded,
    Function(String, Map<String, dynamic>)? onCallSignalReceived,
    Function(String, DeliveryStatus)? onMessageDeliveryStatusChanged,
    VoidCallback? onQueueChanged,
  }) {
    if (onFriendsChanged != null) this.onFriendsChanged = onFriendsChanged;
    if (onDiscoveryChanged != null) this.onDiscoveryChanged = onDiscoveryChanged;
    if (onGroupsChanged != null) this.onGroupsChanged = onGroupsChanged;
    if (onNotificationsChanged != null) this.onNotificationsChanged = onNotificationsChanged;
    if (onStatusChanged != null) this.onStatusChanged = onStatusChanged;
    if (onPrivateMessageReceived != null) this.onPrivateMessageReceived = onPrivateMessageReceived;
    if (onGroupMessageReceived != null) this.onGroupMessageReceived = onGroupMessageReceived;
    if (onFileMessageReceived != null) this.onFileMessageReceived = onFileMessageReceived;
    if (onConnectionRequestReceived != null) this.onConnectionRequestReceived = onConnectionRequestReceived;
    if (onMessageDeleted != null) this.onMessageDeleted = onMessageDeleted;
    if (onMessageEdited != null) this.onMessageEdited = onMessageEdited;
    if (onGroupMessageEdited != null) this.onGroupMessageEdited = onGroupMessageEdited;
    if (onGroupMessageDeleted != null) this.onGroupMessageDeleted = onGroupMessageDeleted;
    if (onIncomingCall != null) _incomingCallListeners.add(onIncomingCall);
    if (onCallStatusChanged != null) this.onCallStatusChanged = onCallStatusChanged;
    if (onCallEnded != null) this.onCallEnded = onCallEnded;
    if (onCallSignalReceived != null) {
      this.onCallSignalReceived = onCallSignalReceived;
      _drainPendingWebRtcSignals();
    }
    if (onMessageDeliveryStatusChanged != null) this.onMessageDeliveryStatusChanged = onMessageDeliveryStatusChanged;
    if (onQueueChanged != null) {
      this.onQueueChanged = onQueueChanged;
      _queueService.onQueueChanged = () {
        this.onQueueChanged?.call();
      };
    }
  }

  void unregisterCallbacks() {
    onFriendsChanged = null;
    onDiscoveryChanged = null;
    onGroupsChanged = null;
    onNotificationsChanged = null;
    onStatusChanged = null;
    onPrivateMessageReceived = null;
    onGroupMessageReceived = null;
    onFileMessageReceived = null;
    onConnectionRequestReceived = null;
    onMessageDeleted = null;
    onMessageEdited = null;
    onGroupMessageEdited = null;
    onGroupMessageDeleted = null;
    
    // --- Call Callbacks Unregistration ---
    // Call callbacks are owned permanently by CallManager and are intentionally NOT cleared here,
    // otherwise a UI screen's dispose() would break call handling for the app lifetime.

    // --- Queue Callbacks ---
    onMessageDeliveryStatusChanged = null;
    onQueueChanged = null;
    _queueService.onQueueChanged = null;
  }

  // --- Networking Logic ---
  Future<String?> getWifiIP() async {
    try {
      String? ip;
      if (Platform.isWindows || Platform.isLinux) {
        ip = await NetworkHelper().getLocalIP();
      } else {
        ip = await _networkInfo.getWifiIP();
      }
      return ip != null ? _convertArabicNumbers(ip) : null;
    } catch (e) {
      return null;
    }
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

  Future<void> _startDiscoveryListener() async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8081);
        _broadcastSocket!.broadcastEnabled = true;
        _broadcastSocket!.listen((event) {
          if (event == RawSocketEvent.read) {
            final datagram = _broadcastSocket!.receive();
            if (datagram != null) _handleDiscoveryMessage(utf8.decode(datagram.data));
          }
        });
        LogService.i('UDP 8081 مستمع');
        return;
      } catch (e) {
        LogService.e('Discovery Listener Error (attempt $attempt): $e');
        LogService.i('UDP 8081 فشل (محاولة $attempt): $e');
        if (attempt == 2) return;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _startMainServer() async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, 8080);
        _serverSocket!.listen(_handleIncomingConnection);
        LogService.i('TCP 8080 خادم');
        return;
      } catch (e) {
        LogService.e('Main Server Error (attempt $attempt): $e');
        LogService.i('TCP 8080 فشل (محاولة $attempt): $e');
        if (attempt == 2) return;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> _initSendSockets() async {
    _sendSockets.clear();
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              NetworkHelper().isLocalNetwork(addr.address)) {
            try {
              final socket = await RawDatagramSocket.bind(addr.address, 0);
              socket.broadcastEnabled = true;
              _sendSockets.add(socket);
              LogService.i('Socket إرسال: ${addr.address}');
              LogService.i('📡 Send socket bound to ${addr.address}');
            } catch (e) {
              LogService.i('Socket إرسال فشل ${addr.address}: $e');
              LogService.w('⚠️ Failed bind send socket ${addr.address}: $e');
            }
          }
        }
      }
    } catch (e) {
      LogService.i('_initSendSockets فشل: $e');
      LogService.w('⚠️ _initSendSockets: $e');
    }
    LogService.i('Sockets إرسال: ${_sendSockets.length}');
    LogService.i('📡 _initSendSockets: ${_sendSockets.length} sockets');
  }

  void triggerAnnouncementNow() {
    _performAnnouncementWithRetry();
  }

  void triggerRescan() {
    LogService.i('🔄 إعادة بحث يدوي');
    LogService.i('📡 Manual rescan triggered');
    _performAnnouncementWithRetry();
    _scanSubnets();
  }

  // --- TCP Unicast Discovery ---
  void _scanSubnets() {
    _performTcpScan();
  }

  Future<void> _performTcpScan() async {
    if (_currentUser == null) return;
    final ownIp = await getWifiIP();
    if (ownIp == null || ownIp == '127.0.0.1') {
      LogService.i('TCP Scan: IP=null أو 127.0.0.1');
      return;
    }

    final parts = ownIp.split('.');
    if (parts.length != 4) {
      LogService.i('TCP Scan: IP صيغة خاطئة $ownIp');
      return;
    }
    final subnetPrefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    LogService.i('بدء TCP Scan: $subnetPrefix.x (IP=$ownIp)');

    await _scanSubnetTcp(subnetPrefix, ownIp);

    LogService.i('انتهاء TCP Scan');
  }

  Future<void> _scanSubnetTcp(String prefix, String ownIp) async {
    for (int i = 1; i <= 254; i += 20) {
      final futures = <Future<void>>[];
      for (int j = i; j < i + 20 && j <= 254; j++) {
        final ip = '$prefix.$j';
        if (ip == ownIp) continue;
        futures.add(_tryTcpDiscover(ip));
      }
      await Future.wait(futures);
    }
  }

  Future<void> _tryTcpDiscover(String ip) async {
    try {
      final socket = await Socket.connect(ip, 8080, timeout: const Duration(milliseconds: 500));
      LogService.i('TCP اتصال: $ip:8080 نجح');
      socket.write('DISCOVER_TCP:${jsonEncode(_currentUser!.toJson())}\n');
      final response = await socket.first.timeout(const Duration(seconds: 1));
      if (response.toString().startsWith('DISCOVER_TCP_RESPONSE:')) {
        final data = jsonDecode(response.toString().substring(21));
        final String id = data['id'];
        if (id != _currentUser?.id && !_discoveredUsers.any((u) => u.id == id)) {
          final String? ipStr = data['ip'];
          if (ipStr != null) _ipDirectory[id] = ipStr;
          _discoveredUsers.add(User(id: id, username: data['username'] ?? '...'));
          LogService.i('TCP كشف: ${data['username']} @ $ip');
          onDiscoveryChanged?.call();
        }
      }
      await socket.close();
    } catch (e) {
      // فشل الاتصال متوقع - تجاهل صامت
    }
  }

  Future<void> _performAnnouncementWithRetry() async {
    for (int i = 0; i < 5; i++) {
      if (_broadcastSocket != null && (_sendSockets.isNotEmpty || i >= 3)) {
        await _performAnnouncement();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await _performAnnouncement();
  }

  void _sendDiscoveryPacket(List<int> payload, String currentIp) {
    bool anySent = false;
    for (final socket in _sendSockets) {
      try {
        socket.send(payload, InternetAddress("255.255.255.255"), 8081);
        anySent = true;
      } catch (e) {
        LogService.w('⚠️ send(${socket.address}): $e');
      }
    }
    for (final socket in _sendSockets) {
      try {
        final addr = socket.address.address;
        final parts = addr.split('.');
        if (parts.length == 4) {
          final subnet = '${parts[0]}.${parts[1]}.${parts[2]}.255';
          if (subnet != '255.255.255.255') {
            socket.send(payload, InternetAddress(subnet), 8081);
            LogService.i('📡 subnet($addr): $subnet');
          }
        }
      } catch (e) {
        LogService.w('⚠️ subnet send(${socket.address}): $e');
      }
    }
    if (!anySent) {
      _broadcastSocket?.send(payload, InternetAddress("255.255.255.255"), 8081);
    }
  }

  // --- Event-Driven Discovery System (v7.1) ---
  // تم إلغاء البث الدوري كل 10 ثوانٍ واستبداله بنظام قائم على الأحداث

  /// إرسال إعلان USER_ONLINE عند دخول المستخدم للتطبيق
  /// يُرسل 3 إعلانات مع 500ms بين كل واحدة لضمان الوصول
  Future<void> _sendInitialOnlineAnnouncement() async {
    if (_currentUser == null) return;
    for (int i = 0; i < 3; i++) {
      await _broadcastOnlineStatus();
      if (i < 2) await Future.delayed(const Duration(milliseconds: 500));
    }
    LogService.i('📡 تم إرسال 3 إعلانات USER_ONLINE عند بدء التشغيل');
  }

  /// إرسال إعلان USER_OFFLINE عند خروج المستخدم
  Future<void> _sendOfflineAnnouncement() async {
    if (_currentUser == null) return;
    final currentIp = await getWifiIP();
    if (currentIp == null) return;

    final announcement = {
      'type': 'USER_OFFLINE',
      'userId': _currentUser!.id,
    };
    final payload = utf8.encode('DISCOVER:${jsonEncode(announcement)}');
    _sendDiscoveryPacket(payload, currentIp);
    LogService.i('📡 تم إرسال USER_OFFLINE عند إيقاف الخدمة');
  }

  /// إرسال إعلان USER_ONLINE (لل.keep-alen والتحديث اليدوي)
  Future<void> _broadcastOnlineStatus() async {
    if (_currentUser == null) return;
    final currentIp = await getWifiIP();
    if (currentIp == null) {
      LogService.w('⚠️ _broadcastOnlineStatus: IP=null');
      return;
    }

    final announcement = {
      'type': 'USER_ONLINE',
      'userId': _currentUser!.id,
      'username': _currentUser!.username,
      'ip': currentIp,
      'port': 8080,
    };
    final payload = utf8.encode('DISCOVER:${jsonEncode(announcement)}');
    _sendDiscoveryPacket(payload, currentIp);
  }

  /// إرسال DISCOVER_REQUEST يدوياً (عند ضغط زر التحديث)
  Future<void> sendDiscoverRequest() async {
    if (_currentUser == null) return;
    final currentIp = await getWifiIP();
    if (currentIp == null) return;

    final announcement = {
      'type': 'DISCOVER_REQUEST',
      'userId': _currentUser!.id,
    };
    final payload = utf8.encode('DISCOVER:${jsonEncode(announcement)}');
    _sendDiscoveryPacket(payload, currentIp);
    LogService.i('📡 تم إرسال DISCOVER_REQUEST يدوياً');
  }

  /// Legacy: للتوافق مع الكود القديم - يُحول إلى USER_ONLINE
  Future<void> _performAnnouncement() async {
    await _broadcastOnlineStatus();
  }

  void _startReconnectScheduler() {
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final friendsToReconnect = _friendIds.where((id) => !_userSockets.containsKey(id) && _ipDirectory.containsKey(id) && _shouldAttemptReconnect(id)).toList();
      for (final friendId in friendsToReconnect) {
        _improvedReconnectToFriend(friendId);
      }
    });
  }

  bool _shouldAttemptReconnect(String friendId) {
    final lastAttempt = _reconnectAttempts[friendId];
    if (lastAttempt == null) return true;
    final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
    final attemptCount = _reconnectCounters[friendId] ?? 0;
    if (attemptCount < 5) return timeSinceLastAttempt.inSeconds >= 3;
    return timeSinceLastAttempt.inSeconds >= 10;
  }

  Timer? _callSignalDrainTimer;

  void _startHeartbeatSystem() {
    _heartbeatTimer?.cancel();

    // === نظام الكشف الجديد (v7.1) ===
    // Keep-Alive: إرسال USER_ONLINE كل 60 ثانية بدلاً من PING كل 5 ثوانٍ
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      // إرسال USER_ONLINE كنبض تأكيد
      await _broadcastOnlineStatus();
    });

    // فحص حالة الأصدقاء كل 5 ثوانٍ (مهلة 70 ثانية)
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      unawaited(_checkFriendStatuses());
    });

    // TCP PING/PONG كل 20 ثانية (للحفاظ على اتصالات TCP حية)
    _startTcpPingPong();

    _startCallHeartbeat();
    _callSignalDrainTimer?.cancel();
    _callSignalDrainTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _drainAllPendingCallSignals();
    });
  }

  /// فحص حالة الأصدقاء وتحديث حالاتهم (كل 5 ثوانٍ)
  Future<void> _checkFriendStatuses() async {
    final now = DateTime.now();
    const offlineTimeout = Duration(seconds: 70); // 60s Keep-Alive + 10s buffer

    for (final friendId in _friendIds) {
      final lastPong = _lastPongTime[friendId];
      final hasConnection = _userSockets.containsKey(friendId);

      if (hasConnection) {
        // هناك اتصال TCP - تحقق من PONG
        if (lastPong != null && now.difference(lastPong) > offlineTimeout) {
          // انتهت مهلة Keep-Alive - تحقق حيوية أولاً قبل القطع المدمر
          final socket = _userSockets[friendId];
          final alive = socket != null && await _pingAndVerify(friendId, socket);
          if (alive) {
            LogService.w('DEBUG _checkFriendStatuses: $friendId looked stale but PING/PONG verified ALIVE - no cut');
            _lastPongTime[friendId] = DateTime.now();
            _updateFriendStatus(friendId, true);
          } else {
            LogService.w('DEBUG _checkFriendStatuses: $friendId stale AND PING/PONG failed - offline + reconnect');
            _updateFriendStatus(friendId, false);
            _quickReconnect(friendId);
          }
        } else {
          // نشط
          _updateFriendStatus(friendId, true);
        }
      } else {
        // لا يوجد اتصال TCP
        if (lastPong != null && now.difference(lastPong) > offlineTimeout) {
          // انتهت المهلة - offline + محاولة إعادة اتصال
          _updateFriendStatus(friendId, false);
          _quickReconnect(friendId);
        } else if (lastPong != null) {
          // هناك آخر PONG لكن لا يوجد اتصال - جارٍ التحقق
          final currentStatus = _userStatuses[friendId];
          if (currentStatus == null || currentStatus.isOnline) {
            _userStatuses[friendId] = UserStatus(
              userId: friendId,
              isOnline: false,
              lastSeen: DateTime.now(),
            );
            onStatusChanged?.call();
          }
        }
      }
    }
  }

  Future<bool> _pingAndVerify(String userId, Socket socket) async {
    _pingCompleters[userId] = Completer<bool>();
    if (!_safeWrite(socket, 'PING\n')) {
      _pingCompleters.remove(userId);
      return false;
    }
    final ok = await _pingCompleters[userId]!.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => false,
    );
    _pingCompleters.remove(userId);
    return ok;
  }

  /// تحديث حالة صديق معين
  void _updateFriendStatus(String friendId, bool isOnline) {
    final currentStatus = _userStatuses[friendId];
    if (currentStatus != null && currentStatus.isOnline == isOnline) return;

    _userStatuses[friendId] = UserStatus(
      userId: friendId,
      isOnline: isOnline,
      lastSeen: isOnline ? null : DateTime.now(),
    );
    onStatusChanged?.call();
  }

  /// TCP PING/PONG كل 20 ثانية للحفاظ على الاتصالات حية
  void _startTcpPingPong() {
    Timer.periodic(const Duration(seconds: 20), (timer) {
      final now = DateTime.now();
      final staleThreshold = const Duration(seconds: 25); // أكثر من 25 ثانية بدون PONG

      for (final entry in _userSockets.entries) {
        final socket = entry.value;
        final userId = entry.key;
        final lastActivity = _socketLastActivity[socket];

        // إرسال PING عبر TCP
        try {
          socket.write('PING\n');
        } catch (_) {}

        // فحص آخر PONG
        final lastPong = _lastPongTime[userId];
        LogService.i(
            'DEBUG heartbeat: PING sent to $userId (lastPongAge=${lastPong == null ? "none" : now.difference(lastPong).inSeconds}s, socketActive=${lastActivity == null ? "no-activity" : "active-${now.difference(lastActivity).inSeconds}s"})');
        if (lastPong != null && now.difference(lastPong) > staleThreshold) {
          if (!_callProtectedSockets.contains(userId)) {
            LogService.w("TCP PONG timeout from $userId (>25s), removing socket");
            _removeSocket(socket);
            _handleFriendDisconnected(userId);
          }
        }
      }
    });
  }

  /// معالجة انقطاع صديق (بدون إرسال UDP)
  void _handleFriendDisconnected(String friendId) {
    // وضع حالة "جارٍ التحقق"
    _userStatuses[friendId] = UserStatus(
      userId: friendId,
      isOnline: false,
      lastSeen: DateTime.now(),
    );
    onStatusChanged?.call();

    // محاولة إعادة اتصال TCP مباشرة (بدون UDP)
    if (_ipDirectory.containsKey(friendId)) {
      LogService.i('🔄 محاولة إعادة اتصال TCP مع $friendId بعد الانقطاع');
      _improvedReconnectToFriend(friendId);
    }
  }

  void _startCallHeartbeat() {
    _callHeartbeatTimer?.cancel();
    _callHeartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      final now = DateTime.now();
      final staleThreshold = const Duration(seconds: 15);
      for (final entry in _callSockets.entries) {
        final socket = entry.value;
        try {
          socket.write('PING\n');
        } catch (_) {
        }
        final lastPong = _callLastPongTime[entry.key];
        if (lastPong != null && now.difference(lastPong) > staleThreshold) {
          _removeCallSocket(socket);
        }
      }
    });
  }

  void _drainAllPendingCallSignals() {
    final userIds = List<String>.from(_pendingCallSignals.keys);
    for (final userId in userIds) {
      _drainCallSignalNow(userId);
    }
  }

  void _drainCallSignalNow(String userId) {
    final signals = _pendingCallSignals[userId];
    if (signals == null || signals.isEmpty) return;
    final callSocket = _callSockets[userId];
    if (callSocket != null) {
      _drainPendingCallSignals(userId, callSocket);
    } else {
      final msgSocket = _userSockets[userId];
      if (msgSocket != null) {
        _drainPendingCallSignals(userId, msgSocket);
      }
    }
  }

  // --- Message Handlers (v7.1 - Event-Driven) ---
  void _handleDiscoveryMessage(String message) {
    final trimmed = message.trim();

    // === البروتوكول الجديد (v7.1) ===
    if (trimmed.startsWith('DISCOVER:')) {
      try {
        final data = jsonDecode(message.substring(9));
        final String messageType = data['type'] ?? 'LEGACY';

        switch (messageType) {
          case 'USER_ONLINE':
            _handleUserOnline(data);
            break;
          case 'USER_OFFLINE':
            _handleUserOffline(data);
            break;
          case 'DISCOVER_REQUEST':
            _handleDiscoverRequest(data);
            break;
          case 'LEGACY':
            // للتوافق مع الإصدارات القديمة
            _handleLegacyDiscover(data);
            break;
          default:
            LogService.w('⚠️ نوع رسالة غير معروف: $messageType');
        }
      } catch (e) {
        LogService.i('خطأ في DISCOVER: $e');
      }
      return;
    }

    // === بروتوكولات قديمة (للتوافق) ===
    if (trimmed.startsWith('PING:')) {
      final userId = trimmed.substring(5);
      if (userId == _currentUser?.id) return;
      final pongData = utf8.encode('PONG:${_currentUser?.id ?? "unknown"}\n');
      for (final socket in _sendSockets) {
        try {
          socket.send(pongData, InternetAddress("255.255.255.255"), 8081);
        } catch (e) {
          LogService.w('⚠️ PONG(${socket.address}): $e');
        }
      }
      if (_sendSockets.isEmpty) {
        try {
          _broadcastSocket?.send(pongData, InternetAddress("255.255.255.255"), 8081);
        } catch (e) {
          LogService.w('⚠️ PONG(broadcast): $e');
        }
      }
      return;
    }
    if (trimmed.startsWith('PONG:')) {
      return;
    }
    if (trimmed.startsWith('STATUS:')) {
      try {
        _handleStatusMessage(jsonDecode(trimmed.substring(7)));
      } catch (e) { /* Ignore malformed status */ }
      return;
    }
  }

  /// معالجة رسالة USER_ONLINE
  void _handleUserOnline(Map<String, dynamic> data) {
    final String userId = data['userId'];
    final String? username = data['username'];
    final String? ip = data['ip'];
    final int? port = data['port'];

    if (userId == _currentUser?.id) return;

    LogService.i('🟢 USER_ONLINE: ${username ?? userId} من ${ip ?? "unknown"}');

    // تحديث دليل المستخدمين
    if (ip != null) _ipDirectory[userId] = ip;
    if (username != null && _userDirectory[userId] != username) {
      _userDirectory[userId] = username;
      _saveFriendsAndDirectory();
    }

    // تحديث الحالة إلى متصل
    _updateFriendStatus(userId, true);

    // إذا كان صديقاً وليس لديه اتصال TCP، حاول الاتصال
    if (_friendIds.contains(userId) && !_userSockets.containsKey(userId) && !_callProtectedSockets.contains(userId)) {
      LogService.i('🔄 محاولة اتصال TCP مع صديق $username بعد USER_ONLINE');
      _improvedReconnectToFriend(userId);
    }

    // إضافة إلى قائمة المكتشفين إذا لم يكن صديقاً
    if (!_friendIds.contains(userId) && !_discoveredUsers.any((u) => u.id == userId)) {
      _discoveredUsers.add(User(id: userId, username: username ?? '...'));
      LogService.i('مستخدم مكتشف: $username');
      onDiscoveryChanged?.call();
    }
  }

  /// معالجة رسالة USER_OFFLINE
  void _handleUserOffline(Map<String, dynamic> data) {
    final String userId = data['userId'];

    if (userId == _currentUser?.id) return;

    LogService.i('🔴 USER_OFFLINE: ${_userDirectory[userId] ?? userId}');

    // تحديث الحالة إلى غير متصل
    _userStatuses[userId] = UserStatus(
      userId: userId,
      isOnline: false,
      lastSeen: DateTime.now(),
    );
    onStatusChanged?.call();

    // إغلاق اتصال TCP مع هذا المستخدم
    final socket = _userSockets[userId];
    if (socket != null) {
      _removeSocket(socket);
    }
  }

  /// معالجة رسالة DISCOVER_REQUEST
  void _handleDiscoverRequest(Map<String, dynamic> data) {
    final String requesterId = data['userId'];

    if (requesterId == _currentUser?.id) return;

    LogService.i('🔍 DISCOVER_REQUEST من ${_userDirectory[requesterId] ?? requesterId}');

    // الرد فوراً بـ USER_ONLINE
    _broadcastOnlineStatus();
  }

  /// للتوافق مع الإصدارات القديمة
  void _handleLegacyDiscover(Map<String, dynamic> data) {
    final String id = data['id'];
    if (id == _currentUser?.id) return;

    final String? ip = data['ip'] != null ? _convertArabicNumbers(data['ip']) : null;
    final String? username = data['username'];

    if (ip != null) _ipDirectory[id] = ip;
    if (username != null && _userDirectory[id] != username) {
      _userDirectory[id] = username;
      _saveFriendsAndDirectory();
    }

    if (_friendIds.contains(id) && !_userSockets.containsKey(id) && !_callProtectedSockets.contains(id) && _shouldAttemptReconnect(id)) {
      final lastDiscover = _lastDiscoverReconnect[id];
      final cooldownOk = lastDiscover == null || DateTime.now().difference(lastDiscover).inSeconds >= 8;
      if (cooldownOk) {
        _lastDiscoverReconnect[id] = DateTime.now();
        LogService.i('محاولة إعادة اتصال بصديق $username (Legacy)');
        _improvedReconnectToFriend(id);
      }
    }

    if (!_friendIds.contains(id) && !_discoveredUsers.any((u) => u.id == id)) {
      _discoveredUsers.add(User(id: id, username: username ?? '...'));
      LogService.i('مستخدم مكتشف: $username');
      onDiscoveryChanged?.call();
    }
  }

  void _handleIncomingConnection(Socket socket) {
    LogService.i('اتصال TCP وارد من ${socket.remoteAddress.address}');
    _setupSocket(socket);
  }

  Future<void> _handleTcpMessage(String message, Socket socket) async {
    final senderId = _findUserIdBySocket(socket);
    final msgType = message.contains(':') ? message.substring(0, message.indexOf(':')) : message.substring(0, message.length > 20 ? 20 : message.length);
    LogService.i('DEBUG _handleTcpMessage: received type=$msgType from=${senderId ?? "unknown"} len=${message.length}');
    try {
      if (message.startsWith('MSG:')) {
        LogService.i('DEBUG _handleTcpMessage: processing MSG');
        final msg = Message.fromJson(jsonDecode(message.substring(4)));
        msg.content = EncryptionService().decryptText(msg.content);
        if (!_queueService.isRecentlySent(msg.id)) {
          await _dbService.insertMessage(msg);
          final key = msg.senderId == _currentUser?.id ? msg.receiverId : msg.senderId;
          _allMessages.putIfAbsent(key, () => []).add(msg);
          _saveAllMessages();
          onPrivateMessageReceived?.call(msg);
          LogService.i('DEBUG _handleTcpMessage: MSG saved and delivered, id=${msg.id}');
        } else {
          LogService.i('DEBUG _handleTcpMessage: MSG ignored (recently sent), id=${msg.id}');
        }
        if (_readReceipts) {
          _safeWrite(socket, 'MSG_ACK:${jsonEncode({"messageId": msg.id, "timestamp": DateTime.now().toUtc().toIso8601String()})}\n');
          LogService.i('DEBUG _handleTcpMessage: MSG_ACK sent for ${msg.id}');
        }
      } else if (message.startsWith('GROUP_MSG:')) {
        final data = jsonDecode(message.substring(10));
        if (data['type'] == 'GROUP_MESSAGE') {
          final msgJson = Map<String, dynamic>.from(data['message']);
          msgJson['content'] = EncryptionService().decryptText(msgJson['content']);
          final groupMessage = GroupMessage.fromJson(msgJson);
          _groupMessages.putIfAbsent(groupMessage.groupId, () => []).add(groupMessage);
          _saveGroupMessages();
          onGroupMessageReceived?.call(groupMessage);
        } else if (data['type'] == 'EDIT_GROUP_MESSAGE') {
          final String groupId = data['groupId'];
          final String messageId = data['messageId'];
          final String newContent = EncryptionService().decryptText(data['newContent']);
          final messageIndex = _groupMessages[groupId]?.indexWhere((msg) => msg.id == messageId);
          if (messageIndex != null && messageIndex != -1) {
            final originalMessage = _groupMessages[groupId]![messageIndex];
            _groupMessages[groupId]![messageIndex] = GroupMessage(
              id: originalMessage.id,
              groupId: originalMessage.groupId,
              senderId: originalMessage.senderId,
              content: newContent,
              timestamp: originalMessage.timestamp,
              edited: true,
              editedAt: DateTime.now(),
            );
            _saveGroupMessages();
            onGroupMessageEdited?.call(groupId, messageId, newContent);
          }
        } else if (data['type'] == 'DELETE_GROUP_MESSAGE') {
          final String groupId = data['groupId'];
          final String messageId = data['messageId'];
          _groupMessages[groupId]?.removeWhere((msg) => msg.id == messageId);
          _saveGroupMessages();
          onGroupMessageDeleted?.call(groupId, messageId);
        }
      } else if (message.startsWith('FILE_TRANSFER:')) {
        _handleFileTransfer(jsonDecode(message.substring(14)));
      } else if (message.startsWith('CONNECT_REQUEST:')) {
        final user = User.fromJson(jsonDecode(message.substring(16)));
        onConnectionRequestReceived?.call(user, socket);
      } else if (message.startsWith('CONNECT_ACCEPT:')) {
        final user = User.fromJson(jsonDecode(message.substring(15)));
        _finalizeConnection(user, socket);
        _safeWrite(socket, 'FINALIZE_CONNECTION:${jsonEncode(_currentUser!.toJson())}\n');
      } else if (message.startsWith('FINALIZE_CONNECTION:')) {
        final user = User.fromJson(jsonDecode(message.substring(20)));
        _finalizeConnection(user, socket);
      } else if (message.startsWith('RECONNECT:')) {
        final user = User.fromJson(jsonDecode(message.substring(10)));
        _finalizeConnection(user, socket);
        _safeWrite(socket, 'RECONNECT_ACK:${jsonEncode(_currentUser!.toJson())}\n');
        _reconnectCounters.remove(user.id);
        _reconnectAttempts.remove(user.id);
        _lastDiscoverReconnect.remove(user.id);
      } else if (message.startsWith('RECONNECT_ACK:')) {
        final user = User.fromJson(jsonDecode(message.substring(14)));
        _finalizeConnection(user, socket);
        _reconnectCounters.remove(user.id);
        _reconnectAttempts.remove(user.id);
      } else if (message.startsWith('UNFRIEND:')) {
        final user = User.fromJson(jsonDecode(message.substring(9)));
        _removeFriend(user.id);
        _removeSocket(socket);
      } else if (message.startsWith('GROUP_UPDATE:')) {
        _handleGroupUpdate(jsonDecode(message.substring(13)));
      } else if (message.startsWith('STATUS:')) {
        _handleStatusMessage(jsonDecode(message.substring(7)));
      } else if (message.startsWith('CALL_SIGNAL:')) {
        final decryptedPayload = EncryptionService().decryptText(message.substring(12));
        LogService.d('CALL_SIGNAL received: ${decryptedPayload.substring(0, decryptedPayload.length > 80 ? 80 : decryptedPayload.length)}...');
        _handleCallSignal(jsonDecode(decryptedPayload));
      } else if (message == 'PING') {
        final pingUserId = _findUserIdBySocket(socket);
        LogService.i('DEBUG _handleTcpMessage: PING received from ${pingUserId ?? "unknown"}, sending PONG');
        if (pingUserId != null) {
          _lastPongTime[pingUserId] = DateTime.now();
        }
        _safeWrite(socket, 'PONG\n');
      } else if (message == 'PONG') {
        final pongUserId = _findUserIdBySocket(socket);
        LogService.i('DEBUG _handleTcpMessage: PONG received from ${pongUserId ?? "unknown"}');
        if (pongUserId != null) {
          _lastPongTime[pongUserId] = DateTime.now();
          final completer = _pingCompleters[pongUserId];
          if (completer != null && !completer.isCompleted) {
            completer.complete(true);
          }
        }
      } else if (message.startsWith('MSG_ACK:')) {
        final data = jsonDecode(message.substring(8));
        LogService.i('DEBUG _handleTcpMessage: MSG_ACK received for messageId=${data['messageId']}');
        _queueService.handleAck(data['messageId']);
        onMessageDeliveryStatusChanged?.call(data['messageId'], DeliveryStatus.sent);
      } else if (message.startsWith('FILE_ACK:')) {
        final data = jsonDecode(message.substring(9));
        LogService.i('DEBUG _handleTcpMessage: FILE_ACK received for messageId=${data['messageId']}');
        _queueService.handleAck(data['messageId']);
        onMessageDeliveryStatusChanged?.call(data['messageId'], DeliveryStatus.sent);
      } else if (message.startsWith('CALL_CONNECT:')) {
        final user = User.fromJson(jsonDecode(message.substring(13)));
        _finalizeCallSocket(user, socket);
        _safeWrite(socket, 'CALL_CONNECT_ACK:${jsonEncode(_currentUser!.toJson())}\n');
      } else if (message.startsWith('CALL_CONNECT_ACK:')) {
        final user = User.fromJson(jsonDecode(message.substring(17)));
        _finalizeCallSocket(user, socket);
        _drainCallSignalNow(user.id);
      }

      else if (message.startsWith('MSG_UPDATE:')) {
        final data = jsonDecode(message.substring(11));
        final type = data['type'];

        if (type == 'DELETE_MESSAGE') {
          final String conversationId = data['conversationId'];
          final String messageId = data['messageId'];

          _allMessages[conversationId]?.removeWhere((msg) => msg.id == messageId);
          _fileMessages[conversationId]?.removeWhere((msg) => msg.id == messageId);

          _saveAllMessages();
          _saveFileMessages();

          onMessageDeleted?.call(conversationId, messageId);
        } else if (type == 'EDIT_MESSAGE') {
          final String conversationId = data['conversationId'];
          final String messageId = data['messageId'];
          final String newContent = EncryptionService().decryptText(data['newContent']);

          final messageIndex = _allMessages[conversationId]?.indexWhere((msg) => msg.id == messageId);
          if (messageIndex != null && messageIndex != -1) {
            final originalMessage = _allMessages[conversationId]![messageIndex];
            _allMessages[conversationId]![messageIndex] = Message(
              id: originalMessage.id,
              senderId: originalMessage.senderId,
              receiverId: originalMessage.receiverId,
              content: newContent,
              timestamp: originalMessage.timestamp,
              edited: true,
              editedAt: DateTime.now(),
            );
            _saveAllMessages();
            onMessageEdited?.call(conversationId, messageId, newContent);
          }
        }
      } else if (message.startsWith('DISCOVER_TCP:')) {
        try {
          final info = jsonDecode(message.substring(13));
          final id = info['id'] as String;
          final username = info['username'] ?? '...';
          LogService.i('طلب DISCOVER_TCP من $username');
          if (id != _currentUser?.id) {
            final ip = info['ip'] as String?;
            if (ip != null) _ipDirectory[id] = ip;
            if (!_discoveredUsers.any((u) => u.id == id)) {
              _discoveredUsers.add(User(id: id, username: username));
              LogService.i('TCP كشف (وارد): $username');
              onDiscoveryChanged?.call();
            }
          }
          getWifiIP().then((selfIp) {
            final response = {
              'id': _currentUser!.id,
              'username': _currentUser!.username,
              'ip': selfIp,
            };
            _safeWrite(socket, 'DISCOVER_TCP_RESPONSE:${jsonEncode(response)}\n');
            LogService.i('رديت على DISCOVER_TCP لـ $username');
          });
        } catch (e) {
          LogService.i('خطأ DISCOVER_TCP: $e');
          LogService.w('⚠️ DISCOVER_TCP handler: $e');
        }
      }


    }

    catch (e) {
      LogService.e('Handle TCP Error: $e on message: $message');
    }
  }

  void _handleStatusMessage(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'USER_STATUS') {
      final status = UserStatus.fromJson(data['status']);
      _userStatuses[status.userId] = status;
      onStatusChanged?.call();
    } else if (type == 'TYPING_STATUS') {
      final String senderId = data['senderId'];
      final bool isTyping = data['isTyping'];

      if (_userStatuses.containsKey(senderId)) {
        _userStatuses[senderId] = UserStatus(
          userId: senderId,
          isOnline: _userStatuses[senderId]!.isOnline,
          lastSeen: _userStatuses[senderId]!.lastSeen,
          isTyping: isTyping, // تحديث حالة الكتابة
          currentChatId: data['currentChatId'],
        );
      } else {
        _userStatuses[senderId] = UserStatus(
          userId: senderId,
          isOnline: true, // افتراض أنه متصل لأنه يرسل حالة
          isTyping: isTyping,
          currentChatId: data['currentChatId'],
        );
      }
      onStatusChanged?.call(); // إعلام الواجهة بتغير الحالة
    }
  }

  void _handleGroupUpdate(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'GROUP_CREATED') {
      final group = Group.fromJson(data['group']);
      _groups[group.id] = group;
      if (group.memberIds.contains(_currentUser!.id)) {
        _userGroups.putIfAbsent(_currentUser!.id, () => []).add(group.id);
      }
    }
    // ... handle other group updates
    _saveGroupsData();
    onGroupsChanged?.call();
  }


  // --- Internal State Management ---
  void _finalizeConnection(User user, Socket socket) {
    final existingSocket = _userSockets[user.id];
    if (existingSocket != null && existingSocket != socket) {
      final existingActive = _isSocketRecentlyActive(existingSocket);
      final newActive = _isSocketRecentlyActive(socket);
      if (existingActive && !newActive) {
        LogService.w(
            'DEBUG _finalizeConnection: keeping LIVE socket for ${user.username}, closing fresh-but-idle new socket (existingActive=$existingActive newActive=$newActive)');
        _safeSocketClose(socket);
        return;
      }
      LogService.i(
          'DEBUG _finalizeConnection: replacing socket for ${user.username} (existingActive=$existingActive newActive=$newActive)');
      _pendingOldSocketClosers.remove(user.id)?.cancel();
      _pendingOldSocketClosers[user.id] = Timer(const Duration(seconds: 3), () {
        _pendingOldSocketClosers.remove(user.id);
        if (_userSockets[user.id] == existingSocket) return;
        _safeSocketClose(existingSocket);
      });
    }
    _userSockets[user.id] = socket;
    _lastPongTime[user.id] = DateTime.now();
    if (!_friendIds.contains(user.id)) _friendIds.add(user.id);
    _userDirectory[user.id] = user.username;
    _discoveredUsers.removeWhere((u) => u.id == user.id);
    _saveFriendsAndDirectory();
    onFriendsChanged?.call();
    onDiscoveryChanged?.call();
    LogService.i("✅ Finalized connection with ${user.username}");
    _flushPendingQueue(user.id, socket);
    _drainPendingCallSignals(user.id, socket);
  }

  void _finalizeCallSocket(User user, Socket socket) {
    final existingSocket = _callSockets[user.id];
    _callSockets[user.id] = socket;
    if (existingSocket != null && existingSocket != socket) {
      _safeSocketClose(existingSocket);
    }
    _callLastPongTime[user.id] = DateTime.now();
    _pendingCallConnections.remove(user.id);
    LogService.i("Call socket established for ${user.username}");
    _drainCallSignalNow(user.id);
  }

  void _drainPendingCallSignals(String userId, Socket socket) {
    final signals = _pendingCallSignals[userId];
    if (signals == null || signals.isEmpty) return;
    final drained = _pendingCallSignals.remove(userId);
    if (drained != null) {
      for (int i = 0; i < drained.length; i++) {
        final encryptedPayload = EncryptionService().encryptText(jsonEncode(drained[i]));
        if (!_safeWrite(socket, 'CALL_SIGNAL:$encryptedPayload\n')) {
          LogService.w("Failed to drain call signal for $userId");
          final remaining = drained.sublist(i);
          _pendingCallSignals.putIfAbsent(userId, () => []).insertAll(0, remaining);
          return;
        }
      }
      unawaited(socket.flush());
    }
  }

  void _drainPendingWebRtcSignals() {
    if (_pendingWebRtcSignals.isEmpty) return;
    final drained = List<Map<String, dynamic>>.from(_pendingWebRtcSignals);
    _pendingWebRtcSignals.clear();
    for (final signal in drained) {
      onCallSignalReceived?.call(signal['callId'], signal);
    }
  }

  Future<void> _flushPendingQueue(String peerId, Socket socket) async {
    final count = await _queueService.flushQueue(peerId, socket, (text) => EncryptionService().encryptText(text));
    if (count > 0) {
      LogService.i("📤 Flushed $count pending messages to $peerId");
    }
  }

  void _removeSocket(Socket socket) {
    String? foundId;
    _userSockets.forEach((id, s) {
      if (s == socket) foundId = id;
    });
    if (foundId != null) {
      if (_userSockets[foundId] != socket) {
        LogService.w("DEBUG _removeSocket: SKIPPED for $foundId - socket already replaced");
        _safeSocketClose(socket);
        return;
      }
      _userSockets.remove(foundId);
      _lastPongTime.remove(foundId);
      LogService.i("DEBUG _removeSocket: removing socket for $foundId, triggering _quickReconnect");
      if (_friendIds.contains(foundId) && _ipDirectory.containsKey(foundId) && !_callProtectedSockets.contains(foundId)) {
        _doubtfulConnections.add(foundId!);
        _quickReconnect(foundId!);
      }
      onFriendsChanged?.call();
      LogService.i("DEBUG _removeSocket: DONE for $foundId");
      _safeSocketClose(socket);
      return;
    }
    String? callFoundId;
    _callSockets.forEach((id, s) {
      if (s == socket) callFoundId = id;
    });
    if (callFoundId != null) {
      if (_callSockets[callFoundId] == socket) {
        _callSockets.remove(callFoundId);
        _callLastPongTime.remove(callFoundId);
        _pendingCallConnections.remove(callFoundId);
        LogService.i("DEBUG _removeCallSocket: removing call socket for $callFoundId");
      }
      if (_friendIds.contains(callFoundId) && _ipDirectory.containsKey(callFoundId)) {
        _quickCallReconnect(callFoundId!);
      }
    }
    _safeSocketClose(socket);
  }

  Future<void> _quickReconnect(String userId) async {
    if (_quickReconnecting.contains(userId)) {
      LogService.w("DEBUG _quickReconnect: SKIPPED for $userId - already reconnecting");
      return;
    }
    if (_pendingConnections[userId] == true) {
      LogService.w("DEBUG _quickReconnect: SKIPPED for $userId - improved reconnect in flight");
      return;
    }
    final lastReconnect = _lastQuickReconnect[userId];
    if (lastReconnect != null && DateTime.now().difference(lastReconnect).inSeconds < 5) {
      LogService.w("DEBUG _quickReconnect: SKIPPED for $userId - cooldown (last: ${lastReconnect})");
      _doubtfulConnections.remove(userId);
      return;
    }
    _lastQuickReconnect[userId] = DateTime.now();
    if (_userSockets.containsKey(userId)) {
      LogService.w("DEBUG _quickReconnect: removing zombie socket for $userId");
      final zombieSocket = _userSockets.remove(userId);
      if (zombieSocket != null) _safeSocketClose(zombieSocket);
      _lastPongTime.remove(userId);
    }
    if (!_friendIds.contains(userId)) {
      LogService.w("DEBUG _quickReconnect: $userId not in friend list, aborting");
      _doubtfulConnections.remove(userId);
      return;
    }

    _quickReconnecting.add(userId);
    final targetIp = _ipDirectory[userId];
    if (targetIp == null) {
      LogService.w("DEBUG _quickReconnect: NO IP for $userId, aborting");
      _doubtfulConnections.remove(userId);
      _quickReconnecting.remove(userId);
      onFriendsChanged?.call();
      return;
    }

    LogService.i("DEBUG _quickReconnect: trying to reconnect to $userId at $targetIp");
    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (_userSockets.containsKey(userId)) {
        LogService.i("DEBUG _quickReconnect: socket already exists for $userId, SUCCESS");
        _doubtfulConnections.remove(userId);
        _quickReconnecting.remove(userId);
        return;
      }
      try {
        LogService.i("DEBUG _quickReconnect: attempt ${i + 1}/3 for $userId...");
        final socket = await Socket.connect(targetIp, 8080, timeout: const Duration(seconds: 3));
        LogService.i("DEBUG _quickReconnect: TCP connected for $userId, sending RECONNECT...");
        _setupSocket(socket);
        _safeWrite(socket, 'RECONNECT:${jsonEncode(_currentUser!.toJson())}\n');
        await Future.delayed(const Duration(milliseconds: 800));
        if (_userSockets.containsKey(userId)) {
          LogService.i("DEBUG _quickReconnect: SUCCESS, new socket for $userId");
          _doubtfulConnections.remove(userId);
          _quickReconnecting.remove(userId);
          await _flushPendingQueue(userId, _userSockets[userId]!);
          return;
        }
        LogService.w("DEBUG _quickReconnect: socket not registered after RECONNECT for $userId");
        _safeSocketClose(socket);
      } catch (e) {
        LogService.w('DEBUG _quickReconnect: attempt ${i + 1}/3 FAILED for $userId: $e');
      }
    }

    LogService.w('DEBUG _quickReconnect: FAILED after 3 attempts for $userId');
    _doubtfulConnections.remove(userId);
    _quickReconnecting.remove(userId);
    onFriendsChanged?.call();
  }

  void _removeCallSocket(Socket socket) {
    String? foundId;
    _callSockets.forEach((id, s) {
      if (s == socket) foundId = id;
    });
    if (foundId != null) {
      if (_callSockets[foundId] != socket) {
        LogService.w("_removeCallSocket skipped for $foundId - socket already replaced");
        _safeSocketClose(socket);
        return;
      }
      _callSockets.remove(foundId);
      _callLastPongTime.remove(foundId);
      _pendingCallConnections.remove(foundId);
      if (_friendIds.contains(foundId) && _ipDirectory.containsKey(foundId)) {
        _quickCallReconnect(foundId!);
      }
      LogService.i("Call socket removed for $foundId");
    }
    _safeSocketClose(socket);
  }

  Future<void> _quickCallReconnect(String userId) async {
    if (_callQuickReconnecting.contains(userId)) return;
    final lastReconnect = _lastCallQuickReconnect[userId];
    if (lastReconnect != null && DateTime.now().difference(lastReconnect).inSeconds < 5) {
      LogService.w("_quickCallReconnect skipped for $userId - cooldown");
      return;
    }
    _lastCallQuickReconnect[userId] = DateTime.now();
    if (_callSockets.containsKey(userId)) {
      final zombieSocket = _callSockets.remove(userId);
      if (zombieSocket != null) _safeSocketClose(zombieSocket);
      _callLastPongTime.remove(userId);
    }
    if (!_friendIds.contains(userId)) return;

    _callQuickReconnecting.add(userId);
    final targetIp = _ipDirectory[userId];
    if (targetIp == null) {
      _callQuickReconnecting.remove(userId);
      return;
    }

    for (int i = 0; i < 3; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (_callSockets.containsKey(userId)) {
        _callQuickReconnecting.remove(userId);
        return;
      }
      try {
        final socket = await Socket.connect(targetIp, 8080, timeout: const Duration(seconds: 3));
        _setupCallSocket(socket);
        _safeWrite(socket, 'CALL_CONNECT:${jsonEncode(_currentUser!.toJson())}\n');
        await Future.delayed(const Duration(milliseconds: 800));
        if (_callSockets.containsKey(userId)) {
          _callQuickReconnecting.remove(userId);
          _drainCallSignalNow(userId);
          return;
        }
        _safeSocketClose(socket);
      } catch (e) {
        LogService.w('_quickCallReconnect[$userId] attempt $i failed: $e');
      }
    }
    _callQuickReconnecting.remove(userId);
  }

  Future<void> _ensureCallSocket(String userId) async {
    if (_pendingCallConnections[userId] == true) return;
    if (_callSockets.containsKey(userId)) {
      return;
    }
    final targetIp = _ipDirectory[userId];
    if (targetIp == null) return;
    _pendingCallConnections[userId] = true;
    try {
      final socket = await Socket.connect(targetIp, 8080, timeout: const Duration(seconds: 5));
      _setupCallSocket(socket);
      _safeWrite(socket, 'CALL_CONNECT:${jsonEncode(_currentUser!.toJson())}\n');
    } catch (e) {
      _pendingCallConnections.remove(userId);
      LogService.w('_ensureCallSocket failed for $userId: $e');
    }
  }

  bool _safeWrite(Socket socket, String message) {
    try {
      socket.write(message);
      return true;
    } catch (e) {
      _removeSocket(socket);
      return false;
    }
  }

/*
  void _setupSocket(Socket socket) {
    String buffer = '';

    socket.listen(
          (data) {
        buffer += utf8.decode(data);

        while (buffer.contains('\n')) {
          final messageEndIndex = buffer.indexOf('\n');
          final completeMessage = buffer.substring(0, messageEndIndex).trim();
          buffer = buffer.substring(messageEndIndex + 1);

          if (completeMessage.isNotEmpty) {
            _handleTcpMessage(completeMessage, socket);
          }
        }
      },
      onDone: () {
        _removeSocket(socket);
      },
      onError: (e) {
        LogService.e('Socket Error: $e');
        _removeSocket(socket);
      },
      cancelOnError: false,
    );
  }
*/
// في ملف: lib/core/services/local_network_service.dart

  void _setupSocket(Socket socket) {
    String buffer = '';
    final friendId = _findUserIdBySocket(socket);

    socket.listen(
          (data) {
        _socketLastActivity[socket] = DateTime.now();
        buffer += utf8.decode(data);
        while (buffer.contains('\n')) {
          final messageEndIndex = buffer.indexOf('\n');
          final completeMessage = buffer.substring(0, messageEndIndex).trim();
          buffer = buffer.substring(messageEndIndex + 1);
          if (completeMessage.isNotEmpty) {
            _handleTcpMessage(completeMessage, socket);
          }
        }
      },
      onDone: () {
        LogService.w("Socket onDone (remote closed) for ${friendId ?? 'unknown'}");
        _removeSocket(socket);
      },
      onError: (e) {
        LogService.e("Socket onError for ${friendId ?? 'unknown'}: $e");
        _removeSocket(socket);
      },
      cancelOnError: false,
    );
  }

  String? _findUserIdBySocket(Socket socket) {
    for (final entry in _userSockets.entries) {
      if (entry.value == socket) return entry.key;
    }
    return null;
  }

  bool _isSocketRecentlyActive(Socket socket, {Duration window = const Duration(seconds: 10)}) {
    final last = _socketLastActivity[socket];
    if (last == null) return false;
    return DateTime.now().difference(last) <= window;
  }

  String? _findUserIdByCallSocket(Socket socket) {
    for (final entry in _callSockets.entries) {
      if (entry.value == socket) return entry.key;
    }
    return null;
  }

  void _setupCallSocket(Socket socket) {
    String buffer = '';
    final userId = _findUserIdByCallSocket(socket);
    if (userId != null) {
      _callLastPongTime[userId] = DateTime.now();
    }

    socket.listen(
      (data) {
        buffer += utf8.decode(data);
        while (buffer.contains('\n')) {
          final messageEndIndex = buffer.indexOf('\n');
          final completeMessage = buffer.substring(0, messageEndIndex).trim();
          buffer = buffer.substring(messageEndIndex + 1);
          if (completeMessage.isNotEmpty) {
            if (completeMessage == 'PING') {
              _safeWrite(socket, 'PONG\n');
            } else if (completeMessage == 'PONG') {
              final pongUserId = _findUserIdByCallSocket(socket);
              if (pongUserId != null) {
                _callLastPongTime[pongUserId] = DateTime.now();
                final completer = _callPingCompleters[pongUserId];
                if (completer != null && !completer.isCompleted) {
                  completer.complete(true);
                }
              }
            } else {
              _handleTcpMessage(completeMessage, socket);
            }
          }
        }
      },
      onDone: () {
        LogService.w("Call socket onDone (remote closed) for ${userId ?? 'unknown'}");
        final currentId = _findUserIdByCallSocket(socket);
        if (currentId != null && _callSockets[currentId] == socket) {
          _removeCallSocket(socket);
        } else {
          LogService.w("Call socket onDone ignored - socket already replaced");
        }
      },
      onError: (e) {
        LogService.e("Call socket onError for ${userId ?? 'unknown'}: $e");
        _removeCallSocket(socket);
      },
      cancelOnError: false,
    );
  }

  void _safeSocketClose(Socket socket) {
    try {
      socket.destroy();
    } catch (e) {
      try {
        socket.close();
      } catch (e2) { /* Ignore */ }
    }
  }

  // دالة جديدة لمحاولة إعادة الاتصال الفوري بجميع الأصدقاء المعروفين
  void _reconnectToAllFriends() {
    final friendsToReconnect = _friendIds.where((id) => !_userSockets.containsKey(id) && _ipDirectory.containsKey(id)).toList();
    for (final friendId in friendsToReconnect) {
      _improvedReconnectToFriend(friendId);
    }
  }

  Future<void> _improvedReconnectToFriend(String friendId) async {
    if (_pendingConnections[friendId] == true || _userSockets.containsKey(friendId)) return;
    if (_quickReconnecting.contains(friendId)) return;
    if (_callProtectedSockets.contains(friendId)) return;
    if (!_shouldAttemptReconnect(friendId)) return;
    final targetIp = _ipDirectory[friendId];
    if (targetIp == null) return;
    _pendingConnections[friendId] = true;
    _reconnectAttempts[friendId] = DateTime.now();
    final attempt = _reconnectCounters[friendId] ?? 0;
    _reconnectCounters[friendId] = attempt + 1;
    const delays = [0, 1, 2, 3, 5, 10];
    final delay = delays[attempt < delays.length ? attempt : delays.length - 1];
    if (delay > 0) {
      await Future.delayed(Duration(seconds: delay));
      if (_userSockets.containsKey(friendId)) {
        _pendingConnections.remove(friendId);
        return;
      }
    }
    Socket? socket;
    try {
      socket = await Socket.connect(targetIp, 8080, timeout: const Duration(seconds: 5));
      _setupSocket(socket);
      _safeWrite(socket, 'RECONNECT:${jsonEncode(_currentUser!.toJson())}\n');
    } catch (e) {
      if (socket != null) _safeSocketClose(socket);
      final oldSocket = _userSockets.remove(friendId);
      _lastPongTime.remove(friendId);
      if (oldSocket != null) _safeSocketClose(oldSocket);
      if ((attempt + 1) > 5) _ipDirectory.remove(friendId);
    } finally {
      _pendingConnections.remove(friendId);
    }
  }

  // --- Public Actions ---
  Future<void> sendConnectionRequest(User targetUser) async {
    final targetIp = _ipDirectory[targetUser.id];
    if (targetIp == null) return;
    try {
      final socket = await Socket.connect(targetIp, 8080, timeout: const Duration(seconds: 5));
      _setupSocket(socket);
      _safeWrite(socket, 'CONNECT_REQUEST:${jsonEncode(_currentUser!.toJson())}\n');
    } catch (e) { /* Handle error */ }
  }

  void acceptConnectionRequest(User requestingUser, Socket socket) {
    _safeWrite(socket, 'CONNECT_ACCEPT:${jsonEncode(_currentUser!.toJson())}\n');
    _finalizeConnection(requestingUser, socket);
  }

  void rejectConnectionRequest(Socket socket) => _safeSocketClose(socket);

  Future<void> sendMessage(Message message) async {
    LogService.i('DEBUG sendMessage: attempting to send to ${message.receiverId}');
    await _dbService.insertMessage(message);
    _allMessages.putIfAbsent(message.receiverId, () => []).add(message);
    _saveAllMessages();
    onPrivateMessageReceived?.call(message);

    final socket = _userSockets[message.receiverId];
    if (socket == null) {
      LogService.w('DEBUG sendMessage: NO SOCKET for ${message.receiverId}, enqueueing');
      _enqueueMessage(message, 'text', showInUi: false);
      return;
    }

    LogService.i('DEBUG sendMessage: socket found for ${message.receiverId}, sending PING to verify...');
    final pongCompleter = Completer<bool>();
    _pingCompleters[message.receiverId] = pongCompleter;
    _safeWrite(socket, 'PING\n');
    final pongReceived = await pongCompleter.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => false,
    );
    _pingCompleters.remove(message.receiverId);

    if (!pongReceived) {
      LogService.w('DEBUG sendMessage: PONG TIMEOUT from ${message.receiverId}, removing socket + reconnecting');
      if (_userSockets[message.receiverId] == socket) {
        _userSockets.remove(message.receiverId);
        _safeSocketClose(socket);
      }
      _lastPongTime.remove(message.receiverId);
      _enqueueMessage(message, 'text', showInUi: false);
      _quickReconnect(message.receiverId);
      return;
    }

    LogService.i('DEBUG sendMessage: PONG received from ${message.receiverId}, writing MSG...');
    final json = message.toJson();
    json['content'] = EncryptionService().encryptText(message.content);
    if (!_safeWrite(socket, 'MSG:${jsonEncode(json)}\n')) {
      LogService.e('DEBUG sendMessage: WRITE FAILED for ${message.receiverId}, enqueueing');
      _enqueueMessage(message, 'text', showInUi: false);
      return;
    }
    LogService.i('DEBUG sendMessage: write completed, waiting for ACK...');

    final acked = await _queueService.waitForAck(message.id);
    if (acked) {
      LogService.i('DEBUG sendMessage: ACK RECEIVED for ${message.id}, delivery confirmed');
      _queueService.markSentSilent(message.id);
      onMessageDeliveryStatusChanged?.call(message.id, DeliveryStatus.sent);
    } else {
      LogService.w('DEBUG sendMessage: ACK TIMEOUT for ${message.id}, enqueueing');
      _enqueueMessage(message, 'text', showInUi: false);
    }
  }

  void _enqueueMessage(Message message, String messageType, {String? groupId, String? fileMetadata, bool showInUi = true}) {
    final pending = PendingMessage(
      id: message.id,
      senderId: message.senderId,
      receiverId: message.receiverId,
      content: message.content,
      timestamp: message.timestamp,
      messageType: messageType,
      groupId: groupId,
      fileMetadata: fileMetadata,
    );
    _queueService.enqueue(pending);
    if (showInUi) {
      onPrivateMessageReceived?.call(message);
    }
    onMessageDeliveryStatusChanged?.call(message.id, DeliveryStatus.pending);
  }

  void sendGroupMessage(String groupId, String content) {
    if (_currentUser == null) return;
    final message = GroupMessage(id: const Uuid().v4(), groupId: groupId, senderId: _currentUser!.id, content: content, timestamp: DateTime.now());
    _groupMessages.putIfAbsent(groupId, () => []).add(message);
    _saveGroupMessages();
    onGroupMessageReceived?.call(message);
    final msgJson = message.toJson();
    msgJson['content'] = EncryptionService().encryptText(content);
    final messageData = {'type': 'GROUP_MESSAGE', 'message': msgJson};
    _sendToGroupMembers(groupId, 'GROUP_MSG:${jsonEncode(messageData)}\n');
  }
  void editMessage(String conversationId, String messageId, String newContent) {
    _queueService.updatePendingContent(messageId, newContent);
    _dbService.updateMessageContent(messageId, newContent);

    final messageIndex = _allMessages[conversationId]?.indexWhere((msg) => msg.id == messageId);
    if (messageIndex != null && messageIndex != -1) {
      final originalMessage = _allMessages[conversationId]![messageIndex];
      _allMessages[conversationId]![messageIndex] = Message(
        id: originalMessage.id,
        senderId: originalMessage.senderId,
        receiverId: originalMessage.receiverId,
        content: newContent,
        timestamp: originalMessage.timestamp,
        edited: true,
        editedAt: DateTime.now(),
      );
      _saveAllMessages();
    }

    if (onMessageEdited != null) {
      onMessageEdited!(conversationId, messageId, newContent);
    }

    final editInfo = {
      'type': 'EDIT_MESSAGE',
      'conversationId': _currentUser!.id,
      'messageId': messageId,
      'newContent': EncryptionService().encryptText(newContent),
    };
    _sendToUser(conversationId, 'MSG_UPDATE:${jsonEncode(editInfo)}');
  }

  void deleteMessage(String conversationId, String messageId) {
    _queueService.deleteMessage(messageId);
    _dbService.deleteMessage(messageId);
    _fileMessages[conversationId]?.removeWhere((msg) => msg.id == messageId);
    _saveFileMessages();
    _allMessages[conversationId]?.removeWhere((msg) => msg.id == messageId);
    _saveAllMessages();

    if (onMessageDeleted != null) {
      onMessageDeleted!(conversationId, messageId);
    }

    final deleteInfo = {
      'type': 'DELETE_MESSAGE',
      'conversationId': _currentUser!.id,
      'messageId': messageId,
      'senderId': _currentUser!.id,
    };
    _sendToUser(conversationId, 'MSG_UPDATE:${jsonEncode(deleteInfo)}');
  }

  void _sendToGroupMembers(String groupId, String message) {
    final group = _groups[groupId];
    if (group == null) return;
    for (final memberId in group.memberIds) {
      if (memberId != _currentUser!.id) {
        final socket = _userSockets[memberId];
        if (socket != null) {
          if (!_safeWrite(socket, message)) {
            LogService.e('_sendToGroupMembers WRITE FAILED for $memberId');
            _enqueueGroupMessageForMember(groupId, memberId, message);
          }
        } else {
          _enqueueGroupMessageForMember(groupId, memberId, message);
        }
      }
    }
  }

  void _enqueueGroupMessageForMember(String groupId, String memberId, String rawMessage) {
    try {
      final data = jsonDecode(rawMessage.substring('GROUP_MSG:'.length));
      if (data['type'] == 'GROUP_MESSAGE') {
        final msgJson = data['message'] as Map<String, dynamic>;
        final msg = Message(
          id: msgJson['id'],
          senderId: msgJson['senderId'],
          receiverId: memberId,
          content: msgJson['content'] is String ? EncryptionService().decryptText(msgJson['content']) : msgJson['content'],
          timestamp: DateTime.parse(msgJson['timestamp']),
        );
        _enqueueMessage(msg, 'group', groupId: groupId);
      }
    } catch (e) {
      LogService.e('❌ Error enqueuing group message for offline member $memberId: $e');
    }
  }

  // تعديل رسالة في مجموعة
  void editGroupMessage(String groupId, String messageId, String newContent) {
    // تحديث الرسالة في مجموعة الرسائل
    final messageIndex = _groupMessages[groupId]?.indexWhere((msg) => msg.id == messageId);
    if (messageIndex != null && messageIndex != -1) {
      _groupMessages[groupId]![messageIndex] = GroupMessage(
        id: messageId,
        groupId: groupId,
        senderId: _currentUser!.id,
        content: newContent,
        timestamp: _groupMessages[groupId]![messageIndex].timestamp,
        edited: true,
        editedAt: DateTime.now(),
      );

      _saveGroupMessages();

      // إرسال رسالة التعديل لأعضاء المجموعة
      _sendToGroupMembers(groupId, 'GROUP_MSG:${jsonEncode({
        'type': 'EDIT_GROUP_MESSAGE',
        'groupId': groupId,
        'messageId': messageId,
        'newContent': EncryptionService().encryptText(newContent),
        'senderId': _currentUser!.id,
      })}');
    }
  }

  // حذف رسالة من مجموعة
  void deleteGroupMessage(String groupId, String messageId) {
    // حذف الرسالة من قائمة رسائل المجموعة
    _groupMessages[groupId]?.removeWhere((msg) => msg.id == messageId);

    // حفظ التغييرات
    _saveGroupMessages();

    // إرسال رسالة الحذف لأعضاء المجموعة
    _sendToGroupMembers(groupId, 'GROUP_MSG:${jsonEncode({
      'type': 'DELETE_GROUP_MESSAGE',
      'groupId': groupId,
      'messageId': messageId,
      'senderId': _currentUser!.id,
    })}');
  }

  // حذف جميع رسائل المجموعة
  void deleteGroupMessages(String groupId) {
    // حذف جميع رسائل المجموعة
    _groupMessages[groupId]?.clear();

    // حفظ التغييرات
    _saveGroupMessages();

    // إرسال رسالة الحذف لأعضاء المجموعة
    _sendToGroupMembers(groupId, 'GROUP_MSG:${jsonEncode({
      'type': 'DELETE_ALL_GROUP_MESSAGES',
      'groupId': groupId,
      'senderId': _currentUser!.id,
    })}');
  }

  // ... (داخل كلاس LocalNetworkService)

  /// **مُحسَّن**: إرسال الملفات على شكل حزم لتجنب انقطاع الشبكة.
  Future<void> sendFileMessage(String receiverId, File file, String fileType, {String? groupId, String? savedPath}) async {
    if (_currentUser == null) return;

    if (!await file.exists()) {
      LogService.e('sendFileMessage: File does not exist: ${file.path}');
      return;
    }
    LogService.i('DEBUG sendFileMessage: file exists: ${file.path}');

    final fileName = p.basename(file.path);
    final fileBytes = await file.readAsBytes();
    final fileSizeBytes = fileBytes.length;
    final messageId = const Uuid().v4();
    LogService.i('DEBUG sendFileMessage: read $fileSizeBytes bytes, fileName=$fileName, msgId=$messageId');

    final localPath = savedPath ?? await _saveFileLocally(fileBytes, '${messageId}_$fileName');
    final fileMessage = FileMessage(
      id: messageId,
      senderId: _currentUser!.id,
      receiverId: receiverId,
      groupId: groupId,
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSizeBytes,
      filePath: localPath,
      timestamp: DateTime.now(),
    );

    final fileKey = groupId ?? receiverId;
    _fileMessages.putIfAbsent(fileKey, () => []).add(fileMessage);
    _saveFileMessages();
    onFileMessageReceived?.call(fileMessage);

    final socket = _userSockets[receiverId];
    if (socket == null) {
      LogService.w('DEBUG sendFileMessage: NO SOCKET for $receiverId, enqueueing file msgId=$messageId');
      final msg = Message(
        id: messageId,
        senderId: _currentUser!.id,
        receiverId: receiverId,
        content: '[ملف] $fileName',
        timestamp: DateTime.now(),
      );
      final fileMetadata = jsonEncode({
        'fileName': fileName,
        'fileType': fileType,
        'fileSize': fileSizeBytes,
        'filePath': localPath,
      });
      _enqueueMessage(msg, 'file', fileMetadata: fileMetadata);
      return;
    }

    LogService.i('DEBUG sendFileMessage: socket found for $receiverId, sending PING to verify...');
    final pongCompleter = Completer<bool>();
    _pingCompleters[receiverId] = pongCompleter;
    _safeWrite(socket, 'PING\n');
    final pongReceived = await pongCompleter.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => false,
    );
    _pingCompleters.remove(receiverId);

    if (!pongReceived) {
      LogService.w('DEBUG sendFileMessage: PONG TIMEOUT from $receiverId, removing socket + falling to queue path msgId=$messageId');
      if (_userSockets[receiverId] == socket) {
        _userSockets.remove(receiverId);
        _safeSocketClose(socket);
      }
      _lastPongTime.remove(receiverId);
      final msg = Message(
        id: messageId,
        senderId: _currentUser!.id,
        receiverId: receiverId,
        content: '[ملف] $fileName',
        timestamp: DateTime.now(),
      );
      final fileMetadata = jsonEncode({
        'fileName': fileName,
        'fileType': fileType,
        'fileSize': fileSizeBytes,
        'filePath': localPath,
      });
      _enqueueMessage(msg, 'file', fileMetadata: fileMetadata);
      _quickReconnect(receiverId);
      return;
    }

    LogService.i('DEBUG sendFileMessage: PONG received from $receiverId, sending file msgId=$messageId');
    try {
      final startData = {
        'type': 'FILE_START',
        'message': fileMessage.toJson(),
      };
      if (!_safeWrite(socket, 'FILE_TRANSFER:${jsonEncode(startData)}\n')) {
        LogService.e('DEBUG sendFileMessage: FILE_START WRITE FAILED for $receiverId msgId=$messageId');
        throw Exception('FILE_START write failed');
      }
      LogService.i('DEBUG sendFileMessage: FILE_START sent to $receiverId msgId=$messageId');

      const chunkSize = 32 * 1024;
      int chunkIndex = 0;
      for (int offset = 0; offset < fileBytes.length; offset += chunkSize) {
        final end = (offset + chunkSize > fileBytes.length) ? fileBytes.length : offset + chunkSize;
        final chunk = fileBytes.sublist(offset, end);
        final chunkData = {
          'type': 'FILE_CHUNK',
          'messageId': messageId,
          'chunk': base64Encode(chunk),
        };
        if (!_safeWrite(socket, 'FILE_TRANSFER:${jsonEncode(chunkData)}\n')) {
          LogService.e('DEBUG sendFileMessage: FILE_CHUNK $chunkIndex WRITE FAILED for $receiverId msgId=$messageId');
          throw Exception('FILE_CHUNK write failed');
        }
        await socket.flush();
        LogService.i('DEBUG sendFileMessage: chunk $chunkIndex sent (offset=$offset, bytes=${chunk.length}) msgId=$messageId');
        chunkIndex++;
      }

      final endData = {
        'type': 'FILE_END',
        'messageId': messageId,
      };
      if (!_safeWrite(socket, 'FILE_TRANSFER:${jsonEncode(endData)}\n')) {
        LogService.e('DEBUG sendFileMessage: FILE_END WRITE FAILED for $receiverId msgId=$messageId');
        throw Exception('FILE_END write failed');
      }
      LogService.i('DEBUG sendFileMessage: FILE_END sent to $receiverId msgId=$messageId, transfer complete');

    } catch (e) {
      LogService.e('❌ خطأ أثناء إرسال الملف إلى $receiverId: $e');
      final msg = Message(
        id: messageId,
        senderId: _currentUser!.id,
        receiverId: receiverId,
        content: '[ملف] $fileName',
        timestamp: DateTime.now(),
      );
      final fileMetadata = jsonEncode({
        'fileName': fileName,
        'fileType': fileType,
        'fileSize': fileSizeBytes,
        'filePath': localPath,
      });
      _enqueueMessage(msg, 'file', fileMetadata: fileMetadata);
      final badSocket = _userSockets[receiverId];
      if (badSocket != null) {
        LogService.w('DEBUG sendFileMessage: catch -> queued file msgId=$messageId, removing socket');
        _removeSocket(badSocket);
      }
    }
  }

  // ... (بقية دوال الكلاس)

  Future<void> createGroup(String groupName, List<String> memberIds) async {
    if (_currentUser == null) return;
    final groupId = const Uuid().v4();
    final group = Group(id: groupId, name: groupName, adminId: _currentUser!.id, memberIds: [...memberIds, _currentUser!.id], createdAt: DateTime.now());
    _groups[groupId] = group;
    _userGroups.putIfAbsent(_currentUser!.id, () => []).add(groupId);
    _saveGroupsData();
    onGroupsChanged?.call();
    final announcement = {'type': 'GROUP_CREATED', 'group': group.toJson()};
    _sendToGroupMembers(groupId, 'GROUP_UPDATE:${jsonEncode(announcement)}\n');
  }

  Future<void> unfriend(String friendId) async {
    final socket = _userSockets[friendId];
    if (socket != null) {
      _safeWrite(socket, 'UNFRIEND:${jsonEncode(_currentUser!.toJson())}\n');
      _removeSocket(socket);
    }
    _removeFriend(friendId);
  }

  void _removeFriend(String friendId) {
    _friendIds.remove(friendId);
    _userDirectory.remove(friendId);
    _allMessages.remove(friendId);
    _ipDirectory.remove(friendId);
    _lastPongTime.remove(friendId);
    _queueService.purgeForPeer(friendId);
    _saveFriendsAndDirectory();
    _saveAllMessages();
    onFriendsChanged?.call();
  }

  // --- Heartbeat Logic (via UDP, no TCP disruption) ---

  // --- Status & Notifications ---
  void updateUserStatus(bool isOnline, {String? currentChatId}) {
    if (_currentUser == null) return;
    final status = UserStatus(userId: _currentUser!.id, isOnline: isOnline, lastSeen: isOnline ? null : DateTime.now(), currentChatId: currentChatId);
    _userStatuses[_currentUser!.id] = status;
    _broadcastUserStatus(status);
    _saveUserStatuses();
    onStatusChanged?.call();
  }

  void _broadcastUserStatus(UserStatus status) {
    if (!_showOnlineStatus) return;
    final statusMessage = {'type': 'USER_STATUS', 'status': status.toJson()};
    final payload = 'STATUS:${jsonEncode(statusMessage)}';
    try {
      _broadcastSocket?.send(utf8.encode(payload), InternetAddress("255.255.255.255"), 8081);
    } catch (e) { /* Ignore */ }
  }

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    _saveNotifications();
    onNotificationsChanged?.call();

    // عرض إشعار حقيقي في شريط الإشعارات
    unawaited(SystemNotificationService().showNotification(
      title: notification.title,
      body: notification.body,
      type: notification.type,
      payload: notification.id,
    ));
  }

  void markNotificationAsRead(String notificationId) {
    final notification = _notifications.firstWhere((n) => n.id == notificationId, orElse: () => AppNotification(id: '', title: '', body: '', type: '', timestamp: DateTime.now()));
    if (notification.id.isNotEmpty) {
      notification.isRead = true;
      _saveNotifications();
      onNotificationsChanged?.call();
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
    final allMessagesJson = _allMessages.map((key, value) => MapEntry(key, jsonEncode(value.map((msg) => msg.toJson()).toList())));
    await prefs.setString('all_messages_v3', jsonEncode(allMessagesJson));
  }


  Future<void> _saveGroupsData() async {
    final prefs = await SharedPreferences.getInstance();
    final groupsJson = _groups.map((key, value) => MapEntry(key, jsonEncode(value.toJson())));
    await prefs.setString('user_groups_v1', jsonEncode(groupsJson));
    final userGroupsJson = _userGroups.map((key, value) => MapEntry(key, value));
    await prefs.setString('user_groups_mapping_v1', jsonEncode(userGroupsJson));
  }

  Future<void> _saveGroupMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final groupMessagesJson = _groupMessages.map((key, value) => MapEntry(key, jsonEncode(value.map((msg) => msg.toJson()).toList())));
    await prefs.setString('group_messages_v1', jsonEncode(groupMessagesJson));
  }

  Future<void> _saveFileMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final fileMessagesJson = _fileMessages.map((key, value) => MapEntry(key, jsonEncode(value.map((msg) => msg.toJson()).toList())));
    await prefs.setString('file_messages_v1', jsonEncode(fileMessagesJson));
  }

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

  Future<void> _saveCallHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('call_history_v1', jsonEncode(_callHistory.toJson()));
  }

  Future<void> _loadDataFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _friendIds.clear();
    _userDirectory.clear();
    _allMessages.clear();
    _groups.clear();
    _groupMessages.clear();
    _fileMessages.clear();
    _userGroups.clear();
    _userStatuses.clear();
    _notifications.clear();

    try {
      _friendIds.addAll(prefs.getStringList('friend_ids_v3') ?? []);
    } catch (e) {
      LogService.e('Error loading friend_ids_v3: $e');
    }

    try {
      final dirStr = prefs.getString('user_directory_v3');
      if (dirStr != null) (jsonDecode(dirStr) as Map<String, dynamic>).forEach((k, v) => _userDirectory[k] = v);
    } catch (e) {
      LogService.e('Error loading user_directory_v3: $e');
    }

    try {
      final allMessagesString = prefs.getString('all_messages_v3');
      if (allMessagesString != null) {
        final allMessagesJson = jsonDecode(allMessagesString) as Map<String, dynamic>;
        allMessagesJson.forEach((key, value) {
          _allMessages[key] = (jsonDecode(value) as List).map((item) => Message.fromJson(item)).toList();
        });
      }
    } catch (e) {
      LogService.e('Error loading all_messages_v3: $e');
    }

    try {
      final groupsString = prefs.getString('user_groups_v1');
      if (groupsString != null) {
        final groupsJson = jsonDecode(groupsString) as Map<String, dynamic>;
        groupsJson.forEach((key, value) => _groups[key] = Group.fromJson(jsonDecode(value)));
      }
    } catch (e) {
      LogService.e('Error loading user_groups_v1: $e');
    }

    try {
      final userGroupsString = prefs.getString('user_groups_mapping_v1');
      if (userGroupsString != null) {
        final userGroupsJson = jsonDecode(userGroupsString) as Map<String, dynamic>;
        userGroupsJson.forEach((key, value) => _userGroups[key] = List<String>.from(value));
      }
    } catch (e) {
      LogService.e('Error loading user_groups_mapping_v1: $e');
    }

    try {
      final groupMessagesString = prefs.getString('group_messages_v1');
      if (groupMessagesString != null) {
        final groupMessagesJson = jsonDecode(groupMessagesString) as Map<String, dynamic>;
        groupMessagesJson.forEach((key, value) => _groupMessages[key] = (jsonDecode(value) as List).map((item) => GroupMessage.fromJson(item)).toList());
      }
    } catch (e) {
      LogService.e('Error loading group_messages_v1: $e');
    }

    try {
      final fileMessagesString = prefs.getString('file_messages_v1');
      if (fileMessagesString != null) {
        final fileMessagesJson = jsonDecode(fileMessagesString) as Map<String, dynamic>;
        fileMessagesJson.forEach((key, value) => _fileMessages[key] = (jsonDecode(value) as List).map((item) => FileMessage.fromJson(item)).toList());
      }
    } catch (e) {
      LogService.e('Error loading file_messages_v1: $e');
    }

    try {
      final statusesString = prefs.getString('user_statuses_v1');
      if (statusesString != null) {
        final statusesJson = jsonDecode(statusesString) as Map<String, dynamic>;
        statusesJson.forEach((key, value) => _userStatuses[key] = UserStatus.fromJson(jsonDecode(value)));
      }
    } catch (e) {
      LogService.e('Error loading user_statuses_v1: $e');
    }

    try {
      final notificationsString = prefs.getString('notifications_v1');
      if (notificationsString != null) {
        final notificationsJson = jsonDecode(notificationsString) as List;
        _notifications.addAll(notificationsJson.map((json) => AppNotification.fromJson(json)).toList());
      }
    } catch (e) {
      LogService.e('Error loading notifications_v1: $e');
    }

    try {
      final callHistoryString = prefs.getString('call_history_v1');
      if (callHistoryString != null) {
        _callHistory = CallHistory.fromJson(jsonDecode(callHistoryString));
      }
    } catch (e) {
      LogService.e('Error loading call_history_v1: $e');
    }

    _showOnlineStatus = prefs.getBool('show_online_status') ?? true;
    _readReceipts = prefs.getBool('read_receipts') ?? true;

    try {
      final dbMessages = await _dbService.getAllMessages();
      for (final msg in dbMessages) {
        final key = msg.senderId == _currentUser?.id ? msg.receiverId : msg.senderId;
        if (!_allMessages.containsKey(key) || !_allMessages[key]!.any((m) => m.id == msg.id)) {
          _allMessages.putIfAbsent(key, () => []).add(msg);
        }
      }
    } catch (e) {
      LogService.e('Error loading messages from SQLite: $e');
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
      LogService.e('❌ Error saving file locally: $e');
      return ''; // إرجاع مسار فارغ في حالة الخطأ
    }
  }


  // --- دوال إدارة الإشعارات (التي كانت مفقودة) ---

  /// يزيل إشعاراً محدداً من القائمة.
  void removeNotification(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    _saveNotifications(); // حفظ التغييرات
    onNotificationsChanged?.call(); // إعلام الواجهة بالتغيير
  }

  /// يضبط كل الإشعارات الحالية كـ "مقروءة".
  void markAllNotificationsAsRead() {
    for (final notification in _notifications) {
      notification.isRead = true;
    }
    _saveNotifications(); // حفظ التغييرات
    onNotificationsChanged?.call(); // إعلام الواجهة بالتغيير
  }

  // --- دوال إدارة حالة الكتابة (Typing Status) ---

  void sendTypingStatus(String receiverId, bool isTyping, {String? chatType = 'private'}) {
    if (_currentUser == null) return;

    _typingTimers[receiverId]?.cancel();

    final typingStatus = {
      'type': 'TYPING_STATUS',
      'senderId': _currentUser!.id,
      'receiverId': receiverId,
      'isTyping': isTyping,
      'chatType': chatType,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _sendToUser(receiverId, 'STATUS:${jsonEncode(typingStatus)}');

    if (isTyping) {
      _typingTimers[receiverId] = Timer(const Duration(seconds: 3), () {
        sendTypingStatus(receiverId, false, chatType: chatType);
      });
    }
  }


  // --- دوال التخزين الجديدة ---


  // --- دوال مساعدة للبث والإرسال ---

  void _sendToUser(String userId, String message) {
    final socket = _userSockets[userId];
    if (socket != null) {
      if (_safeWrite(socket, '$message\n')) {
        unawaited(socket.flush());
      } else {
        LogService.e('❌ Error sending message to $userId');
      }
    }
  }

  void _sendBroadcastMessage(Map<String, dynamic> message) {
    final payload = 'DISCOVER:${jsonEncode(message)}';
    try {
      _broadcastSocket?.send(utf8.encode(payload), InternetAddress("255.255.255.255"), 8081);
    } catch (e) {
      LogService.e('Broadcast message error: $e');
    }
  }

  void _broadcastMessage(Map<String, dynamic> message) {
    _sendBroadcastMessage(message);
  }

  // --- Call Functions ---

  // بدء مكالمة جديدة
  Future<void> startCall(String receiverId, CallType callType) async {
    if (_currentUser == null) return;
    if (_isCallActive) {
      LogService.w('startCall: call already active, rejecting');
      return;
    }

    final existing = _activeCalls.values.where(
      (c) => (c.status == CallStatus.ringing || c.status == CallStatus.active) &&
             (c.callerId == _currentUser!.id && c.receiverId == receiverId),
    );
    if (existing.isNotEmpty) {
      LogService.w('startCall: existing call with $receiverId, rejecting duplicate');
      return;
    }
    
    final callId = const Uuid().v4();
    final call = CallModel(
      id: callId,
      callerId: _currentUser!.id,
      receiverId: receiverId,
      callType: callType,
      status: CallStatus.ringing,
      startTime: DateTime.now(),
    );
    
    _activeCalls[callId] = call;
    _isCallActive = true;
    _callProtectedSockets.add(receiverId);
    _ensureCallSocket(receiverId);
    _callTimers[callId] = Timer(const Duration(seconds: 30), () {
      _handleCallTimeout(callId);
    });
    
    // إرسال إشعار المكالمة إلى الطرف الآخر
    _sendCallSignal(receiverId, {
      'type': 'call_request',
      'callId': callId,
      'callerId': _currentUser!.id,
      'callerName': _currentUser!.username,
      'callType': callType.name,
    });
    
    // إعلام الواجهة المحلية ببدء المكالمة
    onCallStatusChanged?.call(call);
  }

  // قبول مكالمة واردة
  Future<void> acceptCall(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;
    
    // تحديث حالة المكالمة
    _activeCalls[callId] = call.copyWith(status: CallStatus.active);
    
    _callProtectedSockets.add(call.callerId);

    // إيقاف مؤقت الانتظار
    _callTimers[callId]?.cancel();
    _callTimers.remove(callId);
    
    // إرسال إشعار القبول إلى الطرف الآخر
    _sendCallSignal(call.callerId, {
      'type': 'call_accepted',
      'callId': callId,
    });
    
    // إعلام الواجهة المحلية بقبول المكالمة
    onCallStatusChanged?.call(_activeCalls[callId]!);
    
    // بدء مؤقت مدة المكالمة
    _callTimers[callId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      // تحديث مدة المكالمة كل ثانية
      final updatedCall = _activeCalls[callId]?.copyWith(
        duration: timer.tick,
      );
      if (updatedCall != null) {
        _activeCalls[callId] = updatedCall;
        onCallStatusChanged?.call(updatedCall);
      }
    });
  }

  // رفض مكالمة واردة
  Future<void> rejectCall(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;
    
    // تحديث حالة المكالمة
    _activeCalls[callId] = call.copyWith(status: CallStatus.rejected);
    
    // إيقاف المؤقتات
    _callTimers[callId]?.cancel();
    _callTimers.remove(callId);
    
    // إرسال إشعار الرفض إلى الطرف الآخر
    _sendCallSignal(call.callerId, {
      'type': 'call_rejected',
      'callId': callId,
    });
    
    // إعلام الواجهة المحلية برفض المكالمة
    onCallStatusChanged?.call(_activeCalls[callId]!);
    
    // إنهاء المكالمة
    _endCall(callId);
  }

  // إنهاء مكالمة نشطة
  Future<void> endCall(String callId) async {
    final call = _activeCalls[callId];
    if (call == null) return;
    
    // تحديث حالة المكالمة
    _activeCalls[callId] = call.copyWith(
      status: CallStatus.ended,
      endTime: DateTime.now(),
      duration: _callTimers[callId]?.tick,
    );
    
    // إيقاف المؤقتات
    _callTimers[callId]?.cancel();
    _callTimers.remove(callId);
    
    // إرسال إشعار إنهاء المكالمة إلى الطرف الآخر
    _sendCallSignal(
      call.callerId == _currentUser?.id ? call.receiverId : call.callerId,
      {
        'type': 'call_ended',
        'callId': callId,
      }
    );
    
    // إعلام الواجهة المحلية بإنهاء المكالمة
    onCallStatusChanged?.call(_activeCalls[callId]!);
    onCallEnded?.call(callId);
    
    // إنهاء المكالمة وحفظها في السجل
    _endCall(callId);
  }

  // التعامل مع انتهاء وقت انتظار المكالمة
  void _handleCallTimeout(String callId) {
    final call = _activeCalls[callId];
    if (call == null) return;
    
    // تحديث حالة المكالمة
    _activeCalls[callId] = call.copyWith(status: CallStatus.missed);
    
    // إعلام الواجهة المحلية بفوات المكالمة
    onCallStatusChanged?.call(_activeCalls[callId]!);
    onCallEnded?.call(callId);
    
    // إنهاء المكالمة وحفظها في السجل
    _endCall(callId);
  }

  // إنهاء المكالمة وحفظها في السجل
  void _cleanupCallSockets(CallModel call) {
    for (final userId in [call.callerId, call.receiverId]) {
      final socket = _callSockets.remove(userId);
      if (socket != null) {
        _safeSocketClose(socket);
      }
      _callLastPongTime.remove(userId);
      _callPingCompleters.remove(userId);
      _pendingCallConnections.remove(userId);
    }
  }

  void _endCall(String callId) {
    final call = _activeCalls[callId];
    if (call != null) {
      _callProtectedSockets.remove(call.callerId);
      _callProtectedSockets.remove(call.receiverId);
      _cleanupCallSockets(call);
      // إضافة المكالمة إلى السجل
      _callHistory.addCall(call);
      _saveCallHistory();
      
      // إزالة المكالمة من قائمة المكالمات النشطة
      _activeCalls.remove(callId);
      if (_activeCalls.isEmpty) {
        _isCallActive = false;
      }
    }
  }

  // إرسال إشارة مكالمة إلى مستخدم
  void _sendCallSignal(String userId, Map<String, dynamic> signal) {
    LogService.d('DIAG sendSignal type=${signal['type']} callType=${signal['callType']} callId=${signal['callId']} hasCallSocket=${_callSockets[userId] != null} hasMsgSocket=${_userSockets[userId] != null}');
    final callSocket = _callSockets[userId];
    if (callSocket != null) {
      final encryptedPayload = EncryptionService().encryptText(jsonEncode(signal));
      if (_safeWrite(callSocket, 'CALL_SIGNAL:$encryptedPayload\n')) {
        unawaited(callSocket.flush());
        LogService.d('📞 _sendCallSignal WROTE (call channel) userId=$userId type=${signal['type']}');
        return;
      }
      LogService.d('📞 _sendCallSignal WRITE FAILED (call channel) userId=$userId type=${signal['type']}');
    }
    final msgSocket = _userSockets[userId];
    if (msgSocket != null) {
      final encryptedPayload = EncryptionService().encryptText(jsonEncode(signal));
      if (_safeWrite(msgSocket, 'CALL_SIGNAL:$encryptedPayload\n')) {
        unawaited(msgSocket.flush());
        LogService.d('📞 _sendCallSignal WROTE (msg channel) userId=$userId type=${signal['type']}');
        return;
      }
      LogService.d('📞 _sendCallSignal WRITE FAILED (msg channel) userId=$userId type=${signal['type']}');
    }
    LogService.d('📞 _sendCallSignal QUEUING userId=$userId type=${signal['type']}');
    _pendingCallSignals.putIfAbsent(userId, () => []).add(signal);
    unawaited(_ensureCallSocket(userId));
  }

  // التعامل مع إشارات المكالمات الواردة
  void _handleCallSignal(Map<String, dynamic> signal) {
    final type = signal['type'];
    LogService.d('DIAG recvSignal type=$type callType=${signal['callType']} callId=${signal['callId']}');
    LogService.d('📞 _handleCallSignal type=$type callId=${signal['callId']}');

    switch (type) {
      case 'call_request':
        _handleIncomingCall(signal);
        break;
      case 'call_accepted':
        LogService.d('📞 Call ACCEPTED: ${signal['callId']}');
        _handleCallAccepted(signal['callId']);
        break;
      case 'call_rejected':
        _handleCallRejected(signal['callId']);
        break;
      case 'call_ended':
        _handleCallEndedByRemote(signal['callId']);
        break;
      case 'call_signal':
        final innerSignal = Map<String, dynamic>.from(signal);
        innerSignal['type'] = signal['signalType'];
        innerSignal.remove('signalType');
        LogService.d('📞 WebRTC signal routed via call_signal case (signalType=${signal['signalType']})');
        if (onCallSignalReceived != null) {
          onCallSignalReceived!.call(signal['callId'], innerSignal);
        } else {
          _pendingWebRtcSignals.add(innerSignal);
        }
        break;
      default:
        LogService.d('📞 WebRTC signal routed via default case: type=$type');
        if (onCallSignalReceived != null) {
          onCallSignalReceived!.call(signal['callId'], signal);
        } else {
          _pendingWebRtcSignals.add(signal);
        }
        break;
    }
  }

  // التعامل مع مكالمة واردة
  void _handleIncomingCall(Map<String, dynamic> signal) {
    final callId = signal['callId'];
    final callerId = signal['callerId'];
    final callType = CallType.values.firstWhere((e) => e.name == signal['callType'], orElse: () => CallType.audio);
    LogService.d('DIAG incomingCall parsed callType=$callType raw=${signal['callType']}');

    final existingFromCaller = _activeCalls.values.where(
      (c) => (c.status == CallStatus.ringing || c.status == CallStatus.active) &&
             c.callerId == callerId,
    ).isNotEmpty;
    if (existingFromCaller) {
      LogService.d('_handleIncomingCall: ignoring duplicate call_request from $callerId');
      return;
    }
    if (_isCallActive) {
      LogService.d('_handleIncomingCall: call already active, rejecting call from $callerId');
      return;
    }

    LogService.d('📞 _handleIncomingCall: callerId=$callerId callType=$callType userDirHas=${_userDirectory.containsKey(callerId)}');
    
    // إنشاء نموذج المكالمة
    final call = CallModel(
      id: callId,
      callerId: callerId,
      receiverId: _currentUser?.id ?? '',
      callType: callType,
      status: CallStatus.ringing,
      startTime: DateTime.now(),
    );
    
    // إضافة المكالمة إلى المكالمات النشطة
    _activeCalls[callId] = call;
    _isCallActive = true;
    
    // بدء مؤقت انتظار الرد
    _callTimers[callId] = Timer(const Duration(seconds: 30), () {
      _handleCallTimeout(callId);
    });
    
    // إعلام الواجهة المحلية بالمكالمة الواردة
    for (final listener in _incomingCallListeners) {
      listener(call);
    }
  }

  // التعامل مع قبول المكالمة من الطرف الآخر
  void _handleCallAccepted(String callId) {
    final call = _activeCalls[callId];
    if (call == null) return;
    
    // تحديث حالة المكالمة
    _activeCalls[callId] = call.copyWith(status: CallStatus.active);
    
    // إيقاف مؤقت الانتظار
    _callTimers[callId]?.cancel();
    _callTimers.remove(callId);
    
    // إعلام الواجهة المحلية بقبول المكالمة
    onCallStatusChanged?.call(_activeCalls[callId]!);
    
    // بدء مؤقت مدة المكالمة
    _callTimers[callId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      // تحديث مدة المكالمة كل ثانية
      final updatedCall = _activeCalls[callId]?.copyWith(
        duration: timer.tick,
      );
      if (updatedCall != null) {
        _activeCalls[callId] = updatedCall;
        onCallStatusChanged?.call(updatedCall);
      }
    });
  }

  // التعامل مع رفض المكالمة من الطرف الآخر
  void _handleCallRejected(String callId) {
    final call = _activeCalls[callId];
    if (call == null) return;
    
    // تحديث حالة المكالمة
    _activeCalls[callId] = call.copyWith(status: CallStatus.rejected);
    
    // إيقاف المؤقتات
    _callTimers[callId]?.cancel();
    _callTimers.remove(callId);
    
    // إعلام الواجهة المحلية برفض المكالمة
    onCallStatusChanged?.call(_activeCalls[callId]!);
    onCallEnded?.call(callId);
    
    // إنهاء المكالمة وحفظها في السجل
    _endCall(callId);
  }

  // التعامل مع إنهاء المكالمة من الطرف الآخر
  void _handleCallEndedByRemote(String callId) {
    final call = _activeCalls[callId];
    if (call == null) return;
    
    // تحديث حالة المكالمة
    _activeCalls[callId] = call.copyWith(
      status: CallStatus.ended,
      endTime: DateTime.now(),
      duration: _callTimers[callId]?.tick,
    );
    
    // إيقاف المؤقتات
    _callTimers[callId]?.cancel();
    _callTimers.remove(callId);
    
    // إعلام الواجهة المحلية بإنهاء المكالمة
    onCallStatusChanged?.call(_activeCalls[callId]!);
    onCallEnded?.call(callId);
    
    // إنهاء المكالمة وحفظها في السجل
    _endCall(callId);
  }

  // إرسال إشارة WebRTC
  void sendWebRTCSignal(String callId, String receiverId, Map<String, dynamic> signal) {
    _sendCallSignal(receiverId, {
      ...signal,
      'callId': callId,
      'type': 'call_signal',
      'signalType': signal['type'],
    });
  }

  // الحصول على المكالمات النشطة
  List<CallModel> getActiveCalls() => _activeCalls.values.toList();

  // الحصول على سجل المكالمات
  CallHistory getCallHistory() => _callHistory;

  // الحصول على مكالمة نشطة بالمعرف
  CallModel? getActiveCall(String callId) => _activeCalls[callId];

  // حفظ المجموعات
  void _saveGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final groupsJson = _groups.map((groupId, group) => MapEntry(groupId, jsonEncode(group.toJson())));
    await prefs.setString('user_groups_v1', jsonEncode(groupsJson));
  }

  // الحصول على مستخدم بواسطة المعرف
  User? getUserById(String userId) {
    try {
    try {
      return _discoveredUsers.firstWhere((user) => user.id == userId);
    } catch (e) {
      if (_userDirectory.containsKey(userId)) {
        return User(id: userId, username: _userDirectory[userId]!);
      }
      return null;
    }
    } catch (e) {
      if (_userDirectory.containsKey(userId)) {
        return User(id: userId, username: _userDirectory[userId]!);
      }
      return null;
    }
  }

  // مغادرة مجموعة
  Future<void> leaveGroup(String groupId) async {
    final currentUserId = _currentUser?.id;
    if (currentUserId == null) return;
    final group = _groups[groupId];
    if (group != null) {
      final updatedMemberIds = List<String>.from(group.memberIds)..remove(currentUserId);
      final updatedGroup = Group(
        id: group.id,
        name: group.name,
        adminId: group.adminId,
        memberIds: updatedMemberIds,
        createdAt: group.createdAt,
      );

      _groups[groupId] = updatedGroup;
      _saveGroupsData();

      _groupMessages[groupId]?.clear();
      _saveGroupMessages();

      _sendToGroupMembers(groupId, 'GROUP_UPDATE:${jsonEncode({
        'type': 'LEAVE_GROUP',
        'groupId': groupId,
        'userId': currentUserId,
      })}');
    }
  }

  // مسح جميع رسائل المحادثة مع مستخدم معين
  Future<void> clearChatMessages(String userId) async {
    final currentUserId = _currentUser?.id;
    if (currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('messages_${currentUserId}_$userId');
    await prefs.remove('messages_${userId}_$currentUserId');

    _broadcastMessage({
      'type': 'clear_messages',
      'sender_id': currentUserId,
      'receiver_id': userId,
    });
  }

  // حذف ملف من مجموعة
  Future<void> deleteGroupFileMessage(String groupId, String messageId) async {
    _fileMessages[groupId]?.removeWhere((msg) => msg.id == messageId);
    _saveFileMessages();

    final deleteSignal = {
      'type': 'DELETE_GROUP_FILE',
      'groupId': groupId,
      'messageId': messageId,
      'senderId': _currentUser?.id ?? '',
    };
    _sendToGroupMembers(groupId, 'FILE_TRANSFER:${jsonEncode(deleteSignal)}\n');
  }

  // --- معالجة استقبال الملفات ---
  void _handleFileTransfer(Map<String, dynamic> data) async {
    final type = data['type'] as String;

    // **الإصلاح**: استخلاص معرّف الرسالة بطريقة موحدة وآمنة
    // هذا يضمن أننا نحصل دائماً على المعرّف سواء كانت الرسالة من نوع START أو CHUNK أو END.
    String? messageId;
    if (data.containsKey('messageId')) {
      messageId = data['messageId'] as String?;
    } else if (data.containsKey('message') && data['message'] is Map) {
      messageId = (data['message'] as Map)['id'] as String?;
    }

    if (messageId == null) {
      LogService.e('❌ File transfer message received without a valid messageId.');
      return;
    }

    if (type == 'FILE_START') {
      try {
        final fileMessage = FileMessage.fromJson(data['message']);
        final directory = await getApplicationDocumentsDirectory();
        final filesDir = Directory('${directory.path}/files');
        if (!await filesDir.exists()) await filesDir.create(recursive: true);

        final tempPath = '${filesDir.path}/temp_${fileMessage.id}';
        final tempFile = File(tempPath);
        if (await tempFile.exists()) await tempFile.delete();

        final sink = tempFile.openWrite();
        _incomingFileTransfers[fileMessage.id] = _FileTransferState(
          message: fileMessage,
          tempPath: tempPath,
          fileSink: sink,
        );
        final pendingChunks = _pendingFileChunks.remove(fileMessage.id);
        if (pendingChunks != null && pendingChunks.isNotEmpty) {
          for (final chunk in pendingChunks) {
            sink.add(chunk);
          }
          LogService.i('📦 صُرفت ${pendingChunks.length} قطع مبكرة للرسالة ${fileMessage.id}');
        }
        if (_pendingFileEnds.remove(fileMessage.id) == true) {
          LogService.i('📦 إكمال نقل وصلته نهايته مبكراً: ${fileMessage.id}');
          await _completeIncomingFileTransfer(fileMessage.id);
        }
        LogService.i('📥 بدء استقبال الملف: ${fileMessage.fileName} (msgId=${fileMessage.id}, temp=$tempPath, size=${fileMessage.fileSize})');
      } catch (e) {
        LogService.e('❌ خطأ في بدء استقبال الملف: $e');
      }
    } else if (type == 'DELETE_GROUP_FILE') {
      final groupId = data['groupId'] as String;
      final messageId = data['messageId'] as String;
      _fileMessages[groupId]?.removeWhere((msg) => msg.id == messageId);
      _saveFileMessages();

    } else if (type == 'FILE_CHUNK') {
      final state = _incomingFileTransfers[messageId];
      if (state != null) {
        try {
          final chunk = base64Decode(data['chunk'] as String);
          state.fileSink.add(chunk);
          LogService.i('DEBUG _handleFileTransfer: FILE_CHUNK msgId=$messageId bytes=${chunk.length}');
        } catch (e) {
          LogService.e('❌ خطأ في كتابة حزمة الملف: $e');
          await state.fileSink.close().catchError((_) {});
          _incomingFileTransfers.remove(messageId);
        }
      } else {
        try {
          final chunk = base64Decode(data['chunk'] as String);
          _pendingFileChunks.putIfAbsent(messageId, () => []).add(chunk);
          LogService.w('DEBUG _handleFileTransfer: FILE_CHUNK msgId=$messageId buffered (START pending), bytes=${chunk.length}');
        } catch (e) {
          LogService.e('❌ خطأ في تخزين قطعة مبكرة: $e');
        }
      }
    } else if (type == 'FILE_END') {
      final state = _incomingFileTransfers[messageId];
      if (state != null) {
        await _completeIncomingFileTransfer(messageId);
      } else {
        _pendingFileEnds[messageId] = true;
        LogService.w('DEBUG _handleFileTransfer: FILE_END msgId=$messageId deferred (START pending)');
      }
    }
  }

  Future<void> _completeIncomingFileTransfer(String messageId) async {
    final state = _incomingFileTransfers[messageId];
    if (state == null) return;
    try {
      await state.fileSink.close();
      final tempFile = File(state.tempPath);
      final finalPath = '${(await getApplicationDocumentsDirectory()).path}/files/${state.message.id}_${state.message.fileName}';
      await tempFile.rename(finalPath);
      final savedFile = File(finalPath);
      LogService.i('DEBUG _handleFileTransfer: FILE_END msgId=$messageId -> saved to $finalPath size=${await savedFile.length()}');

      final completedFileMessage = state.message..filePath = finalPath;
      final conversationKey = completedFileMessage.groupId ?? completedFileMessage.senderId;

      final existingList = _fileMessages[conversationKey];
      if (existingList == null || !existingList.any((m) => m.id == completedFileMessage.id)) {
        _fileMessages.putIfAbsent(conversationKey, () => []).add(completedFileMessage);
      }
      _saveFileMessages();
      onFileMessageReceived?.call(completedFileMessage);
      LogService.i('✅ اكتمل استقبال الملف: ${completedFileMessage.fileName}');

      final senderSocket = _userSockets[completedFileMessage.senderId];
      if (senderSocket != null) {
        _safeWrite(senderSocket, 'FILE_ACK:${jsonEncode({'messageId': completedFileMessage.id})}\n');
        LogService.i('DEBUG _handleFileTransfer: FILE_ACK sent for ${completedFileMessage.id}');
      }
    } catch (e) {
      LogService.e('❌ خطأ في إنهاء استقبال الملف: $e');
    } finally {
      _incomingFileTransfers.remove(messageId);
    }
  }
}

// كلاس مساعد لتتبع حالة نقل الملفات الواردة
class _FileTransferState {
  final FileMessage message;
  final String tempPath;
  final IOSink fileSink;

  _FileTransferState({required this.message, required this.tempPath, required this.fileSink});
}
