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

    // إيقاف حالة الكتابة
    _networkService.sendTypingStatus(widget.friend.id, false);

    final message = Message(
      id: const Uuid().v4(), // <-- هنا نستخدم Uuid
      senderId: _currentUser.id,
      receiverId: widget.friend.id,
      content: content,
      timestamp: DateTime.now(),
    );
    _networkService.sendMessage(message);
    _messageController.clear();
  }

  Future<void> _pickAndSendImage() async {
    try {
      final ImagePicker _picker = ImagePicker();
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        File file = File(image.path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري إرسال الصورة...')),
        );
        await _networkService.sendFileMessage(widget.friend.id, file, 'image');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء اختيار الصورة: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickAndSendFile() async {
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _networkService.getConnectedFriends().any((u) => u.id == widget.friend.id) 
                  ? Colors.teal 
                  : Colors.grey,
              child: Text(
                widget.friend.username.isNotEmpty 
                    ? widget.friend.username.substring(0, 1).toUpperCase() 
                    : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.friend.username,
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    _isTyping 
                        ? 'يكتب الآن...' 
                        : (_networkService.getConnectedFriends().any((u) => u.id == widget.friend.id) 
                            ? 'متصل' 
                            : 'غير متصل'),
                    style: TextStyle(
                      fontSize: 12,
                      color: _isTyping 
                          ? Colors.greenAccent 
                          : (_networkService.getConnectedFriends().any((u) => u.id == widget.friend.id) 
                              ? Colors.white70 
                              : Colors.white54),
                      fontStyle: _isTyping ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.call),
            onPressed: () => _startCall(CallType.audio),
          ),
          IconButton(
            icon: const Icon(Iconsax.video),
            onPressed: () => _startCall(CallType.video),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'options') {
                _showChatOptions();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'options',
                child: ListTile(
                  leading: Icon(Iconsax.more),
                  title: Text('خيارات'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(10.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderId == _currentUser.id;
                if (message is FileMessage) {
                  return _buildFileMessageBubble(message, isMe);
                } else if (message is Message) {
                  return _buildTextMessageBubble(message, isMe);
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          _buildMessageInputField(),
        ],
      ),
    );
  }

  Widget _buildTextMessageBubble(Message message, bool isMe) {
    final deliveryStatus = _messageStatuses[message.id];

    return InkWell(
        onLongPress: () => _showMessageOptions(message),
      child: Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0),
        decoration: BoxDecoration(
          color: isMe ? Colors.teal.shade300 : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.content, style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isMe) ...[
                  _buildDeliveryStatusIcon(deliveryStatus, message.read),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateTime(message.timestamp),
                    style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54),
                  ),
                ] else ...[
                  Text(
                    _formatDateTime(message.timestamp),
                    style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    )
    );
  }

  Widget _buildDeliveryStatusIcon(DeliveryStatus? status, bool read) {
    if (read) {
      return Icon(Iconsax.tick_circle2, size: 16, color: Colors.lightBlue.shade200);
    }
    switch (status) {
      case DeliveryStatus.pending:
        return const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
        );
      case DeliveryStatus.sending:
        return const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
        );
      case DeliveryStatus.sent:
        return Icon(Iconsax.message_tick, size: 16, color: Colors.white70);
      case DeliveryStatus.failed:
        return Icon(Iconsax.warning_2, size: 16, color: Colors.red.shade300);
      case null:
        return Icon(Iconsax.message_tick, size: 16, color: Colors.white70);
    }
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
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(filePath), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileMessageBubble(FileMessage message, bool isMe) {
    final bool isImage = message.fileType == 'image' || 
        ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(message.fileType.toLowerCase());

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: () async {
          if (isImage && File(message.filePath).existsSync()) {
            _showImagePreview(context, message.filePath);
          } else {
            try {
              await OpenFilex.open(message.filePath);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('لا يمكن فتح الملف: $e'), backgroundColor: Colors.red),
              );
            }
          }
        },
        onLongPress: () => _showMessageOptions(message),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
          padding: const EdgeInsets.all(12.0),
          width: isImage ? 240 : 220,
          decoration: BoxDecoration(
            color: isMe ? Colors.teal.shade300 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isImage && File(message.filePath).existsSync())
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(message.filePath),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFileIcon(message, isMe),
                  ),
                )
              else
                Row(
                  children: [
                    _buildFileIcon(message, isMe),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(message.fileName, style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(formatBytes(message.fileSize, 1), style: TextStyle(fontSize: 12, color: isMe ? Colors.white70 : Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isMe) ...[
                _buildDeliveryStatusIcon(_messageStatuses[message.id], message.read),
                const SizedBox(width: 4),
                Text(
                  _formatDateTime(message.timestamp),
                  style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54),
                ),
              ] else ...[
                Text(
                  _formatDateTime(message.timestamp),
                  style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54),
                ),
              ],
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _buildMessageInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(offset: const Offset(0, -1), blurRadius: 2, color: Colors.black.withValues(alpha: 0.05))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(Iconsax.gallery, color: Colors.grey), onPressed: _pickAndSendImage),
            IconButton(icon: const Icon(Iconsax.attach_square, color: Colors.grey), onPressed: _pickAndSendFile),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(hintText: 'اكتب رسالتك...', border: InputBorder.none),
                onSubmitted: (_) => _sendMessage(),
                onChanged: (value) {
                  // إرسال حالة الكتابة مع تحسين الأداء
                  _networkService.sendTypingStatus(widget.friend.id, true);

                  // إعادة تعيين المؤقت
                  _typingTimer?.cancel();
                  _typingTimer = Timer(const Duration(seconds: 1), () {
                    _networkService.sendTypingStatus(widget.friend.id, false);
                  });
                },
              ),
            ),
            IconButton(icon: const Icon(Iconsax.send_1, color: Colors.teal), onPressed: _sendMessage),
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
    final isConnected = _networkService.getConnectedFriends().any((u) => u.id == widget.friend.id);

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
                  backgroundColor: isConnected ? Colors.teal : Colors.grey,
                  child: Text(widget.friend.username.isNotEmpty ? widget.friend.username.substring(0, 1).toUpperCase() : '?'),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? 'متصل الآن' : 'غير متصل',
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.grey,
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

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              // **الإضافة الجديدة**: عرض خيار التعديل للرسائل النصية الخاصة بالمستخدم فقط
              if (isMyMessage && message is Message)
                ListTile(
                  leading: const Icon(Iconsax.edit),
                  title: const Text('تعديل الرسالة'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showEditMessageDialog(message); // استدعاء نافذة التعديل
                  },
                ),

              if (isMyMessage)
                ListTile(
                  leading: const Icon(Iconsax.trash, color: Colors.red),
                  title: const Text('حذف الرسالة', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _confirmDeleteMessage(message);
                  },
                ),

              // خيار الرد على الرسالة
              ListTile(
                leading: const Icon(Iconsax.message),
                title: const Text('رد على الرسالة'),
                onTap: () {
                  Navigator.of(context).pop();
                  _replyToMessage(message);
                },
              ),

              if (message is Message) // النسخ للرسائل النصية فقط
                ListTile(
                  leading: const Icon(Iconsax.copy),
                  title: const Text('نسخ النص'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Clipboard.setData(ClipboardData(text: message.content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ النص')),
                    );
                  },
                ),
            ],
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
    String replyContent = '';
    if (message is Message) {
      replyContent = message.content;
    } else if (message is FileMessage) {
      replyContent = 'ملف: ${message.fileName}';
    }

    _messageController.text = ''; // مسح النص الحالي
    FocusScope.of(context).requestFocus(FocusNode()); // إزالة التركيز عن حقل الإدخال
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(FocusNode()); // إعادة التركيز بعد مسح
      _messageController.text = 'الرد: "$replyContent"\n\n';
      FocusScope.of(context).requestFocus(FocusNode()); // التركيز على حقل الإدخال
    });

    // عرض إشعار بأن المستخدم يرد على رسالة
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('اكتب ردك على الرسالة')),
    );
  }

  // --- Call Feature Methods ---

  void _listenToConnectionStatus() {
    // التحقق من حالة الاتصال الأولية
    setState(() {
      _isConnected = _networkService.getConnectedFriends().any((u) => u.id == widget.friend.id);
    });

    // الاستماع لتغييرات حالة الاتصال
    _connectionSubscription = Stream.periodic(const Duration(seconds: 3), (_) => null)
        .listen((_) {
      final isConnected = _networkService.getConnectedFriends().any((u) => u.id == widget.friend.id);
      if (isConnected != _isConnected) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
  }

  Future<bool> _handlePermissions(CallType callType) async {
    PermissionStatus microphoneStatus = await Permission.microphone.request();
    if (callType == CallType.video) {
      PermissionStatus cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('إذن الكاميرا مطلوب لمكالمات الفيديو')),
        );
        return false;
      }
    }
    if (!microphoneStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('إذن الميكروفون مطلوب للمكالمات')),
      );
      return false;
    }
    return true;
  }

  void _startCall(CallType callType) async {
    if (!context.mounted) return;
    await CallIntegration().startCall(context, widget.friend, callType);
  }

}
