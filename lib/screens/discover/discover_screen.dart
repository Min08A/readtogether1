import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/book.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/genres.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../books/book_details_screen.dart';

/// Экран 6. Discover — поиск, популярные жанры, популярные книги.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with ReloadOnDataChange {
  final _search = TextEditingController();
  String? _genre;
  List<Book> _books = [];
  bool _loading = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Future<void> load() async {
    final books = await Repos.books.search(
      Session.instance.userId,
      query: _search.text,
      genre: _genre,
    );
    if (!mounted) return;
    setState(() {
      _books = books;
      _loading = false;
    });
  }

  bool get _filtered => _search.text.trim().isNotEmpty || _genre != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const NestedBottomNav(highlighted: MainShell.home),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              const Text('Поиск',
                  style: TextStyle(
                      fontFamily: AppTextStyles.sans,
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 22),
              SearchField(
                controller: _search,
                hint: 'Поиск книг и авторов',
                onChanged: (_) => load(),
              ),
              const SizedBox(height: 22),
              const SectionLabel('Популярные жанры'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final g in Genres.all.take(7))
                    GenreChip(
                      label: g,
                      selected: _genre == g,
                      onTap: () {
                        setState(() => _genre = _genre == g ? null : g);
                        load();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SectionLabel(
                _filtered
                    ? 'Результаты (${_books.length})'
                    : 'Популярные книги',
                actionText: _filtered ? 'Сбросить' : null,
                onAction: () {
                  _search.clear();
                  setState(() => _genre = null);
                  load();
                },
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: LoadingView(),
                )
              else if (_books.isEmpty)
                const EmptyState(
                  icon: Icons.search_off,
                  title: 'Ничего не найдено',
                  subtitle: 'Попробуйте изменить запрос или выбрать другой жанр',
                )
              else
                for (final b in _books) ...[
                  _BookSearchCard(book: b),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BookSearchCard extends StatelessWidget {
  final Book book;
  const _BookSearchCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: 14,
      onTap: () =>
          AppNavigator.push(context, BookDetailsScreen(bookId: book.id)),
      child: Row(
        children: [
          BookCover(book: book, width: 48, height: 70, radius: 3),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bookTitleSans.copyWith(fontSize: 16.5)),
                const SizedBox(height: 4),
                Text(book.author,
                    style: AppTextStyles.author.copyWith(fontSize: 13)),
                if (book.rating != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star_border_rounded,
                          size: 16, color: AppColors.star),
                      const SizedBox(width: 3),
                      Text(book.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                              fontFamily: AppTextStyles.sans,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
