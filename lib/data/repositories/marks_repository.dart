import 'package:sqflite/sqflite.dart';

import '../../models/feed.dart';
import '../../models/reading_mark.dart';
import '../../services/data_bus.dart';
import '../database_helper.dart';

/// Работа с таблицами bookmarks и notes.
class MarksRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Личные закладки (без room_id) и заметки пользователя к книге,
  /// отсортированные от старых к новым — как на макете.
  Future<List<ReadingMark>> personalMarks(int userId, int bookId,
      {bool notesOnly = false}) async {
    final db = await _db;
    final notes = await db.rawQuery('''
      SELECT n.*, u.name AS user_name FROM notes n
      JOIN users u ON u.user_id = n.user_id
      WHERE n.user_id = ? AND n.book_id = ?''', [userId, bookId]);
    final result = notes.map(ReadingMark.noteFromMap).toList();
    if (!notesOnly) {
      final bookmarks = await db.rawQuery('''
        SELECT bm.*, u.name AS user_name FROM bookmarks bm
        JOIN users u ON u.user_id = bm.user_id
        WHERE bm.user_id = ? AND bm.book_id = ? AND bm.room_id IS NULL''',
          [userId, bookId]);
      result.addAll(bookmarks.map(ReadingMark.bookmarkFromMap));
    }
    result.sort((a, b) {
      final byChapter = (a.chapterNumber ?? 0).compareTo(b.chapterNumber ?? 0);
      if (byChapter != 0) return byChapter;
      return (a.pageNumber ?? 0).compareTo(b.pageNumber ?? 0);
    });
    return result;
  }

  /// Общие закладки комнаты совместного чтения.
  Future<List<ReadingMark>> roomBookmarks(int roomId) async {
    final rows = await (await _db).rawQuery('''
      SELECT bm.*, u.name AS user_name FROM bookmarks bm
      JOIN users u ON u.user_id = bm.user_id
      WHERE bm.room_id = ? ORDER BY bm.created_at DESC''', [roomId]);
    return rows.map(ReadingMark.bookmarkFromMap).toList();
  }

  Future<bool> hasBookmarkOnPage(int userId, int bookId, int page) async {
    final rows = await (await _db).query('bookmarks',
        where: 'user_id = ? AND book_id = ? AND page_number = ? AND room_id IS NULL',
        whereArgs: [userId, bookId, page],
        limit: 1);
    return rows.isNotEmpty;
  }

  Future<int> bookmarkCount(int userId) async {
    final rows = await (await _db).rawQuery(
        'SELECT COUNT(*) AS c FROM bookmarks WHERE user_id = ?', [userId]);
    return rows.first['c'] as int;
  }

  Future<int> noteCount(int userId) async {
    final rows = await (await _db)
        .rawQuery('SELECT COUNT(*) AS c FROM notes WHERE user_id = ?', [userId]);
    return rows.first['c'] as int;
  }

  Future<void> addBookmark({
    required int userId,
    required int bookId,
    required int chapter,
    required int page,
    required String snippet,
    int? roomId,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert('bookmarks', {
      'user_id': userId,
      'book_id': bookId,
      'room_id': roomId,
      'chapter_number': chapter,
      'page_number': page,
      'text_snippet': snippet,
      'created_at': now,
    });
    await db.insert('activities', {
      'user_id': userId,
      'book_id': bookId,
      'type': ActivityType.addedBookmark,
      'created_at': now,
    });
    DataBus.instance.changed();
  }

  Future<void> addNote({
    required int userId,
    required int bookId,
    required int chapter,
    required int page,
    required String content,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.insert('notes', {
      'user_id': userId,
      'book_id': bookId,
      'chapter_number': chapter,
      'page_number': page,
      'content': content.trim(),
      'created_at': now,
    });
    await db.insert('activities', {
      'user_id': userId,
      'book_id': bookId,
      'type': ActivityType.addedNote,
      'created_at': now,
    });
    DataBus.instance.changed();
  }

  Future<void> delete(ReadingMark mark) async {
    final db = await _db;
    if (mark.isNote) {
      await db.delete('notes', where: 'note_id = ?', whereArgs: [mark.id]);
    } else {
      await db
          .delete('bookmarks', where: 'bookmark_id = ?', whereArgs: [mark.id]);
    }
    DataBus.instance.changed();
  }
}
