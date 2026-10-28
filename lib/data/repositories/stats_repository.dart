import 'package:sqflite/sqflite.dart';

import '../../models/feed.dart';
import '../../utils/genres.dart';
import '../database_helper.dart';

class GenreShare {
  final String genre;
  final int percent;
  const GenreShare(this.genre, this.percent);
}

/// Агрегированные данные для экрана «Статистика чтения».
class ReadingStats {
  final int booksFinished;
  final int booksTotal;
  final int pagesRead;
  final int streakDays;

  /// Количество сессий чтения по дням недели (Пн..Вс) за 30 дней.
  final List<int> weekdaySessions;
  final List<GenreShare> genres;
  final int roomsJoined;
  final int bookmarks;
  final int notes;

  const ReadingStats({
    required this.booksFinished,
    required this.booksTotal,
    required this.pagesRead,
    required this.streakDays,
    required this.weekdaySessions,
    required this.genres,
    required this.roomsJoined,
    required this.bookmarks,
    required this.notes,
  });
}

/// Только чтение и подсчёт — экран Reading Stats ничего не изменяет.
class StatsRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<ReadingStats> load(int userId) async {
    final db = await _db;
    int count(List<Map<String, Object?>> rows) =>
        (rows.first['c'] as num?)?.toInt() ?? 0;

    final finished = count(await db.rawQuery(
        "SELECT COUNT(*) AS c FROM library WHERE user_id = ? AND status = 'Finished'",
        [userId]));
    final total = count(await db.rawQuery(
        'SELECT COUNT(*) AS c FROM library WHERE user_id = ?', [userId]));
    final pages = count(await db.rawQuery(
        'SELECT SUM(pages_read) AS c FROM library WHERE user_id = ?', [userId]));
    final rooms = count(await db.rawQuery(
        "SELECT COUNT(*) AS c FROM room_members WHERE user_id = ? AND status = 'Joined'",
        [userId]));
    final bookmarks = count(await db.rawQuery(
        'SELECT COUNT(*) AS c FROM bookmarks WHERE user_id = ?', [userId]));
    final notes = count(await db.rawQuery(
        'SELECT COUNT(*) AS c FROM notes WHERE user_id = ?', [userId]));

    // Активность за последние 30 дней.
    final since =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final sessions = await db.rawQuery(
        'SELECT created_at FROM activities WHERE user_id = ? AND type = ? AND created_at >= ?',
        [userId, ActivityType.readingSession, since]);
    final weekdays = List<int>.filled(7, 0);
    for (final r in sessions) {
      final d = DateTime.parse(r['created_at'] as String);
      weekdays[d.weekday - 1]++;
    }

    // Серия дней подряд — по любым событиям активности.
    final allDays = await db.rawQuery(
        'SELECT DISTINCT substr(created_at, 1, 10) AS day FROM activities WHERE user_id = ?',
        [userId]);
    final daySet = allDays.map((r) => r['day'] as String).toSet();
    var streak = 0;
    var cursor = DateTime.now();
    String key(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    // Если сегодня ещё не читали — серия считается со вчерашнего дня.
    if (!daySet.contains(key(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (daySet.contains(key(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Любимые жанры — доля книг библиотеки по жанрам.
    final genreRows = await db.rawQuery('''
      SELECT b.genre AS genre FROM library l JOIN books b ON b.book_id = l.book_id
      WHERE l.user_id = ?''', [userId]);
    final genreCounts = <String, int>{};
    for (final r in genreRows) {
      final g = Genres.normalize(r['genre'] as String?);
      genreCounts[g] = (genreCounts[g] ?? 0) + 1;
    }
    final sorted = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(4).toList();
    final topSum = top.fold<int>(0, (s, e) => s + e.value);
    final genres = top
        .map((e) => GenreShare(
            e.key, topSum == 0 ? 0 : ((e.value / topSum) * 100).round()))
        .toList();

    return ReadingStats(
      booksFinished: finished,
      booksTotal: total,
      pagesRead: pages,
      streakDays: streak,
      weekdaySessions: weekdays,
      genres: genres,
      roomsJoined: rooms,
      bookmarks: bookmarks,
      notes: notes,
    );
  }
}
