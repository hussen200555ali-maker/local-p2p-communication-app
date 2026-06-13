import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/services/local_network_service.dart';
import '../../auth/models/user_model.dart';
import '../models/group_model.dart';
import '../models/group_message_model.dart';
import '../models/file_message_model.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;
  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final LocalNetworkService _networkService = LocalNetworkService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late User _currentUser;
  List<GroupMessage> _messages = [];
  final List<FileMessage> _fileMessages = [];

  // عرض معلومات المجموعة
  void _showGroupInfo() {
    final members = <User>[];
    for (final memberId in widget.group.memberIds) {
      final member = _networkService.getUserById(memberId);
      if (member != null) {
        members.add(member);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'معلومات المجموعة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.cyan,
                child: Text(
                  widget.group.name.isNotEmpty 
                      ? widget.group.name.substring(0, 1).toUpperCase() 
                      : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.group.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'تم إنشاء المجموعة في ${_formatDateTime(widget.group.createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 32),
              Text(
                'الأعضاء (${widget.group.memberIds.length})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final isAdmin = member.id == widget.group.adminId;
                    final isOnline = _networkService.getConnectedFriends().any((u) => u.id == member.id);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isOnline ? Colors.teal : Colors.grey,
                        child: Text(
                          member.username.isNotEmpty 
                              ? member.username.substring(0, 1).toUpperCase() 
                              : '?',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        member.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isOnline ? 'متصل الآن' : 'غير متصل',
                        style: TextStyle(
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                      trailing: isAdmin 
                          ? const Chip(
                              label: Text('المدير'),
                              backgroundColor: Colors.teal,
                              labelStyle: TextStyle(color: Colors.white),
                            ) 
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              if (widget.group.adminId != _currentUser.id)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmLeaveGroup,
                    icon: const Icon(Iconsax.logout, color: Colors.white),
                    label: const Text('مغادرة المجموعة', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // تأكيد مغادرة المجموعة
  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مغادرة المجموعة'),
        content: const Text('هل أنت متأكد من رغبتك في مغادرة هذه المجموعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _leaveGroup();
            },
            child: const Text('مغادرة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // مغادرة المجموعة
  void _leaveGroup() {
    _networkService.leaveGroup(widget.group.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم مغادرة المجموعة')),
    );
  }

  // حذف جميع رسائل المجموعة
  void _clearGroupMessages() {
    setState(() {
      _messages.clear();
      _fileMessages.clear();
    });

    _networkService.deleteGroupMessages(widget.group.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف جميع رسائل المجموعة')),
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

  @override
  void initState() {
    super.initState();
    _currentUser = _networkService.getCurrentUser()!;
    _messages = _networkService.getGroupMessages(widget.group.id);

    _fileMessages.addAll(_networkService.getFileMessages(widget.group.id));

    // **الإصلاح**: تسجيل دالة رد النداء لرسائل المجموعة
    _networkService.registerCallbacks(
      onGroupMessageReceived: (message) {
        if (message.groupId == widget.group.id && mounted) {
          final existingIndex = _messages.indexWhere((m) => m.id == message.id);
          if (existingIndex == -1) {
            setState(() {
              _messages.add(message);
            });
            _scrollToBottom();
          }
        }
      },
      onFileMessageReceived: (fileMessage) {
        if (fileMessage.groupId == widget.group.id && mounted) {
          setState(() {
            if (!_fileMessages.any((f) => f.id == fileMessage.id)) {
              _fileMessages.add(fileMessage);
            }
          });
          _scrollToBottom();
        }
      },
      onGroupMessageEdited: (groupId, messageId, newContent) {
        if (groupId == widget.group.id && mounted) {
          final messageIndex = _messages.indexWhere((msg) => msg.id == messageId);
          if (messageIndex != -1) {
            final oldMessage = _messages[messageIndex];
            final updatedMessage = GroupMessage(
              id: oldMessage.id,
              groupId: oldMessage.groupId,
              senderId: oldMessage.senderId,
              content: newContent,
              timestamp: oldMessage.timestamp,
              edited: true,
              editedAt: DateTime.now(),
            );
            setState(() {
              _messages[messageIndex] = updatedMessage;
            });
          }
        }
      },
      onGroupMessageDeleted: (groupId, messageId) {
        if (groupId == widget.group.id && mounted) {
          setState(() {
            _messages.removeWhere((msg) => msg.id == messageId);
          });
        }
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    // **الإصلاح**: إلغاء تسجيل دالة رد النداء عند إغلاق الشاشة
    _networkService.unregisterCallbacks();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    // إنشاء الرسالة وإضافتها للواجهة مباشرة
    final message = GroupMessage(
      id: const Uuid().v4(),
      groupId: widget.group.id,
      senderId: _currentUser.id,
      content: content,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();

    _networkService.sendGroupMessage(widget.group.id, content);
    _messageController.clear();
  }

  Future<void> _pickAndSendFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;
        String fileType = result.files.single.extension ?? 'file';
        final fileBytes = await file.readAsBytes();

        final fileMessage = FileMessage(
          id: const Uuid().v4(),
          senderId: _currentUser.id,
          receiverId: '',
          groupId: widget.group.id,
          fileName: fileName,
          fileType: fileType,
          fileSize: fileBytes.length,
          filePath: file.path,
          timestamp: DateTime.now(),
        );

        setState(() {
          _fileMessages.add(fileMessage);
        });
        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('جاري إرسال الملف: $fileName...')),
        );

        for (final memberId in widget.group.memberIds) {
          if (memberId != _currentUser.id) {
            await _networkService.sendFileMessage(memberId, file, fileType, groupId: widget.group.id);
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء اختيار الملف: $e'), backgroundColor: Colors.red),
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

  // دالة لدمج وترتيب الرسائل
  List<dynamic> get _allMessages {
    final List<dynamic> all = [];
    all.addAll(_messages);
    all.addAll(_fileMessages);
    all.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return all;
  }

  String _getSenderName(String senderId) {
    if (senderId == _currentUser.id) return 'أنا';
    return _networkService.getUsernameFromDirectory(senderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.cyan,
              child: Text(
                widget.group.name.isNotEmpty 
                    ? widget.group.name.substring(0, 1).toUpperCase() 
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
                    widget.group.name,
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    '${widget.group.memberIds.length} عضو',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ميزة مكالمات المجموعة قيد التطوير')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Iconsax.video),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ميزة فيديو المجموعة قيد التطوير')),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'info') {
                _showGroupInfo();
              } else if (value == 'leave') {
                _confirmLeaveGroup();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'info',
                child: ListTile(
                  leading: Icon(Iconsax.info_circle),
                  title: Text('معلومات المجموعة'),
                ),
              ),
              if (widget.group.adminId != _currentUser.id)
                const PopupMenuItem<String>(
                  value: 'leave',
                  child: ListTile(
                    leading: Icon(Iconsax.logout, color: Colors.red),
                    title: Text('مغادرة المجموعة', style: TextStyle(color: Colors.red)),
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
              itemCount: _allMessages.length,
              itemBuilder: (context, index) {
                final message = _allMessages[index];
                final isMe = message.senderId == _currentUser.id;

                if (message is FileMessage) {
                  return _buildFileMessageBubble(message, isMe);
                } else if (message is GroupMessage) {
                  return _buildMessageBubble(message, isMe);
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

  Widget _buildMessageBubble(GroupMessage message, bool isMe) {
    return InkWell(
      onLongPress: () => _showGroupMessageOptions(message, isMe),
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
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Text(
                  _getSenderName(message.senderId),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                ),
              if (!isMe) const SizedBox(height: 4),
              Text(
                message.content,
                style: TextStyle(color: isMe ? Colors.white : Colors.black87),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (message.edited)
                    Text(
                      'تم التعديل ',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: isMe ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  Text(
                    _formatDateTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
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

  Widget _buildFileMessageBubble(FileMessage message, bool isMe) {

    return InkWell(
      onLongPress: () => _showFileMessageOptions(message, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
          padding: const EdgeInsets.all(12.0),
          width: 220,
          decoration: BoxDecoration(
            color: isMe ? Colors.teal.shade300 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (!isMe)
                Text(
                  _getSenderName(message.senderId),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                ),
              if (!isMe) const SizedBox(height: 4),
              InkWell(
                onTap: () async {
                  try {
                    await OpenFilex.open(message.filePath);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('لا يمكن فتح الملف: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: Row(
                  children: [
                    Icon(Iconsax.document_1, color: isMe ? Colors.white : Colors.black54, size: 40),
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
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatDateTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  if (message.editedAt != null) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Iconsax.edit_2,
                      size: 12,
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
            IconButton(icon: const Icon(Iconsax.attach_square), onPressed: _pickAndSendFile),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(hintText: 'اكتب رسالة في المجموعة...', border: InputBorder.none),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Iconsax.send_1, color: Colors.teal),
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  // عرض خيارات رسالة الملف
  void _showFileMessageOptions(FileMessage message, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Iconsax.message_add),
              title: const Text('الرد'),
              onTap: () {
                Navigator.of(context).pop();
                _replyToMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.document_download),
              title: const Text('تحميل الملف'),
              onTap: () {
                Navigator.of(context).pop();
                _downloadFile(message);
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.document_text),
              title: const Text('معلومات الملف'),
              onTap: () {
                Navigator.of(context).pop();
                _showFileInfo(message);
              },
            ),
            if (isMe) ...[
              ListTile(
                leading: const Icon(Iconsax.trash, color: Colors.red),
                title: const Text('حذف الملف'),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmDeleteFile(message);
                },
              ),
            ]
          ],
        ),
      ),
    );
  }

  // تحميل الملف
  void _downloadFile(FileMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الملف في الجهاز')),
    );
  }

  // عرض معلومات الملف
  void _showFileInfo(FileMessage message) {

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معلومات الملف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الاسم: ${message.fileName}'),
            const SizedBox(height: 8),
            Text('الحجم: ${formatBytes(message.fileSize, 2)}'),
            const SizedBox(height: 8),
            Text('النوع: ${message.fileType}'),
            const SizedBox(height: 8),
            Text('المرسل: ${_getSenderName(message.senderId)}'),
            const SizedBox(height: 8),
            Text('التاريخ: ${message.timestamp.toString().substring(0, 16)}'),
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

  // تأكيد حذف الملف
  void _confirmDeleteFile(FileMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الملف'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذا الملف؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteFile(message);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // حذف الملف
  void _deleteFile(FileMessage message) {
    setState(() {
      _fileMessages.remove(message);
    });

    // حذف الملف من الخدمة
    _networkService.deleteGroupFileMessage(widget.group.id, message.id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف الملف')),
    );
  }

  // تعديل رسالة المجموعة
  void _editGroupMessage(GroupMessage message) {
    final TextEditingController editController = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الرسالة'),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'اكتب الرسالة الجديدة'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateGroupMessage(message, editController.text);
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }

  // تحديث رسالة المجموعة
  void _updateGroupMessage(GroupMessage message, String newContent) {
    final updatedMessage = GroupMessage(
      id: message.id,
      groupId: message.groupId,
      senderId: message.senderId,
      content: newContent,
      timestamp: message.timestamp,
      edited: true,
      editedAt: DateTime.now(),
    );

    // البحث عن index الرسالة وتحديثها
    final index = _messages.indexWhere((msg) => msg.id == message.id);
    if (index != -1) {
      setState(() {
        _messages[index] = updatedMessage;
      });

      // إرسال التحديث للشبكة
      _networkService.editGroupMessage(widget.group.id, message.id, newContent);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تعديل الرسالة')),
      );
    }
  }

  // عرض خيارات رسالة المجموعة
  void _showGroupMessageOptions(GroupMessage message, bool isMe) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Iconsax.message_add),
              title: const Text('الرد'),
              onTap: () {
                Navigator.of(context).pop();
                _replyToMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.copy),
              title: const Text('نسخ النص'),
              onTap: () {
                Navigator.of(context).pop();
                _copyMessage(message.content);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Iconsax.edit),
                title: const Text('تعديل الرسالة'),
                onTap: () {
                  Navigator.of(context).pop();
                  _editGroupMessage(message);
                },
              ),
            if (isMe)
              ListTile(
                leading: const Icon(Iconsax.trash, color: Colors.red),
                title: const Text('حذف الرسالة', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop();
                  _confirmDeleteGroupMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  // نسخ الرسالة
  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ النص')),
    );
  }

  // الرد على الرسالة
  void _replyToMessage(dynamic message) {
    final senderName = _getSenderName(message.senderId);
    String replyContent;
    if (message is GroupMessage) {
      replyContent = message.content;
    } else if (message is FileMessage) {
      replyContent = 'ملف: ${message.fileName}';
    } else {
      return;
    }

    final replyText = 'الرد على "$senderName":\n$replyContent\n-------------\n';
    _messageController.text = replyText;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
    FocusScope.of(context).requestFocus();
  }

  // تأكيد حذف رسالة المجموعة
  void _confirmDeleteGroupMessage(GroupMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الرسالة'),
        content: const Text('هل أنت متأكد من رغبتك في حذف هذه الرسالة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteGroupMessage(message);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // حذف رسالة المجموعة
  void _deleteGroupMessage(GroupMessage message) {
    setState(() {
      _messages.removeWhere((msg) => msg.id == message.id);
    });

    // إرسال طلب الحذف للشبكة
    _networkService.deleteGroupMessage(widget.group.id, message.id);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف الرسالة')),
    );
  }
}
