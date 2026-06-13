import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../features/chat/models/message_model.dart';
import '../../features/chat/models/pending_message_model.dart';
import 'database_service.dart';

class MessageQueueService {
  static final MessageQueueService _instance = MessageQueueService._internal();
  factory MessageQueueService() => _instance;
  MessageQueueService._internal();

  final DatabaseService _dbService = DatabaseService();
  final Map<String, bool> _isFlushing = {};
  final Map<String, Timer> _ackTimers = {};

  final Set<String> _recentlySentIds = {};
  static const int _recentlySentMaxSize = 1000;

  VoidCallback? onQueueChanged;

  Future<void> enqueue(PendingMessage pending) async {
    await _dbService.insertPendingMessage(pending);
    onQueueChanged?.call();
  }

  Future<List<PendingMessage>> getPendingForReceiver(String receiverId) async {
    return _dbService.getPendingMessagesForReceiver(receiverId);
  }

  Future<List<PendingMessage>> getAllPending() async {
    return _dbService.getAllPendingMessages();
  }

  Future<PendingMessage?> getById(String messageId) async {
    return _dbService.getPendingMessage(messageId);
  }

  Future<void> markSent(String messageId) async {
    await _dbService.updatePendingStatus(messageId, DeliveryStatus.sent);
    _recentlySent(messageId);
    onQueueChanged?.call();
  }

  void markSentSilent(String messageId) {
    _recentlySent(messageId);
  }

  Future<void> markFailed(String messageId) async {
    await _dbService.updatePendingStatus(messageId, DeliveryStatus.failed);
    onQueueChanged?.call();
  }

  Future<void> updateRetry(String messageId, int retryCount) async {
    await _dbService.updatePendingRetry(messageId, retryCount, DateTime.now());
  }

  Future<int> getPendingCount() async {
    return _dbService.getPendingMessageCount();
  }

  Future<int> getPendingCountForPeer(String peerId) async {
    return _dbService.getPendingMessageCountForReceiver(peerId);
  }

  Future<void> purgeForPeer(String peerId) async {
    await _dbService.deletePendingMessagesForReceiver(peerId);
    onQueueChanged?.call();
  }

  Future<void> purgeForGroup(String groupId) async {
    await _dbService.deletePendingMessagesForGroup(groupId);
    onQueueChanged?.call();
  }

  Future<void> updatePendingContent(String messageId, String newContent) async {
    await _dbService.updatePendingContent(messageId, newContent);
  }

  Future<void> removeFromQueue(String messageId) async {
    await _dbService.deletePendingMessage(messageId);
    onQueueChanged?.call();
  }

  Future<void> deleteMessage(String messageId) async {
    final pending = await getById(messageId);
    if (pending != null && pending.status == DeliveryStatus.pending) {
      await removeFromQueue(messageId);
    }
  }

  void _recentlySent(String messageId) {
    _recentlySentIds.add(messageId);
    if (_recentlySentIds.length > _recentlySentMaxSize) {
      final toRemove = _recentlySentIds.take(100).toList();
      for (final id in toRemove) {
        _recentlySentIds.remove(id);
      }
    }
  }

  bool isRecentlySent(String messageId) => _recentlySentIds.contains(messageId);

  Future<DeliveryStatus?> getMessageDeliveryStatus(String messageId) async {
    if (_recentlySentIds.contains(messageId)) return DeliveryStatus.sent;
    final pending = await _dbService.getPendingMessage(messageId);
    if (pending != null) return pending.status;
    return null;
  }

  Future<int> flushQueue(
    String peerId,
    Socket socket,
    String Function(String) encryptText,
  ) async {
    if (_isFlushing[peerId] == true) return 0;
    _isFlushing[peerId] = true;

    int sentCount = 0;
    try {
      final pendings = await getPendingForReceiver(peerId);

      for (final pending in pendings) {
        if (pending.status != DeliveryStatus.pending) continue;

        await _dbService.updatePendingStatus(pending.id, DeliveryStatus.sending);

        try {
          if (pending.messageType == 'group') {
            final groupMsg = {
              'type': 'GROUP_MESSAGE',
              'message': {
                'id': pending.id,
                'groupId': pending.groupId,
                'senderId': pending.senderId,
                'content': encryptText(pending.content),
                'timestamp': pending.timestamp.toUtc().toIso8601String(),
              },
            };
            socket.write('GROUP_MSG:${jsonEncode(groupMsg)}\n');
            await socket.flush();
            await markSent(pending.id);
            sentCount++;
            continue;
          }

          final msg = Message(
            id: pending.id,
            senderId: pending.senderId,
            receiverId: pending.receiverId,
            content: pending.content,
            timestamp: pending.timestamp,
          );
          final json = msg.toJson();
          json['content'] = encryptText(pending.content);
          socket.write('MSG:${jsonEncode(json)}\n');
          await socket.flush();

          final bool acked = await _waitForAck(pending.id);

          if (acked) {
            await markSent(pending.id);
            sentCount++;
          } else {
            if (pending.retryCount + 1 >= 3) {
              await markFailed(pending.id);
            } else {
              await _dbService.updatePendingStatus(pending.id, DeliveryStatus.pending);
              await updateRetry(pending.id, pending.retryCount + 1);
            }
          }
        } catch (e) {
          if (pending.retryCount + 1 >= 3) {
            await markFailed(pending.id);
          } else {
            await _dbService.updatePendingStatus(pending.id, DeliveryStatus.pending);
            await updateRetry(pending.id, pending.retryCount + 1);
          }
          break;
        }
      }
    } finally {
      _isFlushing[peerId] = false;
    }
    return sentCount;
  }

  Future<bool> _waitForAck(String messageId) async {
    final completer = Completer<bool>();
    _ackTimers[messageId]?.cancel();

    void listener(String ackedId) {
      if (ackedId == messageId && !completer.isCompleted) {
        completer.complete(true);
      }
    }

    _ackListeners[messageId] = listener;

    _ackTimers[messageId] = Timer(const Duration(seconds: 5), () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    final result = await completer.future;
    _ackTimers[messageId]?.cancel();
    _ackTimers.remove(messageId);
    _ackListeners.remove(messageId);
    return result;
  }

  final Map<String, void Function(String)> _ackListeners = {};

  void handleAck(String messageId) {
    final listener = _ackListeners[messageId];
    if (listener != null) {
      listener(messageId);
    }
  }

  void cancelAckWait(String messageId) {
    _ackTimers[messageId]?.cancel();
    _ackTimers.remove(messageId);
    _ackListeners.remove(messageId);
  }

  Future<void> loadPendingIntoMemory() async {
    final all = await getAllPending();
    for (final p in all) {
      if (p.status == DeliveryStatus.sent) {
        _recentlySent(p.id);
      }
    }
  }
}
