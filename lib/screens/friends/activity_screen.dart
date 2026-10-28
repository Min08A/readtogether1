import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/book.dart';
import '../../models/feed.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_format.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/sheets.dart';
import '../books/book_details_screen.dart';
import 'friend_profile_screen.dart';

/// Экран «Активность» — лента событий друзей (таблица activities).
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with ReloadOnDataChange {
  List<ActivityItem> _items = [];
  final Map<int, Book> _books = {};
  String? _filter;
  bool _loading = true;

  @override
  Future<void> load() async {
    final items = await Repos.social.friendsActivity(Session.instance.userId);
    final repo = Repos.books;
    for (final a in items) {
      final id = a.bookId;
      if (id != null && !_books.containsKey(id)) {
        final b = await repo.byId(id);
        if (b != null) _books[id] = b;
      }
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _chooseFilter() async {
    final value = await showActionSheet<String>(
      context,
      title: 'Показать',
      selected: _filter ?? 'all',
      actions: const [
        SheetAction(value: 'all', label: 'Все события'),
        SheetAction(value: ActivityType.startedReading, label: 'Начали читать'),
        SheetAction(value: ActivityType.finished, label: 'Дочитали'),
        SheetAction(value: ActivityType.addedNote, label: 'Заметки'),
      ],
    );
    if (value == null || !mounted) return;
    setState(() => _filter = value == 'all' ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final items =
        _filter == null ? _items : _items.where((a) => a.type == _filter).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const NestedBottomNav(highlighted: MainShell.home),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(
                    child: Text('Активность', style: AppTextStyles.screenTitle)),
                CircleIconButton(
                  icon: _filter == null ? Icons.tune : Icons.filter_alt,
                  background: AppColors.surface,
                  bordered: true,
                  size: 34,
                  iconSize: 18,
                  tooltip: 'Фильтр',
                  onTap: _chooseFilter,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const LoadingView()
            else if (items.isEmpty)
              const EmptyState(
                icon: Icons.dynamic_feed_outlined,
                title: 'Пока нет активности',
                subtitle: 'Здесь появятся события ваших друзей',
              )
            else
              for (final a in items) ...[
                _ActivityCard(item: a, book: a.bookId == null ? null : _books[a.bookId]),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityItem item;
  final Book? book;
  const _ActivityCard({required this.item, this.book});

  @override
  Widget build(BuildContext context) {
    final b = book;
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      onTap: b == null
          ? () => AppNavigator.push(
              context, FriendProfileScreen(userId: item.userId))
          : () => AppNavigator.push(context, BookDetailsScreen(bookId: b.id)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => AppNavigator.push(
                context, FriendProfileScreen(userId: item.userId)),
            child: LetterAvatar(name: item.userName, size: 38, fontSize: 15),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: item.userName,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: ' ${item.verb} ',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    if (item.bookTitle != null)
                      TextSpan(
                          text: item.bookTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  style: const TextStyle(
                      fontFamily: AppTextStyles.sans,
                      fontSize: 14.5,
                      height: 1.3,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(DateFormatRu.relative(item.createdAt),
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          if (b != null) ...[
            const SizedBox(width: 10),
            BookCover(book: b, width: 38, height: 54, radius: 3),
          ],
        ],
      ),
    );
  }
}
