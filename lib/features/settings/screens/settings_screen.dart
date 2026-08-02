import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/local_network_service.dart';
import '../../../core/services/log_service.dart';
import '../../diagnostics/screens/diagnostic_screen.dart';

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

  Future<void> _exportLogs() async {
    final logPath = LogService().getTodayLogPath();
    if (logPath == null) {
      _showSnack('لا يوجد ملف سجل اليوم');
      return;
    }

    if (Platform.isWindows) {
      await Clipboard.setData(ClipboardData(text: logPath));
      try {
        await Process.run('explorer', ['/select,', logPath]);
      } catch (_) {
        _showSnack('تم نسخ المسار: $logPath');
      }
      return;
    }

    try {
      final file = File(logPath);
      if (!file.existsSync()) {
        _showSnack('ملف السجل غير موجود');
        return;
      }
      final content = await file.readAsString();
      if (mounted) _showLogDialog(content);
    } catch (e) {
      _showSnack('فشل قراءة السجل: $e');
    }
  }

  void _showLogDialog(String content) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.ltr,
        child: Dialog(
          insetPadding: const EdgeInsets.all(8),
          child: Column(
            children: [
              AppBar(
                title: const Text('السجل', style: TextStyle(fontSize: 16)),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'نسخ الكل',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content));
                      Navigator.pop(ctx);
                      _showSnack('تم نسخ السجل بالكامل');
                    },
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    content,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
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
              LocalNetworkService().darkModeNotifier.value = value;
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
          if (Platform.isLinux)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ تحذير أمني',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'هذا التطبيق مخصص للتواصل الخاص على شبكة محلية موثوقة. الشبكات العامة أو المعادية قد تعرض اتصالاتك للخطر.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(),
          const _SectionHeader(title: 'التشخيص'),
          ListTile(
            leading: const Icon(Iconsax.activity),
            title: const Text('تشخيص الشبكة'),
            subtitle: const Text('عرض حالة IP والمنافذ وسجل الاكتشاف'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiagnosticScreen())),
          ),
          ListTile(
            leading: const Icon(Iconsax.document_download),
            title: const Text('تصدير السجلات'),
            subtitle: const Text('إرسال ملف السجل للتشخيص'),
            onTap: _exportLogs,
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
            subtitle: const Text('فريق الشامي'),
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
