class Group {
  final String id;
  final String name;
  String adminId;
  final List<String> memberIds;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.adminId,
    required this.memberIds,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'adminId': adminId,
    'memberIds': memberIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Group.fromJson(Map<String, dynamic> json) => Group(
    id: json['id'],
    name: json['name'],
    adminId: json['adminId'],
    memberIds: List<String>.from(json['memberIds']),
    createdAt: DateTime.parse(json['createdAt']),
  );
}
