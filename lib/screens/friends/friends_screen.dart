import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/reading_room.dart';
import '../../models/social.dart';
import '../../navigation/app_navigator.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/together_widgets.dart';
import 'friend_profile_screen.dart';
import 'search_users_screen.dart';

/// Экран 15. Friends — поиск, запросы в друзья, список друзей
/// с текущими книгами.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with ReloadOnDataChange {
  final _repo = Repos.social;
  final _search = TextEditingController();
  List<FriendRequest> _requests = [];
  List<FriendWithBook> _friends = [];
  Map<int, StreakInfo> _streaks = {};
  bool _loading = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Future<void> load() async {
    final uid = Session.instance.userIdOrNull;
    if (uid == null) return;
    final requests = await _repo.incomingRequests(uid);
    final friends = await _repo.friends(uid, query: _search.text);
    final streaks =
        await Repos.streaks.withFriends(uid, friends.map((f) => f.user.id));
    if (!mounted) return;
    setState(() {
      _requests = requests;
      _friends = friends;
      _streaks = streaks;
      _loading = false;
    });
  }

  Future<void> _accept(FriendRequest r) async {
    await _repo.respondToRequest(r.friendshipId, accept: true);
    if (!mounted) return;
    AppMessages.success(context, '${r.from.name} теперь у вас в друзьях');
  }

  Future<void> _decline(FriendRequest r) async {
    final ok = await AppMessages.confirm(
      context,
      title: 'Отклонить запрос?',
      message: '${r.from.name} не будет добавлен(а) в друзья.',
      confirmText: 'Отклонить',
      destructive: true,
    );
    if (!ok) return;
    await _repo.respondToRequest(r.friendshipId, accept: false);
    if (!mounted) return;
    AppMessages.info(context, 'Запрос от ${r.from.name} отклонён');
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
            children: [
              Row(
                children: [
                  const Expanded(
                      child: Text('Друзья', style: AppTextStyles.screenTitle)),
                  CircleIconButton(
                    icon: Icons.person_add_alt_outlined,
                    background: Colors.transparent,
                    iconSize: 26,
                    size: 40,
                    tooltip: 'Найти друзей',
                    onTap: () =>
                        AppNavigator.push(context, const SearchUsersScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SearchField(
                controller: _search,
                hint: 'Поиск друзей...',
                onChanged: (_) => load(),
              ),
              if (_requests.isNotEmpty) ...[
                const SizedBox(height: 22),
                SectionLabel('Запросы в друзья (${_requests.length})'),
                const SizedBox(height: 10),
                for (final r in _requests) ...[
                  AppCard(
                    radius: 14,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                    onTap: () => AppNavigator.push(
                        context, FriendProfileScreen(userId: r.from.id)),
                    child: Row(
                      children: [
                        LetterAvatar(name: r.from.name, size: 32, fontSize: 14),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(r.from.name,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.itemTitle),
                        ),
                        SmallButton(label: 'Принять', onPressed: () => _accept(r)),
                        const SizedBox(width: 8),
                        SmallButton(
                          label: 'Отклонить',
                          style: SmallButtonStyle.soft,
                          onPressed: () => _decline(r),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 22),
              if (_loading)
                const LoadingView()
              else if (_friends.isEmpty)
                EmptyState(
                  icon: Icons.people_outline,
                  title: _search.text.isEmpty
                      ? 'У вас пока нет друзей'
                      : 'Друзья не найдены',
                  subtitle: _search.text.isEmpty
                      ? 'Найдите друзей по имени или email'
                      : 'Попробуйте другой запрос',
                  action: PrimaryButton(
                    label: 'Найти друзей',
                    compact: true,
                    height: 40,
                    onPressed: () =>
                        AppNavigator.push(context, const SearchUsersScreen()),
                  ),
                )
              else
                for (final f in _friends) ...[
                  _FriendCard(
                      friend: f, streak: _streaks[f.user.id] ?? StreakInfo.none),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final FriendWithBook friend;
  final StreakInfo streak;
  const _FriendCard({required this.friend, required this.streak});

  @override
  Widget build(BuildContext context) {
    final entry = friend.currentBook;
    return AppCard(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      onTap: () => AppNavigator.push(
          context, FriendProfileScreen(userId: friend.user.id)),
      child: Row(
        children: [
          LetterAvatar(name: friend.user.name, size: 38, fontSize: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(friend.user.name,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppTextStyles.itemTitle.copyWith(fontSize: 15.5)),
                    ),
                    const SizedBox(width: 6),
                    StreakFlame(
                      streak: streak,
                      size: 15,
                      explanation:
                          'Совместная серия с ${friend.user.name}: сколько дней подряд вы оба читаете.',
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (entry == null)
                  Text('Сейчас ничего не читает',
                      style: AppTextStyles.caption.copyWith(fontSize: 12.5))
                else ...[
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text: 'Читает ',
                          style: TextStyle(color: AppColors.textSecondary)),
                      TextSpan(text: entry.book.title),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.sans,
                        fontSize: 12.5,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: ProgressLine(
                            value: entry.progressPercent / 100, height: 3),
                      ),
                      const SizedBox(width: 6),
                      Text('${entry.progressPercent}%',
                          style: AppTextStyles.caption.copyWith(fontSize: 10.5)),
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
