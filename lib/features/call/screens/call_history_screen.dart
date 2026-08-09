import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../../core/services/local_network_service.dart';
import '../../auth/models/user_model.dart';
import '../call_integration.dart';
import '../models/call_model.dart';


class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> with TickerProviderStateMixin {
  final LocalNetworkService _networkService = LocalNetworkService();
  late User _currentUser;
  late List<CallModel> _callHistory;
  
  // متحكمات الرسوم المتحركة
  late AnimationController _fadeController;
  
  // الرسوم المتحركة
  late Animation<double> _fadeAnimation;

  String? _filterValue = 'الكل';

  @override
  void initState() {
    super.initState();
    _currentUser = _networkService.getCurrentUser()!;
    final callHistoryData = _networkService.getCallHistory();
    _callHistory = callHistoryData.calls.toList();
    
    // إعداد الرسوم المتحركة
    _setupAnimations();
    
    // بدء الرسوم المتحركة
    _startAnimations();
  }
  
  void _setupAnimations() {
    // إعداد متحكم التلاشي
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
  }
  
  void _startAnimations() {
    // بدء الرسوم المتحركة بالتسلسل
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // تشغيل صوت عند النقر على مكالمة
  void _playTapSound() async {
    try {
      // تم إزالة تشغيل الصوت مؤقتاً
      // await _audioPlayer.play(AssetSource('sounds/tap.mp3'));
    } catch (e) {
      debugPrint('Error playing tap sound: $e');
    }
  }

  // بدء مكالمة جديدة
  void _startCall(String userId, CallType callType) async {
    if (!context.mounted) return;
    final realUser = _networkService.getUserById(userId);
    final friend = realUser ?? User(id: userId, username: userId);
    await CallIntegration().startCall(context, friend, callType);
  }

  // الحصول على أيقونة حالة المكالمة
  IconData _getCallStatusIcon(CallStatus status, bool isOutgoing) {
    switch (status) {
      case CallStatus.ringing:
        return Iconsax.call;
      case CallStatus.active:
        return Iconsax.call;
      case CallStatus.ended:
        return isOutgoing ? Iconsax.call : Iconsax.call;
      case CallStatus.missed:
        return Iconsax.close_circle;
      case CallStatus.rejected:
        return Iconsax.close_circle;
      case CallStatus.connecting:
        return Iconsax.call;
    }
  }

  // الحصول على لون حالة المكالمة
  Color _getCallStatusColor(CallStatus status) {
    switch (status) {
      case CallStatus.ringing:
        return Colors.blue;
      case CallStatus.active:
        return Colors.green;
      case CallStatus.ended:
        return Colors.grey;
      case CallStatus.missed:
        return Colors.red;
      case CallStatus.rejected:
        return Colors.orange;
      case CallStatus.connecting:
        return Colors.amber;
    }
  }

  // تنسيق مدة المكالمة
  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المكالمات'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.filter),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
      ),
      body: _callHistory.isEmpty
          ? _buildEmptyState()
          : _buildCallHistoryList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Iconsax.call,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد سجل مكالمات',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallHistoryList() {
    final filteredCalls = _filterCalls(_callHistory);
    final groupedCalls = _groupCallsByDate(filteredCalls);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: groupedCalls.length,
        itemBuilder: (context, index) {
          final dateGroup = groupedCalls[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  dateGroup['date'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ...dateGroup['calls'].map<Widget>((call) => _buildCallHistoryItem(call)).toList(),
            ],
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _groupCallsByDate(List<CallModel> calls) {
    final Map<String, List<CallModel>> grouped = {};
    final Map<String, DateTime> groupDates = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final call in calls) {
      final callDate = DateTime(
        call.startTime.year,
        call.startTime.month,
        call.startTime.day,
      );

      String dateLabel;
      if (callDate == today) {
        dateLabel = 'اليوم';
      } else if (callDate == yesterday) {
        dateLabel = 'أمس';
      } else {
        dateLabel = DateFormat('dd/MM/yyyy').format(call.startTime);
      }

      if (!grouped.containsKey(dateLabel)) {
        grouped[dateLabel] = [];
        groupDates[dateLabel] = callDate;
      }
      grouped[dateLabel]!.add(call);
    }

    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) => groupDates[b.key]!.compareTo(groupDates[a.key]!));

