import 'package:sqflite/sqflite.dart';

import '../models/feed.dart';
import '../models/reading_room.dart';
import '../utils/password_hasher.dart';


class SeedData {
  SeedData._();

  static const demoEmail = 'amina@readtogether.club';
  static const demoPassword = 'amina2026';

  static Future<void> insert(Database db) async {
    final now = DateTime.now();
    String ago({int days = 0, int hours = 0, int minutes = 0}) => now
        .subtract(Duration(days: days, hours: hours, minutes: minutes))
        .toIso8601String();

    final batch = db.batch();

    
    const users = [
      [1, 'Amina', demoEmail, 'Люблю антиутопии и классику. Читаю по вечерам.'],
      [2, 'Daniyar', 'daniyar@readtogether.club', null],
      [3, 'Alina', 'alina@readtogether.club', null],
      [4, 'Maria', 'maria@readtogether.club', null],
      [5, 'Sanzhar', 'sanzhar@readtogether.club', null],
      [6, 'Aruzhan', 'aruzhan@readtogether.club', null],
      [7, 'Timur', 'timur@readtogether.club', null],
      [8, 'Dias', 'dias@readtogether.club', null],
    ];
    for (final u in users) {
      final id = u[0] as int;
      batch.insert('users', {
        'user_id': id,
        'name': u[1],
        'email': u[2],
        'password_hash':
            PasswordHasher.hash(id == 1 ? demoPassword : 'reader2026'),
        'bio': u[3],
        'created_at': ago(days: 120 - id),
      });
      batch.insert('privacy_settings', {
        'user_id': id,
        'profile_visibility': 'Everyone',
        'library_visibility': 'Friends',
        'activity_visibility': 'Everyone',
        'room_invites_from': 'Friends',
      });
      batch.insert('user_preferences', {
        'user_id': id,
        'theme': 'Light (System)',
        'language': 'ru',
        'push_enabled': 1,
        'email_enabled': 0,
        'favorite_genres': id == 1 ? 'Фикшн,Фантазия,Sci-Fi,Классика' : null,
      });
      batch.insert('reader_settings', {
        'user_id': id,
        'font_family': 'Inter',
        'font_size': 16,
        'line_spacing': 1.5,
        'reader_theme': 'sepia',
      });
    }

    // ---------- books ----------
    const books = <List<Object?>>[
      [1, '1984', 'George Orwell', 'assets/covers/1984.png',
        'Леденящий душу шедевр антиутопии, описывающий жизнь при вездесущем тоталитарном режиме, где мыслепреступление является тягчайшим правонарушением',
        'Антиутопия', 1949, 328, 4.7],
      [2, 'Великий Гэтсби', 'F. Scott Fitzgerald', 'assets/covers/gatsby.png',
        'История загадочного миллионера Джея Гэтсби и его безнадёжной любви — портрет «века джаза» с его роскошью и пустотой.',
        'Классика', 1925, 208, 4.8],
      [3, 'Убить пересмешника', 'Harper Lee', 'assets/covers/mockingbird.png',
        'Взросление в маленьком городке американского Юга глазами девочки, чей отец-адвокат защищает невиновного в суде.',
        'Классика', 1960, 416, 4.9],
      [4, 'Маленький принц', 'A. de Saint-Exupéry', 'assets/covers/little_prince.png',
        'Философская сказка о Маленьком принце, путешествующем между планетами, о дружбе, любви и ответственности.',
        'Фикшн', 1943, 96, 4.8],
      [5, 'Гарри Потер', 'J.K. Rowling', 'assets/covers/harry_potter.png',
        'Мальчик узнаёт, что он волшебник, и отправляется учиться в школу чародейства, где его ждут друзья и опасные тайны.',
        'Фантазия', 1997, 310, 4.7],
      [6, 'Мастер и Маргарита', 'Михаил Булгаков', null,
        'Роман о визите дьявола в Москву 1930-х, переплетённый с историей Понтия Пилата и любовью Мастера и Маргариты.',
        'Классика', 1967, 480, 4.8],
      [7, 'Преступление и наказание', 'Фёдор Достоевский', null,
        'Студент Раскольников решается на преступление, чтобы проверить свою теорию, и сталкивается с муками совести.',
        'Классика', 1866, 672, 4.7],
      [8, 'Дюна', 'Frank Herbert', null,
        'Эпическая история пустынной планеты Арракис, борьбы великих домов и юного Пола Атрейдеса.',
        'Sci-Fi', 1965, 704, 4.6],
      [9, 'Убийство в Восточном экспрессе', 'Agatha Christie', null,
        'Эркюль Пуаро расследует убийство в поезде, застрявшем в снегах, где подозреваемым может быть каждый.',
        'Детектив', 1934, 256, 4.6],
      [10, 'Гордость и предубеждение', 'Jane Austen', null,
        'История Элизабет Беннет и мистера Дарси — о первых впечатлениях, гордости и умении менять мнение.',
        'Романтика', 1813, 432, 4.7],
      [11, 'Сияние', 'Stephen King', null,
        'Семья остаётся на зиму смотрителями пустого горного отеля, где у прошлого есть собственная воля.',
        'Ужасы', 1977, 512, 4.5],
      [12, 'Sapiens', 'Yuval Noah Harari', null,
        'Краткая история человечества: от появления Homo sapiens до научной революции и современности.',
        'Нон-фикшн', 2011, 512, 4.6],
      [13, 'Хоббит', 'J.R.R. Tolkien', null,
        'Хоббит Бильбо Бэггинс неожиданно отправляется в путешествие с гномами к Одинокой горе.',
        'Фантазия', 1937, 310, 4.8],
      [14, 'Путь Абая', 'Мухтар Ауэзов', null,
        'Роман-эпопея о жизни великого казахского поэта Абая Кунанбаева и казахской степи XIX века.',
        'Классика', 1942, 560, 4.8],
    ];
    for (final b in books) {
      batch.insert('books', {
        'book_id': b[0],
        'title': b[1],
        'author': b[2],
        'cover_url': b[3],
        'description': b[4],
        'genre': b[5],
        'year': b[6],
        'pages': b[7],
        'rating': b[8],
        'access_level': 'Public',
      });
    }

    // ---------- library ----------
    void lib(int user, int book, String status, int progress, int pagesRead,
        int addedDays, Duration updated) {
      batch.insert('library', {
        'user_id': user,
        'book_id': book,
        'status': status,
        'progress_percent': progress,
        'pages_read': pagesRead,
        'added_at': ago(days: addedDays),
        'updated_at': now.subtract(updated).toIso8601String(),
      });
    }

    // Amina
    lib(1, 1, 'Reading', 64, 210, 40, const Duration(hours: 1));
    lib(1, 2, 'Reading', 0, 0, 30, const Duration(days: 2));
    lib(1, 4, 'Reading', 95, 91, 20, const Duration(days: 1));
    lib(1, 3, 'Reading', 0, 0, 3, const Duration(days: 3));
    lib(1, 8, 'Planned', 0, 0, 15, const Duration(days: 15));
    lib(1, 6, 'Planned', 0, 0, 14, const Duration(days: 14));
    lib(1, 11, 'Planned', 0, 0, 10, const Duration(days: 10));
    lib(1, 10, 'Finished', 100, 432, 90, const Duration(days: 60));
    lib(1, 9, 'Finished', 100, 256, 85, const Duration(days: 50));
    lib(1, 12, 'Finished', 100, 512, 80, const Duration(days: 45));
    lib(1, 14, 'Finished', 100, 560, 75, const Duration(days: 35));
    lib(1, 7, 'Finished', 100, 672, 70, const Duration(days: 25));
    lib(1, 13, 'Finished', 100, 310, 65, const Duration(days: 18));
    // Daniyar
    lib(2, 5, 'Reading', 58, 180, 20, const Duration(hours: 3));
    lib(2, 1, 'Reading', 58, 190, 10, const Duration(days: 1));
    lib(2, 4, 'Finished', 100, 96, 60, const Duration(days: 5));
    lib(2, 2, 'Finished', 100, 208, 70, const Duration(days: 8));
    lib(2, 3, 'Finished', 100, 416, 80, const Duration(days: 12));
    lib(2, 13, 'Finished', 100, 310, 100, const Duration(days: 40));
    lib(2, 8, 'Finished', 100, 704, 110, const Duration(days: 50));
    lib(2, 7, 'Finished', 100, 672, 115, const Duration(days: 60));
    lib(2, 6, 'Finished', 100, 480, 118, const Duration(days: 70));
    // Alina
    lib(3, 4, 'Reading', 95, 91, 15, const Duration(hours: 2));
    lib(3, 1, 'Reading', 71, 233, 12, const Duration(days: 1));
    lib(3, 10, 'Finished', 100, 432, 50, const Duration(days: 20));
    // Maria
    lib(4, 3, 'Reading', 12, 50, 7, const Duration(minutes: 30));
    lib(4, 5, 'Planned', 0, 0, 6, const Duration(days: 6));
    lib(4, 1, 'Finished', 100, 328, 40, const Duration(days: 9));
    // Остальные
    lib(5, 8, 'Reading', 30, 211, 10, const Duration(days: 2));
    lib(6, 10, 'Reading', 45, 194, 9, const Duration(days: 1));
    lib(7, 12, 'Reading', 20, 102, 8, const Duration(days: 3));
    lib(8, 9, 'Reading', 66, 169, 6, const Duration(days: 2));

    // ---------- friendships ----------
    void friend(int a, int b, String status, int days) => batch.insert(
        'friendships', {
          'user_id_1': a,
          'user_id_2': b,
          'status': status,
          'created_at': ago(days: days),
        });
    friend(1, 2, 'Accepted', 60);
    friend(3, 1, 'Accepted', 0);
    friend(1, 4, 'Accepted', 30);
    friend(5, 1, 'Pending', 2); // входящий запрос (экран «Друзья»)
    friend(1, 6, 'Pending', 1); // исходящий запрос («Отправлено»)
    friend(2, 3, 'Accepted', 50);
    friend(2, 4, 'Accepted', 40);

    // ---------- reading rooms ----------
    batch.insert('reading_rooms', {
      'room_id': 1,
      'book_id': 1,
      'creator_id': 2,
      'name': '1984 — evening reading',
      'privacy': 'Friends',
      // Цель: 18 дней на книгу, прошло 12 → по плану ~67%.
      // Amina 64% — по графику, Daniyar 58% — отстаёт (кнопка «Поторопить»).
      'target_date': now.add(const Duration(days: 6)).toIso8601String(),
      'created_at': ago(days: 12),
      'updated_at': ago(minutes: 10),
    });
    batch.insert('reading_rooms', {
      'room_id': 2,
      'book_id': 1,
      'creator_id': 2,
      'name': '1984 — книжный клуб',
      'privacy': 'InviteOnly',
      'created_at': ago(hours: 1),
      'updated_at': ago(hours: 1),
    });
    void member(int room, int user, String status, int progress) =>
        batch.insert('room_members', {
          'room_id': room,
          'user_id': user,
          'status': status,
          'progress_percent': progress,
          'joined_at': status == 'Joined' ? ago(days: 2) : null,
          // Amina прочитала обсуждение комнаты 1 час назад → 2 непрочитанных.
          'last_read_at': status == 'Joined' ? ago(hours: 1) : null,
        });
    member(1, 1, 'Joined', 64);
    member(1, 2, 'Joined', 58);
    member(1, 3, 'Joined', 71);
    member(2, 2, 'Joined', 58);
    member(2, 4, 'Joined', 100);
    member(2, 1, 'Invited', 64);

    // ---------- bookmarks ----------
    void bookmark(int user, int book, int? room, int chapter, int page,
            String snippet, String createdAt) =>
        batch.insert('bookmarks', {
          'user_id': user,
          'book_id': book,
          'room_id': room,
          'chapter_number': chapter,
          'page_number': page,
          'text_snippet': snippet,
          'created_at': createdAt,
        });
    // Личные закладки Amina в «1984»
    bookmark(1, 1, null, 5, 64,
        'Был холодный ясный апрельский день, и часы пробили тринадцать.',
        ago(days: 20));
    bookmark(1, 1, null, 7, 87,
        'Если и была надежда, то она должна была исходить от пролов…',
        ago(days: 1));
    bookmark(1, 4, null, 2, 21, 'Зорко одно лишь сердце.', ago(days: 6));
    bookmark(1, 4, null, 5, 70, 'Ты навсегда в ответе за всех, кого приручил.',
        ago(days: 2));
    bookmark(1, 13, null, 1, 3, 'В норе под землёй жил-был хоббит.',
        ago(days: 30));
    // Общие закладки комнаты 1
    bookmark(3, 1, 1, 5, 60, 'Тот, кто управляет прошлым, управляет будущим…',
        ago(days: 1));
    bookmark(1, 1, 1, 7, 87, 'Был ясный холодный апрельский день…',
        ago(hours: 20));
    bookmark(2, 1, 1, 8, 104,
        'Если и была надежда, то она должна была заключаться в пролах.',
        ago(hours: 6));

    // ---------- notes ----------
    batch.insert('notes', {
      'user_id': 1,
      'book_id': 1,
      'chapter_number': 8,
      'page_number': 100,
      'content':
          'Интересное изменение в мотивации персонажа во время посещения антикварного магазина.',
      'created_at': ago(hours: 2),
    });
    batch.insert('notes', {
      'user_id': 4,
      'book_id': 5,
      'chapter_number': 3,
      'page_number': 35,
      'content': 'Сцена с письмами — одна из самых смешных.',
      'created_at': ago(days: 1),
    });

    // ---------- messages ----------
    void message(int room, int user, String text, String createdAt,
            {int? chapter, int? page, String? quote, String kind = MessageKind.text}) =>
        batch.insert('messages', {
          'room_id': room,
          'user_id': user,
          'text': text,
          'chapter_number': chapter,
          'page_number': page,
          'quote': quote,
          'kind': kind,
          'created_at': createdAt,
        });
    // id 1..
    message(1, 2, 'Согласен. Политический подтекст просто безумный.',
        ago(days: 1, hours: 1), chapter: 7);
    message(1, 3, 'Я только что отметила свою любимую цитату',
        ago(hours: 3, minutes: 2),
        chapter: 5,
        page: 60,
        quote: 'Тот, кто управляет прошлым, управляет будущим…');
    message(1, 2, 'Эта цитата — легендарная. Оруэлл был провидцем..',
        ago(hours: 3), chapter: 5);
    message(1, 1, 'Эта глава интересная.', ago(minutes: 10), chapter: 17);
    message(2, 2, 'Всем привет! Начинаем с первой главы.', ago(minutes: 55),
        chapter: 1);
    // Спойлер: Alina уже на 18-й главе, Amina — на 17-й.
    message(1, 3, 'Глава 18 — это просто шок, никак не ожидала такого поворота!',
        ago(minutes: 40), chapter: 18);
    message(1, 2, 'Как думаете, почему Уинстон так верит в пролов?',
        ago(minutes: 20), chapter: 7, kind: MessageKind.question);

    // ---------- реакции ----------
    void react(int messageId, int user, String emoji) =>
        batch.insert('message_reactions', {
          'message_id': messageId,
          'user_id': user,
          'emoji': emoji,
          'created_at': ago(hours: 2),
        });
    react(2, 1, '❤️');
    react(2, 2, '❤️');
    react(3, 3, '👍');
    react(4, 2, '👍');
    react(4, 3, '🔥');

    // ---------- activities ----------
    void activity(int user, int? book, String type, String createdAt) =>
        batch.insert('activities', {
          'user_id': user,
          'book_id': book,
          'type': type,
          'created_at': createdAt,
        });
    activity(2, 1, ActivityType.startedReading, ago(hours: 2));
    activity(3, 4, ActivityType.finished, ago(days: 1, hours: 2));
    activity(4, 5, ActivityType.addedNote, ago(days: 1, hours: 4));
    activity(1, 3, ActivityType.startedReading, ago(days: 3));
    activity(1, 1, ActivityType.addedNote, ago(days: 1));

    // Сессии чтения Amina за последние 30 дней — для «Статистики чтения».
    // Последние 12 дней без пропусков (серия «12 дней подряд»).
    const weekdayWeight = {1: 2, 2: 4, 3: 3, 4: 5, 5: 2, 6: 6, 7: 4};
    for (var d = 0; d < 30; d++) {
      final day = now.subtract(Duration(days: d));
      final count = d == 12 ? 0 : weekdayWeight[day.weekday]!;
      for (var i = 0; i < count; i++) {
        final t = DateTime(day.year, day.month, day.day, 8 + i * 2, 15);
        final safe = t.isAfter(now) ? now.subtract(Duration(minutes: 5 + i)) : t;
        activity(1, 1, ActivityType.readingSession, safe.toIso8601String());
      }
    }

    // Сессии чтения друзей — для «огоньков» (совместных серий).
    // Daniyar читает 9 дней подряд, Alina — 4, Maria — 3 дня, но
    // сегодня ещё не читала (серия под угрозой).
    void sessions(int user, int book, Iterable<int> daysAgo) {
      for (final d in daysAgo) {
        final day = now.subtract(Duration(days: d));
        var t = DateTime(day.year, day.month, day.day, 9, 30);
        if (t.isAfter(now)) t = now.subtract(const Duration(minutes: 20));
        activity(user, book, ActivityType.readingSession, t.toIso8601String());
      }
    }

    sessions(2, 1, List.generate(9, (i) => i));
    sessions(3, 1, List.generate(4, (i) => i));
    sessions(4, 3, [1, 2, 3]);

    // ---------- notifications (для Amina) ----------
    void notify(int? actor, int? room, int? book, String type, String text,
            bool read, String createdAt) =>
        batch.insert('notifications', {
          'user_id': 1,
          'actor_id': actor,
          'room_id': room,
          'book_id': book,
          'type': type,
          'text': text,
          'is_read': read ? 1 : 0,
          'created_at': createdAt,
        });
    notify(2, 2, 1, NotificationType.roomInvite, 'пригласил вас в Reading Room',
        false, ago(hours: 1));
    notify(3, null, null, NotificationType.friendAdded,
        'добавила вас в друзья', true, ago(hours: 3));
    notify(4, 1, 1, NotificationType.comment,
        'оставила комментарий в комнате 1984', false, ago(hours: 5));
    notify(null, null, 2, NotificationType.recommendation,
        'Новая рекомендация:', false, ago(days: 1, hours: 1));
    notify(2, null, 1, NotificationType.achievement, 'достиг 75% в книге 1984',
        false, ago(days: 1, hours: 2));
    notify(3, 1, 1, NotificationType.nudge,
        'напоминает: пора читать «1984» — до цели комнаты меньше недели',
        false, ago(hours: 6));
    notify(5, null, null, NotificationType.friendRequest,
        'хочет добавить вас в друзья', true, ago(days: 2));

    await batch.commit(noResult: true);
  }
}
