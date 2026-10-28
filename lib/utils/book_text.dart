import 'dart:convert';
import 'dart:io';

import '../models/book.dart';

/// Одна страница читалки.
class BookPage {
  final int chapter;
  final List<String> paragraphs;
  const BookPage(this.chapter, this.paragraphs);
}

/// Текст книги, разбитый на страницы.
///
/// * Для загруженных TXT-файлов читается настоящий файл.
/// * Для книг каталога и EPUB/PDF показывается демонстрационный текст
///   (полные тексты книг не входят в учебный проект).
abstract class BookContent {
  int get pageCount;
  BookPage page(int number);

  static const int pagesPerChapter = 13;
  static const int _charsPerPage = 900;

  static int chapterOf(int page) => ((page - 1) ~/ pagesPerChapter) + 1;

  static Future<BookContent> load(Book book) async {
    final path = book.fileUrl;
    if (book.fileFormat == 'TXT' && path != null) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final text = utf8.decode(bytes, allowMalformed: true);
        final pages = splitIntoPages(text);
        if (pages.isNotEmpty) return _TxtContent(pages);
      }
    }
    return _DemoContent(book);
  }

  /// Разбивает текст на страницы по абзацам (~900 символов на страницу).
  static List<List<String>> splitIntoPages(String text) {
    final paragraphs = text
        .replaceAll('\r\n', '\n')
        .split(RegExp(r'\n\s*\n|\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final pages = <List<String>>[];
    var current = <String>[];
    var length = 0;
    for (final p in paragraphs) {
      if (length > 0 && length + p.length > _charsPerPage) {
        pages.add(current);
        current = <String>[];
        length = 0;
      }
      current.add(p);
      length += p.length;
    }
    if (current.isNotEmpty) pages.add(current);
    return pages;
  }

  /// Количество страниц для загружаемого файла.
  static Future<int> estimatePages(File file, String format) async {
    if (format == 'TXT') {
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final pages = splitIntoPages(text).length;
      return pages < 1 ? 1 : pages;
    }
    final size = await file.length();
    return (size ~/ 2000).clamp(1, 2000).toInt();
  }
}

class _TxtContent extends BookContent {
  final List<List<String>> _pages;
  _TxtContent(this._pages);

  @override
  int get pageCount => _pages.length;

  @override
  BookPage page(int number) {
    final i = (number - 1).clamp(0, _pages.length - 1).toInt();
    return BookPage(BookContent.chapterOf(number), _pages[i]);
  }
}

class _DemoContent extends BookContent {
  final Book book;
  _DemoContent(this.book);

  @override
  int get pageCount => book.pageCount;

  // Первая пара абзацев — текст с макета экрана Reader.
  static const List<List<String>> _orwell = [
    [
      'Если есть надежда, она в пролах... Они никогда не взбунтуются, пока не станут сознательными, а сознательными не станут, пока не взбунтуются.',
      'Партия, разумеется, утверждала, что освободила пролов от цепей. Но одновременно, верная принципам двоемыслия, она учила, что по своей природе пролы — низшие существа, которых необходимо держать в подчинении.',
    ],
    [
      'Телекран в углу комнаты не умолкал ни на минуту. Уинстон сидел к нему спиной, стараясь, чтобы лицо не выдало ни одной лишней мысли.',
      'За окном ветер гонял по улице обрывки плакатов. С каждого на прохожих смотрели одни и те же внимательные глаза.',
    ],
    [
      'В министерстве работа начиналась рано. Старые газеты переписывались так, будто прошлое было черновиком, который можно исправлять без конца.',
      'Уинстон опустил исправленный лист в щель пневмотрубы и подумал, что где-то в глубине здания он навсегда исчезнет в огне.',
    ],
  ];

  static const List<String> _generic = [
    'Утро выдалось тихим. Свет медленно заполнял комнату, и казалось, что весь мир ещё не решил, каким будет этот день.',
    'Она открыла книгу на заложенной странице и поймала себя на мысли, что история продолжала жить в ней даже тогда, когда страницы были закрыты.',
    'Дорога уходила за холмы, и никто из путников не знал, что ждёт их за поворотом. Но каждый шаг делал прошлое чуть дальше, а будущее — ближе.',
    'В разговоре было больше пауз, чем слов. Иногда именно молчание объясняет то, на что не хватает предложений.',
    'Город шумел внизу, словно огромное сердце. Где-то в этом ритме терялись чужие голоса, обещания и неотправленные письма.',
    'К вечеру стало ясно, что решение уже принято, хотя никто не произнёс его вслух. Оставалось только дождаться утра.',
  ];

  @override
  BookPage page(int number) {
    final chapter = BookContent.chapterOf(number);
    if (book.title == '1984' && book.author == 'George Orwell') {
      return BookPage(chapter, _orwell[number % _orwell.length]);
    }
    final a = _generic[(number * 3) % _generic.length];
    final b = _generic[(number * 3 + 1) % _generic.length];
    final paragraphs = <String>[a, b];
    if (book.fileFormat == 'PDF' || book.fileFormat == 'EPUB') {
      paragraphs.insert(0,
          'Предпросмотр формата ${book.fileFormat} в учебной версии недоступен — ниже показан пример текста. Файлы TXT открываются полностью.');
    }
    return BookPage(chapter, paragraphs);
  }
}
