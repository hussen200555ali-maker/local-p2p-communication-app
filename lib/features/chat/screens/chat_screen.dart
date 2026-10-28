import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import '../../../core/services/local_network_service.dart';
import '../../auth/models/user_model.dart';
import '../../call/call_integration.dart';
import '../../call/models/call_model.dart';
import '../models/message_model.dart';
import '../models/file_message_model.dart';
import '../models/pending_message_model.dart';

class ChatScreen extends StatefulWidget {
  final User friend;
  const ChatScreen({super.key, required this.friend});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            final value = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (value < 0.5) ? (value * 2) : (1 - (value - 0.5) * 2);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFF25D366),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final LocalNetworkService _networkService = LocalNetworkService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late User _currentUser;
  final List<dynamic> _messages = [];
  bool _isTyping = false;
  bool _isConnected = false;
  StreamSubscription? _connectionSubscription;
  Timer? _typingTimer;
  final Map<String, DeliveryStatus> _messageStatuses = {};
  dynamic _replyingTo;
  Message? _editingMessage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentUser = _networkService.getCurrentUser()!;
    _loadInitialMessages().then((_) => _scrollToBottom());
    _registerServiceCallbacks();
    _listenToConnectionStatus();
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _typingTimer?.cancel();
    _networkService.unregisterCallbacks();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialMessages() async {
    final textMessages = _networkService.getMessagesForUser(widget.friend.id);
    final fileMessages = _networkService.getFileMessages(widget.friend.id);
    _messages.clear();
    _messages.addAll(textMessages);
    _messages.addAll(fileMessages);
    _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _messageStatuses.clear();
    for (final msg in _messages) {
      if (msg.senderId == _currentUser.id) {
        final status = await _networkService.getMessageStatus(msg.id);
        if (status != null) _messageStatuses[msg.id] = status;
      }
    }
  }

  void _registerServiceCallbacks() {
    _networkService.registerCallbacks(
        onFriendsChanged: () {
          if (mounted) setState(() {});
        },
        onPrivateMessageReceived: (message) {
          if (_isMessageForThisChat(message.senderId, message.receiverId) && mounted) {
            setState(() {
              if (!_messages.any((m) => m is Message && m.id == message.id)) {
                _messages.add(message);
                _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              }
            });
            _scrollToBottom();
          }
        },
        onFileMessageReceived: (fileMessage) {
          if (fileMessage.groupId == null && _isMessageForThisChat(fileMessage.senderId, fileMessage.receiverId) && mounted) {
            setState(() {
              if (!_messages.any((m) => m is FileMessage && m.id == fileMessage.id)) {
                _messages.add(fileMessage);
                _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
              }
            });
            _scrollToBottom();
          }
        },
        onStatusChanged: () {
          if (mounted) {
            final userStatus = _networkService.getUserStatuses()[widget.friend.id];
            if (userStatus != null) {
              setState(() {
                _isTyping = userStatus.isTyping;
              });
            }
          }
        },
        // **الإضافة الجديدة**: التعامل مع الرسائل المحذوفة
        onMessageDeleted: (conversationId, messageId) {
      // التأكد من أن الحذف يخص هذه المحادثة
      if (conversationId == widget.friend.id && mounted) {
        setState(() {
          // إزالة الرسالة من قائمة الواجهة
          _messages.removeWhere((msg) => msg.id == messageId);
        });
      }
    }
    ,

      // **الإضافة الجديدة**: التعامل مع الرسائل المعدلة
      onMessageEdited: (conversationId, messageId, newContent) {
        if (conversationId == widget.friend.id && mounted) {
          setState(() {
            final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
            if (messageIndex != -1) {
              (_messages[messageIndex] as Message).content = newContent;
            }
          });
        }
      },
      onMessageDeliveryStatusChanged: (messageId, status) {
        if (mounted) {
          setState(() {
            _messageStatuses[messageId] = status;
          });
        }
      },
    );
  }



  bool _isMessageForThisChat(String senderId, String receiverId) {
    return (senderId == _currentUser.id && receiverId == widget.friend.id) ||
        (senderId == widget.friend.id && receiverId == _currentUser.id);
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _networkService.sendTypingStatus(widget.friend.id, false);

    if (_editingMessage != null) {
      final messageId = _editingMessage!.id;
      final newContent = content;
      final index = _messages.indexWhere((msg) => msg is Message && msg.id == messageId);
      if (index != -1) {
        setState(() {
          final updatedMessage = Message(
            id: messageId,
            senderId: _editingMessage!.senderId,
            receiverId: _editingMessage!.receiverId,
            content: newContent,
            timestamp: _editingMessage!.timestamp,
            edited: true,
            editedAt: DateTime.now(),
          );
          _messages[index] = updatedMessage;
          _editingMessage = null;
        });
      }
      _networkService.editMessage(widget.friend.id, messageId, newContent);
      _messageController.clear();
      return;
    }

    final message = Message(
      id: const Uuid().v4(),
      senderId: _currentUser.id,
      receiverId: widget.friend.id,
      content: content,
      timestamp: DateTime.now(),
    );
    _networkService.sendMessage(message);
    _messageController.clear();
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _pickAndSendImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source, imageQuality: 85);
      if (image != null) {
        File file = File(image.path);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري إرسال الصورة...')),
        );
        await _networkService.sendFileMessage(widget.friend.id, file, 'image');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء اختيار الصورة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickAndSendFile() async {
    if (!Platform.isWindows && !Platform.isLinux) {
      var status = await Permission.storage.request();

      if (status.isGranted) {
        try {
          FilePickerResult? result = await FilePicker.platform.pickFiles();
          if (result != null && result.files.single.path != null) {
            File file = File(result.files.single.path!);
            String fileType = result.files.single.extension ?? 'file';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('جاري إرسال الملف: ${result.files.single.name}...')),
            );
            await _networkService.sendFileMessage(widget.friend.id, file, fileType);
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('حدث خطأ أثناء اختيار الملف: $e'), backgroundColor: Colors.red),
          );
        }
      } else if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم رفض إذن الوصول للملفات. يرجى التفعيل من الإعدادات.'),
            action: SnackBarAction(
              label: 'الإعدادات',
              onPressed: openAppSettings,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('إذن الوصول للملفات مطلوب لإرسال الملفات.')),
        );
      }
    } else {
      try {
        FilePickerResult? result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.path != null) {
          File file = File(result.files.single.path!);
          String fileType = result.files.single.extension ?? 'file';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('جاري إرسال الملف: ${result.files.single.name}...')),
          );
          await _networkService.sendFileMessage(widget.friend.id, file, fileType);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء اختيار الملف: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _networkService.showOnlineStatus && _networkService.getConnectedFriends().any((u) => u.id == widget.friend.id);
    final isDoubtful = _networkService.isFriendDoubtful(widget.friend.id);

    return Scaffold(
      backgroundColor: const Color(0xFF0B141A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2C33),
        elevation: 0,
        leadingWidth: 70,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: Row(
            children: [
              const SizedBox(width: 6),
              const Icon(Icons.arrow_back, color: Colors.white),
              const SizedBox(width: 2),
              CircleAvatar(
                radius: 18,
                backgroundColor: isDoubtful ? Colors.orange : (isConnected ? const Color(0xFF25D366) : Colors.grey),
                child: Text(
                  widget.friend.username.isNotEmpty
                      ? widget.friend.username.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.friend.username,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 1),
            if (_isTyping)
              Row(
                children: const [
                  _TypingDots(),
                  SizedBox(width: 6),
                  Text(
                    'يكتب',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF25D366),
                    ),
                  ),
                ],
              )
            else if (isDoubtful)
              const Text(
                'جارٍ التحقق...',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              )
            else
              Text(
                isConnected ? 'متصل' : 'غير متصل',
                style: TextStyle(
                  fontSize: 12,
                  color: isConnected ? const Color(0xFF25D366) : Colors.white60,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.call, color: Colors.white),
            onPressed: () => _startCall(CallType.audio),
          ),
          IconButton(
            icon: const Icon(Iconsax.video, color: Colors.white),
            onPressed: () => _startCall(CallType.video),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Iconsax.more, color: Colors.white),
            color: const Color(0xFF1F2C33),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'options') {
                _showChatOptions();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'options',
                child: Row(
                  children: [
                    Icon(Iconsax.more, color: Colors.white),
                    SizedBox(width: 10),
                    Text('خيارات', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0B141A),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isMe = message.senderId == _currentUser.id;

                  DateTime getDate(dynamic m) {
                    if (m is Message) return m.timestamp;
                    if (m is FileMessage) return m.timestamp;
                    return DateTime.now();
                  }

                  bool isSameSender(dynamic a, dynamic b) {
                    if (a is Message && b is Message) return a.senderId == b.senderId;
                    if (a is FileMessage && b is FileMessage) return a.senderId == b.senderId;
                    return false;
                  }

                  final currentDate = getDate(message);
                  bool showDate = false;
                  if (index == 0) {
                    showDate = true;
                  } else {
                    final previousMessage = _messages[index - 1];
                    final previousDate = getDate(previousMessage);
                    showDate = !_isSameDay(currentDate, previousDate);
                  }

                  bool isFirstInGroup = true;
                  bool isLastInGroup = true;
                  if (index > 0 && !showDate) {
                    final previousMessage = _messages[index - 1];
                    final prevDate = getDate(previousMessage);
                    if (_isSameDay(currentDate, prevDate) && isSameSender(message, previousMessage)) {
                      isFirstInGroup = false;
                    }
                  }
                  if (index < _messages.length - 1) {
                    final nextMessage = _messages[index + 1];
                    final nextDate = getDate(nextMessage);
                    if (_isSameDay(currentDate, nextDate) && isSameSender(message, nextMessage)) {
                      isLastInGroup = false;
                    }
                  }

                  Widget bubble;
                  if (message is FileMessage) {
                    bubble = _buildFileMessageBubble(message, isMe, isFirstInGroup: isFirstInGroup, isLastInGroup: isLastInGroup);
                  } else if (message is Message) {
                    bubble = _buildTextMessageBubble(message, isMe, isFirstInGroup: isFirstInGroup, isLastInGroup: isLastInGroup);
                  } else {
                    return const SizedBox.shrink();
                  }

                  if (showDate) {
                    return Column(
                      children: [
                        _buildDateSeparator(currentDate),
                        bubble,
                      ],
                    );
                  }

                  return bubble;
                },
              ),
            ),
          ),
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildTextMessageBubble(Message message, bool isMe, {bool isFirstInGroup = true, bool isLastInGroup = true}) {
    final deliveryStatus = _messageStatuses[message.id];

    final topLeft = (isMe || !isFirstInGroup) ? const Radius.circular(16) : const Radius.circular(4);
    final topRight = (isMe && !isFirstInGroup) ? const Radius.circular(16) : (isMe ? const Radius.circular(4) : const Radius.circular(16));
    final bottomLeft = isMe ? const Radius.circular(16) : (isLastInGroup ? const Radius.circular(16) : const Radius.circular(4));
    final bottomRight = isMe ? (isLastInGroup ? const Radius.circular(16) : const Radius.circular(4)) : const Radius.circular(16);

    return Dismissible(
      key: Key(message.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        _replyToMessage(message);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFF25D366),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.message_reply, color: Colors.white, size: 18),
        ),
      ),
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(message),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              top: isFirstInGroup ? 4 : 2,
              bottom: isLastInGroup ? 6 : 2,
              left: 6,
              right: 6,
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33),
              borderRadius: BorderRadius.only(
                topLeft: topLeft,
                topRight: topRight,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 1),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (message.edited)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          'معدّل',
                          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                        ),
                      ),
                    if (isMe) ...[
                      _buildDeliveryStatusIcon(deliveryStatus, message.read),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryStatusIcon(DeliveryStatus? status, bool read) {
    if (read && _networkService.readReceipts) {
      return const Icon(Icons.done_all, size: 16, color: Color(0xFF53BDEB));
    }
    switch (status) {
      case DeliveryStatus.pending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white60),
        );
      case DeliveryStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white60),
        );
      case DeliveryStatus.sent:
        return Icon(Icons.done, size: 16, color: Colors.white.withOpacity(0.6));
      case DeliveryStatus.failed:
        return const Icon(Icons.error_outline, size: 16, color: Colors.redAccent);
      case null:
        return Icon(Icons.done, size: 16, color: Colors.white.withOpacity(0.6));
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDateLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) return 'اليوم';
    if (date == yesterday) return 'أمس';

    const weekdays = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];

    if (now.difference(dateTime).inDays < 7) {
      return weekdays[dateTime.weekday - 1];
    }

    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  }

  Widget _buildDateSeparator(DateTime dateTime) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2C33),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _getDateLabel(dateTime),
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  String formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  Widget _buildFileIcon(FileMessage message, bool isMe) {
    return Icon(Iconsax.document_1, color: isMe ? Colors.white : Colors.black54, size: 40);
  }

  void _showImagePreview(BuildContext context, String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withOpacity(0.7),
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          body: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(File(filePath), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileMessageBubble(FileMessage message, bool isMe, {bool isFirstInGroup = true, bool isLastInGroup = true}) {
    final bool isImage = message.fileType == 'image' ||
        ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(message.fileType.toLowerCase());

    final topLeft = (isMe || !isFirstInGroup) ? const Radius.circular(16) : const Radius.circular(4);
    final topRight = (isMe && !isFirstInGroup) ? const Radius.circular(16) : (isMe ? const Radius.circular(4) : const Radius.circular(16));
    final bottomLeft = isMe ? const Radius.circular(16) : (isLastInGroup ? const Radius.circular(16) : const Radius.circular(4));
    final bottomRight = isMe ? (isLastInGroup ? const Radius.circular(16) : const Radius.circular(4)) : const Radius.circular(16);

    return Dismissible(
      key: Key(message.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        _replyToMessage(message);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFF25D366),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.message_reply, color: Colors.white, size: 18),
        ),
      ),
      child: GestureDetector(
        onTap: () async {
          if (isImage && File(message.filePath).existsSync()) {
            _showImagePreview(context, message.filePath);
          } else {
            if (!Platform.isLinux) {
              try {
                await OpenFilex.open(message.filePath);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('لا يمكن فتح الملف: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            }
          }
        },
        onLongPress: () => _showMessageOptions(message),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              top: isFirstInGroup ? 4 : 2,
              bottom: isLastInGroup ? 6 : 2,
              left: 6,
              right: 6,
            ),
            padding: const EdgeInsets.all(6),
            width: isImage ? 250 : 235,
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF005C4B) : const Color(0xFF202C33),
              borderRadius: BorderRadius.only(
                topLeft: topLeft,
                topRight: topRight,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isImage && File(message.filePath).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(message.filePath),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: Colors.black26,
                        child: const Center(child: Icon(Iconsax.image, color: Colors.white54, size: 40)),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Iconsax.document_text, color: Colors.white.withOpacity(0.9), size: 28),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.fileName,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatBytes(message.fileSize, 1),
                              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isMe) ...[
                      _buildDeliveryStatusIcon(_messageStatuses[message.id], message.read),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInputField() {
    final isEditing = _editingMessage != null;
    final isReplying = _replyingTo != null;
    String replyPreview = '';
    if (isReplying) {
      if (_replyingTo is Message) {
        replyPreview = (_replyingTo as Message).content;
      } else if (_replyingTo is FileMessage) {
        replyPreview = '📎 ${(_replyingTo as FileMessage).fileName}';
      }
    }

    return Container(
      color: const Color(0xFF1F2C33),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isReplying)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF1F2C33),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3942),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _replyingTo is Message && _replyingTo.senderId == _currentUser.id ? 'رد على نفسك' : (_replyingTo is Message ? widget.friend.username : widget.friend.username),
                              style: const TextStyle(color: Color(0xFF25D366), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              replyPreview,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                      onPressed: _cancelReply,
                    ),
                  ],
                ),
              ),
            if (isEditing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF1F2C33),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3942),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تعديل الرسالة',
                              style: TextStyle(color: Color(0xFF25D366), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _editingMessage!.content,
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                      onPressed: () {
                        setState(() {
                          _editingMessage = null;
                          _messageController.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Iconsax.gallery, color: Colors.white70),
                    onPressed: () => _pickAndSendImage(source: ImageSource.gallery),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.camera, color: Colors.white70),
                    onPressed: () => _pickAndSendImage(source: ImageSource.camera),
                  ),
                  IconButton(
                    icon: const Icon(Iconsax.attach_square, color: Colors.white70),
                    onPressed: _pickAndSendFile,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3942),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _editingMessage != null ? 'عدّل الرسالة...' : 'اكتب رسالة...',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                          border: InputBorder.none,
                        ),
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                        onChanged: (value) {
                          if (_editingMessage != null) return;
                          _networkService.sendTypingStatus(widget.friend.id, value.trim().isNotEmpty);
                          _typingTimer?.cancel();
                          if (value.trim().isNotEmpty) {
                            _typingTimer = Timer(const Duration(seconds: 1), () {
                              if (mounted) {
                                _networkService.sendTypingStatus(widget.friend.id, false);
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(_editingMessage != null ? Icons.check : Iconsax.send_1, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // إضافة قائمة خيارات المحادثة
  void _showChatOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Iconsax.trash, color: Colors.red),
              title: const Text('حذف المحادثة'),
              onTap: () {
                Navigator.of(context).pop();
                _confirmDeleteChat();
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.user_remove, color: Colors.orange),
              title: const Text('إلغاء الصداقة'),
              onTap: () {
                Navigator.of(context).pop();
                _confirmUnfriend();
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.info_circle),
              title: const Text('معلومات الصديق'),
              onTap: () {
                Navigator.of(context).pop();
                _showFriendInfo();
              },
            ),
          ],
        ),
      ),
    );
  }

  // تأكيد حذف المحادثة
  void _confirmDeleteChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المحادثة'),
        content: const Text('هل أنت متأكد من رغبتك في حذف جميع رسائل هذه المحادثة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteChat();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // حذف المحادثة
  void _deleteChat() {
    setState(() {
      _messages.clear();
    });
    // حذف الرسائل من الخدمة
    _networkService.clearChatMessages(widget.friend.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف المحادثة')),
    );
  }

  // تأكيد إلغاء الصداقة
  void _confirmUnfriend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الصداقة'),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء الصداقة مع هذا المستخدم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _unfriend();
            },
            child: const Text('إلغاء الصداقة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // إلغاء الصداقة
  void _unfriend() {
    _networkService.unfriend(widget.friend.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إلغاء الصداقة')),
    );
  }

  // عرض معلومات الصديق
  void _showFriendInfo() {
    final userStatus = _networkService.getUserStatuses()[widget.friend.id];
    final isConnected = _networkService.showOnlineStatus && _networkService.getConnectedFriends().any((u) => u.id == widget.friend.id);
    final isDoubtful = _networkService.isFriendDoubtful(widget.friend.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.friend.username),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isDoubtful ? Colors.orange : (isConnected ? Colors.teal : Colors.grey),
                  child: Text(widget.friend.username.isNotEmpty ? widget.friend.username.substring(0, 1).toUpperCase() : '?'),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDoubtful ? 'جارٍ التحقق...' : (isConnected ? 'متصل الآن' : 'غير متصل'),
                      style: TextStyle(
                        color: isDoubtful ? Colors.orange : (isConnected ? Colors.green : Colors.grey),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (userStatus?.lastSeen != null)
                      Text(
                        'آخر ظهور: ${_formatDateTime(userStatus!.lastSeen!)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('المعرف:'),
            SelectableText(
              widget.friend.id,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // تنسيق التاريخ والوقت
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'الآن';
        }
        return 'منذ ${difference.inMinutes} دقيقة';
      }
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      final time = TimeOfDay.fromDateTime(dateTime);
      return 'الأمس في ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
  // أضف هذه الدالة داخل كلاس _ChatScreenState
/*
  void _showMessageOptions(dynamic message) {
    // التأكد من أن الرسالة ملك للمستخدم الحالي قبل عرض خيارات التعديل والحذف
    final bool isMyMessage = message.senderId == _currentUser.id;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              // لا تعرض خيار الحذف إلا إذا كانت الرسالة ملكك
              if (isMyMessage)
                ListTile(
                  leading: const Icon(Iconsax.trash, color: Colors.red),
                  title: const Text('حذف الرسالة', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop(); // إغلاق الـ BottomSheet
                    _confirmDeleteMessage(message); // استدعاء دالة تأكيد الحذف
                  },
                ),
              // يمكنك إضافة خيارات أخرى هنا مستقبلاً
              // if (isMyMessage && message is Message) // التعديل للرسائل النصية فقط
              //   ListTile(
              //     leading: const Icon(Iconsax.edit),
              //     title: const Text('تعديل الرسالة'),
              //     onTap: () {
              //       Navigator.of(context).pop();
              //       // TODO: Implement edit logic
              //     },
              //   ),
              ListTile(
                leading: const Icon(Iconsax.copy),
                title: const Text('نسخ النص'),
                // لا تعرض خيار النسخ إلا للرسائل النصية
                enabled: message is Message,
                onTap: () {
                  Navigator.of(context).pop();
                  if (message is Message) {
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ النص')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }*/
  void _showMessageOptions(dynamic message) {
    final bool isMyMessage = message.senderId == _currentUser.id;
    final isTextMessage = message is Message;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2C33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (isMyMessage && isTextMessage)
                  ListTile(
                    leading: const Icon(Iconsax.edit, color: Color(0xFF25D366)),
                    title: const Text('تعديل الرسالة', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _editingMessage = message as Message;
                        _messageController.text = (message as Message).content;
                        _replyingTo = null;
                      });
                      FocusScope.of(context).requestFocus(FocusNode());
                      Future.delayed(const Duration(milliseconds: 100), () {
                        FocusScope.of(context).requestFocus(FocusNode());
                      });
                    },
                  ),
                if (isMyMessage)
                  ListTile(
                    leading: const Icon(Iconsax.trash, color: Colors.redAccent),
                    title: const Text('حذف الرسالة', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.of(context).pop();
                      _confirmDeleteMessage(message);
                    },
                  ),
                ListTile(
                  leading: const Icon(Iconsax.message_reply, color: Colors.white70),
                  title: const Text('رد على الرسالة', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _replyToMessage(message);
                  },
                ),
                if (isTextMessage)
                  ListTile(
                    leading: const Icon(Iconsax.copy, color: Colors.white70),
                    title: const Text('نسخ النص', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.of(context).pop();
                      Clipboard.setData(ClipboardData(text: (message as Message).content));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ النص')),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

// أضف هذه الدالة أيضاً داخل _ChatScreenState

  void _confirmDeleteMessage(dynamic message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذه الرسالة؟ سيتم حذفها من كلا الطرفين.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // استدعاء دالة الحذف في الخدمة (سنضيفها في الخطوة التالية)
              _networkService.deleteMessage(widget.friend.id, message.id);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
// أضف هذه الدالة داخل كلاس _ChatScreenState

  void _showEditMessageDialog(Message message) {
    // استخدام Controller لإدارة النص داخل حقل التعديل
    final TextEditingController editController = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الرسالة'),
        content: TextField(
          controller: editController,
          autofocus: true, // التركيز على الحقل تلقائياً
          decoration: const InputDecoration(
            hintText: 'أدخل النص الجديد',
          ),
          maxLines: null, // السماح بعدة أسطر
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                // تحديث الرسالة محلياً
                final updatedMessage = Message(
                  id: message.id,
                  senderId: message.senderId,
                  receiverId: message.receiverId,
                  content: newContent,
                  timestamp: message.timestamp,
                  edited: true,
                  editedAt: DateTime.now(),
                );

                // البحث عن الرسالة وتحديثها
                final index = _messages.indexWhere((msg) => msg.id == message.id);
                if (index != -1) {
                  setState(() {
                    _messages[index] = updatedMessage;
                  });
                }

                // استدعاء دالة التعديل في الخدمة
                _networkService.editMessage(widget.friend.id, message.id, newContent);
              }
              Navigator.of(context).pop();
            },
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
  }

  // الرد على الرسالة
  void _replyToMessage(dynamic message) {
    setState(() {
      _replyingTo = message;
      _editingMessage = null;
    });
    _messageController.clear();
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        FocusScope.of(context).requestFocus();
      }
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  // --- Call Feature Methods ---

  void _listenToConnectionStatus() {
    // التحقق من حالة الاتصال الأولية
    setState(() {
      _isConnected = _networkService.showOnlineStatus && _networkService.getConnectedFriends().any((u) => u.id == widget.friend.id);
    });

    // الاستماع لتغييرات حالة الاتصال
    _connectionSubscription = Stream.periodic(const Duration(seconds: 3), (_) => null)
        .listen((_) {
      final isConnected = _networkService.showOnlineStatus && _networkService.getConnectedFriends().any((u) => u.id == widget.friend.id);
      if (isConnected != _isConnected) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
  }

  void _startCall(CallType callType) async {
    if (!context.mounted) return;
    await CallIntegration().startCall(context, widget.friend, callType);
  }

}
