/// Закладка (таблица bookmarks) или заметка (таблица notes).
/// Объединены в одну модель, потому что выводятся в одном списке
/// на экране «Закладки и заметки».
class ReadingMark {
  final int id;
  final bool isNote;
  final int userId;
  final String userName;
  final int bookId;
  final int? roomId;
  final int? chapterNumber;
  final int? pageNumber;

  /// Для закладки — отрывок текста, для заметки — текст заметки.
  final String text;
  final DateTime createdAt;

  const ReadingMark({
    required this.id,
    required this.isNote,
    required this.userId,
    required this.userName,
    required this.bookId,
    this.roomId,
    this.chapterNumber,
    this.pageNumber,
    required this.text,
    required this.createdAt,
  });

  factory ReadingMark.bookmarkFromMap(Map<String, Object?> map) => ReadingMark(
        id: map['bookmark_id'] as int,
        isNote: false,
        userId: map['user_id'] as int,
        userName: (map['user_name'] as String?) ?? '',
        bookId: map['book_id'] as int,
        roomId: map['room_id'] as int?,
        chapterNumber: map['chapter_number'] as int?,
        pageNumber: map['page_number'] as int?,
        text: (map['text_snippet'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  factory ReadingMark.noteFromMap(Map<String, Object?> map) => ReadingMark(
        id: map['note_id'] as int,
        isNote: true,
        userId: map['user_id'] as int,
        userName: (map['user_name'] as String?) ?? '',
        bookId: map['book_id'] as int,
        chapterNumber: map['chapter_number'] as int?,
        pageNumber: map['page_number'] as int?,
        text: map['content'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
