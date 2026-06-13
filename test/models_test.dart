import 'package:flutter_test/flutter_test.dart';
import 'package:local_social_app/features/chat/models/message_model.dart';
import 'package:local_social_app/features/chat/models/file_message_model.dart';
import 'package:local_social_app/features/chat/models/group_message_model.dart';
import 'package:local_social_app/features/chat/models/group_model.dart';
import 'package:local_social_app/features/call/models/call_model.dart';
import 'package:local_social_app/features/auth/models/user_model.dart';
import 'package:local_social_app/features/notifications/models/notification_model.dart';
import 'package:local_social_app/features/status/models/user_status_model.dart';

void main() {
  group('Message', () {
    test('toJson and fromJson roundtrip', () {
      final original = Message(
        id: 'msg1',
        senderId: 'user1',
        receiverId: 'user2',
        content: 'Hello',
        timestamp: DateTime(2026, 6, 10, 12, 30),
        read: true,
        edited: true,
        editedAt: DateTime(2026, 6, 10, 12, 31),
      );
      final json = original.toJson();
      final restored = Message.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.senderId, original.senderId);
      expect(restored.receiverId, original.receiverId);
      expect(restored.content, original.content);
      expect(restored.timestamp, original.timestamp);
      expect(restored.read, original.read);
      expect(restored.edited, original.edited);
      expect(restored.editedAt, original.editedAt);
    });

    test('default values', () {
      final msg = Message(
        id: 'msg2',
        senderId: 'user1',
        receiverId: 'user2',
        content: 'Hi',
        timestamp: DateTime.now(),
      );
      expect(msg.read, false);
      expect(msg.edited, false);
      expect(msg.editedAt, null);
    });
  });

  group('FileMessage', () {
    test('toJson and fromJson roundtrip', () {
      final original = FileMessage(
        id: 'file1',
        senderId: 'user1',
        receiverId: 'user2',
        fileName: 'test.pdf',
        fileType: 'pdf',
        fileSize: 1024,
        filePath: '/tmp/test.pdf',
        timestamp: DateTime(2026, 6, 10, 12, 30),
        read: true,
      );
      final json = original.toJson();
      final restored = FileMessage.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.fileName, original.fileName);
      expect(restored.fileType, original.fileType);
      expect(restored.fileSize, original.fileSize);
      expect(restored.filePath, original.filePath);
    });
  });

  group('GroupMessage', () {
    test('toJson and fromJson roundtrip', () {
      final original = GroupMessage(
        id: 'gmsg1',
        groupId: 'group1',
        senderId: 'user1',
        content: 'Group hello',
        timestamp: DateTime(2026, 6, 10, 12, 30),
        edited: true,
        editedAt: DateTime(2026, 6, 10, 12, 31),
      );
      final json = original.toJson();
      final restored = GroupMessage.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.groupId, original.groupId);
      expect(restored.senderId, original.senderId);
      expect(restored.content, original.content);
      expect(restored.edited, original.edited);
    });
  });

  group('Group', () {
    test('toJson and fromJson roundtrip', () {
      final original = Group(
        id: 'group1',
        name: 'Test Group',
        adminId: 'user1',
        memberIds: ['user1', 'user2', 'user3'],
        createdAt: DateTime(2026, 6, 10),
      );
      final json = original.toJson();
      final restored = Group.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.adminId, original.adminId);
      expect(restored.memberIds, original.memberIds);
    });
  });

  group('CallModel', () {
    test('copyWith updates status', () {
      final call = CallModel(
        id: 'call1',
        callerId: 'user1',
        receiverId: 'user2',
        callType: CallType.audio,
        status: CallStatus.ringing,
        startTime: DateTime.now(),
      );
      final updated = call.copyWith(status: CallStatus.active);
      expect(updated.status, CallStatus.active);
      expect(updated.id, call.id);
      expect(updated.duration, null);
    });

    test('toJson and fromJson roundtrip', () {
      final original = CallModel(
        id: 'call1',
        callerId: 'user1',
        receiverId: 'user2',
        callType: CallType.video,
        status: CallStatus.ended,
        startTime: DateTime(2026, 6, 10, 12, 0),
        endTime: DateTime(2026, 6, 10, 12, 5),
        duration: 300,
      );
      final json = original.toJson();
      final restored = CallModel.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.callType, original.callType);
      expect(restored.status, original.status);
      expect(restored.duration, original.duration);
    });
  });

  group('CallHistory', () {
    test('addCall and getCallsWithUser', () {
      final history = CallHistory(calls: []);
      history.addCall(CallModel(
        id: 'call1',
        callerId: 'user1',
        receiverId: 'user2',
        callType: CallType.audio,
        status: CallStatus.ended,
        startTime: DateTime.now(),
      ));
      expect(history.calls.length, 1);
      final user1Calls = history.getCallsWithUser('user1');
      expect(user1Calls.length, 1);
      final user2Calls = history.getCallsWithUser('user2');
      expect(user2Calls.length, 1);
    });

    test('getMissedCalls', () {
      final history = CallHistory(calls: [
        CallModel(
          id: 'call1',
          callerId: 'user1',
          receiverId: 'user2',
          callType: CallType.audio,
          status: CallStatus.missed,
          startTime: DateTime.now(),
        ),
        CallModel(
          id: 'call2',
          callerId: 'user1',
          receiverId: 'user2',
          callType: CallType.audio,
          status: CallStatus.ended,
          startTime: DateTime.now(),
        ),
      ]);
      expect(history.getMissedCalls().length, 1);
    });
  });

  group('User', () {
    test('toJson and fromJson roundtrip', () {
      final original = User(
        id: 'user1',
        username: 'TestUser',
        bio: 'Hello world',
      );
      final json = original.toJson();
      final restored = User.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.username, original.username);
      expect(restored.bio, original.bio);
    });
  });

  group('AppNotification', () {
    test('toJson and fromJson roundtrip', () {
      final original = AppNotification(
        id: 'notif1',
        title: 'Test',
        body: 'Test body',
        type: 'message',
        timestamp: DateTime(2026, 6, 10, 12, 30),
        isRead: false,
      );
      final json = original.toJson();
      final restored = AppNotification.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.type, original.type);
      expect(restored.isRead, original.isRead);
    });
  });

  group('UserStatus', () {
    test('toJson and fromJson roundtrip', () {
      final original = UserStatus(
        userId: 'user1',
        isOnline: true,
        lastSeen: DateTime(2026, 6, 10, 12, 30),
        isTyping: true,
        currentChatId: 'user2',
      );
      final json = original.toJson();
      final restored = UserStatus.fromJson(json);
      expect(restored.userId, original.userId);
      expect(restored.isOnline, original.isOnline);
      expect(restored.isTyping, original.isTyping);
      expect(restored.currentChatId, original.currentChatId);
    });
  });
}
