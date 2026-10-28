import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/reading_room.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import 'create_room_screen.dart';
import 'reading_room_screen.dart';
import 'room_widgets.dart';

/// «Мои Reading Rooms» — приглашения и все комнаты пользователя.
class RoomsListScreen extends StatefulWidget {
  const RoomsListScreen({super.key});

  @override
  State<RoomsListScreen> createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends State<RoomsListScreen>
    with ReloadOnDataChange {
  List<ReadingRoom> _invites = [];
  List<RoomSummary> _rooms = [];
  bool _loading = true;

  @override
  Future<void> load() async {
    final uid = Session.instance.userIdOrNull;
    if (uid == null) return;
    final invites = await Repos.rooms.pendingInvites(uid);
    final rooms = await Repos.rooms.summaries(uid);
    if (!mounted) return;
    setState(() {
      _invites = invites;
      _rooms = rooms;
      _loading = false;
    });
  }

  Future<void> _respond(ReadingRoom room, bool accept) async {
    final uid = Session.instance.userId;
    if (!accept) {
      final ok = await AppMessages.confirm(
        context,
        title: 'Отклонить приглашение?',
        message: 'Вы не будете участником «${room.name}».',
        confirmText: 'Отклонить',
        destructive: true,
      );
      if (!ok) return;
    }
    await Repos.rooms.respondToInvite(room.id, uid, accept: accept);
    if (!mounted) return;
    if (accept) {
      AppMessages.success(context, 'Вы присоединились к «${room.name}»');
      AppNavigator.push(context, ReadingRoomScreen(roomId: room.id));
    } else {
      AppMessages.info(context, 'Приглашение отклонено');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const NestedBottomNav(highlighted: MainShell.home),
      body: SafeArea(
        child: Column(
          children: [
            const BackTitleHeader(title: 'Мои Reading Rooms'),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        if (_invites.isNotEmpty) ...[
                          SectionLabel('Приглашения (${_invites.length})'),
                          const SizedBox(height: 10),
                          for (final r in _invites) ...[
                            AppCard(
                              radius: 16,
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  BookCover(
                                      book: r.book,
                                      width: 40,
                                      height: 58,
                                      radius: 3),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(r.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTextStyles.itemTitle),
                                        Text('${r.creatorName} приглашает вас',
                                            style: AppTextStyles.caption),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            SmallButton(
                                                label: 'Принять',
                                                onPressed: () =>
                                                    _respond(r, true)),
                                            const SizedBox(width: 8),
                                            SmallButton(
                                                label: 'Отклонить',
                                                style: SmallButtonStyle.white,
                                                onPressed: () =>
                                                    _respond(r, false)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 12),
                        ],
                        SectionLabel('Мои комнаты (${_rooms.length})'),
                        const SizedBox(height: 10),
                        if (_rooms.isEmpty)
                          EmptyState(
                            icon: Icons.groups_outlined,
                            title: 'Вы пока не состоите в комнатах',
                            subtitle:
                                'Создайте комнату и пригласите друзей читать вместе',
                            action: PrimaryButton(
                              label: 'Создать комнату',
                              compact: true,
                              height: 40,
                              onPressed: () => AppNavigator.push(
                                  context, const CreateRoomScreen()),
                            ),
                          )
                        else
                          for (final s in _rooms) ...[
                            RoomCard(
                              summary: s,
                              onTap: () => AppNavigator.push(context,
                                  ReadingRoomScreen(roomId: s.room.id)),
                            ),
                            const SizedBox(height: 10),
                          ],
                      ],
                    ),
            ),
            if (!_loading && _rooms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: PrimaryButton(
                  label: 'Создать комнату',
                  icon: Icons.add,
                  onPressed: () =>
                      AppNavigator.push(context, const CreateRoomScreen()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
