import 'package:sqflite/sqflite.dart';

import '../../models/feed.dart';
import '../../models/reading_room.dart';
import '../database_helper.dart';

/// «Огоньки» — серии дней подряд, как в TikTok.
///
/// * Личная серия: дни подряд, когда пользователь читал.
/// * Серия с другом: дни подряд, когда читали ОБА (сессия чтения или
///   сообщение в комнате). Если сегодня ещё не читал кто-то из двоих —
///   огонёк «под угрозой» (серый), если пропущен целый день — гаснет.
/// * Серия комнаты: дни подряд, когда книгу комнаты читали минимум двое.
class StreakRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Дни активности пользователя (YYYY-MM-DD) за последние 400 дней.
  Future<Set<String>> _activeDays(int userId, {int? bookId}) async {
    final db = await _db;
    final since = DateTime.now()
        .subtract(const Duration(days: 400))
        .toIso8601String();
    final sessions = await db.rawQuery(
      'SELECT DISTINCT substr(created_at, 1, 10) AS day FROM activities '
      'WHERE user_id = ? AND type = ? AND created_at >= ? '
      '${bookId == null ? '' : 'AND book_id = ?'}',
      [userId, ActivityType.readingSession, since, if (bookId != null) bookId],
    );
    final days = sessions.map((r) => r['day'] as String).toSet();
    if (bookId == null) {
      final messages = await db.rawQuery(
        'SELECT DISTINCT substr(created_at, 1, 10) AS day FROM messages '
        'WHERE user_id = ? AND created_at >= ?',
        [userId, since],
      );
      days.addAll(messages.map((r) => r['day'] as String));
    }
    return days;
  }

  /// Считает серию по набору дней: от сегодня (или вчера) назад без пропусков.
  static StreakInfo fromDays(Set<String> days) {
    var cursor = DateTime.now();
    final activeToday = days.contains(dayKey(cursor));
    if (!activeToday) cursor = cursor.subtract(const Duration(days: 1));
    var count = 0;
    while (days.contains(dayKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count == 0 ? StreakInfo.none : StreakInfo(count, activeToday);
  }

  Future<StreakInfo> personal(int userId) async =>
      fromDays(await _activeDays(userId));

  /// Совместная серия двух друзей.
  Future<StreakInfo> withFriend(int userId, int friendId) async {
    final mine = await _activeDays(userId);
    final theirs = await _activeDays(friendId);
    return fromDays(mine.intersection(theirs));
  }

  /// Серии со всеми друзьями сразу: friendId → серия.
  Future<Map<int, StreakInfo>> withFriends(
      int userId, Iterable<int> friendIds) async {
    final mine = await _activeDays(userId);
    final result = <int, StreakInfo>{};
    for (final id in friendIds) {
      result[id] = fromDays(mine.intersection(await _activeDays(id)));
    }
    return result;
  }

  /// Серия комнаты: дни, когда книгу читали хотя бы двое участников.
  Future<StreakInfo> room(int roomId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT r.book_id AS book_id, m.user_id AS user_id
      FROM reading_rooms r JOIN room_members m ON m.room_id = r.room_id
      WHERE r.room_id = ? AND m.status = 'Joined' ''', [roomId]);
    if (rows.length < 2) return StreakInfo.none;
    final bookId = rows.first['book_id'] as int;
    final counts = <String, int>{};
    for (final r in rows) {
      final days = await _activeDays(r['user_id'] as int, bookId: bookId);
      for (final d in days) {
        counts[d] = (counts[d] ?? 0) + 1;
      }
    }
    final together =
        counts.entries.where((e) => e.value >= 2).map((e) => e.key).toSet();
    return fromDays(together);
  }
}
