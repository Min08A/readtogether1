

Курсовая работа : «Вёрстка пользовательского интерфейса мобильного приложения на Flutter по разработанным прототипам Figma».

Приложение для совместного чтения и обсуждения электронных книг. Все 27 экранов из макета Figma (`docs/figma/`) свёрстаны и работают с локальной базой **SQLite** (14 таблиц из ER-модели курсовой работы №1).

---

## 1. Запуск

Требуется Flutter **3.24+** (Dart 3.5+). Проверьте: `flutter --version`.

```bash
# 1) распакуйте архив и перейдите в папку проекта
cd readtogether

# 2) сгенерируйте платформенные папки и скачайте пакеты
setup.bat          # Windows
./setup.sh         # macOS / Linux
#   (это то же самое, что:
#    flutter create . --project-name readtogether --platforms android,ios,windows
#    flutter pub get)

# 3) запустите на эмуляторе или телефоне
flutter run
```

**На Mac:** `chmod +x setup.sh && ./setup.sh`, затем `flutter run -d macos` (или на симуляторе iPhone). Нужен установленный Xcode: один раз откройте его, затем `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`, `sudo xcodebuild -runFirstLaunch`, `brew install cocoapods`. Проверка — `flutter doctor`.

`flutter create .` только **добавляет** недостающие папки `android/`, `ios/`, `windows/` — файлы `lib/`, `pubspec.yaml`, `assets/` не перезаписываются.

Можно запускать на Android, iOS и на Windows/macOS/Linux desktop (на desktop SQLite работает через `sqflite_common_ffi`). Web не поддерживается — у SQLite нет web-реализации в `sqflite`.

### Демо-аккаунт

| Email | Пароль |
|---|---|
| `amina@readtogether.club` | `amina2026` |



---

## 2. Структура проекта

```
lib/
├── main.dart                     — точка входа, инициализация SQLite и сессии
├── app.dart                      — MaterialApp, выбор стартового экрана
├── theme/                        — цвета (сняты пипеткой с макетов), шрифты, тема
├── models/                       — модели данных (по таблицам БД)
├── data/
│   ├── database_helper.dart      — создание схемы SQLite (14 таблиц, FK, индексы)
│   ├── seed_data.dart            — демо-данные, совпадающие с макетами
│   ├── repos.dart                — единая точка доступа к данным (замена на API/PostgreSQL)
│   └── repositories/             — весь SQL: auth, books, library, marks, social,
│                                   rooms, notifications, settings, stats
├── services/
│   ├── session.dart              — текущий пользователь (SharedPreferences)
│   ├── data_bus.dart             — обновление экранов после изменений в БД
│   └── demo_simulator.dart       — имитация активности друзей (демо-режим)
├── navigation/
│   ├── main_shell.dart           — нижняя навигация (4 вкладки)
│   └── app_navigator.dart        — переходы между экранами
├── utils/                        — валидаторы, сообщения, даты, хеширование, текст книги
├── widgets/                      — переиспользуемые компоненты
└── screens/                      — экраны по разделам
assets/covers/                    — обложки книг (вырезаны из макетов)
assets/fonts/                     — Inter и Lora (OFL), работают без интернета
docs/figma/                       — PNG-экспорт макетов для сравнения
test/                             — модульные тесты (flutter test)
```

### Переиспользуемые виджеты (`lib/widgets/`)

| Виджет | Где используется |
|---|---|
| `PrimaryButton`, `OutlinedAppButton`, `SmallButton`, `CircleIconButton` | все кнопки приложения |
| `LabeledTextField`, `SearchField`, `PlainTextField` | все поля ввода (подпись + поле + ошибка) |
| `AppCard` | все белые карточки со скруглением |
| `BookCover` | обложки (картинка или сгенерированная обложка для загруженных книг) |
| `LetterAvatar`, `AvatarStack` | аватары пользователей |
| `ProgressLine` | прогресс чтения |
| `SectionLabel` | заголовки разделов («ПРОДОЛЖИТЬ ЧТЕНИЕ») |
| `GenreChip`, `RadioDot`, `SelectableRow` | выбор жанров, доступа, друзей, приватности |
| `BackTitleHeader`, `CenteredHeader` | шапки экранов |
| `AppBottomNav` / `NestedBottomNav` | нижняя навигация |
| `EmptyState`, `StatTile`, `LoadingView` | пустые состояния, плитки статистики |
| `showActionSheet`, `showStatusPicker` | нижние меню выбора |
| `MessageInputBar` | поле сообщения в двух экранах Reading Room |

