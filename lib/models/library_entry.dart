import 'book.dart';

/// Статусы книги в личной библиотеке (поле library.status).
enum LibraryStatus {
  reading('Reading', 'Читаю'),
  planned('Planned', 'В планах'),
  finished('Finished', 'Закончено');

  const LibraryStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static LibraryStatus fromDb(String value) =>
      LibraryStatus.values.firstWhere((s) => s.dbValue == value,
          orElse: () => LibraryStatus.planned);
}

/// Запись таблицы library вместе с данными книги (JOIN books).
class LibraryEntry {
  final int id;
  final int userId;
  final Book book;
  final LibraryStatus status;
  final int progressPercent;
  final int pagesRead;
  final DateTime addedAt;
  final DateTime updatedAt;

  const LibraryEntry({
    required this.id,
    required this.userId,
    required this.book,
    required this.status,
    required this.progressPercent,
    required this.pagesRead,
    required this.addedAt,
    required this.updatedAt,
  });

  factory LibraryEntry.fromJoinedMap(Map<String, Object?> map) => LibraryEntry(
        id: map['library_id'] as int,
        userId: map['user_id'] as int,
        book: Book.fromMap(map),
        status: LibraryStatus.fromDb(map['status'] as String),
        progressPercent: (map['progress_percent'] as int?) ?? 0,
        pagesRead: (map['pages_read'] as int?) ?? 0,
        addedAt: DateTime.parse(map['added_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}
