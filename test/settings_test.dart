import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Settings Persistence', () {
    test('default settings values are correct', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getBool('dark_mode'), isNull);
      expect(prefs.getBool('show_online_status'), isNull);
      expect(prefs.getBool('read_receipts'), isNull);
    });

    test('settings can be saved and retrieved', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('dark_mode', true);
      await prefs.setBool('show_online_status', false);
      await prefs.setBool('read_receipts', false);

      expect(prefs.getBool('dark_mode'), true);
      expect(prefs.getBool('show_online_status'), false);
      expect(prefs.getBool('read_receipts'), false);
    });

    test('non-existent settings return null', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getBool('non_existent_key'), isNull);
    });

    test('settings survive SharedPreferences reload', () async {
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      await prefs.setBool('dark_mode', true);
      await prefs.setBool('show_online_status', false);

      prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('dark_mode'), true);
      expect(prefs.getBool('show_online_status'), false);
      expect(prefs.containsKey('read_receipts'), false);
    });
  });
}