---

## 3. Экраны: Figma → Flutter → SQLite

| # | Макет (`docs/figma/`) | Файл Flutter | Таблицы |
|---|---|---|---|
| 1 | onboarding | `screens/auth/onboarding_screen.dart` | user_preferences (жанры) |
| 2 | login | `screens/auth/login_screen.dart` | users |
| 3 | register | `screens/auth/register_screen.dart` | users + privacy_settings, user_preferences, reader_settings |
| 4 | forgot-password | `screens/auth/forgot_password_screen.dart` | users |
| 5 | home | `screens/home/home_screen.dart` | library, friendships, books, notifications |
| 6 | discover | `screens/discover/discover_screen.dart` | books |
| 7 | book-details | `screens/books/book_details_screen.dart` | books, library, friendships |
| 8 | my-library | `screens/library/library_screen.dart` | library, books |
| 9 | empty-library | там же (пустое состояние) | library |
| 10 | reader | `screens/reader/reader_screen.dart` | books, library, bookmarks, reader_settings, activities |
| 11 | reader-settings | `screens/reader/reader_settings_sheet.dart` | reader_settings |
| 12 | bookmarks-notes | `screens/reader/bookmarks_notes_screen.dart` | bookmarks, notes |
| 13 | upload-book | `screens/upload/upload_book_screen.dart` | books, library |
| 14 | upload-success | `screens/upload/upload_success_screen.dart` | books |
| 15 | create-room | `screens/rooms/create_room_screen.dart` | reading_rooms, room_members, notifications |
| 16 | room-invite | `screens/rooms/room_invite_dialog.dart` | room_members, reading_rooms |
| 17 | reading-together | `screens/rooms/reading_room_screen.dart` | room_members, bookmarks, messages |
| 18 | reading-room | `screens/rooms/room_discussion_screen.dart` | room_members, bookmarks, messages |
| 19 | friends | `screens/friends/friends_screen.dart` | friendships, library |
| 20 | friend-profile | `screens/friends/friend_profile_screen.dart` | users, library, privacy_settings |
| 21 | search-users | `screens/friends/search_users_screen.dart` | users, friendships |
| 22 | activity | `screens/friends/activity_screen.dart` | activities |
| 23 | profile | `screens/profile/profile_screen.dart` | users, library, bookmarks, activities |
| 24 | edit-profile | `screens/profile/edit_profile_screen.dart` | users |
| 25 | settings | `screens/profile/settings_screen.dart` | privacy_settings, user_preferences, users |
| 26 | notifications | `screens/notifications/notifications_screen.dart` | notifications, room_members |
| 27 | reading-stats | `screens/profile/reading_stats_screen.dart` | library, activities, room_members (только чтение) |

---

## 4. Навигация и сценарии

Нижняя навигация: **Главное · Библиотека · Друзья · Профиль**. Вложенные экраны (Поиск, Уведомления, Активность, Найти друзей, Профиль друга, Настройки) тоже показывают нижнюю панель, как на макетах, — нажатие возвращает на нужную вкладку. Системная кнопка «назад» на вкладке, отличной от «Главное», возвращает на «Главное».

Все сценарии из КР №1 проходятся полностью:

1. **Регистрация:** Onboarding → жанры → «Начать» → Регистрация → Home.
2. **Поиск книги:** Home → 🔍 → Discover → книга → «Добавить в библиотеку» → выбор раздела.
3. **Загрузка книги:** Библиотека → ⊕ → выбрать файл → метаданные → доступ → «Добавить» → Upload Success.
4. **Чтение:** Home → «Продолжить чтение» → Reader → свайп/тап у края → «Закладка», «Выделения», «Настройки».
5. **Совместное чтение:** Book Details → «Читают: N друзей» → «Создать Reading Room» → Reading Room → сообщения, общие закладки.
6. **Друзья:** Друзья → 👤+ → Найти друзей → «Добавить» → «Отправлено»; запросы «Принять/Отклонить» → Профиль друга → «Читать вместе».
7. **Профиль:** Профиль → 📊 Статистика / ⚙ Настройки / «Редактировать» → «Сохранить».
8. **Уведомления:** Home → 🔔 → приглашение → «Принять» → Reading Room.
9. **Настройки:** приватность, тема, уведомления, помощь, о нас, смена пароля, выход.

