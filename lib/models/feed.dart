/// Типы событий ленты активности (activities.type).
class ActivityType {
  ActivityType._();
  static const startedReading = 'started_reading';
  static const finished = 'finished';
  static const addedNote = 'added_note';
  static const addedBookmark = 'added_bookmark';
  static const addedBook = 'added_book';
  static const joinedRoom = 'joined_room';

  /// Сессия чтения — используется для статистики (график по дням, серия).
  static const readingSession = 'reading_session';
}

/// Типы уведомлений (notifications.type).
class NotificationType {
  NotificationType._();
  static const roomInvite = 'room_invite';
  static const friendAdded = 'friend_added';
  static const friendRequest = 'friend_request';
  static const comment = 'comment';
  static const recommendation = 'recommendation';
  static const achievement = 'achievement';

  /// «Поторопить» — напоминание отстающему участнику комнаты.
  static const nudge = 'nudge';
}

/// Событие activities + имя пользователя + книга.
class ActivityItem {
  final int id;
  final int userId;
  final String userName;
  final int? bookId;
  final String? bookTitle;
  final String? bookCover;
  final String type;
  final DateTime createdAt;

  const ActivityItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.bookId,
    this.bookTitle,
    this.bookCover,
    required this.type,
    required this.createdAt,
  });

  /// Глагол действия для ленты с учётом рода по имени:
  /// «Daniyar начал читать», «Alina дочитала».
  String get verb {
    final f = _looksFeminine(userName);
    switch (type) {
      case ActivityType.startedReading:
        return f ? 'начала читать' : 'начал читать';
      case ActivityType.finished:
        return f ? 'дочитала' : 'дочитал';
      case ActivityType.addedNote:
        return f ? 'добавила заметку в' : 'добавил заметку в';
      case ActivityType.addedBookmark:
        return f ? 'добавила закладку в' : 'добавил закладку в';
      case ActivityType.addedBook:
        return f ? 'загрузила книгу' : 'загрузил книгу';
      case ActivityType.joinedRoom:
        return f ? 'присоединилась к комнате по книге' : 'присоединился к комнате по книге';
      default:
        return f ? 'читала' : 'читал';
    }
  }

  /// Упрощённое определение рода по окончанию имени (Amina, Alina, Maria).
  static bool _looksFeminine(String name) {
    final n = name.trim().toLowerCase();
    return n.endsWith('a') || n.endsWith('а') || n.endsWith('я');
  }

  factory ActivityItem.fromMap(Map<String, Object?> map) => ActivityItem(
        id: map['activity_id'] as int,
        userId: map['user_id'] as int,
        userName: (map['name'] as String?) ?? '',
        bookId: map['book_id'] as int?,
        bookTitle: map['title'] as String?,
        bookCover: map['cover_url'] as String?,
        type: map['type'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// Уведомление notifications + имя автора.
class NotificationItem {
  final int id;
  final int userId;
  final int? actorId;
  final String? actorName;
  final int? roomId;
  final int? bookId;
  final String? bookTitle;
  final String type;
  final String text;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    this.actorId,
    this.actorName,
    this.roomId,
    this.bookId,
    this.bookTitle,
    required this.type,
    required this.text,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromMap(Map<String, Object?> map) =>
      NotificationItem(
        id: map['notification_id'] as int,
        userId: map['user_id'] as int,
        actorId: map['actor_id'] as int?,
        actorName: map['actor_name'] as String?,
        roomId: map['room_id'] as int?,
        bookId: map['book_id'] as int?,
        bookTitle: map['book_title'] as String?,
        type: map['type'] as String,
        text: (map['text'] as String?) ?? '',
        isRead: (map['is_read'] as int? ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
