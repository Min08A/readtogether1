import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repos.dart';
import '../../data/repositories/room_repository.dart';
import '../../models/library_entry.dart';
import '../../models/reading_room.dart';
import '../../services/demo_simulator.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/book_text.dart';
import '../../utils/date_format.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/together_widgets.dart';

/// Глава, до которой дочитал пользователь (для защиты от спойлеров).
/// Если книга закончена — спойлеров для него нет.
int viewerChapter(LibraryEntry? entry) {
  if (entry == null) return 1;
  if (entry.status == LibraryStatus.finished) return 1 << 30;
  return BookContent.chapterOf(entry.pagesRead < 1 ? 1 : entry.pagesRead);
}

/// Поле ввода сообщения внизу комнаты (общий компонент двух экранов комнаты).
/// Кнопка «?» переключает режим «Вопрос к главе».
class MessageInputBar extends StatefulWidget {
  final int roomId;
  final bool canWrite;
  final String hint;
  final int myChapter;
  final bool allowQuestion;
  final VoidCallback? onSent;

  const MessageInputBar({
    super.key,
    required this.roomId,
    required this.canWrite,
    required this.myChapter,
    this.hint = 'написать сообщение...',
    this.allowQuestion = true,
    this.onSent,
  });

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _question = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!widget.canWrite) {
      AppMessages.unavailable(
          context, 'Присоединитесь к комнате, чтобы писать сообщения');
      return;
    }
    final error = Validators.message(_controller.text);
    if (error != null) {
      AppMessages.error(context, error);
      return;
    }
    if (_question && _controller.text.trim().length < 5) {
      AppMessages.error(context, 'Вопрос слишком короткий — минимум 5 символов');
      return;
    }
    setState(() => _sending = true);
    final uid = Session.instance.userId;
    final chapter = widget.myChapter > 100000 ? null : widget.myChapter;
    await Repos.rooms.sendMessage(
      widget.roomId,
      uid,
      _controller.text,
      chapter: chapter,
      kind: _question ? MessageKind.question : MessageKind.text,
    );
    DemoSimulator.instance
        .onUserMessage(widget.roomId, uid, question: _question);
    if (!mounted) return;
    if (_question) {
      AppMessages.success(context, 'Вопрос к главе опубликован');
    }
    _controller.clear();
    setState(() {
      _sending = false;
      _question = false;
    });
    widget.onSent?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_question)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                  '❓ Вопрос к главе ${widget.myChapter > 100000 ? '' : widget.myChapter} — друзья увидят его выделенным',
                  style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
            ),
          Row(
            children: [
              if (widget.allowQuestion) ...[
                Tooltip(
                  message: 'Вопрос к главе',
                  child: Material(
                    color: _question ? AppColors.primary : AppColors.chip,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _question = !_question),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.question_mark_rounded,
                            size: 18,
                            color: _question
                                ? Colors.white
                                : AppColors.textPrimary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.only(left: 16, right: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _question ? AppColors.primary : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          enabled: !_sending,
                          maxLength: 500,
                          maxLengthEnforcement: MaxLengthEnforcement.enforced,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                          decoration: InputDecoration(
                            hintText:
                                _question ? 'Ваш вопрос к главе...' : widget.hint,
                            hintStyle: AppTextStyles.hint.copyWith(fontSize: 14),
                            border: InputBorder.none,
                            counterText: '',
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Отправить',
                        onPressed: _sending ? null : _send,
                        icon: Transform.rotate(
                          angle: -0.6,
                          child: const Icon(Icons.send_outlined,
                              size: 20, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Сообщение в комнате: вопрос, цитата, спойлер, реакции.
class MessageTile extends StatelessWidget {
  final RoomMessage message;
  final bool hiddenAsSpoiler;
  final bool compactTime;
  final VoidCallback onReveal;
  final ValueChanged<String> onToggleReaction;
  final VoidCallback onAddReaction;

  const MessageTile({
    super.key,
    required this.message,
    required this.hiddenAsSpoiler,
    required this.onReveal,
    required this.onToggleReaction,
    required this.onAddReaction,
    this.compactTime = false,
  });

  String get _time {
    final d = message.createdAt;
    if (!compactTime) return DateFormatRu.relative(d);
    return DateFormatRu.isToday(d)
        ? DateFormatRu.time(d)
        : '${DateFormatRu.shortDate(d)}, ${DateFormatRu.time(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final m = message;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compactTime)
          Text('${m.userName} · $_time',
              style: AppTextStyles.caption
                  .copyWith(fontSize: 11.5, fontWeight: FontWeight.w500))
        else
          Row(
            children: [
              Expanded(
                child: Text(m.userName,
                    style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
              ),
              Text(_time, style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
        if (m.isQuestion)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1D6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
                '❓ Вопрос к главе ${m.chapterNumber ?? ''}'.trimRight(),
                style: const TextStyle(
                    fontFamily: AppTextStyles.sans,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A5A00))),
          ),
        const SizedBox(height: 2),
        if (hiddenAsSpoiler)
          SpoilerPlate(chapter: m.chapterNumber ?? 0, onReveal: onReveal)
        else ...[
          if (m.quote != null) QuoteBlock(quote: m.quote!, page: m.pageNumber),
          Text(m.text,
              style: AppTextStyles.body.copyWith(
                  fontSize: 14.5,
                  fontWeight:
                      m.isQuestion ? FontWeight.w600 : FontWeight.w400)),
          ReactionBar(
            reactions: m.reactions,
            onToggle: onToggleReaction,
            onAdd: onAddReaction,
          ),
        ],
      ],
    );
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onLongPress: hiddenAsSpoiler ? null : onAddReaction,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LetterAvatar(
              name: m.userName,
              size: compactTime ? 22.0 : 26.0,
              fontSize: compactTime ? 10.0 : 11.0),
          SizedBox(width: compactTime ? 10.0 : 12.0),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Логика спойлеров/реакций, общая для двух экранов комнаты.
mixin RoomMessagesLogic<T extends StatefulWidget> on State<T> {
  final Set<int> revealedSpoilers = {};

  int get myChapterForSpoilers;

  bool isSpoiler(RoomMessage m) =>
      m.userId != Session.instance.userId &&
      m.chapterNumber != null &&
      m.chapterNumber! > myChapterForSpoilers &&
      !revealedSpoilers.contains(m.id);

  Future<void> revealSpoiler(RoomMessage m) async {
    final ok = await confirmRevealSpoiler(context, m.chapterNumber ?? 0);
    if (ok && mounted) setState(() => revealedSpoilers.add(m.id));
  }

  Future<void> toggleReaction(RoomMessage m, String emoji) async {
    await Repos.rooms.toggleReaction(m.id, Session.instance.userId, emoji);
  }

  Future<void> pickReaction(RoomMessage m) async {
    final emoji = await showReactionPicker(context, RoomRepository.reactionEmojis);
    if (emoji == null) return;
    final added =
        await Repos.rooms.toggleReaction(m.id, Session.instance.userId, emoji);
    if (!added && mounted) AppMessages.info(context, 'Реакция $emoji убрана');
  }
}

/// Карточка комнаты для «Мои Reading Rooms».
class RoomCard extends StatelessWidget {
  final RoomSummary summary;
  final VoidCallback onTap;
  final double? width;

  const RoomCard({
    super.key,
    required this.summary,
    required this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final last = s.lastMessage;
    return SizedBox(
      width: width,
      child: AppCard(
        radius: 16,
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(book: s.room.book, width: 46, height: 68, radius: 3),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.room.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                AppTextStyles.itemTitle.copyWith(fontSize: 14.5)),
                      ),
                      StreakFlame(
                        streak: s.streak,
                        size: 15,
                        explanation:
                            'Огонёк комнаты: сколько дней подряд книгу комнаты читают минимум двое участников.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      AvatarStack(
                          names: s.members.map((m) => m.userName).toList(),
                          size: 20),
                      const SizedBox(width: 6),
                      Text('${s.members.length}',
                          style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
                      const Spacer(),
                      Text('вы: ${s.myProgress}%',
                          style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          last == null
                              ? 'Сообщений пока нет'
                              : '${last.userName}: ${last.isQuestion ? '❓ ' : ''}${last.text}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTextStyles.sans,
                            fontSize: 12.5,
                            fontWeight:
                                s.unread > 0 ? FontWeight.w600 : FontWeight.w400,
                            color: s.unread > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (s.unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('${s.unread}',
                              style: const TextStyle(
                                  fontFamily: AppTextStyles.sans,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Диалог добавления общей закладки в комнату.
Future<bool> showAddRoomBookmarkDialog(BuildContext context, ReadingRoom room,
    {int? initialPage, String? initialText}) async {
  final page = TextEditingController(text: initialPage?.toString() ?? '');
  final text = TextEditingController(text: initialText ?? '');
  final formKey = GlobalKey<FormState>();
  final maxPage = room.book.pageCount;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Общая закладка · ${room.name}',
          style: AppTextStyles.centeredHeader),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LabeledTextField(
                label: 'Страница (1–$maxPage)',
                controller: page,
                hint: 'Номер страницы',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 5,
                validator: (v) =>
                    Validators.intInRange(v, 1, maxPage, field: 'Номер страницы'),
              ),
              const SizedBox(height: 12),
              LabeledTextField(
                label: 'Цитата',
                controller: text,
                hint: 'Отрывок текста',
                maxLines: 3,
                maxLength: 300,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Введите цитату';
                  if (value.length < 3) return 'Цитата слишком короткая';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Отмена',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
          },
          child: const Text('Добавить'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  final p = int.parse(page.text.trim());
  final snippet = text.text.trim();
  await Repos.marks.addBookmark(
    userId: Session.instance.userId,
    bookId: room.book.id,
    roomId: room.id,
    chapter: BookContent.chapterOf(p),
    page: p,
    snippet: snippet.length > 300 ? snippet.substring(0, 300) : snippet,
  );
  return true;
}

/// Выбор комнаты, если по книге их несколько.
Future<ReadingRoom?> pickRoom(BuildContext context, List<ReadingRoom> rooms) async {
  if (rooms.length == 1) return rooms.first;
  return showModalBottomSheet<ReadingRoom>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('В какую комнату?', style: AppTextStyles.centeredHeader),
          const SizedBox(height: 8),
          for (final r in rooms)
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(r.name, style: AppTextStyles.body),
              subtitle: Text('${r.memberCount} участника',
                  style: AppTextStyles.caption),
              onTap: () => Navigator.of(ctx).pop(r),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// «Обсудить эту страницу»: цитата со страницы отправляется в чат комнаты.
/// Возвращает комнату, куда ушло сообщение, или null.
Future<ReadingRoom?> showDiscussPageSheet(
  BuildContext context, {
  required ReadingRoom room,
  required String quote,
  required int page,
  required int chapter,
}) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final send = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Обсудить в «${room.name}»',
                style: AppTextStyles.centeredHeader),
            const SizedBox(height: 10),
            QuoteBlock(quote: quote, page: page),
            const SizedBox(height: 10),
            PlainTextField(
              controller: controller,
              hint: 'Что вы думаете об этом отрывке?',
              maxLines: 3,
              maxLength: 500,
              validator: Validators.message,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Отправить в комнату'),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
  if (send != true) return null;
  final uid = Session.instance.userId;
  await Repos.rooms.sendMessage(room.id, uid, controller.text,
      chapter: chapter, page: page, quote: quote);
  DemoSimulator.instance.onUserMessage(room.id, uid);
  return room;
}

/// Нижнее меню «Информация о комнате»: цель, огонёк, выход из комнаты.
Future<void> showRoomInfoSheet(BuildContext context, ReadingRoom room,
    {StreakInfo streak = StreakInfo.none}) {
  final uid = Session.instance.userId;
  final isCreator = room.creatorId == uid;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.name,
                style: AppTextStyles.centeredHeader.copyWith(fontSize: 19)),
            const SizedBox(height: 14),
            _infoRow(Icons.menu_book_outlined, 'Книга', room.book.title),
            _infoRow(Icons.person_outline, 'Создатель',
                isCreator ? 'Вы' : room.creatorName),
            _infoRow(Icons.shield_outlined, 'Приватность', room.privacy.label),
            _infoRow(Icons.groups_outlined, 'Участники', '${room.memberCount}'),
            _infoRow(Icons.event_outlined, 'Создана',
                DateFormatRu.createdLabel(room.createdAt)
                    .replaceFirst('Создана ', '')),
            _infoRow(Icons.flag_outlined, 'Цель',
                room.targetDate == null
                    ? 'не задана'
                    : 'дочитать к ${DateFormatRu.shortDate(room.targetDate!)}'),
            _infoRow(Icons.local_fire_department_outlined, 'Огонёк комнаты',
                streak.isAlive
                    ? '${streak.days} дн.${streak.activeToday ? '' : ' (под угрозой)'}'
                    : 'нет'),
            const SizedBox(height: 10),
            if (isCreator)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.primary),
                  icon: const Icon(Icons.edit_calendar_outlined),
                  label: Text(room.targetDate == null
                      ? 'Задать цель (срок)'
                      : 'Изменить цель'),
                  onPressed: () async {
                    final date = await pickTargetDate(ctx, room.targetDate);
                    if (date == null) return;
                    await Repos.rooms.setTargetDate(room.id, date);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    if (context.mounted) {
                      AppMessages.success(context,
                          'Цель обновлена: дочитать к ${DateFormatRu.shortDate(date)}');
                    }
                  },
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.logout),
                label: const Text('Покинуть комнату'),
                onPressed: () async {
                  final ok = await AppMessages.confirm(
                    ctx,
                    title: 'Покинуть комнату?',
                    message:
                        'Вы перестанете видеть обсуждение и общие закладки «${room.name}».',
                    confirmText: 'Покинуть',
                    destructive: true,
                  );
                  if (!ok) return;
                  await Repos.rooms.leaveRoom(room.id, uid);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!context.mounted) return;
                  AppMessages.info(context, 'Вы покинули комнату «${room.name}»');
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Выбор даты цели комнаты: от завтра до года вперёд.
Future<DateTime?> pickTargetDate(BuildContext context, DateTime? current) {
  final now = DateTime.now();
  final first = DateTime(now.year, now.month, now.day + 1);
  final last = DateTime(now.year + 1, now.month, now.day);
  var initial = current ?? DateTime(now.year, now.month, now.day + 14);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    helpText: 'Дочитать к',
    cancelText: 'Отмена',
    confirmText: 'Готово',
  );
}

Widget _infoRow(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodySecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.itemTitle.copyWith(fontSize: 14)),
          ),
        ],
      ),
    );
