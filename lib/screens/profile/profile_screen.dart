import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/app_user.dart';
import '../../models/feed.dart';
import '../../models/library_entry.dart';
import '../../navigation/app_navigator.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_format.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../books/book_details_screen.dart';
import '../reader/reader_screen.dart';
import 'edit_profile_screen.dart';
import 'reading_stats_screen.dart';
import 'settings_screen.dart';

/// Экран 18. Profile — аватар, имя, email, статистика, читаю сейчас,
/// недавняя активность.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with ReloadOnDataChange {
  AppUser? _user;
  Map<LibraryStatus, int> _counts = {};
  int _bookmarks = 0;
  LibraryEntry? _current;
  List<ActivityItem> _activity = [];
  bool _loading = true;

  @override
  Future<void> load() async {
    final uid = Session.instance.userIdOrNull;
    if (uid == null) return;
    final user = await Repos.auth.getUser(uid);
    final lib = Repos.library;
    final counts = await lib.counts(uid);
    final current = await lib.currentReading(uid);
    final bookmarks = await Repos.marks.bookmarkCount(uid);
    final activity = await Repos.social.userActivity(uid, limit: 4);
    if (!mounted) return;
    setState(() {
      _user = user;
      _counts = counts;
      _current = current;
      _bookmarks = bookmarks;
      _activity = activity;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return ColoredBox(
      color: AppColors.backgroundWarm,
      child: SafeArea(
        bottom: false,
        child: _loading || user == null
            ? const LoadingView()
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  SizedBox(
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Text('Мой профиль',
                            style: TextStyle(
                                fontFamily: AppTextStyles.sans,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleIconButton(
                                icon: Icons.bar_chart_rounded,
                                background: AppColors.surface,
                                bordered: true,
                                tooltip: 'Статистика чтения',
                                onTap: () => AppNavigator.push(
                                    context, const ReadingStatsScreen()),
                              ),
                              const SizedBox(width: 20),
                              CircleIconButton(
                                icon: Icons.settings_outlined,
                                background: AppColors.surface,
                                bordered: true,
                                tooltip: 'Настройки',
                                onTap: () => AppNavigator.push(
                                    context, const SettingsScreen()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: LetterAvatar(
                        name: user.name, size: 82, fontSize: 28, whiteBorder: true),
                  ),
                  const SizedBox(height: 12),
                  Text(user.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: AppTextStyles.serif,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(user.email,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySecondary),
                  const SizedBox(height: 12),
                  Center(
                    child: SmallButton(
                      label: 'Редактировать',
                      style: SmallButtonStyle.white,
                      height: 30,
                      fontSize: 13.5,
                      onPressed: () =>
                          AppNavigator.push(context, const EditProfileScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                          child: StatTile(
                              value:
                                  '${_counts.values.fold<int>(0, (a, b) => a + b)}',
                              label: 'Книг')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatTile(
                              value: '${_counts[LibraryStatus.finished] ?? 0}',
                              label: 'Закончено')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatTile(
                              value: '${_counts[LibraryStatus.reading] ?? 0}',
                              label: 'Читает')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: StatTile(value: '$_bookmarks', label: 'Закладок')),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Читаю сейчас'),
                  const SizedBox(height: 10),
                  _currentCard(),
                  const SizedBox(height: 22),
                  const SectionLabel('Недавняя активность'),
                  const SizedBox(height: 10),
                  if (_activity.isEmpty)
                    const Text('Пока нет активности',
                        style: AppTextStyles.bodySecondary)
                  else
                    for (final a in _activity) ...[
                      _ActivityRow(item: a),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
      ),
    );
  }

  Widget _currentCard() {
    final c = _current;
    if (c == null) {
      return const AppCard(
        child: Text('Сейчас вы ничего не читаете',
            style: AppTextStyles.bodySecondary),
      );
    }
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: () => AppNavigator.push(context, ReaderScreen(bookId: c.book.id)),
      child: Row(
        children: [
          BookCover(book: c.book, width: 48, height: 70, radius: 3),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bookTitleSerif.copyWith(fontSize: 18)),
                const SizedBox(height: 2),
                Text(c.book.author, style: AppTextStyles.author),
                const SizedBox(height: 10),
                ProgressLine(value: c.progressPercent / 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityItem item;
  const _ActivityRow({required this.item});

  IconData get _icon {
    switch (item.type) {
      case ActivityType.addedNote:
      case ActivityType.addedBookmark:
        return Icons.bookmark_border;
      case ActivityType.finished:
        return Icons.check_circle_outline;
      case ActivityType.joinedRoom:
        return Icons.groups_outlined;
      case ActivityType.addedBook:
        return Icons.upload_file_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final verb = item.verb;
    final capitalized = verb.isEmpty
        ? verb
        : '${verb.substring(0, 1).toUpperCase()}${verb.substring(1)}';
    return AppCard(
      radius: 12,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      onTap: item.bookId == null
          ? null
          : () => AppNavigator.push(
              context, BookDetailsScreen(bookId: item.bookId!)),
      child: Row(
        children: [
          Icon(_icon, size: 19, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$capitalized '),
                if (item.bookTitle != null)
                  TextSpan(
                      text: item.bookTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              style: const TextStyle(
                  fontFamily: AppTextStyles.sans,
                  fontSize: 13.5,
                  height: 1.3,
                  color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text(DateFormatRu.relative(item.createdAt).toLowerCase(),
              style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}
