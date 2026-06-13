enum DeliveryStatus { pending, sending, sent, failed }

class PendingMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  DeliveryStatus status;
  final String messageType; // text, file, group
  final String? groupId;
  final String? fileMetadata;
  int retryCount;
  DateTime? lastAttemptAt;

  PendingMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.status = DeliveryStatus.pending,
    this.messageType = 'text',
    this.groupId,
    this.fileMetadata,
    this.retryCount = 0,
    this.lastAttemptAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'content': content,
    'timestamp': timestamp.toUtc().toIso8601String(),
    'status': status.name,
    'messageType': messageType,
    'groupId': groupId,
    'fileMetadata': fileMetadata,
    'retryCount': retryCount,
    'lastAttemptAt': lastAttemptAt?.toUtc().toIso8601String(),
  };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
    id: json['id'],
    senderId: json['senderId'],
    receiverId: json['receiverId'],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    status: DeliveryStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => DeliveryStatus.pending),
    messageType: json['messageType'] ?? 'text',
    groupId: json['groupId'],
    fileMetadata: json['fileMetadata'],
    retryCount: json['retryCount'] ?? 0,
    lastAttemptAt: json['lastAttemptAt'] != null ? DateTime.parse(json['lastAttemptAt']) : null,
  );

  PendingMessage copyWith({
    DeliveryStatus? status,
    int? retryCount,
    DateTime? lastAttemptAt,
    String? content,
    String? fileMetadata,
  }) => PendingMessage(
    id: id,
    senderId: senderId,
    receiverId: receiverId,
    content: content ?? this.content,
    timestamp: timestamp,
    status: status ?? this.status,
    messageType: messageType,
    groupId: groupId,
    fileMetadata: fileMetadata ?? this.fileMetadata,
    retryCount: retryCount ?? this.retryCount,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
  );
}
