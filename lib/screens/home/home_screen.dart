import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/app_user.dart';
import '../../models/book.dart';
import '../../models/library_entry.dart';
import '../../models/reading_room.dart';
import '../../models/social.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../services/data_bus.dart';
import '../../services/demo_simulator.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/together_widgets.dart';
import '../books/book_details_screen.dart';
import '../discover/discover_screen.dart';
import '../friends/activity_screen.dart';
import '../friends/friend_profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/reading_stats_screen.dart';
import '../reader/reader_screen.dart';
import '../rooms/create_room_screen.dart';
import '../rooms/reading_room_screen.dart';
import '../rooms/room_widgets.dart';
import '../rooms/rooms_list_screen.dart';

/// Экран 5. Home — приветствие, «Продолжить чтение», друзья читают,
/// рекомендации.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ReloadOnDataChange {
  AppUser? _user;
  LibraryEntry? _current;
  List<FriendWithBook> _friends = [];
  List<Book> _recommendations = [];
  int _unread = 0;
  List<RoomSummary> _rooms = [];
  int _invites = 0;
  StreakInfo _streak = StreakInfo.none;
  bool _loading = true;

  @override
  Future<void> load() async {
    final uid = Session.instance.userIdOrNull;
    if (uid == null) return;
    final user = await Repos.auth.getUser(uid);
    final current = await Repos.library.currentReading(uid);
    final friends = await Repos.social.friends(uid);
    final prefs = await Repos.settings.preferences(uid);
    final recs =
        await Repos.books.recommendations(uid, prefs.favoriteGenres);
    final unread = await Repos.notifications.unreadCount(uid);
    final rooms = await Repos.rooms.summaries(uid);
    final invites = await Repos.rooms.pendingInvites(uid);
    final streak = await Repos.streaks.personal(uid);
    // Демо-режим: друзья «читают» дальше сами (см. DemoSimulator).
    DemoSimulator.instance.tick();
    if (!mounted) return;
    setState(() {
      _user = user;
      _current = current;
      _friends = friends.where((f) => f.currentBook != null).toList();
      _recommendations = recs;
      _unread = unread;
      _rooms = rooms;
      _invites = invites.length;
      _streak = streak;
      _loading = false;
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'ДОБРОЕ УТРО';
    if (h >= 12 && h < 18) return 'ДОБРЫЙ ДЕНЬ';
    if (h >= 18 && h < 23) return 'ДОБРЫЙ ВЕЧЕР';
    return 'ДОБРОЙ НОЧИ';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(color: AppColors.background, child: LoadingView());
    }
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              _header(),
              const SizedBox(height: 22),
              const SectionLabel('Продолжить чтение'),
              const SizedBox(height: 12),
              _continueReading(),
              const SizedBox(height: 22),
              SectionLabel(
                _invites > 0
                    ? 'Мои Reading Rooms · приглашений: $_invites'
                    : 'Мои Reading Rooms',
                actionText: 'Все',
                onAction: () =>
                    AppNavigator.push(context, const RoomsListScreen()),
              ),
              const SizedBox(height: 12),
              _roomsList(),
              const SizedBox(height: 22),
              SectionLabel(
                'Друзья читают',
                actionText: 'Все',
                onAction: () =>
                    AppNavigator.push(context, const ActivityScreen()),
              ),
              const SizedBox(height: 12),
              _friendsReading(),
              const SizedBox(height: 22),
              const SectionLabel('Рекомендации для тебя'),
              const SizedBox(height: 12),
              _recommendationsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(_greeting,
                      style:
                          AppTextStyles.sectionLabel.copyWith(fontSize: 12.5)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onLongPress: () =>
                        AppNavigator.push(context, const ReadingStatsScreen()),
                    child: StreakFlame(
                      streak: _streak,
                      size: 15,
                      explanation:
                          'Ваша личная серия: сколько дней подряд вы читаете. Откройте любую книгу сегодня, чтобы огонёк не погас.',
                    ),
                  ),
                ],
              ),
              Text(
                _user?.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppTextStyles.serif,
                  fontSize: 27,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        CircleIconButton(
          icon: Icons.search,
          tooltip: 'Поиск книг',
          size: 36,
          iconSize: 19,
          onTap: () => AppNavigator.push(context, const DiscoverScreen()),
        ),
        const SizedBox(width: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleIconButton(
              icon: Icons.notifications_none_rounded,
              tooltip: 'Уведомления',
              size: 36,
              iconSize: 19,
              onTap: () =>
                  AppNavigator.push(context, const NotificationsScreen()),
            ),
            if (_unread > 0)
              Positioned(
                right: 1,
                top: 1,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.genreRed,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => MainShell.currentTab.value = MainShell.profile,
          child: LetterAvatar(name: _user?.name ?? '', size: 36, fontSize: 15),
        ),
      ],
    );
  }

  Widget _continueReading() {
    final entry = _current;
    if (entry == null) {
      return AppCard(
        child: EmptyState(
          icon: Icons.auto_stories_outlined,
          title: 'Вы пока ничего не читаете',
          subtitle: 'Найдите книгу в каталоге или загрузите свою',
          action: PrimaryButton(
            label: 'Найти книги',
            compact: true,
            height: 40,
            onPressed: () => AppNavigator.push(context, const DiscoverScreen()),
          ),
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 18,
      onTap: () =>
          AppNavigator.push(context, ReaderScreen(bookId: entry.book.id)),
      child: Row(
        children: [
          BookCover(book: entry.book, width: 74, height: 110, radius: 4),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bookTitleSerif.copyWith(fontSize: 22)),
                const SizedBox(height: 4),
                Text(entry.book.author,
                    style: AppTextStyles.author.copyWith(fontSize: 13.5)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('${entry.progressPercent}%',
                        style: const TextStyle(
                            fontFamily: AppTextStyles.sans,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const Spacer(),
                    Text('${entry.pagesRead} с. прочтено',
                        style: AppTextStyles.caption.copyWith(fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressLine(value: entry.progressPercent / 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomsList() {
    if (_rooms.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.groups_outlined,
          title: 'Читайте вместе с друзьями',
          subtitle: _invites > 0
              ? 'У вас есть приглашения — откройте «Все»'
              : 'Создайте Reading Room и пригласите друзей',
          action: PrimaryButton(
            label: _invites > 0 ? 'Открыть приглашения' : 'Создать комнату',
            compact: true,
            height: 40,
            onPressed: () => AppNavigator.push(
                context,
                _invites > 0
                    ? const RoomsListScreen()
                    : const CreateRoomScreen()),
          ),
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _rooms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => RoomCard(
          summary: _rooms[i],
          width: 300,
          onTap: () => AppNavigator.push(
              context, ReadingRoomScreen(roomId: _rooms[i].room.id)),
        ),
      ),
    );
  }

  Widget _friendsReading() {
    if (_friends.isEmpty) {
      return AppCard(
        child: EmptyState(
          icon: Icons.people_outline,
          title: 'Друзья пока ничего не читают',
          subtitle: 'Добавьте друзей, чтобы видеть их прогресс',
          action: PrimaryButton(
            label: 'Найти друзей',
            compact: true,
            height: 40,
            onPressed: () => MainShell.currentTab.value = MainShell.friends,
          ),
        ),
      );
    }
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _friends.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final f = _friends[i];
          final book = f.currentBook!.book;
          return SizedBox(
            width: 170,
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              radius: 14,
              onTap: () => AppNavigator.push(
                  context, FriendProfileScreen(userId: f.user.id)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      LetterAvatar(name: f.user.name, size: 22, fontSize: 11),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(f.user.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: AppTextStyles.sans,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      BookCover(book: book, width: 38, height: 54, radius: 3),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bookTitleSans),
                            const SizedBox(height: 2),
                            Text(book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.author
                                    .copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _recommendationsList() {
    if (_recommendations.isEmpty) {
      return const Text('Вы уже добавили все книги каталога — отлично!',
          style: AppTextStyles.bodySecondary);
    }
    return SizedBox(
      height: 222,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _recommendations.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final b = _recommendations[i];
          return GestureDetector(
            onTap: () =>
                AppNavigator.push(context, BookDetailsScreen(bookId: b.id)),
            child: SizedBox(
              width: 172,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BookCover(
                      book: b, width: 108, height: 152, radius: 4, shadow: true),
                  const SizedBox(height: 12),
                  Text(b.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bookTitleSans.copyWith(fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(b.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.author.copyWith(fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
