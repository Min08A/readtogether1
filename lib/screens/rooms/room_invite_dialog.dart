import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/reading_room.dart';
import '../../navigation/app_navigator.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/date_format.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import 'reading_room_screen.dart';

/// Экран 13. Room Invite — приглашение от друга, «Присоединиться» /
/// «Отклонить». Показывается как диалог поверх текущего экрана (как в макете).
Future<void> showRoomInvite(BuildContext context, int roomId) async {
  final repo = Repos.rooms;
  final uid = Session.instance.userId;
  final room = await repo.room(roomId);
  final status = await repo.membership(roomId, uid);
  if (!context.mounted) return;
  if (room == null) {
    AppMessages.error(context, 'Комната не найдена или была удалена');
    return;
  }
  if (status == MemberStatus.joined) {
    AppMessages.info(context, 'Вы уже участник этой комнаты');
    AppNavigator.push(context, ReadingRoomScreen(roomId: roomId));
    return;
  }
  if (status == MemberStatus.declined || status == null) {
    AppMessages.unavailable(context, 'Это приглашение больше не действительно');
    return;
  }
  final accepted = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.dialogBarrier,
    builder: (_) => _RoomInviteCard(room: room),
  );
  if (accepted == null || !context.mounted) return;
  await repo.respondToInvite(roomId, uid, accept: accepted);
  if (!context.mounted) return;
  if (accepted) {
    AppMessages.success(context, 'Вы присоединились к «${room.name}»');
    AppNavigator.push(context, ReadingRoomScreen(roomId: roomId));
  } else {
    AppMessages.info(context, 'Приглашение отклонено');
  }
}

class _RoomInviteCard extends StatelessWidget {
  final ReadingRoom room;
  const _RoomInviteCard({required this.room});

  @override
  Widget build(BuildContext context) {
    final count = room.memberCount;
    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 33),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LetterAvatar(name: room.creatorName, size: 56, fontSize: 19),
            const SizedBox(height: 14),
            Text('${room.creatorName} приглашает вас',
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 14.5)),
            const SizedBox(height: 2),
            Text('Читать «${room.book.title}» вместе',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: AppTextStyles.sans,
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            const SizedBox(height: 6),
            Text(
              '$count ${DateFormatRu.plural(count, 'участник', 'участника', 'участников')} • ${DateFormatRu.createdLabel(room.createdAt)}',
              style: AppTextStyles.caption.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundWarm,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  BookCover(book: room.book, width: 46, height: 68, radius: 3),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(room.book.title,
                            style: AppTextStyles.bookTitleSerif
                                .copyWith(fontSize: 17)),
                        const SizedBox(height: 2),
                        Text(room.book.author, style: AppTextStyles.author),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Присоединиться',
              height: 42,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            OutlinedAppButton(
              label: 'Отклонить',
              height: 42,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
