class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String content;
  final DateTime timestamp;
  bool edited;
  DateTime? editedAt;

  GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.content,
    required this.timestamp,
    this.edited = false,
    this.editedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'senderId': senderId,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'edited': edited,
    'editedAt': editedAt?.toIso8601String(),
  };

  factory GroupMessage.fromJson(Map<String, dynamic> json) => GroupMessage(
    id: json['id'],
    groupId: json['groupId'],
    senderId: json['senderId'],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    edited: json['edited'] ?? false,
    editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt']) : null,
  );
}
