class UserStatus {
  final String userId;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool isTyping;
  final String? currentChatId;

  UserStatus({
    required this.userId,
    required this.isOnline,
    this.lastSeen,
    this.isTyping = false,
    this.currentChatId,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'isOnline': isOnline,
    'lastSeen': lastSeen?.toIso8601String(),
    'isTyping': isTyping,
    'currentChatId': currentChatId,
  };

  factory UserStatus.fromJson(Map<String, dynamic> json) => UserStatus(
    userId: json['userId'],
    isOnline: json['isOnline'],
    lastSeen:
    json['lastSeen'] != null ? DateTime.parse(json['lastSeen']) : null,
    isTyping: json['isTyping'] ?? false,
    currentChatId: json['currentChatId'],
  );
}
