class Message {
  final String id;
  final String senderId;
  final String receiverId;
   String content;
  final DateTime timestamp;
  bool read;
  bool edited;
  DateTime? editedAt;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.read = false,
    this.edited = false,
    this.editedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'read': read,
    'edited': edited,
    'editedAt': editedAt?.toIso8601String(),
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'],
    senderId: json['senderId'],
    receiverId: json['receiverId'],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    read: json['read'] is bool ? json['read'] : (json['read'] ?? 0) == 1,
    edited: json['edited'] is bool ? json['edited'] : (json['edited'] ?? 0) == 1,
    editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt']) : null,
  );
}
