import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/library_entry.dart';
import '../../models/reading_mark.dart';
import '../../models/reading_room.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common.dart';
import '../../widgets/together_widgets.dart';
import 'room_widgets.dart';

/// Экран 14б. Обсуждение в комнате (компактный вид Reading Room из макета
/// «reading-room»): прогресс, общие закладки и вся переписка
/// с вопросами к главам, цитатами, реакциями и защитой от спойлеров.
class RoomDiscussionScreen extends StatefulWidget {
  final int roomId;
  const RoomDiscussionScreen({super.key, required this.roomId});

  @override
  State<RoomDiscussionScreen> createState() => _RoomDiscussionScreenState();
}

class _RoomDiscussionScreenState extends State<RoomDiscussionScreen>
    with ReloadOnDataChange, RoomMessagesLogic {
  final _scroll = ScrollController();
  ReadingRoom? _room;
  List<RoomMember> _members = [];
  List<ReadingMark> _bookmarks = [];
  List<RoomMessage> _messages = [];
  LibraryEntry? _myEntry;
  bool _isMember = false;
  bool _loading = true;
  bool _scrolledInitially = false;
  int _lastCount = 0;

  @override
  int get myChapterForSpoilers => viewerChapter(_myEntry);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
    final isMember = members.any((m) => m.userId == uid);
    if (isMember) await Repos.rooms.markRead(widget.roomId, uid);
    if (!mounted) return;
    final grew = messages.length > _lastCount;
    setState(() {
      _room = room;
      _members = members;
      _bookmarks = bookmarks;
      _messages = messages;
      _myEntry = entry;
      _isMember = isMember;
      _loading = false;
      _lastCount = messages.length;
    });
    // Прокрутка к последнему сообщению при открытии и при новых сообщениях.
    if (!_scrolledInitially || grew) {
      _scrolledInitially = true;
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
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
                  Flexible(
                    child: Text(room?.book.title ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppTextStyles.serif,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.people, size: 14, color: Color(0xFF6E8FB5)),
                  const SizedBox(width: 3),
                  Text('${_members.length}',
                      style: AppTextStyles.caption.copyWith(fontSize: 14)),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : room == null
                      ? const EmptyState(
                          icon: Icons.meeting_room_outlined,
                          title: 'Комната не найдена')
                      : _content(),
            ),
            if (room != null)
              MessageInputBar(
                roomId: room.id,
                canWrite: _isMember,
                myChapter: myChapterForSpoilers,
                hint: '...',
                onSent: _scrollToEnd,
              ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final uid = Session.instance.userId;
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      children: [
        AppCard(
          radius: 14,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ПРОГРЕСС',
                  style: AppTextStyles.sectionLabel.copyWith(fontSize: 11.5)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in _members)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LetterAvatar(name: m.userName, size: 24, fontSize: 10),
                        const SizedBox(width: 8),
                        Text('${m.userName} (${m.progressPercent}%)',
                            style:
                                AppTextStyles.itemTitle.copyWith(fontSize: 13.5)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionLabel('Общие закладки'),
        const SizedBox(height: 10),
        if (_bookmarks.isEmpty)
          const Text('Пока нет общих закладок',
              style: AppTextStyles.bodySecondary),
        for (final b in _bookmarks) ...[
          AppCard(
            radius: 14,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    LetterAvatar(name: b.userName, size: 20, fontSize: 9),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(b.userName,
                          style:
                              AppTextStyles.itemTitle.copyWith(fontSize: 13.5)),
                    ),
                    Text('Глава ${b.chapterNumber ?? '—'}',
                        style: AppTextStyles.caption.copyWith(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                if (_bookmarkHidden(b, uid))
                  SpoilerPlate(
                    chapter: b.chapterNumber ?? 0,
                    onReveal: () async {
                      final ok =
                          await confirmRevealSpoiler(context, b.chapterNumber ?? 0);
                      if (ok && mounted) {
                        setState(() => revealedSpoilers.add(-b.id));
                      }
                    },
                  )
                else
                  Text('«${b.text}»',
                      style: AppTextStyles.body.copyWith(fontSize: 14.5)),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 8),
        const SectionLabel('Обсуждение'),
        const SizedBox(height: 10),
        AppCard(
          radius: 14,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: _messages.isEmpty
              ? const Text('Сообщений пока нет — начните обсуждение!',
                  style: AppTextStyles.bodySecondary)
              : Column(
                  children: [
                    for (var i = 0; i < _messages.length; i++) ...[
                      MessageTile(
                        message: _messages[i],
                        compactTime: true,
                        hiddenAsSpoiler: isSpoiler(_messages[i]),
                        onReveal: () => revealSpoiler(_messages[i]),
                        onToggleReaction: (e) => toggleReaction(_messages[i], e),
                        onAddReaction: () => pickReaction(_messages[i]),
                      ),
                      if (i != _messages.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Долгое нажатие на сообщение — реакция. Кнопка «?» — вопрос к главе.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  bool _bookmarkHidden(ReadingMark b, int uid) =>
      b.userId != uid &&
      b.chapterNumber != null &&
      b.chapterNumber! > myChapterForSpoilers &&
      !revealedSpoilers.contains(-b.id);
}
