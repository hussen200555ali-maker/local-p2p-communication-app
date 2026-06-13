// استيراد الحزم الأساسية والمكتبات الضرورية
import 'dart:async'; // للتعامل مع العمليات غير المتزامنة والمؤقتات (Timers)
import 'dart:convert'; // لتحويل البيانات من وإلى صيغة JSON
import 'dart:io'; // للتعامل مع الشبكات (Sockets) والملفات
import 'package:flutter/material.dart'; // لاستخدام `debugPrint` وأدوات فلاتر الأساسية
import 'package:network_info_plus/network_info_plus.dart'; // للحصول على معلومات الشبكة مثل IP
import 'package:path_provider/path_provider.dart'; // للحصول على مسارات تخزين الملفات في الجهاز
import 'package:shared_preferences/shared_preferences.dart'; // لتخزين البيانات البسيطة بشكل دائم
import 'package:uuid/uuid.dart'; // لإنشاء معرفات فريدة عالمية (UUIDs)

import 'system_notification_service.dart'; // استيراد خدمة الإشعارات الحقيقية
import 'encryption_service.dart'; // استيراد خدمة التشفير

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
  ServerSocket? _serverSocket;
  Timer? _announcementTimer;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  // --- Data Directories & State ---
  final Map<String, String> _ipDirectory = {};
  final Map<String, String> _userDirectory = {};
  final Map<String, Socket> _userSockets = {};
  final List<String> _friendIds = [];
  final Map<String, List<Message>> _allMessages = {};
  List<User> _discoveredUsers = [];
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

  // --- File Transfer State ---
  final Map<String, _FileTransferState> _incomingFileTransfers = {};

  // --- Settings ---
  bool _showOnlineStatus = true;
  bool _readReceipts = true;

  // --- Call Management ---
  final Map<String, CallModel> _activeCalls = {};
  final Map<String, Timer> _callTimers = {};
  CallHistory _callHistory = CallHistory(calls: []);

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
  Function(CallModel)? onIncomingCall;
  Function(CallModel)? onCallStatusChanged;
  Function(String)? onCallEnded;
  Function(String, Map<String, dynamic>)? onCallSignalReceived;

  // --- Queue Callbacks ---
  Function(String, DeliveryStatus)? onMessageDeliveryStatusChanged;
  VoidCallback? onQueueChanged;

  // --- Lifecycle State ---
  bool _isServiceRunning = false;

  // --- Public Getters ---
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
    debugPrint("🚀 Starting LocalNetworkService...");
    await EncryptionService().init();
    _currentUser = user;
    await _loadDataFromStorage();
    await _dbService.resetStuckPendingMessages();
    await _queueService.loadPendingIntoMemory();
    await _startDiscoveryListener();
    await _startMainServer();
    _startAnnouncing();
    _startReconnectScheduler();
    _startHeartbeatSystem();
    updateUserStatus(true);

    // فوراً بمحاولة إعادة الاتصال بجميع الأصدقاء عند بدء التشغيل
    _reconnectToAllFriends();

    debugPrint("✅ LocalNetworkService started successfully.");
  }

  Future<void> stop() async {
    if (!_isServiceRunning) return;
    _isServiceRunning = false;
    debugPrint("🛑 Stopping LocalNetworkService...");
    _announcementTimer?.cancel();
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _callSignalDrainTimer?.cancel();
    _broadcastSocket?.close();
    await _serverSocket?.close();
    // Create a copy of the sockets to avoid concurrent modification
    final socketsToClose = List<Socket>.from(_userSockets.values);
    socketsToClose.forEach(_safeSocketClose);
    _userSockets.clear();
    if (_currentUser != null) updateUserStatus(false);
    onFriendsChanged?.call();
    debugPrint("🗑️ LocalNetworkService stopped.");
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
  // ...
  Function(String, String, String)? onMessageEdited, // conversationId, messageId, newContent
// ...
    Function(String, String, String)? onGroupMessageEdited,
    Function(String, String)? onGroupMessageDeleted,
  Function(User, dynamic)? onConnectionRequestReceived,
  Function(String, String)? onMessageDeleted,
    // --- Call Callbacks ---
    Function(CallModel)? onIncomingCall,
    Function(CallModel)? onCallStatusChanged,
    Function(String)? onCallEnded,
    Function(String, Map<String, dynamic>)? onCallSignalReceived,
    // --- Queue Callbacks ---
    Function(String, DeliveryStatus)? onMessageDeliveryStatusChanged,
    VoidCallback? onQueueChanged,
  }) {
    this.onFriendsChanged = onFriendsChanged;
    this.onDiscoveryChanged = onDiscoveryChanged;
    this.onGroupsChanged = onGroupsChanged;
    this.onNotificationsChanged = onNotificationsChanged;
    this.onStatusChanged = onStatusChanged;
    this.onPrivateMessageReceived = onPrivateMessageReceived;
    this.onGroupMessageReceived = onGroupMessageReceived;
    this.onFileMessageReceived = onFileMessageReceived;
    this.onConnectionRequestReceived = onConnectionRequestReceived;
    this.onMessageDeleted = onMessageDeleted;
    this.onGroupMessageEdited = onGroupMessageEdited;
    this.onGroupMessageDeleted = onGroupMessageDeleted;
    
    // --- Call Callbacks Registration ---
    this.onIncomingCall = onIncomingCall;
    this.onCallStatusChanged = onCallStatusChanged;
    this.onCallEnded = onCallEnded;
    this.onCallSignalReceived = onCallSignalReceived;

    // --- Queue Callbacks ---
    this.onMessageDeliveryStatusChanged = onMessageDeliveryStatusChanged;
    this.onQueueChanged = onQueueChanged;
    _queueService.onQueueChanged = () {
      this.onQueueChanged?.call();
    };
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
    onIncomingCall = null;
    onCallStatusChanged = null;
    onCallEnded = null;
    onCallSignalReceived = null;

    // --- Queue Callbacks ---
    onMessageDeliveryStatusChanged = null;
    onQueueChanged = null;
    _queueService.onQueueChanged = null;
  }

  // --- Networking Logic ---
  Future<String?> getWifiIP() async {
    try {
      String? ip = await _networkInfo.getWifiIP();
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
    try {
      _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8081);
      _broadcastSocket!.broadcastEnabled = true;
      _broadcastSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _broadcastSocket!.receive();
          if (datagram != null) _handleDiscoveryMessage(utf8.decode(datagram.data));
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

  void _startAnnouncing() {
    _announcementTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_currentUser == null) return;
      final currentIp = await getWifiIP();
      if (currentIp == null) return;
      final announcement = {'id': _currentUser!.id, 'username': _currentUser!.username, 'ip': currentIp};
      final payload = 'DISCOVER:${jsonEncode(announcement)}';
      try {
        _broadcastSocket?.send(utf8.encode(payload), InternetAddress("255.255.255.255"), 8081);
      } catch (e) { /* Ignore */ }
    });
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
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      try {
        _broadcastSocket?.send(
          utf8.encode('PING:${_currentUser?.id ?? "unknown"}\n'),
          InternetAddress("255.255.255.255"),
          8081,
        );
      } catch (e) { /* Ignore */ }
    });
    _callSignalDrainTimer?.cancel();
    _callSignalDrainTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _drainAllPendingCallSignals();
    });
  }

  void _drainAllPendingCallSignals() {
    final userIds = List<String>.from(_pendingCallSignals.keys);
    for (final userId in userIds) {
      final signals = _pendingCallSignals[userId];
      if (signals == null || signals.isEmpty) continue;
      final socket = _userSockets[userId];
      if (socket != null) {
        _drainPendingCallSignals(userId, socket);
      }
    }
  }

  // --- Message Handlers ---
  void _handleDiscoveryMessage(String message) {
    final trimmed = message.trim();
    if (trimmed.startsWith('PING:')) {
      final userId = trimmed.substring(5);
      if (userId == _currentUser?.id) return;
      try {
        _broadcastSocket?.send(
          utf8.encode('PONG:${_currentUser?.id ?? "unknown"}\n'),
          InternetAddress("255.255.255.255"),
          8081,
        );
      } catch (e) { /* Ignore */ }
      return;
    }
    if (trimmed.startsWith('PONG:')) {
      return;
    }
    if (!message.startsWith('DISCOVER:')) return;
    try {
      final data = jsonDecode(message.substring(9));
      final String id = data['id'];
      if (id == _currentUser?.id) return;
      final String ip = _convertArabicNumbers(data['ip']);
      final String username = data['username'];
      _ipDirectory[id] = ip;
      if (_userDirectory[id] != username) {
        _userDirectory[id] = username;
        _saveFriendsAndDirectory();
      }
      if (_friendIds.contains(id) && !_userSockets.containsKey(id)) {
        _improvedReconnectToFriend(id);
      }
      if (!_friendIds.contains(id) && !_discoveredUsers.any((u) => u.id == id)) {
        _discoveredUsers.add(User(id: id, username: username));
        onDiscoveryChanged?.call();
      }
    } catch (e) { /* Ignore */ }
  }

  void _handleIncomingConnection(Socket socket) => _setupSocket(socket);

  void _handleTcpMessage(String message, Socket socket) {
    try {
      if (message.startsWith('MSG:')) {
        final msg = Message.fromJson(jsonDecode(message.substring(4)));
        msg.content = EncryptionService().decryptText(msg.content);
        if (!_queueService.isRecentlySent(msg.id)) {
          _dbService.insertMessage(msg);
          _allMessages.putIfAbsent(msg.senderId, () => []).add(msg);
          _saveAllMessages();
          onPrivateMessageReceived?.call(msg);
        }
        try { socket.write('MSG_ACK:${jsonEncode({"messageId": msg.id, "timestamp": DateTime.now().toUtc().toIso8601String()})}\n'); } catch (_) {}
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
        socket.write('FINALIZE_CONNECTION:${jsonEncode(_currentUser!.toJson())}\n');
      } else if (message.startsWith('FINALIZE_CONNECTION:')) {
        final user = User.fromJson(jsonDecode(message.substring(20)));
        _finalizeConnection(user, socket);
      } else if (message.startsWith('RECONNECT:')) {
        final user = User.fromJson(jsonDecode(message.substring(10)));
        _finalizeConnection(user, socket);
        socket.write('RECONNECT_ACK:${jsonEncode(_currentUser!.toJson())}\n');
        _reconnectCounters.remove(user.id);
        _reconnectAttempts.remove(user.id);
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
        _handleCallSignal(jsonDecode(message.substring(12)));
      } else if (message == 'PING') {
        try { socket.write('PONG\n'); } catch (_) {}
      } else if (message == 'PONG') {
        // heartbeat من الطرف الآخر — لا إجراء مطلوب
      } else if (message.startsWith('MSG_ACK:')) {
        final data = jsonDecode(message.substring(8));
        _queueService.handleAck(data['messageId']);
        onMessageDeliveryStatusChanged?.call(data['messageId'], DeliveryStatus.sent);
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
      }


    }

    catch (e) {
      debugPrint('Handle TCP Error: $e on message: $message');
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
    if (!_userSockets.containsKey(user.id)) {
      _userSockets[user.id] = socket;
      if (!_friendIds.contains(user.id)) _friendIds.add(user.id);
      _userDirectory[user.id] = user.username;
      _discoveredUsers.removeWhere((u) => u.id == user.id);
      _saveFriendsAndDirectory();
      onFriendsChanged?.call();
      onDiscoveryChanged?.call();
      debugPrint("✅ Finalized connection with ${user.username}");
    }
    _flushPendingQueue(user.id, socket);
    _drainPendingCallSignals(user.id, socket);
  }

  void _drainPendingCallSignals(String userId, Socket socket) {
    final signals = _pendingCallSignals[userId];
    if (signals == null || signals.isEmpty) return;
    final drained = _pendingCallSignals.remove(userId);
    if (drained != null) {
      for (int i = 0; i < drained.length; i++) {
        try {
          socket.write('CALL_SIGNAL:${jsonEncode(drained[i])}\n');
        } catch (e) {
          debugPrint("Failed to drain call signal for $userId: $e");
          final remaining = drained.sublist(i);
          _pendingCallSignals.putIfAbsent(userId, () => []).insertAll(0, remaining);
          _removeSocket(socket);
          return;
        }
      }
    }
  }

  Future<void> _flushPendingQueue(String peerId, Socket socket) async {
    final count = await _queueService.flushQueue(peerId, socket, (text) => EncryptionService().encryptText(text));
    if (count > 0) {
      debugPrint("📤 Flushed $count pending messages to $peerId");
    }
  }

  void _removeSocket(Socket socket) {
    String? userIdToRemove;
    _userSockets.forEach((id, s) {
      if (s == socket) userIdToRemove = id;
    });
    if (userIdToRemove != null) {
      _userSockets.remove(userIdToRemove);
      onFriendsChanged?.call();
      debugPrint("🔌 Socket removed for $userIdToRemove");
    }
    _safeSocketClose(socket);
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
        debugPrint('Socket Error: $e');
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
        debugPrint("🔌 Socket onDone (remote closed) for ${friendId ?? 'unknown'}");
        _removeSocket(socket);
      },
      onError: (e) {
        debugPrint("🔌 Socket onError for ${friendId ?? 'unknown'}: $e");
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
    try {
      final socket = await Socket.connect(targetIp, 8080, timeout: const Duration(seconds: 5));
      _setupSocket(socket);
      socket.write('RECONNECT:${jsonEncode(_currentUser!.toJson())}\n');
    } catch (e) {
      _userSockets.remove(friendId);
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
      socket.write('CONNECT_REQUEST:${jsonEncode(_currentUser!.toJson())}\n');
    } catch (e) { /* Handle error */ }
  }

  void acceptConnectionRequest(User requestingUser, Socket socket) {
    socket.write('CONNECT_ACCEPT:${jsonEncode(_currentUser!.toJson())}\n');
    _finalizeConnection(requestingUser, socket);
  }

  void rejectConnectionRequest(Socket socket) => _safeSocketClose(socket);

  void sendMessage(Message message) {
    final socket = _userSockets[message.receiverId];
    if (socket != null) {
      try {
        final json = message.toJson();
        json['content'] = EncryptionService().encryptText(message.content);
        socket.write('MSG:${jsonEncode(json)}\n');
        _dbService.insertMessage(message);
        _allMessages.putIfAbsent(message.receiverId, () => []).add(message);
        _saveAllMessages();
        _queueService.markSentSilent(message.id);
        onPrivateMessageReceived?.call(message);
      } catch (e) {
        _removeSocket(socket);
      }
    } else {
      _enqueueMessage(message, 'text');
    }
  }

  void _enqueueMessage(Message message, String messageType, {String? groupId, String? fileMetadata}) {
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
    onPrivateMessageReceived?.call(message);
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
          socket.write(message);
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
      debugPrint('❌ Error enqueuing group message for offline member $memberId: $e');
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
  Future<void> sendFileMessage(String receiverId, File file, String fileType, {String? groupId}) async {
    if (_currentUser == null) return;

    final socket = _userSockets[receiverId];
    if (socket == null) {
      final messageId = const Uuid().v4();
      final localPath = await _saveFileLocally(await file.readAsBytes(), '${messageId}_${file.path.split('/').last}');
      final msg = Message(
        id: messageId,
        senderId: _currentUser!.id,
        receiverId: receiverId,
        content: '[ملف] ${file.path.split('/').last}',
        timestamp: DateTime.now(),
      );
      final fileMetadata = jsonEncode({
        'fileName': file.path.split('/').last,
        'fileType': fileType,
        'fileSize': await file.length(),
        'filePath': localPath,
      });
      _enqueueMessage(msg, 'file', fileMetadata: fileMetadata);
      return;
    }

    try {
      final fileName = file.path.split('/').last;
      final fileSizeBytes = await file.length();
      final messageId = const Uuid().v4();

      // حفظ نسخة محلية للمرسل لعرضها فوراً
      final localPath = await _saveFileLocally(await file.readAsBytes(), '${messageId}_$fileName');
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

      // 1. إرسال رسالة بدء نقل الملف مع البيانات الوصفية
      final startData = {
        'type': 'FILE_START',
        'message': fileMessage.toJson(),
      };
      socket.write('FILE_TRANSFER:${jsonEncode(startData)}\n');

      // 2. بث الملف على شكل حزم
      const chunkSize = 32 * 1024; // حزم بحجم 32 كيلوبايت
      final stream = file.openRead();
      await for (var chunk in stream) {
        final chunkData = {
          'type': 'FILE_CHUNK',
          'messageId': messageId,
          'chunk': base64Encode(chunk),
        };
        socket.write('FILE_TRANSFER:${jsonEncode(chunkData)}\n');
        // **الإصلاح**: انتظار تفريغ المخزن المؤقت للشبكة لضمان إرسال الحزمة
        // هذا يوفر تحكماً أفضل في التدفق ويمنع إغراق الشبكة.
        await socket.flush();
      }

      // 3. إرسال رسالة انتهاء نقل الملف
      final endData = {
        'type': 'FILE_END',
        'messageId': messageId,
      };
      socket.write('FILE_TRANSFER:${jsonEncode(endData)}\n');

      // إضافة الرسالة لواجهة المرسل فوراً
      final fileKey = groupId ?? receiverId;
      _fileMessages.putIfAbsent(fileKey, () => []).add(fileMessage);
      _saveFileMessages();
      onFileMessageReceived?.call(fileMessage);

    } catch (e) {
      debugPrint('❌ خطأ أثناء إرسال الملف إلى $receiverId: $e');
      _removeSocket(socket);
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
      try {
        socket.write('UNFRIEND:${jsonEncode(_currentUser!.toJson())}\n');
      } catch (e) { /* Ignore */ }
      _removeSocket(socket);
    }
    _removeFriend(friendId);
  }

  void _removeFriend(String friendId) {
    _friendIds.remove(friendId);
    _userDirectory.remove(friendId);
    _allMessages.remove(friendId);
    _ipDirectory.remove(friendId);
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
    final payload = 'DISCOVER:${jsonEncode(statusMessage)}';
    try {
      _broadcastSocket?.send(utf8.encode(payload), InternetAddress("255.255.255.255"), 8081);
    } catch (e) { /* Ignore */ }
  }

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    _saveNotifications();
    onNotificationsChanged?.call();

    // عرض إشعار حقيقي في شريط الإشعارات
    SystemNotificationService().showNotification(
      title: notification.title,
      body: notification.body,
      type: notification.type,
      payload: notification.id,
    );
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
    // Clear old data
    _friendIds.clear();
    _userDirectory.clear();
    _allMessages.clear();
    _groups.clear();
    _groupMessages.clear();
    _fileMessages.clear();
    _userGroups.clear();
    _userStatuses.clear();
    _notifications.clear();

    // Load friends and directory
    _friendIds.addAll(prefs.getStringList('friend_ids_v3') ?? []);
    final dirStr = prefs.getString('user_directory_v3');
    if (dirStr != null) (jsonDecode(dirStr) as Map<String, dynamic>).forEach((k, v) => _userDirectory[k] = v);

    final allMessagesString = prefs.getString('all_messages_v3');
    if (allMessagesString != null) {
      final allMessagesJson = jsonDecode(allMessagesString) as Map<String, dynamic>;
      allMessagesJson.forEach((key, value) {
        _allMessages[key] = (jsonDecode(value) as List).map((item) => Message.fromJson(item)).toList();
      });
    }

    // Load groups
    final groupsString = prefs.getString('user_groups_v1');
    if (groupsString != null) {
      final groupsJson = jsonDecode(groupsString) as Map<String, dynamic>;
      groupsJson.forEach((key, value) => _groups[key] = Group.fromJson(jsonDecode(value)));
    }

    // Load user groups mapping
    final userGroupsString = prefs.getString('user_groups_mapping_v1');
    if (userGroupsString != null) {
      final userGroupsJson = jsonDecode(userGroupsString) as Map<String, dynamic>;
      userGroupsJson.forEach((key, value) => _userGroups[key] = List<String>.from(value));
    }

    // Load group messages
    final groupMessagesString = prefs.getString('group_messages_v1');
    if (groupMessagesString != null) {
      final groupMessagesJson = jsonDecode(groupMessagesString) as Map<String, dynamic>;
      groupMessagesJson.forEach((key, value) => _groupMessages[key] = (jsonDecode(value) as List).map((item) => GroupMessage.fromJson(item)).toList());
    }

    // Load file messages
    final fileMessagesString = prefs.getString('file_messages_v1');
    if (fileMessagesString != null) {
      final fileMessagesJson = jsonDecode(fileMessagesString) as Map<String, dynamic>;
      fileMessagesJson.forEach((key, value) => _fileMessages[key] = (jsonDecode(value) as List).map((item) => FileMessage.fromJson(item)).toList());
    }

    // Load user statuses
    final statusesString = prefs.getString('user_statuses_v1');
    if (statusesString != null) {
      final statusesJson = jsonDecode(statusesString) as Map<String, dynamic>;
      statusesJson.forEach((key, value) => _userStatuses[key] = UserStatus.fromJson(jsonDecode(value)));
    }

    // Load notifications
    final notificationsString = prefs.getString('notifications_v1');
    if (notificationsString != null) {
      final notificationsJson = jsonDecode(notificationsString) as List;
      _notifications.addAll(notificationsJson.map((json) => AppNotification.fromJson(json)).toList());
    }
    
    // Load call history
    final callHistoryString = prefs.getString('call_history_v1');
    if (callHistoryString != null) {
      _callHistory = CallHistory.fromJson(jsonDecode(callHistoryString));
    }

    // Load privacy settings
    _showOnlineStatus = prefs.getBool('show_online_status') ?? true;
    _readReceipts = prefs.getBool('read_receipts') ?? true;
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
      try {
        socket.write('$message\n'); // إضافة \n لضمان فصل الرسائل
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

  void _broadcastMessage(Map<String, dynamic> message) {
    _sendBroadcastMessage(message);
  }

  // --- Call Functions ---

  // بدء مكالمة جديدة
  Future<void> startCall(String receiverId, CallType callType) async {
    if (_currentUser == null) return;
    
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
  void _endCall(String callId) {
    final call = _activeCalls[callId];
    if (call != null) {
      // إضافة المكالمة إلى السجل
      _callHistory.addCall(call);
      _saveCallHistory();
      
      // إزالة المكالمة من قائمة المكالمات النشطة
      _activeCalls.remove(callId);
    }
  }

  // إرسال إشارة مكالمة إلى مستخدم
  void _sendCallSignal(String userId, Map<String, dynamic> signal) {
    final socket = _userSockets[userId];
    if (socket != null) {
      try {
        socket.write('CALL_SIGNAL:${jsonEncode(signal)}\n');
      } catch (e) {
        _removeSocket(socket);
      }
      if (!_userSockets.containsKey(userId)) {
        _pendingCallSignals.putIfAbsent(userId, () => []).add(signal);
      }
    } else {
      _pendingCallSignals.putIfAbsent(userId, () => []).add(signal);
    }
  }

  // التعامل مع إشارات المكالمات الواردة
  void _handleCallSignal(Map<String, dynamic> signal) {
    final type = signal['type'];
    
    switch (type) {
      case 'call_request':
        _handleIncomingCall(signal);
        break;
      case 'call_accepted':
        _handleCallAccepted(signal['callId']);
        break;
      case 'call_rejected':
        _handleCallRejected(signal['callId']);
        break;
      case 'call_ended':
        _handleCallEndedByRemote(signal['callId']);
        break;
      case 'call_signal':
        // إشارات WebRTC
        onCallSignalReceived?.call(signal['callId'], signal);
        break;
      default:
        onCallSignalReceived?.call(signal['callId'], signal);
        break;
    }
  }

  // التعامل مع مكالمة واردة
  void _handleIncomingCall(Map<String, dynamic> signal) {
    final callId = signal['callId'];
    final callerId = signal['callerId'];
    final callType = CallType.values.firstWhere((e) => e.name == signal['callType']);
    
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
    
    // بدء مؤقت انتظار الرد
    _callTimers[callId] = Timer(const Duration(seconds: 30), () {
      _handleCallTimeout(callId);
    });
    
    // إعلام الواجهة المحلية بالمكالمة الواردة
    onIncomingCall?.call(call);
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
      'type': 'call_signal',
      'callId': callId,
      ...signal,
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
    await prefs.setString('groups', jsonEncode(groupsJson));
  }

  // الحصول على مستخدم بواسطة المعرف
  User? getUserById(String userId) {
    try {
      return _discoveredUsers.firstWhere((user) => user.id == userId);
    } catch (e) {
      if (_userDirectory.containsKey(userId)) {
        return User(id: userId, username: _userDirectory[userId]!);
      }
      return null;
    }
  }

  // مغادرة مجموعة
  Future<void> leaveGroup(String groupId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('current_user_id');

    if (currentUserId != null) {
      // إزالة المستخدم من قائمة أعضاء المجموعة
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
        _saveGroups();

        // حذف رسائل المجموعة
        _groupMessages[groupId]?.clear();
        _saveGroupMessages();

        // إعلام الأعضاء الآخرين
        _sendToGroupMembers(groupId, 'GROUP_UPDATE:${jsonEncode({
          'type': 'LEAVE_GROUP',
          'groupId': groupId,
          'userId': currentUserId,
        })}');
      }
    }
  }

  // مسح جميع رسائل المحادثة مع مستخدم معين
  Future<void> clearChatMessages(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('current_user_id');

    if (currentUserId != null) {
      await prefs.remove('messages_${currentUserId}_$userId');
      await prefs.remove('messages_${userId}_$currentUserId');

      // إعلام الأجهزة الأخرى بمسح الرسائل
      _broadcastMessage({
        'type': 'clear_messages',
        'sender_id': currentUserId,
        'receiver_id': userId,
      });
    }
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

  void sendPrivateMessage(String id, String jsonEncode) {}

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
      debugPrint('❌ File transfer message received without a valid messageId.');
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
        debugPrint('📥 بدء استقبال الملف: ${fileMessage.fileName}');
      } catch (e) {
        debugPrint('❌ خطأ في بدء استقبال الملف: $e');
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
        } catch (e) {
          debugPrint('❌ خطأ في كتابة حزمة الملف: $e');
          await state.fileSink.close().catchError((_) {});
          _incomingFileTransfers.remove(messageId);
        }
      }
    } else if (type == 'FILE_END') {
      final state = _incomingFileTransfers[messageId];
      if (state != null) {
        try {
          await state.fileSink.close();
          final tempFile = File(state.tempPath);
          final finalPath = '${(await getApplicationDocumentsDirectory()).path}/files/${state.message.id}_${state.message.fileName}';
          await tempFile.rename(finalPath);

          final completedFileMessage = state.message..filePath = finalPath;
          final conversationKey = completedFileMessage.groupId ?? completedFileMessage.senderId;

          _fileMessages.putIfAbsent(conversationKey, () => []).add(completedFileMessage);
          _saveFileMessages();
          onFileMessageReceived?.call(completedFileMessage);
          debugPrint('✅ اكتمل استقبال الملف: ${completedFileMessage.fileName}');
        } catch (e) {
          debugPrint('❌ خطأ في إنهاء استقبال الملف: $e');
        } finally {
          _incomingFileTransfers.remove(messageId);
        }
      }
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
