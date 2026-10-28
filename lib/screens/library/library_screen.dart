import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/library_entry.dart';
import '../../navigation/app_navigator.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/sheets.dart';
import '../books/book_details_screen.dart';
import '../discover/discover_screen.dart';
import '../reader/reader_screen.dart';
import '../upload/upload_book_screen.dart';

/// Экран 8. My Library — вкладки «Читаю», «В планах», «Закончено»,
/// список книг с прогрессом. Включает пустое состояние библиотеки.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with ReloadOnDataChange {
  final _repo = Repos.library;
  LibraryStatus _tab = LibraryStatus.reading;
  List<LibraryEntry> _entries = [];
  int _total = 0;
  bool _loading = true;

  @override
  Future<void> load() async {
    final uid = Session.instance.userIdOrNull;
    if (uid == null) return;
    final entries = await _repo.byStatus(uid, _tab);
    final counts = await _repo.counts(uid);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _total = counts.values.fold(0, (a, b) => a + b);
      _loading = false;
    });
  }

  void _selectTab(LibraryStatus tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    load();
  }

  Future<void> _entryMenu(LibraryEntry entry) async {
    final action = await showActionSheet<String>(
      context,
      title: entry.book.title,
      actions: const [
        SheetAction(value: 'read', label: 'Читать', icon: Icons.auto_stories_outlined),
        SheetAction(value: 'status', label: 'Изменить статус', icon: Icons.swap_horiz),
        SheetAction(value: 'details', label: 'О книге', icon: Icons.info_outline),
        SheetAction(
            value: 'remove',
            label: 'Удалить из библиотеки',
            icon: Icons.delete_outline,
            destructive: true),
      ],
    );
    if (!mounted || action == null) return;
    final uid = Session.instance.userId;
    switch (action) {
      case 'read':
        AppNavigator.push(context, ReaderScreen(bookId: entry.book.id));
      case 'details':
        AppNavigator.push(context, BookDetailsScreen(bookId: entry.book.id));
      case 'status':
        final status = await showStatusPicker(context,
            current: entry.status, title: 'Изменить статус');
        if (status == null || !mounted) return;
        if (status == entry.status) {
          AppMessages.info(context, 'Статус не изменился');
          return;
        }
        await _repo.updateStatus(uid, entry.book.id, status, entry.book.pageCount);
        if (!mounted) return;
        AppMessages.success(context, 'Книга перемещена в «${status.label}»');
      case 'remove':
        final ok = await AppMessages.confirm(
          context,
          title: 'Удалить книгу?',
          message:
              '«${entry.book.title}» будет удалена из библиотеки вместе с прогрессом чтения.',
          confirmText: 'Удалить',
          destructive: true,
        );
        if (!ok) return;
        await _repo.remove(uid, entry.book.id);
        if (!mounted) return;
        AppMessages.success(context, 'Книга удалена из библиотеки');
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = !_loading && _entries.isEmpty;
    return ColoredBox(
      color: empty ? AppColors.backgroundWarm : AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Моя библиотека', style: AppTextStyles.screenTitle),
                  ),
                  CircleIconButton(
                    icon: Icons.add_circle_outline,
                    background: Colors.transparent,
                    iconSize: 27,
                    size: 40,
                    tooltip: 'Загрузить книгу',
                    onTap: () =>
                        AppNavigator.push(context, const UploadBookScreen()),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(
                children: [
                  for (final s in LibraryStatus.values) ...[
                    _TabLabel(
                      label: s.label,
                      selected: s == _tab,
                      onTap: () => _selectTab(s),
                    ),
                    const SizedBox(width: 20),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : empty
                      ? _emptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 24,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.54,
                          ),
                          itemCount: _entries.length,
                          itemBuilder: (_, i) => _BookGridItem(
                            entry: _entries[i],
                            onTap: () => AppNavigator.push(context,
                                BookDetailsScreen(bookId: _entries[i].book.id)),
                            onLongPress: () => _entryMenu(_entries[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    final whole = _total == 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
                color: AppColors.chip, shape: BoxShape.circle),
            padding: const EdgeInsets.only(left: 30, top: 34),
            child: const Align(
              alignment: Alignment.topLeft,
              child: CornerMark(size: 24, color: AppColors.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          whole ? 'Ваша библиотека пуста' : 'В разделе «${_tab.label}» пусто',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTextStyles.sans,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Найдите книги или загрузите свои',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: AppTextStyles.sans,
              fontSize: 14,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Найти книги',
          onPressed: () => AppNavigator.push(context, const DiscoverScreen()),
        ),
        const SizedBox(height: 12),
        OutlinedAppButton(
          label: 'Загрузить книгу',
          darkBorder: true,
          onPressed: () => AppNavigator.push(context, const UploadBookScreen()),
        ),
      ],
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTextStyles.sans,
                fontSize: 14.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              height: 2,
              width: selected ? 46.0 : 0.0,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookGridItem extends StatelessWidget {
  final LibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookGridItem({
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final showProgress =
        entry.status == LibraryStatus.reading && entry.progressPercent > 0;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: LayoutBuilder(
        builder: (context, c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(
              book: entry.book,
              width: c.maxWidth,
              height: c.maxWidth * 1.31,
              radius: 6,
              shadow: true,
            ),
            const SizedBox(height: 10),
            Text(entry.book.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bookTitleSans.copyWith(fontSize: 16)),
            const SizedBox(height: 2),
            Text(entry.book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.author.copyWith(fontSize: 12)),
            if (showProgress) ...[
              const SizedBox(height: 6),
              ProgressLine(value: entry.progressPercent / 100, height: 3),
              const SizedBox(height: 5),
              Text('${entry.progressPercent}%',
                  style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}
