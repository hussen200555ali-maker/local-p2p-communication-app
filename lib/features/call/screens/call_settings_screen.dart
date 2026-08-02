import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';

class CallSettingsScreen extends StatefulWidget {
  const CallSettingsScreen({super.key});

  @override
  State<CallSettingsScreen> createState() => _CallSettingsScreenState();
}

class _CallSettingsScreenState extends State<CallSettingsScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  // إعدادات المكالمات
  bool _vibrateDuringCalls = true;
  bool _useRingtone = true;
  bool _autoAnswerCalls = false;
  bool _showCallNotifications = true;
  String _selectedRingtone = 'default';
  double _callVolume = 0.8;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vibrateDuringCalls = prefs.getBool('vibrate_during_calls') ?? true;
      _useRingtone = prefs.getBool('use_ringtone') ?? true;
      _autoAnswerCalls = prefs.getBool('auto_answer_calls') ?? false;
      _showCallNotifications = prefs.getBool('show_call_notifications') ?? true;
      _selectedRingtone = prefs.getString('selected_ringtone') ?? 'default';
      _callVolume = prefs.getDouble('call_volume') ?? 0.8;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrate_during_calls', _vibrateDuringCalls);
    await prefs.setBool('use_ringtone', _useRingtone);
    await prefs.setBool('auto_answer_calls', _autoAnswerCalls);
    await prefs.setBool('show_call_notifications', _showCallNotifications);
    await prefs.setString('selected_ringtone', _selectedRingtone);
    await prefs.setDouble('call_volume', _callVolume);
  }

  Future<void> _playRingtone() async {
    try {
      await _audioPlayer.setVolume(_callVolume);
      if (_selectedRingtone == 'default') {
        await _audioPlayer.play(AssetSource('sounds/ringtone.wav'));
      } else {
        await _audioPlayer.play(DeviceFileSource(_selectedRingtone));
      }
    } catch (e) {
      debugPrint('Error playing ringtone: $e');
    }
  }

  Future<void> _selectCustomRingtone() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedRingtone = result.files.single.path!;
        });
        await _saveSettings();
      }
    } catch (e) {
      debugPrint('Error selecting ringtone: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات المكالمات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // إعدادات الصوت
          _buildSectionTitle('إعدادات الصوت'),
          _buildSwitchTile(
            title: 'استخدام نغمة رنين',
            subtitle: 'تشغيل نغمة عند ورود مكالمة',
            value: _useRingtone,
            onChanged: (value) {
              setState(() {
                _useRingtone = value;
              });
              _saveSettings();
            },
          ),

          if (_useRingtone) ...[
            _buildRingtoneSelector(),
            _buildVolumeSlider(),
          ],

          // إعدادات الاهتزاز
          _buildSectionTitle('إعدادات الاهتزاز'),
          _buildSwitchTile(
            title: 'اهتزاز أثناء الرنين',
            subtitle: 'اهتزاز الجهاز عند ورود مكالمة',
            value: _vibrateDuringCalls,
            onChanged: (value) {
              setState(() {
                _vibrateDuringCalls = value;
              });
              _saveSettings();
            },
          ),

          // إعدادات الإجابة التلقائية
          _buildSectionTitle('الإعدادات المتقدمة'),
          _buildSwitchTile(
            title: 'الإجابة التلقائية',
            subtitle: 'الإجابة تلقائياً على المكالمات من جهات الاتصال',
            value: _autoAnswerCalls,
            onChanged: (value) {
              setState(() {
                _autoAnswerCalls = value;
              });
              _saveSettings();
            },
          ),

          // إعدادات الإشعارات
          _buildSwitchTile(
            title: 'عرض إشعارات المكالمات',
            subtitle: 'عرض إشعار عند ورود مكالمة',
            value: _showCallNotifications,
            onChanged: (value) {
              setState(() {
                _showCallNotifications = value;
              });
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.teal,
    );
  }

  Widget _buildRingtoneSelector() {
    return ListTile(
      title: const Text('نغمة الرنين'),
      subtitle: Text(_selectedRingtone == 'default' ? 'الافتراضية' : 'مخصصة'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Iconsax.play),
            onPressed: _playRingtone,
          ),
          const Icon(Iconsax.arrow_left_2),
        ],
      ),
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('نغمة افتراضية'),
                trailing: _selectedRingtone == 'default'
                    ? const Icon(Icons.check, color: Colors.teal)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedRingtone = 'default';
                  });
                  _saveSettings();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('اختر نغمة مخصصة'),
                trailing: _selectedRingtone != 'default'
                    ? const Icon(Icons.check, color: Colors.teal)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  _selectCustomRingtone();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVolumeSlider() {
    return ListTile(
      title: const Text('مستوى صوت المكالمة'),
      subtitle: Slider(
        value: _callVolume,
        min: 0.0,
        max: 1.0,
        divisions: 10,
      activeColor: Colors.teal,
        onChanged: (value) {
          setState(() {
            _callVolume = value;
          });
          _saveSettings();
        },
      ),
    );
  }
}
