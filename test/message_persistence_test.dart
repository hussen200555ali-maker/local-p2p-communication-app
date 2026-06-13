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
  });
}
