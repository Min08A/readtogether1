import 'package:sqflite/sqflite.dart';

import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../models/feed.dart';
import '../../services/data_bus.dart';
import '../../utils/genres.dart';
import '../database_helper.dart';

/// Работа с таблицей books (каталог + загруженные пользователем книги).
class BookRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Условие видимости книги для пользователя: публичные книги,
  /// свои загрузки и книги друзей с уровнем доступа «Для друзей».
  static const _visible = '''
    (b.access_level = 'Public' OR b.uploaded_by = ? OR
      (b.access_level = 'Friends' AND b.uploaded_by IN (
        SELECT CASE WHEN f.user_id_1 = ? THEN f.user_id_2 ELSE f.user_id_1 END
        FROM friendships f
        WHERE f.status = 'Accepted' AND (f.user_id_1 = ? OR f.user_id_2 = ?))))''';

  Future<Book?> byId(int id) async {
    final rows = await (await _db)
        .query('books', where: 'book_id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Book.fromMap(rows.first);
  }

  /// Поиск по названию и автору + фильтр по жанру (экран Discover).
  Future<List<Book>> search(int userId,
      {String query = '', String? genre}) async {
    final where = <String>[_visible];
    final args = <Object?>[userId, userId, userId, userId];
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      where.add('(LOWER(b.title) LIKE ? OR LOWER(b.author) LIKE ?)');
      args.addAll(['%$q%', '%$q%']);
    }
    if (genre != null) {
      final values = Genres.dbValuesFor(genre);
      where.add('b.genre IN (${List.filled(values.length, '?').join(',')})');
      args.addAll(values);
    }
    final rows = await (await _db).rawQuery(
      'SELECT b.* FROM books b WHERE ${where.join(' AND ')} '
      'ORDER BY b.rating DESC, b.title',
      args,
    );
    return rows.map(Book.fromMap).toList();
  }

  /// Рекомендации: книги любимых жанров, которых ещё нет в библиотеке.
  Future<List<Book>> recommendations(int userId, List<String> genres,
      {int limit = 6}) async {
    final db = await _db;
    final genreValues = genres.expand(Genres.dbValuesFor).toList();
    const base = 'SELECT b.* FROM books b WHERE $_visible AND b.book_id NOT IN '
        '(SELECT book_id FROM library WHERE user_id = ?)';
    final args = <Object?>[userId, userId, userId, userId, userId];
    var rows = <Map<String, Object?>>[];
    if (genreValues.isNotEmpty) {
      rows = await db.rawQuery(
        '$base AND b.genre IN (${List.filled(genreValues.length, '?').join(',')}) '
        'ORDER BY b.rating DESC LIMIT ?',
        [...args, ...genreValues, limit],
      );
    }
    if (rows.isEmpty) {
      rows = await db.rawQuery('$base ORDER BY b.rating DESC LIMIT ?',
          [...args, limit]);
    }
    return rows.map(Book.fromMap).toList();
  }

  /// Друзья пользователя, у которых книга есть в библиотеке.
  Future<List<AppUser>> friendsWithBook(int userId, int bookId) async {
    final rows = await (await _db).rawQuery('''
      SELECT u.* FROM users u
      JOIN library l ON l.user_id = u.user_id AND l.book_id = ?
      WHERE u.user_id IN (
        SELECT CASE WHEN f.user_id_1 = ? THEN f.user_id_2 ELSE f.user_id_1 END
        FROM friendships f
        WHERE f.status = 'Accepted' AND (f.user_id_1 = ? OR f.user_id_2 = ?))
      ORDER BY l.updated_at DESC''', [bookId, userId, userId, userId]);
    return rows.map(AppUser.fromMap).toList();
  }

  /// Экран Upload Book: книга сохраняется в books и сразу в library.
  Future<int> uploadBook({
    required int userId,
    required String title,
    required String author,
    required String fileUrl,
    required String fileFormat,
    required int pages,
    required String accessLevel,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final id = await db.transaction((txn) async {
      final bookId = await txn.insert('books', {
        'title': title.trim(),
        'author': author.trim(),
        'pages': pages,
        'file_url': fileUrl,
        'file_format': fileFormat,
        'uploaded_by': userId,
        'access_level': accessLevel,
        'description': 'Книга загружена пользователем ($fileFormat).',
      });
      await txn.insert('library', {
        'user_id': userId,
        'book_id': bookId,
        'status': 'Reading',
        'progress_percent': 0,
        'pages_read': 0,
        'added_at': now,
        'updated_at': now,
      });
      await txn.insert('activities', {
        'user_id': userId,
        'book_id': bookId,
        'type': ActivityType.addedBook,
        'created_at': now,
      });
      return bookId;
    });
    DataBus.instance.changed();
    return id;
  }
}
