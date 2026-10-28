import 'dart:math';

import '../data/repos.dart';
import '../data/database_helper.dart';
import '../data/repositories/room_repository.dart';
import '../models/feed.dart';
import '../utils/book_text.dart';
import 'data_bus.dart';
import 'session.dart';

/// ДЕМО-РЕЖИМ. В учебном проекте нет сервера, поэтому друзья не могут
/// писать по-настоящему. Симулятор «оживляет» их локально:
///  * через несколько секунд после вашего сообщения кто-то из участников
///    комнаты отвечает заготовленной фразой и иногда ставит реакцию;
///  * прогресс друзей понемногу растёт со временем (и продлевает их огоньки).
/// Отключается в «Настройки → Демо-активность друзей».
/// После подключения сервера и PostgreSQL этот класс удаляется.
class DemoSimulator {
  DemoSimulator._();
  static final DemoSimulator instance = DemoSimulator._();

  final _random = Random();
  DateTime? _lastTick;

  static const _replies = [
    'Согласна, тоже об этом думала!',
    'Интересная мысль 🤔',
    'Я как раз дочитываю эту часть.',
    'Ха, точно подмечено 😄',
    'Давайте обсудим это подробнее вечером?',
    'У меня от этой главы мурашки.',
    'Отличная цитата, сохраню себе.',
  ];

  static const _answers = [
    'Мне кажется, потому что у них ещё осталось что-то настоящее.',
    'Думаю, это его единственная надежда — больше верить не во что.',
    'Хороший вопрос! Я думаю, автор хочет показать контраст с Партией.',
  ];

  bool get _enabled => Session.instance.demoActivity;

  /// Вызывается после отправки сообщения текущим пользователем.
  void onUserMessage(int roomId, int userId, {bool question = false}) {
    if (!_enabled) return;
    Future<void>.delayed(Duration(seconds: 3 + _random.nextInt(4)), () async {
      if (!_enabled || Session.instance.userIdOrNull != userId) return;
      final repo = Repos.rooms;
      final others = (await repo.members(roomId))
          .where((m) => m.userId != userId)
          .toList();
      if (others.isEmpty) return;
      final friend = others[_random.nextInt(others.length)];
      final room = await repo.room(roomId);
      final chapter = room == null
          ? null
          : BookContent.chapterOf(friend.pageIn(room.book.pageCount));
      final pool = question ? _answers : _replies;
      await repo.sendMessage(
        roomId,
        friend.userId,
        pool[_random.nextInt(pool.length)],
        chapter: chapter,
      );
      // Иногда друг ставит реакцию на ваше последнее сообщение.
      if (_random.nextBool()) {
        final messages = await repo.messages(roomId);
        final mine = messages.where((m) => m.userId == userId).toList();
        if (mine.isNotEmpty) {
          await repo.toggleReaction(mine.last.id, friend.userId,
              RoomRepository.reactionEmojis[_random.nextInt(2)]);
        }
      }
    });
  }

  /// Продвигает прогресс друзей (не чаще раза в 10 минут).
  Future<void> tick() async {
    final uid = Session.instance.userIdOrNull;
    if (!_enabled || uid == null) return;
    final now = DateTime.now();
    final last = _lastTick;
    if (last != null && now.difference(last).inMinutes < 10) return;
    _lastTick = now;

    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT l.library_id, l.user_id, l.book_id, l.pages_read, l.updated_at,
             b.pages
      FROM library l JOIN books b ON b.book_id = l.book_id
      WHERE l.user_id <> ? AND l.status = 'Reading' ''', [uid]);
    var changed = false;
    for (final r in rows) {
      final updated = DateTime.parse(r['updated_at'] as String);
      final hours = now.difference(updated).inHours;
      if (hours < 1) continue;
      final pages = (r['pages'] as int?) ?? 100;
      final read = (r['pages_read'] as int?) ?? 0;
      final next = min(pages - 1, read + min(hours * 3, 15) + _random.nextInt(4));
      if (next <= read) continue;
      final percent = ((next / pages) * 100).round().clamp(0, 99).toInt();
      final stamp = now.toIso8601String();
      await db.update(
        'library',
        {'pages_read': next, 'progress_percent': percent, 'updated_at': stamp},
        where: 'library_id = ?',
        whereArgs: [r['library_id']],
      );
      await db.rawUpdate('''
        UPDATE room_members SET progress_percent = ?
        WHERE user_id = ? AND room_id IN
          (SELECT room_id FROM reading_rooms WHERE book_id = ?)''',
          [percent, r['user_id'], r['book_id']]);
      await db.insert('activities', {
        'user_id': r['user_id'],
        'book_id': r['book_id'],
        'type': ActivityType.readingSession,
        'created_at': stamp,
      });
      changed = true;
    }
    if (changed) DataBus.instance.changed();
  }

  /// Подсказка для UI: сообщение, которое показывается в README/настройках.
  static const description =
      'Друзья отвечают в комнатах и читают дальше сами. Это имитация: '
      'в учебной версии нет сервера.';
}
