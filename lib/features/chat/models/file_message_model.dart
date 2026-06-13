class FileMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String? groupId;
  final String fileName;
  final String fileType;
  final int fileSize;
  String filePath;
  final DateTime timestamp;
  bool read;
  bool edited;
  DateTime? editedAt;

  FileMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.groupId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.filePath,
    required this.timestamp,
    this.read = false,
    this.edited = false,
    this.editedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'senderId': senderId,
    'receiverId': receiverId,
    'groupId': groupId,
    'fileName': fileName,
    'fileType': fileType,
    'fileSize': fileSize,
    'filePath': filePath,
    'timestamp': timestamp.toIso8601String(),
    'read': read,
    'edited': edited,
    'editedAt': editedAt?.toIso8601String(),
  };

  factory FileMessage.fromJson(Map<String, dynamic> json) => FileMessage(
    id: json['id'],
    senderId: json['senderId'],
    receiverId: json['receiverId'],
    groupId: json['groupId'],
    fileName: json['fileName'],
    fileType: json['fileType'],
    fileSize: json['fileSize'],
    filePath: json['filePath'],
    timestamp: DateTime.parse(json['timestamp']),
    read: json['read'] ?? false,
    edited: json['edited'] ?? false,
    editedAt: json['editedAt'] != null ? DateTime.parse(json['editedAt']) : null,
  );
}
