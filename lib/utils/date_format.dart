/// Форматирование дат по-русски без внешних пакетов.
class DateFormatRu {
  DateFormatRu._();

  static const _months = [
    'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];

  /// «только что», «10 минут назад», «2 часа назад», «вчера», «12 окт».
  static String relative(DateTime date, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final diff = n.difference(date);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${_plural(diff.inMinutes, 'минуту', 'минуты', 'минут')} назад';
    }
    if (diff.inHours < 24 && n.day == date.day) {
      return '${diff.inHours} ${_plural(diff.inHours, 'час', 'часа', 'часов')} назад';
    }
    if (isYesterday(date, now: n)) return 'Вчера';
    if (diff.inDays < 7) {
      final d = diff.inDays < 1 ? 1 : diff.inDays;
      return '$d ${_plural(d, 'день', 'дня', 'дней')} назад';
    }
    return shortDate(date);
  }

  /// «12 окт».
  static String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  /// «12:40».
  static String time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static bool isToday(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  static bool isYesterday(DateTime d, {DateTime? now}) {
    final y = (now ?? DateTime.now()).subtract(const Duration(days: 1));
    return d.year == y.year && d.month == y.month && d.day == y.day;
  }

  /// «Создана сегодня» / «Создана вчера» / «Создана 12 окт».
  static String createdLabel(DateTime d) {
    if (isToday(d)) return 'Создана сегодня';
    if (isYesterday(d)) return 'Создана вчера';
    return 'Создана ${shortDate(d)}';
  }

  static String _plural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  /// Склонение для произвольных слов: plural(3, 'друг', 'друга', 'друзей').
  static String plural(int n, String one, String few, String many) =>
      _plural(n, one, few, many);
}