    return sortedGroups.map((entry) => {
      'date': entry.key,
      'calls': entry.value,
    }).toList();
  }

  Widget _buildCallHistoryItem(CallModel call) {
    final isOutgoing = call.callerId == _currentUser.id;
    final otherUserId = isOutgoing ? call.receiverId : call.callerId;
    final otherUser = _networkService.getUserById(otherUserId);
    final userName = otherUser?.username ?? 'مستخدم غير معروف';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getCallStatusColor(call.status),
        child: Icon(
          _getCallStatusIcon(call.status, isOutgoing),
          color: Colors.white,
        ),
      ),
      title: Text(
        userName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Row(
        children: [
          Icon(
            isOutgoing ? Iconsax.call : Iconsax.call,
            size: 16,
            color: _getCallStatusColor(call.status),
          ),
          const SizedBox(width: 4),
          Text(
            _getCallStatusText(call.status, isOutgoing),
            style: TextStyle(
              color: _getCallStatusColor(call.status),
            ),
          ),
          if (call.duration != null && call.duration! > 0) ...[
            const Text(' • '),
            Text(
              _formatDuration(call.duration!),
              style: TextStyle(
                color: _getCallStatusColor(call.status),
              ),
            ),
          ],
        ],
      ),
      trailing: Text(
        DateFormat('h:mm a').format(call.startTime),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 14,
        ),
      ),
      onTap: () {
        _playTapSound();
        _showCallDetailsDialog(call);
      },
    );
  }

  String _getCallStatusText(CallStatus status, bool isOutgoing) {
    switch (status) {
      case CallStatus.ringing:
        return 'يرن...';
      case CallStatus.active:
        return 'مكالمة نشطة';
      case CallStatus.ended:
        return isOutgoing ? 'تم الاتصال' : 'مكالمة واردة';
      case CallStatus.missed:
        return isOutgoing ? 'لم يرد' : 'فائتة';
      case CallStatus.rejected:
        return isOutgoing ? 'مرفوضة' : 'مرفوضة';
      case CallStatus.connecting:
        return 'جاري الاتصال...';
    }
  }

  void _showCallDetailsDialog(CallModel call) {
    final isOutgoing = call.callerId == _currentUser.id;
    final otherUserId = isOutgoing ? call.receiverId : call.callerId;
    final otherUser = _networkService.getUserById(otherUserId);
    final userName = otherUser?.username ?? 'مستخدم غير معروف';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل المكالمة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('المتصل', userName),
            _buildDetailRow('نوع المكالمة', call.callType == CallType.audio ? 'صوتية' : 'فيديو'),
            _buildDetailRow('الاتجاه', isOutgoing ? 'صادرة' : 'واردة'),
            _buildDetailRow('الحالة', _getCallStatusText(call.status, isOutgoing)),
            _buildDetailRow(
              'التاريخ والوقت', 
              DateFormat('dd/MM/yyyy - h:mm a').format(call.startTime),
            ),
            if (call.duration != null && call.duration! > 0)
              _buildDetailRow('المدة', _formatDuration(call.duration!)),
            if (call.endTime != null)
              _buildDetailRow(
                'وقت الانتهاء', 
                DateFormat('h:mm a').format(call.endTime!),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
          if (call.status == CallStatus.ended || call.status == CallStatus.missed)
            ElevatedButton.icon(
              icon: Icon(
                call.callType == CallType.audio ? Iconsax.call : Iconsax.video,
              ),
              label: const Text('إعادة الاتصال'),
              onPressed: () {
                Navigator.of(context).pop();
                _startCall(otherUserId, call.callType);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فلترة سجل المكالمات'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('الكل'),
            _buildFilterOption('المكالمات الفائتة'),
            _buildFilterOption('المكالمات الصادرة'),
            _buildFilterOption('المكالمات الواردة'),
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

  Widget _buildFilterOption(String title) {
    return RadioListTile<String>(
      title: Text(title),
      value: title,
      groupValue: _filterValue,
      onChanged: (String? value) {
        if (value != null) {
          setState(() {
            _filterValue = value;
          });
          Navigator.of(context).pop();
        }
      },
    );
  }

  List<CallModel> _filterCalls(List<CallModel> calls) {
    if (_filterValue == 'الكل') {
      return calls;
    }
    return calls.where((call) {
      final isOutgoing = call.callerId == _currentUser.id;
      switch (_filterValue) {
        case 'المكالمات الفائتة':
          return call.status == CallStatus.missed;
        case 'المكالمات الصادرة':
          return isOutgoing;
        case 'المكالمات الواردة':
          return !isOutgoing;
        default:
          return true;
      }
    }).toList();
  }
}
