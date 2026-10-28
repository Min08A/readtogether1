import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/app_user.dart';
import '../../models/library_entry.dart';
import '../../models/reading_room.dart';
import '../../models/settings.dart';
import '../../models/social.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/date_format.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/sheets.dart';
import '../../widgets/together_widgets.dart';
import '../books/book_details_screen.dart';
import '../rooms/create_room_screen.dart';

/// Экран 16. Friend Profile — имя, прочитано книг, «Читать вместе»,
/// текущая книга, недавно законченные. Учитывает настройки приватности.
class FriendProfileScreen extends StatefulWidget {
  final int userId;
  const FriendProfileScreen({super.key, required this.userId});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen>
    with ReloadOnDataChange {
  final _social = Repos.social;
  AppUser? _user;
  FriendState _state = FriendState.none;
  LibraryEntry? _current;
  List<LibraryEntry> _finished = [];
  int _finishedCount = 0;
  bool _libraryHidden = false;
  StreakInfo _streak = StreakInfo.none;
  bool _loading = true;

  int get _uid => Session.instance.userId;

  @override
  Future<void> load() async {
    final user = await Repos.auth.getUser(widget.userId);
    final state = await _social.stateWith(_uid, widget.userId);
    final privacy = await Repos.settings.privacy(widget.userId);
    final lib = Repos.library;
    final current = await lib.currentReading(widget.userId);
    final finished = await lib.recentlyFinished(widget.userId);
    final counts = await lib.counts(widget.userId);
    final streak = await Repos.streaks.withFriend(_uid, widget.userId);
    final hidden = privacy.libraryVisibility == Visibility3.nobody ||
        (privacy.libraryVisibility == Visibility3.friends &&
            state != FriendState.friends);
    if (!mounted) return;
    setState(() {
      _user = user;
      _state = state;
      _current = current;
      _finished = finished;
      _finishedCount = counts[LibraryStatus.finished] ?? 0;
      _libraryHidden = hidden;
      _streak = streak;
      _loading = false;
    });
  }

  Future<void> _menu() async {
    final user = _user!;
    final action = await showActionSheet<String>(
      context,
      title: user.name,
      actions: [
        if (_state == FriendState.friends)
          const SheetAction(
              value: 'remove',
              label: 'Удалить из друзей',
              icon: Icons.person_remove_outlined,
              destructive: true)
        else if (_state == FriendState.none)
          const SheetAction(
              value: 'add',
              label: 'Добавить в друзья',
              icon: Icons.person_add_alt_outlined),
        const SheetAction(
            value: 'room',
            label: 'Пригласить в Reading Room',
            icon: Icons.groups_outlined),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'remove':
        final ok = await AppMessages.confirm(
          context,
          title: 'Удалить ${user.name} из друзей?',
          message: 'Вы перестанете видеть прогресс чтения друг друга.',
          confirmText: 'Удалить',
          destructive: true,
        );
        if (!ok) return;
        await _social.removeFriend(_uid, user.id);
        if (!mounted) return;
        AppMessages.success(context, '${user.name} удалён(а) из друзей');
      case 'add':
        await _social.sendRequest(_uid, user.id);
        if (!mounted) return;
        AppMessages.success(context, 'Запрос в друзья отправлен');
      case 'room':
        _readTogether();
    }
  }

  void _readTogether() {
    if (_state != FriendState.friends) {
      AppMessages.unavailable(
          context, 'Читать вместе можно только с друзьями. Сначала добавьте пользователя в друзья');
      return;
    }
    AppNavigator.push(
      context,
      CreateRoomScreen(bookId: _current?.book.id, inviteUserId: widget.userId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      bottomNavigationBar: const NestedBottomNav(highlighted: MainShell.friends),
      body: SafeArea(
        child: _loading
            ? const LoadingView()
            : _user == null
                ? const EmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'Пользователь не найден')
                : _content(_user!),
      ),
    );
  }

  /// Карточка совместного огонька (как в TikTok).
  Widget _streakCard(AppUser user) {
    final s = _streak;
    final String title;
    final String subtitle;
    if (!s.isAlive) {
      title = 'Зажгите огонёк с ${user.name}';
      subtitle = 'Читайте оба хотя бы раз в день — и серия начнётся';
    } else if (s.activeToday) {
      title = '${s.days} ${DateFormatRu.plural(s.days, 'день', 'дня', 'дней')} читаете вместе';
      subtitle = 'Сегодня оба уже читали — серия продлена 🔥';
    } else {
      title = 'Огонёк под угрозой: ${s.days} ${DateFormatRu.plural(s.days, 'день', 'дня', 'дней')}';
      subtitle = 'Сегодня кто-то из вас ещё не читал — не дайте серии погаснуть';
    }
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      onTap: () => showStreakInfo(context, s,
          explanation:
              'Совместная серия: сколько дней подряд вы и ${user.name} читаете (или пишете в комнате).'),
      child: Row(
        children: [
          StreakFlame(streak: s, size: 30, showZero: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.itemTitle),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(AppUser user) {
    final current = _current;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: [
            CircleIconButton(
              icon: Icons.arrow_circle_left_outlined,
              background: AppColors.surface,
              bordered: true,
              iconSize: 22,
              tooltip: 'Назад',
              onTap: () => Navigator.of(context).pop(),
            ),
            const Spacer(),
            CircleIconButton(
              icon: Icons.more_vert,
              background: AppColors.surface,
              bordered: true,
              iconSize: 20,
              tooltip: 'Действия',
              onTap: _menu,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: LetterAvatar(
              name: user.name, size: 78, fontSize: 30, whiteBorder: true),
        ),
        const SizedBox(height: 14),
        Text(user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: AppTextStyles.serif,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(
          _libraryHidden
              ? 'Библиотека скрыта настройками приватности'
              : 'Прочитано $_finishedCount ${DateFormatRu.plural(_finishedCount, 'книга', 'книги', 'книг')}',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary.copyWith(fontSize: 14.5),
        ),
        if (user.bio != null) ...[
          const SizedBox(height: 6),
          Text(user.bio!,
              textAlign: TextAlign.center, style: AppTextStyles.caption),
        ],
        if (_state == FriendState.friends) ...[
          const SizedBox(height: 14),
          _streakCard(user),
        ],
        const SizedBox(height: 18),
        if (_state == FriendState.friends)
          PrimaryButton(
            label: 'Читать вместе',
            icon: Icons.chat_bubble_outline,
            onPressed: _readTogether,
          )
        else if (_state == FriendState.incomingPending)
          PrimaryButton(
            label: 'Принять запрос в друзья',
            icon: Icons.person_add_alt,
            onPressed: () async {
              await _social.acceptFrom(_uid, user.id);
              if (mounted) {
                AppMessages.success(context, '${user.name} теперь у вас в друзьях');
              }
            },
          )
        else if (_state == FriendState.outgoingPending)
          OutlinedAppButton(
            label: 'Запрос отправлен',
            onPressed: () => AppMessages.unavailable(
                context, 'Запрос уже отправлен — дождитесь ответа'),
          )
        else
          PrimaryButton(
            label: 'Добавить в друзья',
            icon: Icons.person_add_alt,
            onPressed: () async {
              await _social.sendRequest(_uid, user.id);
              if (mounted) AppMessages.success(context, 'Запрос в друзья отправлен');
            },
          ),
        if (!_libraryHidden) ...[
          const SizedBox(height: 22),
          const SectionLabel('Сейчас читает'),
          const SizedBox(height: 10),
          if (current == null)
            const Text('Сейчас ничего не читает',
                style: AppTextStyles.bodySecondary)
          else
            AppCard(
              radius: 18,
              padding: const EdgeInsets.all(16),
              onTap: () => AppNavigator.push(
                  context, BookDetailsScreen(bookId: current.book.id)),
              child: Row(
                children: [
                  BookCover(book: current.book, width: 58, height: 86, radius: 3),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(current.book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bookTitleSans
                                .copyWith(fontSize: 18)),
                        const SizedBox(height: 2),
                        Text(current.book.author,
                            style: AppTextStyles.author.copyWith(fontSize: 13.5)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text('${current.progressPercent}%',
                                style: const TextStyle(
                                    fontFamily: AppTextStyles.sans,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text('${current.pagesRead} с. прочтено',
                                style: AppTextStyles.caption),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ProgressLine(value: current.progressPercent / 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          const SectionLabel('Недавно закончено'),
          const SizedBox(height: 10),
          if (_finished.isEmpty)
            const Text('Пока нет законченных книг',
                style: AppTextStyles.bodySecondary)
          else
            SizedBox(
              height: 205,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _finished.length,
                separatorBuilder: (_, __) => const SizedBox(width: 13),
                itemBuilder: (_, i) {
                  final e = _finished[i];
                  return GestureDetector(
                    onTap: () => AppNavigator.push(
                        context, BookDetailsScreen(bookId: e.book.id)),
                    child: SizedBox(
                      width: 104,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BookCover(
                              book: e.book, width: 104, height: 148, radius: 5),
                          const SizedBox(height: 6),
                          Text(e.book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bookTitleSans
                                  .copyWith(fontSize: 13.5, height: 1.1)),
                          Text(e.book.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.author.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}
