import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/library_entry.dart';
import '../../models/reading_mark.dart';
import '../../models/reading_room.dart';
import '../../navigation/app_navigator.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/date_format.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/together_widgets.dart';
import '../books/book_details_screen.dart';
import '../reader/reader_screen.dart';
import 'room_discussion_screen.dart';
import 'room_widgets.dart';

/// Экран 14. Reading Room — прогресс участников, цель и темп, общие закладки,
/// обсуждение (со спойлер-защитой и реакциями), поле ввода сообщения.
class ReadingRoomScreen extends StatefulWidget {
  final int roomId;
  const ReadingRoomScreen({super.key, required this.roomId});

  @override
  State<ReadingRoomScreen> createState() => _ReadingRoomScreenState();
}

class _ReadingRoomScreenState extends State<ReadingRoomScreen>
    with ReloadOnDataChange, RoomMessagesLogic {
  ReadingRoom? _room;
  List<RoomMember> _members = [];
  List<ReadingMark> _bookmarks = [];
  List<RoomMessage> _messages = [];
  LibraryEntry? _myEntry;
  StreakInfo _streak = StreakInfo.none;
  bool _isMember = false;
  bool _loading = true;

  int get _uid => Session.instance.userId;

  @override
  int get myChapterForSpoilers => viewerChapter(_myEntry);

  @override
  Future<void> load() async {
    final uid = Session.instance.userIdOrNull;
    if (uid == null) return;
    final room = await Repos.rooms.room(widget.roomId);
    final members = await Repos.rooms.members(widget.roomId);
    final bookmarks = await Repos.marks.roomBookmarks(widget.roomId);
    final messages = await Repos.rooms.messages(widget.roomId, viewerId: uid);
    final entry =
        room == null ? null : await Repos.library.entry(uid, room.book.id);
    final streak = await Repos.streaks.room(widget.roomId);
    final isMember = members.any((m) => m.userId == uid);
    if (isMember) await Repos.rooms.markRead(widget.roomId, uid);
    if (!mounted) return;
    setState(() {
      _room = room;
      _members = members;
      _bookmarks = bookmarks;
      _messages = messages;
      _myEntry = entry;
      _streak = streak;
      _isMember = isMember;
      _loading = false;
    });
  }

  Future<void> _addBookmark() async {
    final room = _room!;
    if (!_isMember) {
      AppMessages.unavailable(
          context, 'Только участники комнаты могут добавлять закладки');
      return;
    }
    final added = await showAddRoomBookmarkDialog(context, room,
        initialPage: _myEntry?.pagesRead);
    if (added && mounted) AppMessages.success(context, 'Общая закладка добавлена');
  }

  Future<void> _nudge(RoomMember m) async {
    final room = _room!;
    final sent = await Repos.rooms.nudge(room.id, _uid, m.userId, room.book.title);
    if (!mounted) return;
    if (sent) {
      AppMessages.success(context, 'Напоминание отправлено: ${m.userName}');
    } else {
      AppMessages.unavailable(
          context, 'Вы уже напоминали ${m.userName} сегодня — попробуйте завтра');
    }
  }

  Future<void> _setGoal() async {
    final room = _room!;
    if (room.creatorId != _uid) {
      AppMessages.unavailable(
          context, 'Цель комнаты может задать только создатель — ${room.creatorName}');
      return;
    }
    final date = await pickTargetDate(context, room.targetDate);
    if (date == null) return;
    await Repos.rooms.setTargetDate(room.id, date);
    if (mounted) {
      AppMessages.success(
          context, 'Цель: дочитать к ${DateFormatRu.shortDate(date)}');
    }
  }

  void _openDiscussion() => AppNavigator.push(
      context, RoomDiscussionScreen(roomId: widget.roomId));

  void _read() {
    final room = _room!;
    AppNavigator.push(context, ReaderScreen(bookId: room.book.id));
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CenteredHeader(
              titleWidget: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Reading Room',
                      style: TextStyle(
                          fontFamily: AppTextStyles.serif,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(width: 6),
                  StreakFlame(
                    streak: _streak,
                    size: 17,
                    explanation:
                        'Огонёк комнаты: сколько дней подряд книгу читают минимум двое участников.',
                  ),
                ],
              ),
              trailing: room == null
                  ? null
                  : CircleIconButton(
                      icon: Icons.info_outline,
                      background: AppColors.surface,
                      bordered: true,
                      iconSize: 20,
                      tooltip: 'О комнате',
                      onTap: () =>
                          showRoomInfoSheet(context, room, streak: _streak),
                    ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : room == null
                      ? const EmptyState(
                          icon: Icons.meeting_room_outlined,
                          title: 'Комната не найдена')
                      : _content(room),
            ),
            if (room != null)
              MessageInputBar(
                roomId: room.id,
                canWrite: _isMember,
                myChapter: myChapterForSpoilers,
              ),
          ],
        ),
      ),
    );
  }

  Widget _content(ReadingRoom room) {
    final latest = _messages.reversed.take(3).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      children: [
        AppCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          onTap: () => AppNavigator.push(
              context, BookDetailsScreen(bookId: room.book.id)),
          child: Row(
            children: [
              BookCover(book: room.book, width: 48, height: 72, radius: 3),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTextStyles.bookTitleSerif.copyWith(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(room.book.author,
                        style: AppTextStyles.author.copyWith(fontSize: 14)),
                  ],
                ),
              ),
              SmallButton(
                label: 'Читать',
                height: 34,
                fontSize: 13.5,
                onPressed: _read,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _goalCard(room),
        const SizedBox(height: 22),
        const SectionLabel('Активные читатели'),
        const SizedBox(height: 10),
        for (final m in _members) ...[
          _memberCard(room, m),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 14),
        SectionLabel('Общие закладки',
            actionText: '+ Добавить', onAction: _addBookmark),
        const SizedBox(height: 10),
        if (_bookmarks.isEmpty)
          const Text('Пока нет общих закладок', style: AppTextStyles.bodySecondary)
        else
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _bookmarks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _SharedBookmarkCard(
                mark: _bookmarks[i],
                hidden: _bookmarkHidden(_bookmarks[i]),
                onReveal: () async {
                  final ok = await confirmRevealSpoiler(
                      context, _bookmarks[i].chapterNumber ?? 0);
                  if (ok && mounted) {
                    setState(() => revealedSpoilers.add(-_bookmarks[i].id));
                  }
                },
              ),
            ),
          ),
        const SizedBox(height: 22),
        SectionLabel('Обсуждение',
            actionText: 'Все сообщения', onAction: _openDiscussion),
        const SizedBox(height: 10),
        AppCard(
          radius: 14,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          onTap: _openDiscussion,
          child: latest.isEmpty
              ? const Text('Сообщений пока нет — начните обсуждение!',
                  style: AppTextStyles.bodySecondary)
              : Column(
                  children: [
                    for (final msg in latest) ...[
                      MessageTile(
                        message: msg,
                        hiddenAsSpoiler: isSpoiler(msg),
                        onReveal: () => revealSpoiler(msg),
                        onToggleReaction: (e) => toggleReaction(msg, e),
                        onAddReaction: () => pickReaction(msg),
                      ),
                      if (msg != latest.last) const SizedBox(height: 14),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  /// Закладки скрываются по тем же правилам, что и сообщения
  /// (id закладок хранятся в revealedSpoilers со знаком минус).
  bool _bookmarkHidden(ReadingMark b) =>
      b.userId != _uid &&
      b.chapterNumber != null &&
      b.chapterNumber! > myChapterForSpoilers &&
      !revealedSpoilers.contains(-b.id);

  Widget _goalCard(ReadingRoom room) {
    final target = room.targetDate;
    if (target == null) {
      if (room.creatorId != _uid) return const SizedBox.shrink();
      return AppCard(
        radius: 14,
        padding: const EdgeInsets.all(12),
        onTap: _setGoal,
        child: const Row(
          children: [
            Icon(Icons.flag_outlined, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text('Задайте цель: к какому дню дочитать книгу',
                  style: AppTextStyles.body),
            ),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      );
    }
    final days = room.daysLeft ?? 0;
    final pages = room.book.pageCount;
    final myPage = _myEntry?.pagesRead ?? 0;
    final perDay =
        days <= 0 ? pages - myPage : ((pages - myPage) / days).ceil();
    final expected = room.expectedProgress ?? 0;
    return AppCard(
      radius: 14,
      padding: const EdgeInsets.all(14),
      onTap: room.creatorId == _uid ? _setGoal : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Цель: дочитать к ${DateFormatRu.shortDate(target)}',
                    style: AppTextStyles.itemTitle),
              ),
              Text(
                days < 0
                    ? 'срок прошёл'
                    : days == 0
                        ? 'сегодня!'
                        : 'осталось $days ${DateFormatRu.plural(days, 'день', 'дня', 'дней')}',
                style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: days <= 2 ? AppColors.genreRed : AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              ProgressLine(value: expected / 100, height: 6, color: AppColors.chip,
                  track: AppColors.background),
              ProgressLine(
                  value: (_myEntry?.progressPercent ?? 0) / 100,
                  height: 6,
                  color: AppColors.primary,
                  track: Colors.transparent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            myPage >= pages
                ? 'Вы дочитали книгу 🎉'
                : 'По плану сегодня — $expected%. Вам нужно ~${perDay < 1 ? 1 : perDay} стр. в день.',
            style: AppTextStyles.caption.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _memberCard(ReadingRoom room, RoomMember m) {
    final pace = m.paceFor(room);
    final (label, color) = paceLabel(pace);
    final isMe = m.userId == _uid;
    return AppCard(
      radius: 12,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          LetterAvatar(name: m.userName, size: 30, fontSize: 13),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(isMe ? '${m.userName} (вы)' : m.userName,
                          style: AppTextStyles.itemTitle),
                    ),
                    Text('${m.progressPercent}%',
                        style: const TextStyle(
                            fontFamily: AppTextStyles.sans,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressLine(value: m.progressPercent / 100),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text('стр. ${m.pageIn(room.book.pageCount)}',
                        style: AppTextStyles.caption.copyWith(fontSize: 11)),
                    if (label.isNotEmpty) ...[
                      Text('  ·  ', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                      Text(label,
                          style: TextStyle(
                              fontFamily: AppTextStyles.sans,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ],
                    const Spacer(),
                    if (!isMe && _isMember && pace == PaceStatus.behind)
                      SmallButton(
                        label: 'Поторопить',
                        style: SmallButtonStyle.soft,
                        height: 24,
                        fontSize: 11.5,
                        onPressed: () => _nudge(m),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedBookmarkCard extends StatelessWidget {
  final ReadingMark mark;
  final bool hidden;
  final VoidCallback onReveal;

  const _SharedBookmarkCard({
    required this.mark,
    required this.hidden,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: AppCard(
        radius: 12,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        onTap: hidden ? onReveal : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LetterAvatar(name: mark.userName, size: 18, fontSize: 9),
                const SizedBox(width: 6),
                Text(mark.userName,
                    style: AppTextStyles.itemTitle.copyWith(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: hidden
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.visibility_off_outlined,
                            size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Спойлер · нажмите, чтобы открыть',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 12.5)),
                        ),
                      ],
                    )
                  : Text(mark.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body
                          .copyWith(fontSize: 13.5, height: 1.25)),
            ),
            Text(
                'Глава ${mark.chapterNumber ?? '—'} · Страница ${mark.pageNumber ?? '—'}',
                style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
