import 'package:sqflite/sqflite.dart';

import '../../models/feed.dart';
import '../../services/data_bus.dart';
import '../database_helper.dart';

/// Работа с таблицей notifications.
class NotificationRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<NotificationItem>> list(int userId) async {
    final rows = await (await _db).rawQuery('''
      SELECT n.*, u.name AS actor_name, b.title AS book_title FROM notifications n
      LEFT JOIN users u ON u.user_id = n.actor_id
      LEFT JOIN books b ON b.book_id = n.book_id
      WHERE n.user_id = ? ORDER BY n.created_at DESC''', [userId]);
    return rows.map(NotificationItem.fromMap).toList();
  }

  Future<int> unreadCount(int userId) async {
    final rows = await (await _db).rawQuery(
        'SELECT COUNT(*) AS c FROM notifications WHERE user_id = ? AND is_read = 0',
        [userId]);
    return rows.first['c'] as int;
  }

  Future<void> markRead(int notificationId) async {
    await (await _db).update('notifications', {'is_read': 1},
        where: 'notification_id = ?', whereArgs: [notificationId]);
    DataBus.instance.changed();
  }

  Future<void> markAllRead(int userId) async {
    await (await _db).update('notifications', {'is_read': 1},
        where: 'user_id = ?', whereArgs: [userId]);
    DataBus.instance.changed();
  }

  Future<void> delete(int notificationId) async {
    await (await _db).delete('notifications',
        where: 'notification_id = ?', whereArgs: [notificationId]);
    DataBus.instance.changed();
  }
}
