import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/book.dart';
import '../../models/reading_mark.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/date_format.dart';
import '../../widgets/common.dart';
import 'note_dialog.dart';

/// Экран 11. Bookmarks & Notes — закладки и заметки с привязкой
/// к главе и странице. Нажатие на запись открывает страницу в читалке.
class BookmarksNotesScreen extends StatefulWidget {
  final int bookId;
  const BookmarksNotesScreen({super.key, required this.bookId});

  @override
  State<BookmarksNotesScreen> createState() => _BookmarksNotesScreenState();
}

class _BookmarksNotesScreenState extends State<BookmarksNotesScreen>
    with ReloadOnDataChange {
  final _repo = Repos.marks;
  Book? _book;
  List<ReadingMark> _marks = [];
  bool _notesOnly = false;
  bool _loading = true;

  @override
  Future<void> load() async {
    final book = await Repos.books.byId(widget.bookId);
    final marks = await _repo.personalMarks(
        Session.instance.userId, widget.bookId,
        notesOnly: _notesOnly);
    if (!mounted) return;
    setState(() {
      _book = book;
      _marks = marks;
      _loading = false;
    });
  }

  Future<void> _addNote() async {
    final book = _book;
    if (book == null) return;
    final saved = await showAddNoteDialog(context,
        bookId: book.id, maxPage: book.pageCount);
    if (saved && mounted) AppMessages.success(context, 'Заметка сохранена');
  }

  Future<bool> _confirmDelete(ReadingMark m) {
    return AppMessages.confirm(
      context,
      title: m.isNote ? 'Удалить заметку?' : 'Удалить закладку?',
      message: 'Это действие нельзя отменить.',
      confirmText: 'Удалить',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _book?.title ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        tooltip: 'Добавить заметку',
        onPressed: _addNote,
        child: const Icon(Icons.add, size: 28),
      ),
      body: SafeArea(
        child: Column(
          children: [
            CenteredHeader(
              whiteCircle: false,
              titleWidget: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: title,
                      style: const TextStyle(
                          fontFamily: AppTextStyles.serif,
                          fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' – Закладки'),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppTextStyles.sans,
                    fontSize: 19,
                    color: AppColors.textPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _Segmented(
                left: 'Закладки',
                right: 'Заметки',
                rightSelected: _notesOnly,
                onChanged: (notes) {
                  setState(() => _notesOnly = notes);
                  load();
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : _marks.isEmpty
                      ? EmptyState(
                          icon: _notesOnly
                              ? Icons.edit_note
                              : Icons.bookmark_border,
                          title: _notesOnly
                              ? 'Заметок пока нет'
                              : 'Закладок пока нет',
                          subtitle: _notesOnly
                              ? 'Нажмите «+», чтобы добавить заметку'
                              : 'Добавляйте закладки кнопкой «Закладка» в читалке',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
                          itemCount: _marks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final m = _marks[i];
                            return Dismissible(
                              key: ValueKey('${m.isNote}-${m.id}'),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) => _confirmDelete(m),
                              onDismissed: (_) async {
                                setState(() => _marks.removeAt(i));
                                await _repo.delete(m);
                                if (mounted) {
                                  AppMessages.success(context,
                                      m.isNote ? 'Заметка удалена' : 'Закладка удалена');
                                }
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.delete_outline,
                                    color: Colors.white),
                              ),
                              child: _MarkCard(
                                mark: m,
                                onTap: () =>
                                    Navigator.of(context).pop(m.pageNumber),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final String left;
  final String right;
  final bool rightSelected;
  final ValueChanged<bool> onChanged;

  const _Segmented({
    required this.left,
    required this.right,
    required this.rightSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget part(String label, bool selected, bool value) => Expanded(
          child: GestureDetector(
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: selected ? Border.all(color: AppColors.border) : null,
              ),
              child: Text(label,
                  style: TextStyle(
                    fontFamily: AppTextStyles.sans,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  )),
            ),
          ),
        );
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          part(left, !rightSelected, false),
          part(right, rightSelected, true),
        ],
      ),
    );
  }
}

class _MarkCard extends StatelessWidget {
  final ReadingMark mark;
  final VoidCallback onTap;
  const _MarkCard({required this.mark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final where = mark.isNote
        ? 'Глава ${mark.chapterNumber ?? '—'} · Заметка'
        : 'Глава ${mark.chapterNumber ?? '—'} · страница ${mark.pageNumber ?? '—'}';
    return AppCard(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(where,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.sans,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
              Text(DateFormatRu.relative(mark.createdAt),
                  style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mark.isNote ? '"${mark.text}"' : '«${mark.text}»',
            style: TextStyle(
              fontFamily: AppTextStyles.sans,
              fontSize: mark.isNote ? 15 : 14.5,
              height: 1.3,
              fontStyle: mark.isNote ? FontStyle.normal : FontStyle.italic,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
