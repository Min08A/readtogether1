import 'book.dart';

enum RoomPrivacy {
  friends('Friends', 'Только друзья'),
  inviteOnly('InviteOnly', 'Только по приглашению');

  const RoomPrivacy(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static RoomPrivacy fromDb(String v) => RoomPrivacy.values
      .firstWhere((p) => p.dbValue == v, orElse: () => RoomPrivacy.friends);
}

enum MemberStatus {
  invited('Invited'),
  joined('Joined'),
  declined('Declined');

  const MemberStatus(this.dbValue);
  final String dbValue;

  static MemberStatus fromDb(String v) => MemberStatus.values
      .firstWhere((s) => s.dbValue == v, orElse: () => MemberStatus.invited);
}

/// Таблица reading_rooms + книга + создатель.
class ReadingRoom {
  final int id;
  final Book book;
  final int creatorId;
  final String creatorName;
  final String name;
  final RoomPrivacy privacy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Цель комнаты: дочитать книгу к этой дате (необязательно).
  final DateTime? targetDate;

  /// Количество участников (без отклонивших приглашение).
  final int memberCount;

  const ReadingRoom({
    required this.id,
    required this.book,
    required this.creatorId,
    required this.creatorName,
    required this.name,
    required this.privacy,
    required this.createdAt,
    required this.updatedAt,
    this.targetDate,
    required this.memberCount,
  });

  /// Ожидаемый прогресс (0–100) на сегодня, если задана цель.
  int? get expectedProgress {
    final target = targetDate;
    if (target == null) return null;
    final total = target.difference(createdAt).inMinutes;
    if (total <= 0) return 100;
    final passed = DateTime.now().difference(createdAt).inMinutes;
    return ((passed / total) * 100).round().clamp(0, 100).toInt();
  }

  /// Дней до цели (может быть отрицательным, если срок прошёл).
  int? get daysLeft {
    final target = targetDate;
    if (target == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(target.year, target.month, target.day);
    return day.difference(today).inDays;
  }

  factory ReadingRoom.fromJoinedMap(Map<String, Object?> map) {
    final target = map['room_target_date'] as String?;
    return ReadingRoom(
      id: map['room_id'] as int,
      book: Book.fromMap(map),
      creatorId: map['creator_id'] as int,
      creatorName: (map['creator_name'] as String?) ?? '',
      name: map['room_name'] as String,
      privacy: RoomPrivacy.fromDb(map['privacy'] as String),
      createdAt: DateTime.parse(map['room_created_at'] as String),
      updatedAt: DateTime.parse(map['room_updated_at'] as String),
      targetDate: target == null ? null : DateTime.parse(target),
      memberCount: (map['member_count'] as int?) ?? 0,
    );
  }
}

/// Темп участника относительно цели комнаты.
enum PaceStatus { ahead, onTrack, behind, unknown }

/// Таблица room_members + имя пользователя.
class RoomMember {
  final int id;
  final int roomId;
  final int userId;
  final String userName;
  final MemberStatus status;
  final int progressPercent;

  const RoomMember({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.status,
    required this.progressPercent,
  });

  /// Текущая страница участника в книге из [pages] страниц.
  int pageIn(int pages) =>
      ((progressPercent / 100) * pages).round().clamp(1, pages).toInt();

  PaceStatus paceFor(ReadingRoom room) {
    final expected = room.expectedProgress;
    if (expected == null) return PaceStatus.unknown;
    if (progressPercent >= 100 || progressPercent >= expected + 5) {
      return PaceStatus.ahead;
    }
    if (progressPercent >= expected - 5) return PaceStatus.onTrack;
    return PaceStatus.behind;
  }

  factory RoomMember.fromMap(Map<String, Object?> map) => RoomMember(
        id: map['member_id'] as int,
        roomId: map['room_id'] as int,
        userId: map['user_id'] as int,
        userName: map['name'] as String,
        status: MemberStatus.fromDb(map['status'] as String),
        progressPercent: (map['progress_percent'] as int?) ?? 0,
      );
}

/// Тип сообщения в комнате.
class MessageKind {
  MessageKind._();
  static const text = 'text';

  /// «Вопрос к главе» — выделяется в обсуждении.
  static const question = 'question';
}

/// Количество одинаковых реакций под сообщением.
class ReactionCount {
  final String emoji;
  final int count;
  final bool mine;
  const ReactionCount(this.emoji, this.count, this.mine);
}

/// Таблица messages + имя автора + реакции.
class RoomMessage {
  final int id;
  final int roomId;
  final int userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  /// Глава, к которой относится сообщение (для защиты от спойлеров).
  final int? chapterNumber;
  final int? pageNumber;

  /// Цитата из книги, если сообщение отправлено из читалки.
  final String? quote;
  final String kind;
  final List<ReactionCount> reactions;

  const RoomMessage({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
    this.chapterNumber,
    this.pageNumber,
    this.quote,
    this.kind = MessageKind.text,
    this.reactions = const [],
  });

  bool get isQuestion => kind == MessageKind.question;

  RoomMessage withReactions(List<ReactionCount> r) => RoomMessage(
        id: id,
        roomId: roomId,
        userId: userId,
        userName: userName,
        text: text,
        createdAt: createdAt,
        chapterNumber: chapterNumber,
        pageNumber: pageNumber,
        quote: quote,
        kind: kind,
        reactions: r,
      );

  factory RoomMessage.fromMap(Map<String, Object?> map) => RoomMessage(
        id: map['message_id'] as int,
        roomId: map['room_id'] as int,
        userId: map['user_id'] as int,
        userName: map['name'] as String,
        text: map['text'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        chapterNumber: map['chapter_number'] as int?,
        pageNumber: map['page_number'] as int?,
        quote: map['quote'] as String?,
        kind: (map['kind'] as String?) ?? MessageKind.text,
      );
}

/// «Огонёк» — серия дней подряд (как в TikTok).
class StreakInfo {
  /// Сколько дней подряд серия продолжается.
  final int days;

  /// true — сегодня серия уже продлена; false — серия под угрозой
  /// (нужно почитать сегодня, иначе огонёк погаснет).
  final bool activeToday;

  const StreakInfo(this.days, this.activeToday);

  static const none = StreakInfo(0, false);

  bool get isAlive => days > 0;
}

/// Карточка комнаты для списка «Мои Reading Rooms».
class RoomSummary {
  final ReadingRoom room;
  final List<RoomMember> members;
  final RoomMessage? lastMessage;
  final int unread;
  final StreakInfo streak;
  final int myProgress;

  const RoomSummary({
    required this.room,
    required this.members,
    this.lastMessage,
    required this.unread,
    required this.streak,
    required this.myProgress,
  });
}
