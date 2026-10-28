-- ReadTogether — схема PostgreSQL (серверная часть).
-- Соответствует локальной SQLite-схеме приложения (lib/data/database_helper.dart, версия 2):
-- 14 таблиц из КР №1 + message_reactions.
-- Отличия от SQLite: IDENTITY вместо AUTOINCREMENT, TIMESTAMPTZ вместо TEXT-дат,
-- BOOLEAN вместо 0/1, NUMERIC для рейтинга.
--
-- Создание:  psql -U postgres -d readtogether -f postgresql_schema.sql

BEGIN;

CREATE TABLE users (
    user_id       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(30)  NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    password_hash TEXT         NOT NULL,          -- на сервере лучше bcrypt/argon2
    avatar_url    TEXT,
    bio           VARCHAR(200),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE books (
    book_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title        VARCHAR(100) NOT NULL,
    author       VARCHAR(60)  NOT NULL,
    cover_url    TEXT,
    description  TEXT,
    genre        VARCHAR(40),
    year         INTEGER,
    pages        INTEGER CHECK (pages IS NULL OR pages > 0),
    rating       NUMERIC(2,1) CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
    file_url     TEXT,                              -- ссылка на файл в S3
    file_format  VARCHAR(4) CHECK (file_format IS NULL OR file_format IN ('EPUB','PDF','TXT')),
    uploaded_by  INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    access_level VARCHAR(8) NOT NULL DEFAULT 'Public'
                 CHECK (access_level IN ('Private','Friends','Public'))
);

CREATE TABLE library (
    library_id       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id          INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    book_id          INTEGER NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
    status           VARCHAR(8) NOT NULL CHECK (status IN ('Reading','Planned','Finished')),
    progress_percent SMALLINT NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
    pages_read       INTEGER  NOT NULL DEFAULT 0,
    added_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, book_id)
);

CREATE TABLE reading_rooms (
    room_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_id     INTEGER NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
    creator_id  INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    name        VARCHAR(50) NOT NULL,
    privacy     VARCHAR(10) NOT NULL CHECK (privacy IN ('Friends','InviteOnly')),
    target_date TIMESTAMPTZ,                         -- цель: дочитать к дате
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE bookmarks (
    bookmark_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id        INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    book_id        INTEGER NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
    room_id        INTEGER REFERENCES reading_rooms(room_id) ON DELETE CASCADE,
    chapter_number INTEGER,
    page_number    INTEGER NOT NULL,
    text_snippet   TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE notes (
    note_id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id        INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    book_id        INTEGER NOT NULL REFERENCES books(book_id) ON DELETE CASCADE,
    chapter_number INTEGER,
    page_number    INTEGER,
    content        VARCHAR(500) NOT NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE friendships (
    friendship_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id_1     INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    user_id_2     INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status        VARCHAR(8) NOT NULL CHECK (status IN ('Pending','Accepted','Declined')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id_1, user_id_2),
    CHECK (user_id_1 <> user_id_2)
);

CREATE TABLE room_members (
    member_id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_id          INTEGER NOT NULL REFERENCES reading_rooms(room_id) ON DELETE CASCADE,
    user_id          INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status           VARCHAR(8) NOT NULL CHECK (status IN ('Invited','Joined','Declined')),
    progress_percent SMALLINT NOT NULL DEFAULT 0,
    joined_at        TIMESTAMPTZ,
    last_read_at     TIMESTAMPTZ,                    -- для счётчика непрочитанных
    UNIQUE (room_id, user_id)
);

CREATE TABLE messages (
    message_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_id        INTEGER NOT NULL REFERENCES reading_rooms(room_id) ON DELETE CASCADE,
    user_id        INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    text           VARCHAR(500) NOT NULL,
    chapter_number INTEGER,                          -- защита от спойлеров
    page_number    INTEGER,
    quote          TEXT,                             -- цитата из книги
    kind           VARCHAR(10) NOT NULL DEFAULT 'text' CHECK (kind IN ('text','question')),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE message_reactions (
    reaction_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    message_id  INTEGER NOT NULL REFERENCES messages(message_id) ON DELETE CASCADE,
    user_id     INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    emoji       VARCHAR(8) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (message_id, user_id, emoji)
);

CREATE TABLE activities (
    activity_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    book_id     INTEGER REFERENCES books(book_id) ON DELETE CASCADE,
    type        VARCHAR(20) NOT NULL,                -- reading_session, finished, ...
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE notifications (
    notification_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    actor_id        INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
    room_id         INTEGER REFERENCES reading_rooms(room_id) ON DELETE CASCADE,
    book_id         INTEGER REFERENCES books(book_id) ON DELETE CASCADE,
    type            VARCHAR(20) NOT NULL,            -- room_invite, nudge, comment, ...
    text            TEXT,
    is_read         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE privacy_settings (
    user_id             INTEGER PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    profile_visibility  VARCHAR(8) NOT NULL DEFAULT 'Everyone',
    library_visibility  VARCHAR(8) NOT NULL DEFAULT 'Friends',
    activity_visibility VARCHAR(8) NOT NULL DEFAULT 'Everyone',
    room_invites_from   VARCHAR(8) NOT NULL DEFAULT 'Friends'
);

CREATE TABLE user_preferences (
    user_id         INTEGER PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    theme           VARCHAR(20) NOT NULL DEFAULT 'Light (System)',
    language        VARCHAR(5)  NOT NULL DEFAULT 'ru',
    push_enabled    BOOLEAN NOT NULL DEFAULT TRUE,
    email_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
    favorite_genres TEXT
);

CREATE TABLE reader_settings (
    user_id      INTEGER PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
    font_family  VARCHAR(20)  NOT NULL DEFAULT 'Inter',
    font_size    SMALLINT     NOT NULL DEFAULT 16 CHECK (font_size BETWEEN 12 AND 28),
    line_spacing NUMERIC(2,1) NOT NULL DEFAULT 1.5,
    reader_theme VARCHAR(5)   NOT NULL DEFAULT 'sepia'
);

CREATE INDEX idx_library_user        ON library(user_id);
CREATE INDEX idx_bookmarks_book      ON bookmarks(user_id, book_id);
CREATE INDEX idx_notes_book          ON notes(user_id, book_id);
CREATE INDEX idx_messages_room       ON messages(room_id, created_at);
CREATE INDEX idx_reactions_message   ON message_reactions(message_id);
CREATE INDEX idx_activities_user_day ON activities(user_id, created_at);
CREATE INDEX idx_notifications_user  ON notifications(user_id, is_read);

COMMIT;
