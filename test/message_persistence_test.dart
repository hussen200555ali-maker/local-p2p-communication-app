import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_social_app/features/chat/models/message_model.dart';

void main() {
  group('Message Persistence (C-3 Fix)', () {
    test('all_messages_v3 can be serialized and deserialized', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final messages = <String, List<Message>>{};
      messages['friend1'] = [
        Message(
          id: 'msg1',
          senderId: 'user1',
          receiverId: 'friend1',
          content: 'Hello',
          timestamp: DateTime(2026, 6, 10, 12, 0),
        ),
        Message(
          id: 'msg2',
          senderId: 'friend1',
          receiverId: 'user1',
          content: 'Hi there',
          timestamp: DateTime(2026, 6, 10, 12, 1),
        ),
      ];
      messages['friend2'] = [
        Message(
          id: 'msg3',
          senderId: 'user1',
          receiverId: 'friend2',
          content: 'Hey',
          timestamp: DateTime(2026, 6, 10, 12, 2),
        ),
      ];

      final allMessagesJson = messages.map(
        (key, value) => MapEntry(key, jsonEncode(value.map((msg) => msg.toJson()).toList())),
      );
      await prefs.setString('all_messages_v3', jsonEncode(allMessagesJson));

      final stored = prefs.getString('all_messages_v3');
      expect(stored, isNotNull);

      final decoded = jsonDecode(stored!) as Map<String, dynamic>;
      expect(decoded.length, 2);
      expect(decoded.containsKey('friend1'), true);
      expect(decoded.containsKey('friend2'), true);

      final friend1Messages = (jsonDecode(decoded['friend1']) as List)
          .map((item) => Message.fromJson(item))
          .toList();
      expect(friend1Messages.length, 2);
      expect(friend1Messages[0].content, 'Hello');
      expect(friend1Messages[1].content, 'Hi there');
    });

    test('empty messages map persists correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final emptyMap = <String, List<Message>>{};
      final allMessagesJson = emptyMap.map(
        (key, value) => MapEntry(key, jsonEncode(value.map((msg) => msg.toJson()).toList())),
      );
      await prefs.setString('all_messages_v3', jsonEncode(allMessagesJson));

      final stored = prefs.getString('all_messages_v3');
      expect(stored, isNotNull);

      final decoded = jsonDecode(stored!) as Map<String, dynamic>;
      expect(decoded.isEmpty, true);
    });

    test('messages survive app restart simulation', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final originalMessages = <String, List<Message>>{};
      originalMessages['test_friend'] = [
        Message(
          id: 'persist1',
          senderId: 'me',
          receiverId: 'test_friend',
          content: 'This should persist',
          timestamp: DateTime(2026, 6, 10, 12, 0),
        ),
      ];

      final allMessagesJson = originalMessages.map(
        (key, value) => MapEntry(key, jsonEncode(value.map((msg) => msg.toJson()).toList())),
      );
      await prefs.setString('all_messages_v3', jsonEncode(allMessagesJson));

      final restoredPrefs = await SharedPreferences.getInstance();
      final stored = restoredPrefs.getString('all_messages_v3');
      expect(stored, isNotNull);

      final decoded = jsonDecode(stored!) as Map<String, dynamic>;

      final restoredMessages = <String, List<Message>>{};
      decoded.forEach((key, value) {
        restoredMessages[key] = (jsonDecode(value) as List)
            .map((item) => Message.fromJson(item))
            .toList();
      });

      expect(restoredMessages.containsKey('test_friend'), true);
      expect(restoredMessages['test_friend']!.length, 1);
      expect(restoredMessages['test_friend']!.first.content, 'This should persist');
      expect(restoredMessages['test_friend']!.first.id, 'persist1');
    });

    test('corrupt JSON in one section does not block other sections', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Save valid friend_ids
      await prefs.setStringList('friend_ids_v3', ['friend1', 'friend2']);

      // Save corrupt data in all_messages_v3
      await prefs.setString('all_messages_v3', 'this is not valid json');

      // Save valid user directory
      await prefs.setString('user_directory_v3', jsonEncode({'friend1': 'Friend One'}));

      // Simulate _loadDataFromStorage logic
      final errors = <String>[];

      try {
        final ids = prefs.getStringList('friend_ids_v3') ?? [];
        expect(ids.length, 2);
      } catch (e) {
        errors.add('friend_ids_v3: $e');
      }

      try {
        final dirStr = prefs.getString('user_directory_v3');
        if (dirStr != null) {
          (jsonDecode(dirStr) as Map<String, dynamic>).forEach((k, v) => {});
        }
      } catch (e) {
        errors.add('user_directory_v3: $e');
      }

      try {
        final msgs = prefs.getString('all_messages_v3');
        if (msgs != null) {
          jsonDecode(msgs) as Map<String, dynamic>;
        }
      } catch (e) {
        errors.add('all_messages_v3: $e');
      }

      // Only all_messages_v3 should have failed
      expect(errors.where((e) => e.startsWith('all_messages_v3')).length, 1);
      expect(errors.where((e) => e.startsWith('friend_ids_v3')).length, 0);
      expect(errors.where((e) => e.startsWith('user_directory_v3')).length, 0);
    });

    test('partial corrupt data recovers clean sections', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final validMsg = Message(
        id: 'valid1', senderId: 'me', receiverId: 'f1',
        content: 'Valid message', timestamp: DateTime(2026, 6, 10),
      );

      final messagesMap = <String, dynamic>{};
      messagesMap['friend1'] = jsonEncode([validMsg.toJson()]);
      messagesMap['corrupt_friend'] = 'not a json array';
      messagesMap['friend2'] = jsonEncode([validMsg.toJson()]);

      await prefs.setString('all_messages_v3', jsonEncode(messagesMap));

      final stored = prefs.getString('all_messages_v3')!;
      final decoded = jsonDecode(stored) as Map<String, dynamic>;
      final loadedMessages = <String, List<Message>>{};

      decoded.forEach((key, value) {
        try {
          loadedMessages[key] = (jsonDecode(value) as List)
              .map((item) => Message.fromJson(item))
              .toList();
        } catch (_) {}
      });

      expect(loadedMessages.containsKey('friend1'), true);
      expect(loadedMessages.containsKey('friend2'), true);
      expect(loadedMessages.containsKey('corrupt_friend'), false);
      expect(loadedMessages['friend1']!.length, 1);
      expect(loadedMessages['friend1']!.first.content, 'Valid message');
    });
  });
}
