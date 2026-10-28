import 'package:sqflite/sqflite.dart';

import '../../models/app_user.dart';
import '../../models/feed.dart';
import '../../models/library_entry.dart';
import '../../models/social.dart';
import '../../services/data_bus.dart';
import '../database_helper.dart';

/// Работа с таблицами friendships и activities.
class SocialRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Подзапрос: id друзей пользователя (статус Accepted).
  static const _friendIds = '''
    SELECT CASE WHEN f.user_id_1 = ? THEN f.user_id_2 ELSE f.user_id_1 END
    FROM friendships f
    WHERE f.status = 'Accepted' AND (f.user_id_1 = ? OR f.user_id_2 = ?)''';

  /// Друзья + книга, которую каждый читает сейчас.
  Future<List<FriendWithBook>> friends(int userId, {String query = ''}) async {
    final db = await _db;
    final q = query.trim().toLowerCase();
    final users = await db.rawQuery(
      'SELECT u.* FROM users u WHERE u.user_id IN ($_friendIds) '
      '${q.isEmpty ? '' : 'AND LOWER(u.name) LIKE ?'} ORDER BY u.user_id',
      [userId, userId, userId, if (q.isNotEmpty) '%$q%'],
    );
    final result = <FriendWithBook>[];
    for (final row in users) {
      final user = AppUser.fromMap(row);
      final reading = await db.rawQuery('''
        SELECT l.*, b.* FROM library l JOIN books b ON b.book_id = l.book_id
        WHERE l.user_id = ? AND l.status = 'Reading'
        ORDER BY l.updated_at DESC LIMIT 1''', [user.id]);
      result.add(FriendWithBook(
        user: user,
        currentBook:
            reading.isEmpty ? null : LibraryEntry.fromJoinedMap(reading.first),
      ));
    }
    return result;
  }

  Future<List<FriendRequest>> incomingRequests(int userId) async {
    final rows = await (await _db).rawQuery('''
      SELECT f.friendship_id, u.* FROM friendships f
      JOIN users u ON u.user_id = f.user_id_1
      WHERE f.user_id_2 = ? AND f.status = 'Pending'
      ORDER BY f.created_at DESC''', [userId]);
    return rows
        .map((r) => FriendRequest(
            friendshipId: r['friendship_id'] as int, from: AppUser.fromMap(r)))
        .toList();
  }

  Future<void> respondToRequest(int friendshipId, {required bool accept}) async {
    await (await _db).update(
      'friendships',
      {'status': accept ? 'Accepted' : 'Declined'},
      where: 'friendship_id = ?',
      whereArgs: [friendshipId],
    );
    DataBus.instance.changed();
  }

  /// Принять входящий запрос от конкретного пользователя.
  Future<void> acceptFrom(int userId, int fromId) async {
    await (await _db).update('friendships', {'status': 'Accepted'},
        where: "user_id_1 = ? AND user_id_2 = ? AND status = 'Pending'",
        whereArgs: [fromId, userId]);
    DataBus.instance.changed();
  }

  Future<FriendState> stateWith(int userId, int otherId) async {
    final rows = await (await _db).query('friendships',
        where: '(user_id_1 = ? AND user_id_2 = ?) OR (user_id_1 = ? AND user_id_2 = ?)',
        whereArgs: [userId, otherId, otherId, userId],
        limit: 1);
    if (rows.isEmpty) return FriendState.none;
    final row = rows.first;
    switch (row['status']) {
      case 'Accepted':
        return FriendState.friends;
      case 'Pending':
        return row['user_id_1'] == userId
            ? FriendState.outgoingPending
            : FriendState.incomingPending;
      default:
        return FriendState.none;
    }
  }

  /// Поиск пользователей по имени или email (экран Search Users).
  /// Друзья в выдачу не попадают.
  Future<List<UserSearchResult>> searchUsers(int userId, String query) async {
    final q = query.trim().toLowerCase();
    final rows = await (await _db).rawQuery(
      'SELECT u.* FROM users u WHERE u.user_id <> ? '
      'AND u.user_id NOT IN ($_friendIds) '
      '${q.isEmpty ? '' : 'AND (LOWER(u.name) LIKE ? OR LOWER(u.email) LIKE ?)'} '
      'ORDER BY u.name',
      [userId, userId, userId, userId, if (q.isNotEmpty) ...['%$q%', '%$q%']],
    );
    final result = <UserSearchResult>[];
    for (final r in rows) {
      final user = AppUser.fromMap(r);
      result.add(UserSearchResult(
          user: user, state: await stateWith(userId, user.id)));
    }
    return result;
  }

  /// Кнопка «Добавить»: создаёт запись Pending в friendships.
  Future<void> sendRequest(int fromId, int toId) async {
    final db = await _db;
    final existing = await db.query('friendships',
        where: '(user_id_1 = ? AND user_id_2 = ?) OR (user_id_1 = ? AND user_id_2 = ?)',
        whereArgs: [fromId, toId, toId, fromId],
        limit: 1);
    final now = DateTime.now().toIso8601String();
    if (existing.isEmpty) {
      await db.insert('friendships', {
        'user_id_1': fromId,
        'user_id_2': toId,
        'status': 'Pending',
        'created_at': now,
      });
    } else {
      // Ранее отклонённый запрос можно отправить заново.
      await db.update(
        'friendships',
        {
          'user_id_1': fromId,
          'user_id_2': toId,
          'status': 'Pending',
          'created_at': now,
        },
        where: 'friendship_id = ?',
        whereArgs: [existing.first['friendship_id']],
      );
    }
    DataBus.instance.changed();
  }

  Future<void> removeFriend(int userId, int friendId) async {
    await (await _db).delete('friendships',
        where: '(user_id_1 = ? AND user_id_2 = ?) OR (user_id_1 = ? AND user_id_2 = ?)',
        whereArgs: [userId, friendId, friendId, userId]);
    DataBus.instance.changed();
  }

  /// Лента друзей (экран «Активность»).
  Future<List<ActivityItem>> friendsActivity(int userId, {int limit = 30}) async {
    final rows = await (await _db).rawQuery('''
      SELECT a.*, u.name, b.title, b.cover_url FROM activities a
      JOIN users u ON u.user_id = a.user_id
      LEFT JOIN books b ON b.book_id = a.book_id
      WHERE a.user_id IN ($_friendIds) AND a.type <> ?
      ORDER BY a.created_at DESC LIMIT ?''',
        [userId, userId, userId, ActivityType.readingSession, limit]);
    return rows.map(ActivityItem.fromMap).toList();
  }

  /// Недавняя активность пользователя (экран «Мой профиль»).
  Future<List<ActivityItem>> userActivity(int userId, {int limit = 5}) async {
    final rows = await (await _db).rawQuery('''
      SELECT a.*, u.name, b.title, b.cover_url FROM activities a
      JOIN users u ON u.user_id = a.user_id
      LEFT JOIN books b ON b.book_id = a.book_id
      WHERE a.user_id = ? AND a.type <> ?
      ORDER BY a.created_at DESC LIMIT ?''',
        [userId, ActivityType.readingSession, limit]);
    return rows.map(ActivityItem.fromMap).toList();
  }
}
