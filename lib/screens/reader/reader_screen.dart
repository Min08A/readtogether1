import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/book.dart';
import '../../models/library_entry.dart';
import '../../models/reading_room.dart';
import '../../models/settings.dart';
import '../../navigation/app_navigator.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/book_text.dart';
import '../../widgets/common.dart';
import '../../widgets/sheets.dart';
import '../books/book_details_screen.dart';
import '../rooms/create_room_screen.dart';
import '../rooms/reading_room_screen.dart';
import '../rooms/room_widgets.dart';
import 'bookmarks_notes_screen.dart';
import 'note_dialog.dart';
import 'reader_settings_sheet.dart';

/// Экран 9. Reader — текст главы, название, прогресс, доступ к закладкам
/// и заметкам. Листание — свайпом или нажатием у края экрана.
class ReaderScreen extends StatefulWidget {
  final int bookId;
  const ReaderScreen({super.key, required this.bookId});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _library = Repos.library;
  final _marks = Repos.marks;
  final _scroll = ScrollController();

  Book? _book;
  BookContent? _content;
  ReaderSettings? _settings;
  int _page = 1;
  bool _bookmarked = false;
  bool _loading = true;
  bool _askedToFinish = false;

  /// Комнаты по этой книге и участники (для «Читаете вместе»).
  List<ReadingRoom> _rooms = [];
  List<RoomMember> _companions = [];