Дополнительно: долгое нажатие на книгу в библиотеке — смена статуса / удаление; свайп влево по закладке или уведомлению — удаление с подтверждением.

---

## 5. Валидация полей

| Поле | Правила |
|---|---|
| Email | обязательно, формат `name@example.com`, ≤ 100 символов, уникальность в БД |
| Имя | 2–30 символов, только буквы (лат./кир./каз.), пробел, дефис |
| Пароль (новый) | 8–64 символа, буквы и цифры, без пробелов; подтверждение должно совпадать |
| Пароль (вход) | обязательно, ≥ 6 символов; проверка по хешу в БД |
| Био | ≤ 200 символов |
| Название комнаты | 3–50 символов; нужен хотя бы один приглашённый друг |
| Заметка / сообщение | не пустое, ≤ 500 символов |
| Номер страницы | целое число в диапазоне 1…N (N — страниц в книге) |
| Название / автор книги | обязательно, ≤ 100 / ≤ 60 символов |
| Файл книги | только EPUB / PDF / TXT, ≤ 50 МБ |

Ошибки показываются **под полем** (красным) и дублируются сообщением о причине.

## 6. Информационные сообщения (`utils/app_messages.dart`)

* **Успех** (зелёный SnackBar): «Профиль сохранён», «Закладка добавлена», «Комната создана…».
* **Ошибка** (красный): «Неверный пароль», «Аккаунт с таким email не найден», «Выберите хотя бы один жанр».
* **Предупреждение** (оранжевый): «На этой странице уже есть закладка», «Есть несохранённые изменения».
* **Подтверждение** (AlertDialog): удаление книги/закладки/друга, выход, отклонение приглашения.
* **Недоступное действие**: «Это последняя страница книги», «Запрос уже отправлен», «Загрузка фото будет доступна…».
* **Информация**: «Книга добавлена в раздел „Читаю“», «Вы вышли из аккаунта».

---

## 7. Обоснованные отличия от макета

* **Шрифты.** Используются Inter (интерфейс) и Lora (с засечками) — встроены в приложение, работают без интернета и поддерживают кириллицу и казахские буквы.
* **Ссылки «Все» / «+ Добавить» / «Все сообщения»** в заголовках разделов добавлены, чтобы на экраны «Активность», «Обсуждение» и добавление общей закладки можно было попасть (в макете отдельной кнопки нет).
* **Настройки:** добавлены пункты «Выйти из аккаунта» и «Сбросить демо-данные» — без выхода невозможно продемонстрировать вход/регистрацию.
* **Найти друзей:** показываются пользователи, которые ещё **не** в друзьях (Daniyar, Alina, Maria в демо-данных уже друзья, поэтому в поиске другие имена).
* **Цифры** (страницы, проценты, счётчики) берутся из базы данных, а не рисуются статично, поэтому могут немного отличаться от макета.
* **Тёмная тема** реализована в читалке; для интерфейса пункт выдаёт предупреждение «появится в следующей версии».
* **Тексты книг каталога** — демонстрационные (полные тексты защищены авторским правом). Загруженные **TXT**-файлы открываются полностью; для EPUB/PDF показывается пример текста.
* В «Upload Success» в круг добавлена галочка, а заголовок «Рекомендаций для тебя» исправлен на «Рекомендации для тебя».

---

## 8. База данных

Файл `readtogether.db` создаётся при первом запуске (`DatabaseHelper`). Включены `PRAGMA foreign_keys = ON`, `ON DELETE CASCADE`, уникальные ограничения (`UNIQUE(user_id, book_id)` в library, `UNIQUE(user_id_1, user_id_2)` в friendships, `UNIQUE(room_id, user_id)` в room_members) и `CHECK` для статусов.
Единственное расширение схемы КР №1 — необязательное поле `notifications.book_id` (чтобы уведомление-рекомендация открывало книгу).

