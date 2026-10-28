import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../models/library_entry.dart';
import '../../navigation/app_navigator.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/date_format.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/sheets.dart';
import '../reader/reader_screen.dart';
import '../rooms/create_room_screen.dart';

/// Экран 7. Book Details — обложка, автор, год, страницы, жанр, описание,
/// «Начать чтение», «Добавить в библиотеку», друзья, которые читают.
class BookDetailsScreen extends StatefulWidget {
  final int bookId;
  const BookDetailsScreen({super.key, required this.bookId});

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen>
    with ReloadOnDataChange {
  final _library = Repos.library;
  Book? _book;
  LibraryEntry? _entry;
  List<AppUser> _friends = [];
  bool _loading = true;

  int get _uid => Session.instance.userId;

  @override
  Future<void> load() async {
    final book = await Repos.books.byId(widget.bookId);
    final entry = await _library.entry(_uid, widget.bookId);
    final friends = await Repos.books.friendsWithBook(_uid, widget.bookId);
    if (!mounted) return;
    setState(() {
      _book = book;
      _entry = entry;
      _friends = friends;
      _loading = false;
    });
  }

  Future<void> _addToLibrary() async {
    final book = _book!;
    final entry = _entry;
    final status = await showStatusPicker(
      context,
      current: entry?.status,
      title: entry == null ? 'Добавить в библиотеку' : 'Изменить статус',
    );
    if (status == null || !mounted) return;
    if (entry == null) {
      await _library.add(_uid, book.id, status);
      if (!mounted) return;
      AppMessages.success(
          context, '«${book.title}» добавлена в раздел «${status.label}»');
    } else if (entry.status == status) {
      AppMessages.info(context, 'Книга уже находится в разделе «${status.label}»');
    } else {
      await _library.updateStatus(_uid, book.id, status, book.pageCount);
      if (!mounted) return;
      AppMessages.success(context, 'Статус изменён на «${status.label}»');
    }
  }

  /// Иконка-закладка в шапке: быстрое добавление в «В планах».
  Future<void> _quickSave() async {
    final book = _book!;
    final entry = _entry;
    if (entry != null) {
      AppMessages.warning(context,
          'Книга уже в вашей библиотеке (раздел «${entry.status.label}»)');
      return;
    }
    await _library.add(_uid, book.id, LibraryStatus.planned);
    if (!mounted) return;
    AppMessages.success(context, 'Книга сохранена в «В планах»');
  }

  void _showFriends() {
    final book = _book!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  _friends.isEmpty
                      ? 'Никто из друзей пока не читает эту книгу'
                      : 'Эту книгу читают',
                  style: AppTextStyles.centeredHeader),
              const SizedBox(height: 12),
              for (final f in _friends)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      LetterAvatar(name: f.name, size: 34),
                      const SizedBox(width: 12),
                      Text(f.name, style: AppTextStyles.itemTitle),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Создать Reading Room',
                icon: Icons.groups_outlined,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  AppNavigator.push(context, CreateRoomScreen(bookId: book.id));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const LoadingView()
            : book == null
                ? const EmptyState(
                    icon: Icons.error_outline, title: 'Книга не найдена')
                : _content(book),
      ),
    );
  }

  Widget _content(Book book) {
    final entry = _entry;
    final inProgress = entry != null && entry.pagesRead > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Row(
          children: [
            CircleIconButton.backOutlined(
                onTap: () => Navigator.of(context).pop()),
            const Spacer(),
            CircleIconButton(
              icon: entry == null ? Icons.bookmark_border : Icons.bookmark,
              background: Colors.transparent,
              iconSize: 24,
              tooltip: 'Сохранить в «В планах»',
              onTap: _quickSave,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: BookCover(
              book: book, width: 130, height: 190, radius: 6, shadow: true),
        ),
        const SizedBox(height: 22),
        Text(book.title,
            textAlign: TextAlign.center,
            style: AppTextStyles.bookTitleSerif.copyWith(fontSize: 27)),
        const SizedBox(height: 4),
        Text(book.author,
            textAlign: TextAlign.center,
            style: AppTextStyles.author.copyWith(fontSize: 15)),
        const SizedBox(height: 26),
        Row(
          children: [
            _meta('Год', book.year?.toString() ?? '—'),
            _meta('Страниц', book.pages?.toString() ?? '—'),
            _meta('Жанр', (book.genre ?? '—').toLowerCase()),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          book.description ?? 'Описание отсутствует.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.sans,
            fontSize: 14,
            height: 1.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: inProgress ? 'Продолжить чтение' : 'Начать чтение',
          onPressed: () =>
              AppNavigator.push(context, ReaderScreen(bookId: book.id)),
        ),
        const SizedBox(height: 12),
        OutlinedAppButton(
          label: entry == null
              ? 'Добавить в библиотеку'
              : 'В библиотеке · ${entry.status.label}',
          onPressed: _addToLibrary,
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: _showFriends,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                if (_friends.isNotEmpty) ...[
                  AvatarStack(names: _friends.map((f) => f.name).toList()),
                  const SizedBox(width: 10),
                ] else ...[
                  const Icon(Icons.group_add_outlined,
                      size: 22, color: AppColors.textSecondary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    _friends.isEmpty
                        ? 'Пригласить друзей читать вместе'
                        : 'Читают: ${_friends.length} ${DateFormatRu.plural(_friends.length, 'друг', 'друга', 'друзей')}',
                    style: AppTextStyles.caption.copyWith(fontSize: 12.5),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _meta(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label.toUpperCase(),
              style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: AppTextStyles.sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
