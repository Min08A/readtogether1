/// Таблица users.
class AppUser {
  final int id;
  final String name;
  final String email;
  final String passwordHash;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
  });

  /// Первая буква имени для круглого аватара.
  String get initial => name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
        id: map['user_id'] as int,
        name: map['name'] as String,
        email: map['email'] as String,
        passwordHash: map['password_hash'] as String,
        avatarUrl: map['avatar_url'] as String?,
        bio: map['bio'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
