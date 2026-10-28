import 'package:sqflite/sqflite.dart';

import '../repos.dart';
import '../../models/feed.dart';
import '../../models/reading_room.dart';
import '../../services/data_bus.dart';
import '../database_helper.dart';

/// Работа с таблицами reading_rooms, room_members, messages,
/// message_reactions.
class RoomRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  static const reactionEmojis = ['👍', '❤️', '😂', '😮', '🔥'];

  static const _selectRoom = '''
    SELECT r.room_id, r.creator_id, r.name AS room_name, r.privacy,
           r.target_date AS room_target_date,
           r.created_at AS room_created_at, r.updated_at AS room_updated_at,
           b.*, u.name AS creator_name,
           (SELECT COUNT(*) FROM room_members m
             WHERE m.room_id = r.room_id AND m.status <> 'Declined') AS member_count
    FROM reading_rooms r
    JOIN books b ON b.book_id = r.book_id
    JOIN users u ON u.user_id = r.creator_id''';

  Future<ReadingRoom?> room(int roomId) async {
    final rows = await (await _db)
        .rawQuery('$_selectRoom WHERE r.room_id = ? LIMIT 1', [roomId]);
    return rows.isEmpty ? null : ReadingRoom.fromJoinedMap(rows.first);
  }

  /// Комнаты, в которых пользователь участвует (опционально — по книге).
  Future<List<ReadingRoom>> joinedRooms(int userId, {int? bookId}) async {
    final rows = await (await _db).rawQuery('''
      $_selectRoom WHERE r.room_id IN
        (SELECT room_id FROM room_members WHERE user_id = ? AND status = 'Joined')
      ${bookId == null ? '' : 'AND r.book_id = ?'}
      ORDER BY r.updated_at DESC''', [userId, if (bookId != null) bookId]);
    return rows.map(ReadingRoom.fromJoinedMap).toList();
  }

  /// Комнаты, куда пользователя пригласили, но он ещё не ответил.
  Future<List<ReadingRoom>> pendingInvites(int userId) async {
    final rows = await (await _db).rawQuery('''
      $_selectRoom WHERE r.room_id IN
        (SELECT room_id FROM room_members WHERE user_id = ? AND status = 'Invited')
      ORDER BY r.created_at DESC''', [userId]);
    return rows.map(ReadingRoom.fromJoinedMap).toList();
  }

  /// Карточки «Мои Reading Rooms»: участники, последнее сообщение,
  /// непрочитанные, огонёк комнаты.
  Future<List<RoomSummary>> summaries(int userId) async {
    final rooms = await joinedRooms(userId);
    final streaks = Repos.streaks;
    final result = <RoomSummary>[];
    for (final room in rooms) {
      final members = await this.members(room.id);
      final last = await lastMessage(room.id);
      final me = members.where((m) => m.userId == userId);
      result.add(RoomSummary(
        room: room,
        members: members,
        lastMessage: last,
        unread: await unreadCount(room.id, userId),
        streak: await streaks.room(room.id),
        myProgress: me.isEmpty ? 0 : me.first.progressPercent,
      ));
    }
    return result;
  }

  Future<int> totalUnread(int userId) async {
    final rooms = await joinedRooms(userId);
    var total = 0;
    for (final r in rooms) {
      total += await unreadCount(r.id, userId);
    }
    return total;
  }

  Future<List<RoomMember>> members(int roomId, {bool joinedOnly = true}) async {
    final rows = await (await _db).rawQuery('''
      SELECT m.*, u.name FROM room_members m
      JOIN users u ON u.user_id = m.user_id
      WHERE m.room_id = ? ${joinedOnly ? "AND m.status = 'Joined'" : "AND m.status <> 'Declined'"}
      ORDER BY m.member_id''', [roomId]);
    return rows.map(RoomMember.fromMap).toList();
  }

  Future<MemberStatus?> membership(int roomId, int userId) async {
    final rows = await (await _db).query('room_members',
        columns: ['status'],
        where: 'room_id = ? AND user_id = ?',
        whereArgs: [roomId, userId],
        limit: 1);
    return rows.isEmpty
        ? null
        : MemberStatus.fromDb(rows.first['status'] as String);
  }

  // ---------------- сообщения ----------------

  /// Сообщения комнаты с реакциями (viewerId — чтобы отметить «мои»).
  Future<List<RoomMessage>> messages(int roomId, {int? viewerId}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT msg.*, u.name FROM messages msg
      JOIN users u ON u.user_id = msg.user_id
      WHERE msg.room_id = ? ORDER BY msg.created_at''', [roomId]);
    final reactions = await db.rawQuery('''
      SELECT r.message_id, r.emoji, COUNT(*) AS c,
             SUM(CASE WHEN r.user_id = ? THEN 1 ELSE 0 END) AS mine
      FROM message_reactions r
      JOIN messages msg ON msg.message_id = r.message_id
      WHERE msg.room_id = ?
      GROUP BY r.message_id, r.emoji
      ORDER BY MIN(r.created_at)''', [viewerId ?? -1, roomId]);
    final byMessage = <int, List<ReactionCount>>{};
    for (final r in reactions) {
      byMessage.putIfAbsent(r['message_id'] as int, () => []).add(
          ReactionCount(r['emoji'] as String, (r['c'] as num).toInt(),
              ((r['mine'] as num?) ?? 0) > 0));
    }
    return rows.map((m) {
      final msg = RoomMessage.fromMap(m);
      return msg.withReactions(byMessage[msg.id] ?? const []);
    }).toList();
  }

  Future<RoomMessage?> lastMessage(int roomId) async {
    final rows = await (await _db).rawQuery('''
      SELECT msg.*, u.name FROM messages msg
      JOIN users u ON u.user_id = msg.user_id
      WHERE msg.room_id = ? ORDER BY msg.created_at DESC LIMIT 1''', [roomId]);
    return rows.isEmpty ? null : RoomMessage.fromMap(rows.first);
  }

  Future<int> sendMessage(
    int roomId,
    int userId,
    String text, {
    int? chapter,
    int? page,
    String? quote,
    String kind = MessageKind.text,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final id = await db.insert('messages', {
      'room_id': roomId,
      'user_id': userId,
      'text': text.trim(),
      'chapter_number': chapter,
      'page_number': page,
      'quote': quote,
      'kind': kind,
      'created_at': now,
    });
    await db.update('reading_rooms', {'updated_at': now},
        where: 'room_id = ?', whereArgs: [roomId]);
    // Своё сообщение считается прочитанным.
    await db.update('room_members', {'last_read_at': now},
        where: 'room_id = ? AND user_id = ?', whereArgs: [roomId, userId]);
    DataBus.instance.changed();
    return id;
  }

  /// Отметить обсуждение комнаты прочитанным.
  Future<void> markRead(int roomId, int userId) async {
    await (await _db).update(
        'room_members', {'last_read_at': DateTime.now().toIso8601String()},
        where: 'room_id = ? AND user_id = ?', whereArgs: [roomId, userId]);
  }

  Future<int> unreadCount(int roomId, int userId) async {
    final rows = await (await _db).rawQuery('''
      SELECT COUNT(*) AS c FROM messages msg
      WHERE msg.room_id = ? AND msg.user_id <> ? AND msg.created_at >
        COALESCE((SELECT last_read_at FROM room_members
                  WHERE room_id = ? AND user_id = ?), '')''',
        [roomId, userId, roomId, userId]);
    return (rows.first['c'] as num).toInt();
  }

  /// Поставить / снять реакцию. Возвращает true, если реакция добавлена.
  Future<bool> toggleReaction(int messageId, int userId, String emoji) async {
    final db = await _db;
    final removed = await db.delete('message_reactions',
        where: 'message_id = ? AND user_id = ? AND emoji = ?',
        whereArgs: [messageId, userId, emoji]);
    if (removed == 0) {
      await db.insert('message_reactions', {
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
    DataBus.instance.changed();
    return removed == 0;
  }

  // ---------------- комнаты ----------------

  /// Экран Create Room: комната + создатель (Joined) + приглашённые (Invited)
  /// + уведомления приглашённым.
  Future<int> createRoom({
    required int creatorId,
    required int bookId,
    required String name,
    required RoomPrivacy privacy,
    required List<int> inviteeIds,
    DateTime? targetDate,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final roomId = await db.transaction((txn) async {
      final id = await txn.insert('reading_rooms', {
        'book_id': bookId,
        'creator_id': creatorId,
        'name': name.trim(),
        'privacy': privacy.dbValue,
        'target_date': targetDate?.toIso8601String(),
        'created_at': now,
        'updated_at': now,
      });
      Future<int> progressOf(int userId) async {
        final rows = await txn.query('library',
            columns: ['progress_percent'],
            where: 'user_id = ? AND book_id = ?',
            whereArgs: [userId, bookId],
            limit: 1);
        return rows.isEmpty ? 0 : (rows.first['progress_percent'] as int);
      }

      await txn.insert('room_members', {
        'room_id': id,
        'user_id': creatorId,
        'status': MemberStatus.joined.dbValue,
        'progress_percent': await progressOf(creatorId),
        'joined_at': now,
        'last_read_at': now,
      });
      for (final invitee in inviteeIds) {
        await txn.insert('room_members', {
          'room_id': id,
          'user_id': invitee,
          'status': MemberStatus.invited.dbValue,
          'progress_percent': await progressOf(invitee),
        });
        await txn.insert('notifications', {
          'user_id': invitee,
          'actor_id': creatorId,
          'room_id': id,
          'book_id': bookId,
          'type': NotificationType.roomInvite,
          'text': 'пригласил(а) вас в Reading Room',
          'is_read': 0,
          'created_at': now,
        });
      }
      return id;
    });
    DataBus.instance.changed();
    return roomId;
  }

  Future<void> setTargetDate(int roomId, DateTime? date) async {
    await (await _db).update(
        'reading_rooms', {'target_date': date?.toIso8601String()},
        where: 'room_id = ?', whereArgs: [roomId]);
    DataBus.instance.changed();
  }

  /// «Присоединиться» / «Отклонить» на экране приглашения.
  Future<void> respondToInvite(int roomId, int userId,
      {required bool accept}) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'room_members',
      {
        'status':
            accept ? MemberStatus.joined.dbValue : MemberStatus.declined.dbValue,
        'joined_at': accept ? now : null,
        'last_read_at': accept ? now : null,
      },
      where: 'room_id = ? AND user_id = ?',
      whereArgs: [roomId, userId],
    );
    await db.update('notifications', {'is_read': 1},
        where: 'user_id = ? AND room_id = ? AND type = ?',
        whereArgs: [userId, roomId, NotificationType.roomInvite]);
    if (accept) {
      final room = await this.room(roomId);
      await db.insert('activities', {
        'user_id': userId,
        'book_id': room?.book.id,
        'type': ActivityType.joinedRoom,
        'created_at': now,
      });
    }
    DataBus.instance.changed();
  }

  Future<void> leaveRoom(int roomId, int userId) async {
    await (await _db).delete('room_members',
        where: 'room_id = ? AND user_id = ?', whereArgs: [roomId, userId]);
    DataBus.instance.changed();
  }

  /// «Поторопить» участника: уведомление не чаще одного раза в день.
  /// Возвращает false, если сегодня уже напоминали.
  Future<bool> nudge(int roomId, int fromId, int toId, String bookTitle) async {
    final db = await _db;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final existing = await db.query('notifications',
        where:
            'user_id = ? AND actor_id = ? AND room_id = ? AND type = ? AND created_at >= ?',
        whereArgs: [toId, fromId, roomId, NotificationType.nudge, todayStart],
        limit: 1);
    if (existing.isNotEmpty) return false;
    await db.insert('notifications', {
      'user_id': toId,
      'actor_id': fromId,
      'room_id': roomId,
      'type': NotificationType.nudge,
      'text': 'напоминает: пора читать «$bookTitle» — в комнате вы отстаёте',
      'is_read': 0,
      'created_at': now.toIso8601String(),
    });
    DataBus.instance.changed();
    return true;
  }
}
