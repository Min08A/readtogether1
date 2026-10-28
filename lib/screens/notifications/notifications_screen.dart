import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/feed.dart';
import '../../models/reading_room.dart';
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
import '../books/book_details_screen.dart';
import '../friends/friend_profile_screen.dart';
import '../profile/settings_screen.dart';
import '../rooms/reading_room_screen.dart';
import '../rooms/room_discussion_screen.dart';
import '../rooms/room_invite_dialog.dart';

/// Экран 21. Notifications — приглашения, добавления в друзья,
/// комментарии, рекомендации, достижения.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with ReloadOnDataChange {
  final _repo = Repos.notifications;
  final _rooms = Repos.rooms;
  List<NotificationItem> _items = [];

  /// Комнаты, в которые пользователь всё ещё приглашён (кнопки активны).
  final Set<int> _pendingRooms = {};
  bool _loading = true;

  int get _uid => Session.instance.userId;

  @override
  Future<void> load() async {
    final items = await _repo.list(_uid);
    final pending = <int>{};
    for (final n in items) {
      final roomId = n.roomId;
      if (n.type == NotificationType.roomInvite && roomId != null) {
        if (await _rooms.membership(roomId, _uid) == MemberStatus.invited) {
          pending.add(roomId);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _pendingRooms
        ..clear()
        ..addAll(pending);
      _loading = false;
    });
  }

  Future<void> _open(NotificationItem n) async {
    if (!n.isRead) await _repo.markRead(n.id);
    if (!mounted) return;
    switch (n.type) {
      case NotificationType.roomInvite:
        if (n.roomId != null) await showRoomInvite(context, n.roomId!);
      case NotificationType.nudge:
        if (n.roomId != null) {
          AppNavigator.push(context, ReadingRoomScreen(roomId: n.roomId!));
        }
      case NotificationType.comment:
        if (n.roomId != null) {
          AppNavigator.push(context, RoomDiscussionScreen(roomId: n.roomId!));
        }
      case NotificationType.recommendation:
        if (n.bookId != null) {
          AppNavigator.push(context, BookDetailsScreen(bookId: n.bookId!));
        }
      case NotificationType.friendRequest:
        MainShell.goToTab(context, MainShell.friends);
      default:
        if (n.actorId != null) {
          AppNavigator.push(context, FriendProfileScreen(userId: n.actorId!));
        }
    }
  }

  Future<void> _respond(NotificationItem n, bool accept) async {
    final roomId = n.roomId!;
    if (!accept) {
      final ok = await AppMessages.confirm(
        context,
        title: 'Отклонить приглашение?',
        message: '${n.actorName ?? 'Друг'} не увидит вас среди участников комнаты.',
        confirmText: 'Отклонить',
        destructive: true,
      );
      if (!ok) return;
    }
    await _rooms.respondToInvite(roomId, _uid, accept: accept);
    if (!mounted) return;
    if (accept) {
      AppMessages.success(context, 'Вы присоединились к Reading Room');
      AppNavigator.push(context, ReadingRoomScreen(roomId: roomId));
    } else {
      AppMessages.info(context, 'Приглашение отклонено');
    }
  }

  Future<void> _delete(NotificationItem n) async {
    await _repo.delete(n.id);
    if (mounted) AppMessages.success(context, 'Уведомление удалено');
  }

  String _groupOf(DateTime d) {
    if (DateFormatRu.isToday(d)) return 'Сегодня';
    if (DateFormatRu.isYesterday(d)) return 'Вчера';
    return 'Ранее';
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<NotificationItem>>{};
    for (final n in _items) {
      groups.putIfAbsent(_groupOf(n.createdAt), () => []).add(n);
    }
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
                  child: Text('Уведомления',
                      style: TextStyle(
                          fontFamily: AppTextStyles.sans,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                CircleIconButton(
                  icon: Icons.settings_outlined,
                  background: AppColors.surface,
                  bordered: true,
                  tooltip: 'Настройки уведомлений',
                  onTap: () => showNotificationSettingsSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const LoadingView()
            else if (_items.isEmpty)
              const EmptyState(
                icon: Icons.notifications_none,
                title: 'Уведомлений нет',
                subtitle: 'Здесь появятся приглашения и новости друзей',
              )
            else
              for (final entry in groups.entries) ...[
                SectionLabel(entry.key),
                const SizedBox(height: 10),
                for (final n in entry.value) ...[
                  Dismissible(
                    key: ValueKey('n-${n.id}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => AppMessages.confirm(
                      context,
                      title: 'Удалить уведомление?',
                      message: 'Уведомление будет удалено без возможности восстановления.',
                      confirmText: 'Удалить',
                      destructive: true,
                    ),
                    onDismissed: (_) {
                      setState(() => _items.remove(n));
                      _delete(n);
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    child: _NotificationCard(
                      item: n,
                      showActions: n.type == NotificationType.roomInvite &&
                          n.roomId != null &&
                          _pendingRooms.contains(n.roomId),
                      onTap: () => _open(n),
                      onAccept: () => _respond(n, true),
                      onDecline: () => _respond(n, false),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem item;
  final bool showActions;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _NotificationCard({
    required this.item,
    required this.showActions,
    required this.onTap,
    required this.onAccept,
    required this.onDecline,
  });

  Widget _leading() {
    switch (item.type) {
      case NotificationType.recommendation:
        return _iconCircle(Icons.auto_awesome);
      case NotificationType.achievement:
        return _iconCircle(Icons.workspace_premium_outlined);
      case NotificationType.nudge:
        return Stack(
          clipBehavior: Clip.none,
          children: [
            LetterAvatar(name: item.actorName ?? '?', size: 34, fontSize: 14),
            const Positioned(
              right: -4,
              bottom: -4,
              child: Text('⏰', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
      default:
        return LetterAvatar(name: item.actorName ?? '?', size: 34, fontSize: 14);
    }
  }

  Widget _iconCircle(IconData icon) => Container(
        width: 34,
        height: 34,
        decoration:
            const BoxDecoration(color: AppColors.chip, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: AppColors.primary),
      );

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _leading(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        if (item.actorName != null)
                          TextSpan(
                              text: '${item.actorName} ',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        TextSpan(text: item.text),
                        if (item.type == NotificationType.recommendation &&
                            item.bookTitle != null)
                          TextSpan(
                              text: ' ${item.bookTitle}',
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
                        style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              if (item.isRead && !showActions)
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  decoration: const BoxDecoration(
                      color: AppColors.chip, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 14, color: AppColors.primary),
                ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                SmallButton(
                    label: 'Принять', height: 32, fontSize: 13.5, onPressed: onAccept),
                const SizedBox(width: 8),
                SmallButton(
                    label: 'Отклонить',
                    height: 32,
                    fontSize: 13.5,
                    style: SmallButtonStyle.white,
                    onPressed: onDecline),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