Пароли хранятся как `соль$SHA-256`, сам пароль не сохраняется.

---

## 9. Совместное чтение  

| Функция | Где | Как работает |
|---|---|---|
| **Мои Reading Rooms** | Главная → блок «Мои Reading Rooms», «Все» → `rooms_list_screen.dart` | Карточки комнат: участники, последнее сообщение, **счётчик непрочитанных**, огонёк комнаты; приглашения с «Принять/Отклонить» |
| **Связь с читалкой** | `reader_screen.dart` | Полоска «Читаете вместе: Daniyar · стр. 190 ↑»; кнопка «Читать» в комнате; меню «Обсудить эту страницу» и «Общая закладка в комнату»; **долгое нажатие на абзац** — цитата сразу в чат |
| **Защита от спойлеров** | обе страницы комнаты | Сообщения и закладки о главах дальше вашей скрыты плашкой «Спойлер · глава N». «Показать» спрашивает подтверждение |
| **Цель и темп** | Create Room → «Цель», Reading Room → карточка цели | «Дочитать к дате»: прогресс по плану, сколько страниц в день; у участников метки «впереди / по графику / отстаёт»; кнопка **«Поторопить»** (уведомление, не чаще 1 раза в день) |
| **Реакции и вопросы** | обсуждение | Долгое нажатие на сообщение → 👍 ❤️ 😂 😮 🔥; кнопка **«?»** публикует «Вопрос к главе» (выделяется) |
| **🔥 Огоньки (как в TikTok)** | Главная (личный), Друзья, Профиль друга, комнаты | Серия дней подряд: личная — вы читали; **с другом — читали оба**; комнаты — книгу читали минимум двое. Серый огонёк с ⏳ — серия под угрозой (сегодня ещё не читали) |
| **Демо-активность друзей** | `services/demo_simulator.dart`, выключается в Настройках | Сервера нет, поэтому друзья «оживлены» локально: отвечают на сообщения через 3–6 с, ставят реакции, их прогресс растёт. **Это имитация** — после подключения сервера класс удаляется |

Изменения базы (версия 2, миграция `onUpgrade` сохраняет данные): `reading_rooms.target_date`, `room_members.last_read_at`, `messages.chapter_number / page_number / quote / kind`, новая таблица `message_reactions`. Огоньки **не хранятся**, а вычисляются из `activities` и `messages` (`streak_repository.dart`).


---

## 10. Переход на PostgreSQL

**Важно:** мобильное приложение не подключают к PostgreSQL напрямую — иначе логин и пароль от базы окажутся внутри APK, и любой сможет их достать. Правильная схема:

```
Flutter-приложение ──HTTP/JSON──► сервер (REST API) ──► PostgreSQL
        │                         Dart Shelf / Node.js / Python FastAPI
        └── SQLite остаётся локальным кешем для офлайн-чтения
```

Что уже подготовлено:
* **`docs/postgresql_schema.sql`** — готовая схема всех таблиц для PostgreSQL (IDENTITY, TIMESTAMPTZ, BOOLEAN, внешние ключи, индексы).
* **`lib/data/repos.dart`** — единая точка доступа к данным. Экраны обращаются только к `Repos.books`, `Repos.rooms`… и не знают, что под ними SQLite.

План перехода:
1. Поднять PostgreSQL и выполнить `psql -d readtogether -f docs/postgresql_schema.sql`.
2. Написать сервер с эндпоинтами (`POST /login`, `GET /rooms`, `POST /rooms/{id}/messages`…).
3. Добавить пакет `http` и классы вида `class ApiRoomRepository implements RoomRepository { … }` — в Dart любой класс можно реализовать как интерфейс.
4. В `main.dart` заменить реализации: `Repos.rooms = ApiRoomRepository();` — экраны менять не нужно.
5. Удалить `DemoSimulator` — сообщения друзей начнут приходить с сервера по-настоящему (для мгновенных обновлений — WebSocket).
