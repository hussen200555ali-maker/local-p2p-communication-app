class User {
  final String id;
  String username;
  String? avatarUrl;
  String? profileImage;
  String? bio;

  User({required this.id, required this.username, this.avatarUrl, this.profileImage, this.bio});

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'avatarUrl': avatarUrl,
        'profileImage': profileImage,
        'bio': bio,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        username: json['username'],
        avatarUrl: json['avatarUrl'],
        profileImage: json['profileImage'],
        bio: json['bio'],
      );
}
