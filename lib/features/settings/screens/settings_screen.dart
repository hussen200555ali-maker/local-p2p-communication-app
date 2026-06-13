import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _showOnlineStatus = true;
  bool _readReceipts = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('dark_mode') ?? false;
      _showOnlineStatus = prefs.getBool('show_online_status') ?? true;
      _readReceipts = prefs.getBool('read_receipts') ?? true;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'المظهر'),
          SwitchListTile(
            title: const Text('الوضع الداكن'),
            subtitle: const Text('تغيير مظهر التطبيق إلى الألوان الداكنة'),
            secondary: const Icon(Iconsax.moon),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() => _isDarkMode = value);
              _saveSetting('dark_mode', value);
            },
          ),
          const Divider(),
          const _SectionHeader(title: 'الخصوصية'),
          SwitchListTile(
            title: const Text('إظهار الحالة'),
            subtitle: const Text('السماح للآخرين برؤية حالتك (متصل/غير متصل)'),
            secondary: const Icon(Iconsax.eye),
            value: _showOnlineStatus,
            onChanged: (value) {
              setState(() => _showOnlineStatus = value);
              _saveSetting('show_online_status', value);
            },
          ),
          SwitchListTile(
            title: const Text('تأكيد القراءة'),
            subtitle: const Text('إظهار علامة القراءة للرسائل'),
            secondary: const Icon(Iconsax.tick_circle),
            value: _readReceipts,
            onChanged: (value) {
              setState(() => _readReceipts = value);
              _saveSetting('read_receipts', value);
            },
          ),
          const Divider(),
          const _SectionHeader(title: 'حول'),
          ListTile(
            leading: const Icon(Iconsax.info_circle),
            title: const Text('الإصدار'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Iconsax.code),
            title: const Text('المطور'),
            subtitle: const Text('Local Social App Team'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
