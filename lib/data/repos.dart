import 'repositories/auth_repository.dart';
import 'repositories/book_repository.dart';
import 'repositories/library_repository.dart';
import 'repositories/marks_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/room_repository.dart';
import 'repositories/settings_repository.dart';
import 'repositories/social_repository.dart';
import 'repositories/stats_repository.dart';
import 'repositories/streak_repository.dart';

/// Единая точка доступа к данным.
///
/// Экраны НЕ создают репозитории сами и не знают, откуда берутся данные:
/// они обращаются к `Repos.books`, `Repos.rooms` и т. д.
///
/// Сейчас все репозитории работают с локальной SQLite. Чтобы перейти на
/// сервер с PostgreSQL, достаточно написать новую реализацию, например
///
///   class ApiBookRepository implements BookRepository { ... HTTP-запросы ... }
///
/// и заменить её здесь (или в main.dart):  `Repos.books = ApiBookRepository();`
/// В Dart любой класс является интерфейсом, поэтому экраны менять не нужно.
/// Подробнее — README, раздел «Переход на PostgreSQL», и docs/postgresql_schema.sql.
class Repos {
  Repos._();

  static AuthRepository auth = AuthRepository();
  static BookRepository books = BookRepository();
  static LibraryRepository library = LibraryRepository();
  static MarksRepository marks = MarksRepository();
  static SocialRepository social = SocialRepository();
  static RoomRepository rooms = RoomRepository();
  static NotificationRepository notifications = NotificationRepository();
  static SettingsRepository settings = SettingsRepository();
  static StatsRepository stats = StatsRepository();
  static StreakRepository streaks = StreakRepository();
}
