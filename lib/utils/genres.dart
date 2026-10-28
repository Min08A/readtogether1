/// Справочник жанров, используемый на Onboarding и в Discover.
class Genres {
  Genres._();

  static const List<String> all = [
    'Фикшн',
    'Фантазия',
    'Романтика',
    'Детектив',
    'Sci-Fi',
    'Классика',
    'Ужасы',
    'Нон-фикшн',
  ];

  /// Какие значения books.genre относятся к жанру-фильтру.
  static const Map<String, List<String>> _aliases = {
    'Sci-Fi': ['Sci-Fi', 'Антиутопия'],
    'Фантазия': ['Фантазия', 'Фэнтези'],
  };

  static List<String> dbValuesFor(String chip) => _aliases[chip] ?? [chip];

  /// Приводит жанр книги к одному из жанров-фильтров (для статистики).
  static String normalize(String? genre) {
    if (genre == null || genre.isEmpty) return 'Другое';
    for (final entry in _aliases.entries) {
      if (entry.value.any((v) => v.toLowerCase() == genre.toLowerCase())) {
        return entry.key;
      }
    }
    return genre;
  }
}
