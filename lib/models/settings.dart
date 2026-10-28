/// Варианты видимости для настроек приватности.
enum Visibility3 {
  everyone('Everyone', 'Все'),
  friends('Friends', 'Друзья'),
  nobody('Nobody', 'Никто');

  const Visibility3(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static Visibility3 fromDb(String? v) => Visibility3.values
      .firstWhere((e) => e.dbValue == v, orElse: () => Visibility3.friends);
}

/// Таблица privacy_settings.
class PrivacySettings {
  final int userId;
  final Visibility3 profileVisibility;
  final Visibility3 libraryVisibility;
  final Visibility3 activityVisibility;
  final Visibility3 roomInvitesFrom;

  const PrivacySettings({
    required this.userId,
    required this.profileVisibility,
    required this.libraryVisibility,
    required this.activityVisibility,
    required this.roomInvitesFrom,
  });

  factory PrivacySettings.fromMap(Map<String, Object?> m) => PrivacySettings(
        userId: m['user_id'] as int,
        profileVisibility: Visibility3.fromDb(m['profile_visibility'] as String?),
        libraryVisibility: Visibility3.fromDb(m['library_visibility'] as String?),
        activityVisibility:
            Visibility3.fromDb(m['activity_visibility'] as String?),
        roomInvitesFrom: Visibility3.fromDb(m['room_invites_from'] as String?),
      );
}

/// Таблица user_preferences.
class UserPreferences {
  final int userId;
  final String theme;
  final String language;
  final bool pushEnabled;
  final bool emailEnabled;
  final List<String> favoriteGenres;

  const UserPreferences({
    required this.userId,
    required this.theme,
    required this.language,
    required this.pushEnabled,
    required this.emailEnabled,
    required this.favoriteGenres,
  });

  factory UserPreferences.fromMap(Map<String, Object?> m) {
    final genres = (m['favorite_genres'] as String?) ?? '';
    return UserPreferences(
      userId: m['user_id'] as int,
      theme: (m['theme'] as String?) ?? 'Light (System)',
      language: (m['language'] as String?) ?? 'ru',
      pushEnabled: (m['push_enabled'] as int? ?? 1) == 1,
      emailEnabled: (m['email_enabled'] as int? ?? 0) == 1,
      favoriteGenres: genres
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList(),
    );
  }
}

enum ReaderTheme {
  light('light', 'Светлая'),
  sepia('sepia', 'Сепия'),
  dark('dark', 'Тёмная');

  const ReaderTheme(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static ReaderTheme fromDb(String? v) => ReaderTheme.values
      .firstWhere((t) => t.dbValue == v, orElse: () => ReaderTheme.sepia);
}

/// Таблица reader_settings.
class ReaderSettings {
  final int userId;
  final String fontFamily;
  final int fontSize;
  final double lineSpacing;
  final ReaderTheme readerTheme;

  const ReaderSettings({
    required this.userId,
    required this.fontFamily,
    required this.fontSize,
    required this.lineSpacing,
    required this.readerTheme,
  });

  ReaderSettings copyWith({
    String? fontFamily,
    int? fontSize,
    double? lineSpacing,
    ReaderTheme? readerTheme,
  }) =>
      ReaderSettings(
        userId: userId,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSize: fontSize ?? this.fontSize,
        lineSpacing: lineSpacing ?? this.lineSpacing,
        readerTheme: readerTheme ?? this.readerTheme,
      );

  factory ReaderSettings.fromMap(Map<String, Object?> m) => ReaderSettings(
        userId: m['user_id'] as int,
        fontFamily: (m['font_family'] as String?) ?? 'Inter',
        fontSize: (m['font_size'] as int?) ?? 16,
        lineSpacing: (m['line_spacing'] as num?)?.toDouble() ?? 1.5,
        readerTheme: ReaderTheme.fromDb(m['reader_theme'] as String?),
      );
}
