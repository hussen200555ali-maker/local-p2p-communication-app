import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/local_network_service.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final LocalNetworkService _service = LocalNetworkService();
  Timer? _refreshTimer;

  String? _myIp;
  bool _isRunning = false;
  bool _broadcastAlive = false;
  bool _serverAlive = false;
  int _sendSocketCount = 0;
  String _sendSocketInfo = '';
  int _discoveredCount = 0;
  List<String> _discoveredNames = [];
  int _connectedCount = 0;
  int _friendCount = 0;
  List<String> _log = [];
  String? _currentUserInfo;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    _service.getWifiIP().then((ip) {
      if (mounted) setState(() => _myIp = ip);
    });
    setState(() {
      _isRunning = _service.isRunning;
      _broadcastAlive = _service.getDiagnosticBroadcastSocketAlive();
      _serverAlive = _service.getDiagnosticServerSocketAlive();
      _sendSocketCount = _service.getDiagnosticSendSocketCount();
      _sendSocketInfo = _service.getDiagnosticSendSocketsInfo() ?? '';
      _discoveredCount = _service.getDiagnosticDiscoveredUserCount();
      _discoveredNames = _service.getDiagnosticDiscoveredUserNames();
      _connectedCount = _service.getDiagnosticConnectedFriendsCount();
      _friendCount = _service.getDiagnosticFriendIdsCount();
      _log = _service.getDiagnosticLog();
      final user = _service.getCurrentUser();
      _currentUserInfo = user != null ? '${user.username} (${user.id.substring(0, 12)}...)' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تشخيص الشبكة')),
      body: RefreshIndicator(
        onRefresh: () async { _refresh(); await Future.delayed(const Duration(seconds: 1)); },
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildSection('حالة الخدمة', [
              _row('$_currentUserInfo', 'المستخدم'),
              _row(_myIp ?? '⏳ جاري...', 'IP الحالي'),
              _row(_statusBadge(_isRunning), 'الخدمة شغالة'),
            ]),
            _buildSection('المنافذ', [
              _row(_statusBadge(_broadcastAlive), 'UDP 8081 (استقبال)'),
              _row(_statusBadge(_serverAlive), 'TCP 8080 (خادم)'),
              _row('$_sendSocketCount', 'Sockets إرسال'),
              _row(_sendSocketInfo.isNotEmpty ? _sendSocketInfo : 'لا يوجد', 'عناوين الإرسال'),
            ]),
            _buildSection('الاكتشاف والاتصالات', [
              _row('$_discoveredCount', 'مستخدمين مكتشفين'),
              if (_discoveredNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_discoveredNames.join('\n'), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ),
              _row('$_connectedCount', 'اتصالات TCP نشطة'),
              _row('$_friendCount', 'أصدقاء محفوظين'),
            ]),
            _buildSection('سجل الأحداث (آخر ${_log.length})', [
              if (_log.isEmpty)
                const Text('لا توجد أحداث بعد', style: TextStyle(color: Colors.grey))
              else
                ..._log.reversed.take(50).map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(e, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                )),
            ]),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  String _statusBadge(bool alive) {
    return alive ? '✅ شغال' : '❌ معطل';
  }
}
