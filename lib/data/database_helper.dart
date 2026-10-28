import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'seed_data.dart';

/// Подключение к локальной базе SQLite и создание схемы.
///
/// Схема повторяет ER-модель из курсовой работы №1 (14 таблиц)
/// + таблица message_reactions (реакции на сообщения):
/// users, books, library, bookmarks, notes, friendships, reading_rooms,
/// room_members, messages, activities, notifications, privacy_settings,
/// user_preferences, reader_settings.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'readtogether.db';
  /// v1 — схема КР №1 (14 таблиц).
  /// v2 — совместное чтение: цель комнаты, главы сообщений (спойлеры),
  ///      цитаты, вопросы к главе, отметка прочтения, реакции.
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    print('DATABASE PATH: $dir');
    final db = await openDatabase(
      p.join(dir, _dbName),
      version: _dbVersion,
      onConfigure: (db) async {
        // Включаем проверку внешних ключей и каскадное удаление.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await SeedData.insert(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _migrateToV2(db);
      },
    );
    _db = db;
    return db;
  }

  /// Полный сброс базы к демо-данным (пункт в настройках).
  Future<void> resetDatabase() async {
    final dir = await getDatabasesPath();
    await _db?.close();
    _db = null;
    await deleteDatabase(p.join(dir, _dbName));
    await database;
  }

  static const _reactionsTable = '''
      CREATE TABLE message_reactions (
        reaction_id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id  INTEGER NOT NULL REFERENCES messages(message_id) ON DELETE CASCADE,
        user_id     INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        emoji       TEXT    NOT NULL,
        created_at  TEXT    NOT NULL,
        UNIQUE (message_id, user_id, emoji)
      )''';

  /// Миграция базы, созданной версией 1 приложения (данные сохраняются).
  static Future<void> _migrateToV2(Database db) async {
    final batch = db.batch();
    batch.execute('ALTER TABLE reading_rooms ADD COLUMN target_date TEXT');
    batch.execute('ALTER TABLE room_members ADD COLUMN last_read_at TEXT');
    batch.execute('ALTER TABLE messages ADD COLUMN chapter_number INTEGER');
    batch.execute('ALTER TABLE messages ADD COLUMN page_number INTEGER');
    batch.execute('ALTER TABLE messages ADD COLUMN quote TEXT');
    batch.execute(
        "ALTER TABLE messages ADD COLUMN kind TEXT NOT NULL DEFAULT 'text'");
    batch.execute(_reactionsTable);
    batch.execute(
        'CREATE INDEX idx_reactions_message ON message_reactions(message_id)');
    await batch.commit(noResult: true);
  }

  static Future<void> _createSchema(Database db) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE users (
        user_id       INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL,
        email         TEXT    NOT NULL UNIQUE,
        password_hash TEXT    NOT NULL,
        avatar_url    TEXT,
        bio           TEXT,
        created_at    TEXT    NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE books (
        book_id      INTEGER PRIMARY KEY AUTOINCREMENT,
        title        TEXT NOT NULL,
        author       TEXT NOT NULL,
        cover_url    TEXT,
        description  TEXT,
        genre        TEXT,
        year         INTEGER,
        pages        INTEGER,
        rating       REAL CHECK (rating IS NULL OR (rating >= 0 AND rating <= 5)),
        file_url     TEXT,
        file_format  TEXT CHECK (file_format IS NULL OR file_format IN ('EPUB','PDF','TXT')),
        uploaded_by  INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
        access_level TEXT NOT NULL DEFAULT 'Public'
                     CHECK (access_level IN ('Private','Friends','Public'))
      )''');

    batch.execute('''
      CREATE TABLE library (
        library_id       INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id          INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        book_id          INTEGER NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
        status           TEXT    NOT NULL CHECK (status IN ('Reading','Planned','Finished')),
        progress_percent INTEGER NOT NULL DEFAULT 0
                         CHECK (progress_percent BETWEEN 0 AND 100),
        pages_read       INTEGER NOT NULL DEFAULT 0,
        added_at         TEXT    NOT NULL,
        updated_at       TEXT    NOT NULL,
        UNIQUE (user_id, book_id)
      )''');

    batch.execute('''
      CREATE TABLE reading_rooms (
        room_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id    INTEGER NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
        creator_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        name       TEXT    NOT NULL,
        privacy    TEXT    NOT NULL CHECK (privacy IN ('Friends','InviteOnly')),
        target_date TEXT,
        created_at TEXT    NOT NULL,
        updated_at TEXT    NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE bookmarks (
        bookmark_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id        INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        book_id        INTEGER NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
        room_id        INTEGER REFERENCES reading_rooms(room_id) ON DELETE CASCADE,
        chapter_number INTEGER,
        page_number    INTEGER NOT NULL,
        text_snippet   TEXT,
        created_at     TEXT    NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE notes (
        note_id        INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id        INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        book_id        INTEGER NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
        chapter_number INTEGER,
        page_number    INTEGER,
        content        TEXT    NOT NULL,
        created_at     TEXT    NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE friendships (
        friendship_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id_1     INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        user_id_2     INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        status        TEXT    NOT NULL CHECK (status IN ('Pending','Accepted','Declined')),
        created_at    TEXT    NOT NULL,
        UNIQUE (user_id_1, user_id_2),
        CHECK (user_id_1 <> user_id_2)
      )''');

    batch.execute('''
      CREATE TABLE room_members (
        member_id        INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id          INTEGER NOT NULL REFERENCES reading_rooms(room_id) ON DELETE CASCADE,
        user_id          INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        status           TEXT    NOT NULL CHECK (status IN ('Invited','Joined','Declined')),
        progress_percent INTEGER NOT NULL DEFAULT 0,
        joined_at        TEXT,
        last_read_at     TEXT,
        UNIQUE (room_id, user_id)
      )''');

    batch.execute('''
      CREATE TABLE messages (
        message_id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_id    INTEGER NOT NULL REFERENCES reading_rooms(room_id) ON DELETE CASCADE,
        user_id    INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        text       TEXT    NOT NULL,
        chapter_number INTEGER,
        page_number    INTEGER,
        quote      TEXT,
        kind       TEXT    NOT NULL DEFAULT 'text' CHECK (kind IN ('text','question')),
        created_at TEXT    NOT NULL
      )''');

    batch.execute(_reactionsTable);

    batch.execute('''
      CREATE TABLE activities (
        activity_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        book_id     INTEGER REFERENCES books(book_id) ON DELETE CASCADE,
        type        TEXT    NOT NULL,
        created_at  TEXT    NOT NULL
      )''');

    // book_id — необязательная ссылка на книгу для уведомлений-рекомендаций
    // (расширение схемы из КР №1, нужно для перехода к книге по нажатию).
    batch.execute('''
      CREATE TABLE notifications (
        notification_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id         INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        actor_id        INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
        room_id         INTEGER REFERENCES reading_rooms(room_id) ON DELETE CASCADE,
        book_id         INTEGER REFERENCES books(book_id) ON DELETE CASCADE,
        type            TEXT    NOT NULL,
        text            TEXT,
        is_read         INTEGER NOT NULL DEFAULT 0,
        created_at      TEXT    NOT NULL
      )''');

    batch.execute('''
      CREATE TABLE privacy_settings (
        user_id             INTEGER PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
        profile_visibility  TEXT NOT NULL DEFAULT 'Everyone',
        library_visibility  TEXT NOT NULL DEFAULT 'Friends',
        activity_visibility TEXT NOT NULL DEFAULT 'Everyone',
        room_invites_from   TEXT NOT NULL DEFAULT 'Friends'
      )''');

    batch.execute('''
      CREATE TABLE user_preferences (
        user_id         INTEGER PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
        theme           TEXT    NOT NULL DEFAULT 'Light (System)',
        language        TEXT    NOT NULL DEFAULT 'ru',
        push_enabled    INTEGER NOT NULL DEFAULT 1,
        email_enabled   INTEGER NOT NULL DEFAULT 0,
        favorite_genres TEXT
      )''');

    batch.execute('''
      CREATE TABLE reader_settings (
        user_id      INTEGER PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
        font_family  TEXT    NOT NULL DEFAULT 'Inter',
        font_size    INTEGER NOT NULL DEFAULT 16,
        line_spacing REAL    NOT NULL DEFAULT 1.5,
        reader_theme TEXT    NOT NULL DEFAULT 'sepia'
      )''');

    // Индексы для частых выборок.
    batch.execute('CREATE INDEX idx_library_user ON library(user_id)');
    batch.execute('CREATE INDEX idx_bookmarks_book ON bookmarks(user_id, book_id)');
    batch.execute('CREATE INDEX idx_notes_book ON notes(user_id, book_id)');
    batch.execute('CREATE INDEX idx_messages_room ON messages(room_id)');
    batch.execute('CREATE INDEX idx_activities_user ON activities(user_id)');
    batch.execute('CREATE INDEX idx_notifications_user ON notifications(user_id)');
    batch.execute(
        'CREATE INDEX idx_reactions_message ON message_reactions(message_id)');

    await batch.commit(noResult: true);
  }
}
