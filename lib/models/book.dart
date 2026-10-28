/// Таблица books.
class Book {
  final int id;
  final String title;
  final String author;
  final String? coverUrl;
  final String? description;
  final String? genre;
  final int? year;
  final int? pages;
  final double? rating;
  final String? fileUrl;
  final String? fileFormat;
  final int? uploadedBy;
  final String accessLevel;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    this.coverUrl,
    this.description,
    this.genre,
    this.year,
    this.pages,
    this.rating,
    this.fileUrl,
    this.fileFormat,
    this.uploadedBy,
    this.accessLevel = 'Public',
  });

  /// Количество страниц, никогда не меньше 1 (нужно читалке).
  int get pageCount => (pages == null || pages! < 1) ? 1 : pages!;

  bool get isUploaded => uploadedBy != null;

  factory Book.fromMap(Map<String, Object?> map) => Book(
        id: map['book_id'] as int,
        title: map['title'] as String,
        author: map['author'] as String,
        coverUrl: map['cover_url'] as String?,
        description: map['description'] as String?,
        genre: map['genre'] as String?,
        year: map['year'] as int?,
        pages: map['pages'] as int?,
        rating: (map['rating'] as num?)?.toDouble(),
        fileUrl: map['file_url'] as String?,
        fileFormat: map['file_format'] as String?,
        uploadedBy: map['uploaded_by'] as int?,
        accessLevel: (map['access_level'] as String?) ?? 'Public',
      );
}
