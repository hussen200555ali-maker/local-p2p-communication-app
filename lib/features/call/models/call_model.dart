enum CallType {
  audio,
  video,
}

enum CallStatus {
  ringing,    // يرن
  active,      // نشط
  ended,       // انتهى
  missed,      // فائت
  rejected,    // مرفوض
  connecting,   // جاري الاتصال
}

class CallModel {
  final String id;
  final String callerId;
  final String receiverId;
  final CallType callType;
  final CallStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final int? duration; // بالثواني

  CallModel({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.callType,
    required this.status,
    required this.startTime,
    this.endTime,
    this.duration,
  });

  // إنشاء نسخة من المكالمة مع تحديث الحالة
  CallModel copyWith({
    CallStatus? status,
    DateTime? endTime,
    int? duration,
  }) {
    return CallModel(
      id: id,
      callerId: callerId,
      receiverId: receiverId,
      callType: callType,
      status: status ?? this.status,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
    );
  }

  // تحويل النموذج إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callerId': callerId,
      'receiverId': receiverId,
      'callType': callType.name,
      'status': status.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration,
    };
  }

  // إنشاء نموذج من JSON
  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'],
      callerId: json['callerId'],
      receiverId: json['receiverId'],
      callType: CallType.values.firstWhere((e) => e.name == json['callType']),
      status: CallStatus.values.firstWhere((e) => e.name == json['status']),
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      duration: json['duration'],
    );
  }
}

class CallHistory {
  final List<CallModel> calls;

  CallHistory({required this.calls});

  // إضافة مكالمة إلى السجل
  void addCall(CallModel call) {
    calls.add(call);
    // ترتيب المكالمات حسب التاريخ (الأحدث أولاً)
    calls.sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  // الحصول على مكالمات مع مستخدم معين
  List<CallModel> getCallsWithUser(String userId) {
    return calls.where((call) => 
      call.callerId == userId || call.receiverId == userId
    ).toList();
  }

  // الحصول على المكالمات الفائتة
  List<CallModel> getMissedCalls() {
    return calls.where((call) => call.status == CallStatus.missed).toList();
  }

  // تحويل السجل إلى JSON
  Map<String, dynamic> toJson() {
    return {
      'calls': calls.map((call) => call.toJson()).toList(),
    };
  }

  // إنشاء سجل من JSON
  factory CallHistory.fromJson(Map<String, dynamic> json) {
    final List<dynamic> callsList = json['calls'] ?? [];
    final List<CallModel> parsedCalls = callsList
        .map((callJson) => CallModel.fromJson(callJson))
        .toList();

    return CallHistory(calls: parsedCalls);
  }
}
