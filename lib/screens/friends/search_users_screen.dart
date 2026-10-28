import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/social.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'friend_profile_screen.dart';

/// Экран 17. Search Users — поиск по имени или email,
/// кнопки «Добавить» / «Отправлено».
class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen>
    with ReloadOnDataChange {
  final _repo = Repos.social;
  final _search = TextEditingController();
  List<UserSearchResult> _results = [];
  bool _loading = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Future<void> load() async {
    final results =
        await _repo.searchUsers(Session.instance.userId, _search.text);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _onAction(UserSearchResult r) async {
    final uid = Session.instance.userId;
    switch (r.state) {
      case FriendState.none:
        await _repo.sendRequest(uid, r.user.id);
        if (!mounted) return;
        AppMessages.success(context, 'Запрос в друзья отправлен: ${r.user.name}');
      case FriendState.outgoingPending:
        AppMessages.unavailable(
            context, 'Запрос уже отправлен — дождитесь ответа ${r.user.name}');
      case FriendState.incomingPending:
        await _repo.acceptFrom(uid, r.user.id);
        if (!mounted) return;
        AppMessages.success(context, '${r.user.name} теперь у вас в друзьях');
      case FriendState.friends:
        AppMessages.info(context, '${r.user.name} уже у вас в друзьях');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      bottomNavigationBar: const NestedBottomNav(highlighted: MainShell.friends),
      body: SafeArea(
        child: Column(
          children: [
            BackTitleHeader(
              title: 'Найти друзей',
              style: AppTextStyles.headerTitle.copyWith(color: AppColors.primary),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SearchField(
                controller: _search,
                hint: 'Поиск по имени или email...',
                onChanged: (_) => load(),
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : _results.isEmpty
                      ? const EmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'Пользователи не найдены',
                          subtitle: 'Проверьте имя или email',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final r = _results[i];
                            return AppCard(
                              radius: 14,
                              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                              onTap: () => AppNavigator.push(
                                  context, FriendProfileScreen(userId: r.user.id)),
                              child: Row(
                                children: [
                                  LetterAvatar(
                                      name: r.user.name, size: 32, fontSize: 14),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(r.user.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.itemTitle),
                                  ),
                                  _actionButton(r),
                                ],
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

  Widget _actionButton(UserSearchResult r) => switch (r.state) {
        FriendState.none => SmallButton(
            label: 'Добавить',
            style: SmallButtonStyle.outlined,
            onPressed: () => _onAction(r)),
        FriendState.outgoingPending => SmallButton(
            label: 'Отправлено',
            style: SmallButtonStyle.disabled,
            onPressed: () => _onAction(r)),
        FriendState.incomingPending =>
          SmallButton(label: 'Принять', onPressed: () => _onAction(r)),
        FriendState.friends => SmallButton(
            label: 'В друзьях',
            style: SmallButtonStyle.disabled,
            onPressed: () => _onAction(r)),
      };
}
