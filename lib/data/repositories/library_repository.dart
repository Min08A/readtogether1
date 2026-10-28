import 'package:sqflite/sqflite.dart';

import '../../models/feed.dart';
import '../../models/library_entry.dart';
import '../../services/data_bus.dart';
import '../database_helper.dart';

class AlreadyInLibraryException implements Exception {
  final LibraryStatus status;
  AlreadyInLibraryException(this.status);
}

/// Работа с таблицей library (личная библиотека и прогресс чтения).
class LibraryRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  static const _select =
      'SELECT l.*, b.* FROM library l JOIN books b ON b.book_id = l.book_id';

  Future<List<LibraryEntry>> byStatus(int userId, LibraryStatus status) async {
    final rows = await (await _db).rawQuery(
      '$_select WHERE l.user_id = ? AND l.status = ? ORDER BY l.added_at',
      [userId, status.dbValue],
    );
    return rows.map(LibraryEntry.fromJoinedMap).toList();
  }

  Future<List<LibraryEntry>> all(int userId) async {
    final rows = await (await _db).rawQuery(
      '$_select WHERE l.user_id = ? ORDER BY l.updated_at DESC',
      [userId],
    );
    return rows.map(LibraryEntry.fromJoinedMap).toList();
  }

  Future<LibraryEntry?> entry(int userId, int bookId) async {
    final rows = await (await _db).rawQuery(
      '$_select WHERE l.user_id = ? AND l.book_id = ? LIMIT 1',
      [userId, bookId],
    );
    return rows.isEmpty ? null : LibraryEntry.fromJoinedMap(rows.first);
  }

  /// Книга для блока «Продолжить чтение» / «Сейчас читает».
  Future<LibraryEntry?> currentReading(int userId) async {
    final rows = await (await _db).rawQuery(
      '$_select WHERE l.user_id = ? AND l.status = ? '
      'ORDER BY (l.progress_percent > 0) DESC, l.updated_at DESC LIMIT 1',
      [userId, LibraryStatus.reading.dbValue],
    );
    return rows.isEmpty ? null : LibraryEntry.fromJoinedMap(rows.first);
  }

  /// Недавно законченные книги (профиль друга).
  Future<List<LibraryEntry>> recentlyFinished(int userId, {int limit = 6}) async {
    final rows = await (await _db).rawQuery(
      '$_select WHERE l.user_id = ? AND l.status = ? '
      'ORDER BY l.updated_at DESC LIMIT ?',
      [userId, LibraryStatus.finished.dbValue, limit],
    );
    return rows.map(LibraryEntry.fromJoinedMap).toList();
  }

  /// Количество книг по статусам (профиль, статистика).
  Future<Map<LibraryStatus, int>> counts(int userId) async {
    final rows = await (await _db).rawQuery(
      'SELECT status, COUNT(*) AS c FROM library WHERE user_id = ? GROUP BY status',
      [userId],
    );
    final result = {for (final s in LibraryStatus.values) s: 0};
    for (final r in rows) {
      result[LibraryStatus.fromDb(r['status'] as String)] = r['c'] as int;
    }
    return result;
  }

  /// «Добавить в библиотеку». Бросает исключение, если книга уже есть.
  Future<void> add(int userId, int bookId, LibraryStatus status) async {
    final existing = await entry(userId, bookId);
    if (existing != null) throw AlreadyInLibraryException(existing.status);
    final now = DateTime.now().toIso8601String();
    final db = await _db;
    await db.insert('library', {
      'user_id': userId,
      'book_id': bookId,
      'status': status.dbValue,
      'progress_percent': 0,
      'pages_read': 0,
      'added_at': now,
      'updated_at': now,
    });
    if (status == LibraryStatus.reading) {
      await _activity(db, userId, bookId, ActivityType.startedReading);
    }
    DataBus.instance.changed();
  }

  Future<void> updateStatus(
      int userId, int bookId, LibraryStatus status, int pages) async {
    final db = await _db;
    final values = <String, Object?>{
      'status': status.dbValue,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (status == LibraryStatus.finished) {
      values['progress_percent'] = 100;
      values['pages_read'] = pages;
    }
    await db.update('library', values,
        where: 'user_id = ? AND book_id = ?', whereArgs: [userId, bookId]);
    if (status == LibraryStatus.finished) {
      await _activity(db, userId, bookId, ActivityType.finished);
      await _syncRoomProgress(db, userId, bookId, 100);
    }
    DataBus.instance.changed();
  }

  Future<void> remove(int userId, int bookId) async {
    await (await _db).delete('library',
        where: 'user_id = ? AND book_id = ?', whereArgs: [userId, bookId]);
    DataBus.instance.changed();
  }

  /// Сохраняет текущую страницу читалки и пересчитывает прогресс.
  /// Если книги ещё нет в библиотеке — добавляет её со статусом «Читаю».
  /// Прогресс синхронизируется с участием в комнатах (room_members).
  Future<int> saveProgress(int userId, int bookId, int page, int pages,
      {bool notify = true}) async {
    final db = await _db;
    final percent = ((page / pages) * 100).round().clamp(0, 100).toInt();
    final now = DateTime.now().toIso8601String();
    final existing = await entry(userId, bookId);
    if (existing == null) {
      await db.insert('library', {
        'user_id': userId,
        'book_id': bookId,
        'status': LibraryStatus.reading.dbValue,
        'progress_percent': percent,
        'pages_read': page,
        'added_at': now,
        'updated_at': now,
      });
      await _activity(db, userId, bookId, ActivityType.startedReading);
    } else {
      final status = existing.status == LibraryStatus.planned
          ? LibraryStatus.reading
          : existing.status;
      await db.update(
        'library',
        {
          'status': status.dbValue,
          'progress_percent': percent,
          'pages_read': page,
          'updated_at': now,
        },
        where: 'library_id = ?',
        whereArgs: [existing.id],
      );
      if (existing.status == LibraryStatus.planned) {
        await _activity(db, userId, bookId, ActivityType.startedReading);
      }
    }
    await _syncRoomProgress(db, userId, bookId, percent);
    if (notify) DataBus.instance.changed();
    return percent;
  }

  /// Отмечает сессию чтения (для графика и серии дней в статистике).
  Future<void> logReadingSession(int userId, int bookId) async {
    await _activity(await _db, userId, bookId, ActivityType.readingSession);
  }

  Future<void> _syncRoomProgress(
      Database db, int userId, int bookId, int percent) async {
    await db.rawUpdate('''
      UPDATE room_members SET progress_percent = ?
      WHERE user_id = ? AND room_id IN (SELECT room_id FROM reading_rooms WHERE book_id = ?)''',
        [percent, userId, bookId]);
  }

  Future<void> _activity(
      Database db, int userId, int bookId, String type) async {
    await db.insert('activities', {
      'user_id': userId,
      'book_id': bookId,
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