  int get _uid => Session.instance.userId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scroll.dispose();
    // Обновляем остальные экраны (прогресс на Home, в библиотеке, в комнатах).
    Future.microtask(DataBus.instance.changed);
    super.dispose();
  }

  Future<void> _init() async {
    final book = await Repos.books.byId(widget.bookId);
    if (book == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final content = await BookContent.load(book);
    final settings = await Repos.settings.readerSettings(_uid);
    final entry = await _library.entry(_uid, book.id);
    final start = (entry == null || entry.pagesRead < 1)
        ? 1
        : entry.pagesRead.clamp(1, content.pageCount).toInt();
    await _library.saveProgress(_uid, book.id, start, content.pageCount,
        notify: false);
    await _library.logReadingSession(_uid, book.id);
    final bookmarked = await _marks.hasBookmarkOnPage(_uid, book.id, start);
    await _loadCompanions(book.id);
    if (!mounted) return;
    setState(() {
      _book = book;
      _content = content;
      _settings = settings;
      _page = start;
      _bookmarked = bookmarked;
      _askedToFinish = entry?.status == LibraryStatus.finished;
      _loading = false;
    });
    if (entry == null) {
      AppMessages.info(context, 'Книга добавлена в раздел «Читаю»');
    }
  }

  Future<void> _goTo(int page) async {
    final content = _content!;
    final book = _book!;
    if (page < 1) {
      AppMessages.unavailable(context, 'Это первая страница книги');
      return;
    }
    if (page > content.pageCount) {
      AppMessages.unavailable(context, 'Это последняя страница книги');
      return;
    }
    await _library.saveProgress(_uid, book.id, page, content.pageCount,
        notify: false);
    final bookmarked = await _marks.hasBookmarkOnPage(_uid, book.id, page);
    if (!mounted) return;
    setState(() {
      _page = page;
      _bookmarked = bookmarked;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (page == content.pageCount && !_askedToFinish) {
      _askedToFinish = true;
      final finish = await AppMessages.confirm(
        context,
        title: 'Книга дочитана!',
        message: 'Отметить «${book.title}» как прочитанную?',
        confirmText: 'Отметить',
        cancelText: 'Позже',
      );
      if (finish) {
        await _library.updateStatus(
            _uid, book.id, LibraryStatus.finished, content.pageCount);
        if (mounted) {
          AppMessages.success(context, 'Книга перемещена в «Закончено»');
        }
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final book = _book!;
    if (_bookmarked) {
      AppMessages.warning(context,
          'На этой странице уже есть закладка. Управлять закладками можно в разделе «Выделения»');
      return;
    }
    final page = _content!.page(_page);
    final first = page.paragraphs.isEmpty ? '' : page.paragraphs.first;
    final snippet =
        first.length > 110 ? '${first.substring(0, 110).trimRight()}…' : first;
    await _marks.addBookmark(
      userId: _uid,
      bookId: book.id,
      chapter: page.chapter,
      page: _page,
      snippet: snippet,
    );
    if (!mounted) return;
    setState(() => _bookmarked = true);
    AppMessages.success(
        context, 'Закладка добавлена: глава ${page.chapter}, стр. $_page');
  }

  void _openSettings() {
    showReaderSettingsSheet(
      context,
      settings: _settings!,
      onChanged: (s) {
        setState(() => _settings = s);
        Repos.settings.saveReaderSettings(s);
      },
    );
  }

  Future<void> _openMarks() async {
    final page = await AppNavigator.push<int>(
        context, BookmarksNotesScreen(bookId: widget.bookId));
    if (page != null && mounted) _goTo(page);
  }

  Future<void> _loadCompanions(int bookId) async {
    final rooms = await Repos.rooms.joinedRooms(_uid, bookId: bookId);
    final byUser = <int, RoomMember>{};
    for (final r in rooms) {
      for (final m in await Repos.rooms.members(r.id)) {
        if (m.userId != _uid) byUser[m.userId] = m;
      }
    }
    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _companions = byUser.values.toList();
    });
  }

  /// Нет комнаты по книге — предлагаем создать.
  Future<ReadingRoom?> _requireRoom() async {
    if (_rooms.isNotEmpty) return pickRoom(context, _rooms);
    final create = await AppMessages.confirm(
      context,
      title: 'Нет комнаты по этой книге',
      message:
          'Чтобы обсуждать страницы и ставить общие закладки, создайте Reading Room и пригласите друзей.',
      confirmText: 'Создать комнату',
    );
    if (create && mounted) {
      await AppNavigator.push(context, CreateRoomScreen(bookId: widget.bookId));
      if (mounted) await _loadCompanions(widget.bookId);
    }
    return null;
  }

  /// «Обсудить эту страницу»: цитата → чат комнаты.
  Future<void> _discuss({String? paragraph}) async {
    final room = await _requireRoom();
    if (room == null || !mounted) return;
    final page = _content!.page(_page);
    final source = paragraph ?? (page.paragraphs.isEmpty ? '' : page.paragraphs.first);
    final quote =
        source.length > 220 ? '${source.substring(0, 220).trimRight()}…' : source;
    final sent = await showDiscussPageSheet(context,
        room: room, quote: quote, page: _page, chapter: page.chapter);
    if (sent != null && mounted) {
      AppMessages.success(context, 'Отправлено в «${sent.name}»');
    }
  }

  /// Общая закладка в комнату с текущей страницы.
  Future<void> _sharedBookmark({String? paragraph}) async {
    final room = await _requireRoom();
    if (room == null || !mounted) return;
    final page = _content!.page(_page);
    final source = paragraph ?? (page.paragraphs.isEmpty ? '' : page.paragraphs.first);
    final added = await showAddRoomBookmarkDialog(context, room,
        initialPage: _page,
        initialText: source.length > 200 ? source.substring(0, 200) : source);
    if (added && mounted) {
      AppMessages.success(context, 'Общая закладка добавлена в «${room.name}»');
    }
  }

  /// Долгое нажатие на абзац — действия с цитатой.
  Future<void> _paragraphActions(String paragraph) async {
    final action = await showActionSheet<String>(
      context,
      title: 'Отрывок',
      actions: const [
        SheetAction(
            value: 'discuss',
            label: 'Обсудить в комнате',
            icon: Icons.forum_outlined),
        SheetAction(
            value: 'shared',
            label: 'Общая закладка в комнату',
            icon: Icons.bookmark_add_outlined),
        SheetAction(value: 'note', label: 'Заметка', icon: Icons.edit_note),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'discuss':
        await _discuss(paragraph: paragraph);
      case 'shared':
        await _sharedBookmark(paragraph: paragraph);
      case 'note':
        final saved = await showAddNoteDialog(context,
            bookId: widget.bookId,
            maxPage: _content!.pageCount,
            initialPage: _page);
        if (saved && mounted) AppMessages.success(context, 'Заметка сохранена');
    }
  }

  Future<void> _openRoom() async {
    final room = await pickRoom(context, _rooms);
    if (room != null && mounted) {
      AppNavigator.push(context, ReadingRoomScreen(roomId: room.id));
    }
  }

  Future<void> _menu() async {
    final action = await showActionSheet<String>(
      context,
      actions: const [
        SheetAction(
            value: 'marks',
            label: 'Закладки и заметки',
            icon: Icons.bookmarks_outlined),
        SheetAction(
            value: 'note', label: 'Добавить заметку', icon: Icons.edit_note),
        SheetAction(
            value: 'goto',
            label: 'Перейти к странице',
            icon: Icons.find_in_page_outlined),
        SheetAction(
            value: 'discuss',
            label: 'Обсудить эту страницу',
            icon: Icons.forum_outlined),
        SheetAction(
            value: 'shared',
            label: 'Общая закладка в комнату',
            icon: Icons.bookmark_add_outlined),
        SheetAction(
            value: 'room',
            label: 'Reading Room по книге',
            icon: Icons.groups_outlined),
        SheetAction(value: 'details', label: 'О книге', icon: Icons.info_outline),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'marks':
        _openMarks();
      case 'note':
        final saved = await showAddNoteDialog(context,
            bookId: widget.bookId,
            maxPage: _content!.pageCount,
            initialPage: _page);
        if (saved && mounted) AppMessages.success(context, 'Заметка сохранена');
      case 'goto':
        final page = await showGoToPageDialog(context,
            current: _page, maxPage: _content!.pageCount);
        if (page != null && mounted) _goTo(page);
      case 'discuss':
        await _discuss();
      case 'shared':
        await _sharedBookmark();
      case 'room':
        if (_rooms.isEmpty) {
          AppNavigator.push(context, CreateRoomScreen(bookId: widget.bookId));
        } else {
          await _openRoom();
        }
      case 'details':
        AppNavigator.push(context, BookDetailsScreen(bookId: widget.bookId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    final (bg, fg) = readerColors(settings?.readerTheme ?? ReaderTheme.sepia);
    final dark = settings?.readerTheme == ReaderTheme.dark;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _loading
            ? const LoadingView()
            : _book == null
                ? const EmptyState(
                    icon: Icons.error_outline, title: 'Книга не найдена')
                : _reader(fg, dark),
      ),
      bottomNavigationBar: _loading || _book == null ? null : _bottomBar(dark),
    );
  }

  Widget _reader(Color fg, bool dark) {
    final book = _book!;
    final content = _content!;
    final settings = _settings!;
    final page = content.page(_page);
    final font = readerFontStyle(settings.fontFamily);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Назад',
                icon: Icon(Icons.arrow_circle_left_outlined, color: fg, size: 26),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(book.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AppTextStyles.serif,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: fg)),
              ),
              IconButton(
                tooltip: 'Меню',
                icon: Icon(Icons.more_horiz, color: fg),
                onPressed: _menu,
              ),
            ],
          ),
        ),
        if (_companions.isNotEmpty) _companionsStrip(fg, dark),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -150) _goTo(_page + 1);
                if (v > 150) _goTo(_page - 1);
              },
              onTapUp: (d) {
                final x = d.localPosition.dx;
                if (x < constraints.maxWidth * 0.2) _goTo(_page - 1);
                if (x > constraints.maxWidth * 0.8) _goTo(_page + 1);
              },
              child: SingleChildScrollView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text('Глава ${page.chapter}',
                          style: TextStyle(
                              fontFamily: AppTextStyles.sans,
                              fontSize: (settings.fontSize + 5).toDouble(),
                              fontWeight: FontWeight.w700,
                              color: fg)),
                    ),
                    const SizedBox(height: 18),
                    for (final p in page.paragraphs) ...[
                      GestureDetector(
                        onLongPress: () => _paragraphActions(p),
                        child: Text(
                          p,
                          style: font.copyWith(
                            fontSize: settings.fontSize.toDouble() + 1,
                            height: 1.15 * settings.lineSpacing,
                            color: fg,
                          ),
                        ),
                      ),
                      SizedBox(height: settings.fontSize * 0.9),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        InkWell(
          onTap: () async {
            final p = await showGoToPageDialog(context,
                current: _page, maxPage: content.pageCount);
            if (p != null && mounted) _goTo(p);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            child: Text('Страница $_page из ${content.pageCount}',
                style: TextStyle(
                    fontFamily: AppTextStyles.sans,
                    fontSize: 12.5,
                    color: dark ? AppColors.textMuted : AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }

  /// «Читаете вместе»: где сейчас друзья по комнате.
  Widget _companionsStrip(Color fg, bool dark) {
    final pages = _content!.pageCount;
    return InkWell(
      onTap: _openRoom,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF2A2F36) : AppColors.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.groups_outlined, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in _companions) ...[
                      LetterAvatar(name: m.userName, size: 18, fontSize: 9),
                      const SizedBox(width: 4),
                      Text(
                        '${m.userName} · стр. ${m.pageIn(pages)}'
                        '${m.pageIn(pages) > _page ? ' ↑' : m.pageIn(pages) < _page ? ' ↓' : ''}',
                        style: TextStyle(
                            fontFamily: AppTextStyles.sans,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: fg),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ],
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: fg),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(bool dark) {
    final color = dark ? AppColors.readerDarkText : AppColors.textPrimary;
    final muted = dark ? AppColors.textMuted : AppColors.textSecondary;
    Widget item(IconData icon, String label, VoidCallback onTap, Color c) =>
        Expanded(
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: c),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontFamily: AppTextStyles.sans,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: c)),
                ],
              ),
            ),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF181B20) : AppColors.surface,
        border: Border(
            top: BorderSide(
                color: dark ? const Color(0xFF2E333A) : AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            item(_bookmarked ? Icons.bookmark : Icons.bookmark_border,
                'Закладка', _toggleBookmark, color),
            item(Icons.edit_outlined, 'Выделения', _openMarks, muted),
            item(Icons.description_outlined, 'Настройки', _openSettings, muted),
          ],
        ),
      ),
    );
  }
}
