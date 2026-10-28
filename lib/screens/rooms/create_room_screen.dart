import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../models/book.dart';
import '../../models/reading_room.dart';
import '../../models/social.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/date_format.dart';
import '../../utils/validators.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../../widgets/sheets.dart';
import 'reading_room_screen.dart';
import 'room_widgets.dart';

/// Экран 12. Create Room — выбранная книга, название комнаты, приглашение
/// друзей, приватность, «Создать».
class CreateRoomScreen extends StatefulWidget {
  final int? bookId;
  final int? inviteUserId;

  const CreateRoomScreen({super.key, this.bookId, this.inviteUserId});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  List<Book> _books = [];
  Book? _book;
  List<FriendWithBook> _friends = [];
  final Set<int> _invited = {};
  RoomPrivacy _privacy = RoomPrivacy.friends;
  DateTime? _targetDate;
  bool _loading = true;
  bool _saving = false;

  int get _uid => Session.instance.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await Repos.library.all(_uid);
    final books = entries.map((e) => e.book).toList();
    if (books.isEmpty) books.addAll(await Repos.books.search(_uid));
    Book? selected;
    if (widget.bookId != null) {
      selected = await Repos.books.byId(widget.bookId!);
      if (selected != null && !books.any((b) => b.id == selected!.id)) {
        books.insert(0, selected);
      }
    }
    selected ??= books.isEmpty ? null : books.first;
    final friends = await Repos.social.friends(_uid);
    if (!mounted) return;
    setState(() {
      _books = books;
      _book = selected;
      _friends = friends;
      if (widget.inviteUserId != null) _invited.add(widget.inviteUserId!);
      if (selected != null) _name.text = '${selected.title} — evening reading';
      _loading = false;
    });
  }

  Future<void> _chooseBook() async {
    if (_books.isEmpty) {
      AppMessages.unavailable(context, 'Добавьте книги в библиотеку');
      return;
    }
    final id = await showActionSheet<int>(
      context,
      title: 'Выберите книгу',
      selected: _book?.id,
      actions: [
        for (final b in _books.take(12))
          SheetAction(value: b.id, label: b.title, subtitle: b.author),
      ],
    );
    if (id == null || !mounted) return;
    final book = _books.firstWhere((b) => b.id == id);
    final oldDefault = '${_book?.title} — evening reading';
    setState(() {
      if (_name.text == oldDefault) _name.text = '${book.title} — evening reading';
      _book = book;
    });
  }

  Future<void> _create() async {
    FocusScope.of(context).unfocus();
    final book = _book;
    if (book == null) {
      AppMessages.error(context, 'Выберите книгу для комнаты');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      AppMessages.error(context, 'Проверьте название комнаты');
      return;
    }
    if (_invited.isEmpty) {
      AppMessages.error(context, 'Пригласите хотя бы одного друга');
      return;
    }
    setState(() => _saving = true);
    final roomId = await Repos.rooms.createRoom(
      creatorId: _uid,
      bookId: book.id,
      name: _name.text,
      privacy: _privacy,
      inviteeIds: _invited.toList(),
      targetDate: _targetDate,
    );
    if (!mounted) return;
    AppMessages.success(context,
        'Комната создана. Приглашения отправлены: ${_invited.length}');
    AppNavigator.replace(context, ReadingRoomScreen(roomId: roomId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const CenteredHeader(title: 'Создать Reading Room'),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                        children: [
                          const SectionLabel('Выбранная книга'),
                          const SizedBox(height: 10),
                          _bookCard(),
                          const SizedBox(height: 18),
                          const SectionLabel('Название Reading Room'),
                          const SizedBox(height: 10),
                          PlainTextField(
                            controller: _name,
                            hint: 'Например: 1984 — evening reading',
                            maxLength: 50,
                            validator: Validators.roomName,
                          ),
                          const SizedBox(height: 18),
                          const SectionLabel('Пригласить друзей'),
                          const SizedBox(height: 10),
                          _friendsCard(),
                          const SizedBox(height: 18),
                          const SectionLabel('Цель (необязательно)'),
                          const SizedBox(height: 10),
                          AppCard(
                            radius: 14,
                            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                            onTap: () async {
                              final d = await pickTargetDate(context, _targetDate);
                              if (d != null && mounted) {
                                setState(() => _targetDate = d);
                              }
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.flag_outlined,
                                    size: 18, color: AppColors.textPrimary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _targetDate == null
                                        ? 'Дочитать к… (выбрать дату)'
                                        : 'Дочитать к ${DateFormatRu.shortDate(_targetDate!)}',
                                    style: AppTextStyles.body.copyWith(
                                        color: _targetDate == null
                                            ? AppColors.textMuted
                                            : AppColors.textPrimary),
                                  ),
                                ),
                                if (_targetDate != null)
                                  IconButton(
                                    tooltip: 'Убрать цель',
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () =>
                                        setState(() => _targetDate = null),
                                  )
                                else
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Icon(Icons.calendar_month_outlined,
                                        size: 18, color: AppColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const SectionLabel('Настройки конфиденциальности'),
                          const SizedBox(height: 10),
                          AppCard(
                            radius: 14,
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Column(
                              children: [
                                SelectableRow(
                                  leading: const Icon(Icons.people_outline,
                                      size: 18, color: AppColors.textPrimary),
                                  label: RoomPrivacy.friends.label,
                                  selected: _privacy == RoomPrivacy.friends,
                                  onTap: () => setState(
                                      () => _privacy = RoomPrivacy.friends),
                                ),
                                SelectableRow(
                                  leading: const Icon(Icons.mail_outline,
                                      size: 18, color: AppColors.textPrimary),
                                  label: RoomPrivacy.inviteOnly.label,
                                  selected: _privacy == RoomPrivacy.inviteOnly,
                                  onTap: () => setState(
                                      () => _privacy = RoomPrivacy.inviteOnly),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PrimaryButton(
                  label: 'Создать',
                  compact: true,
                  loading: _saving,
                  onPressed: _loading ? null : _create,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bookCard() {
    final book = _book;
    return AppCard(
      radius: 14,
      padding: const EdgeInsets.all(12),
      onTap: _chooseBook,
      child: Row(
        children: [
          if (book != null)
            BookCover(book: book, width: 40, height: 56, radius: 3)
          else
            Container(width: 40, height: 56, color: AppColors.chip),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book?.title ?? 'Книга не выбрана',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bookTitleSerif.copyWith(fontSize: 17)),
                const SizedBox(height: 2),
                Text(book?.author ?? 'Нажмите, чтобы выбрать',
                    style: AppTextStyles.author),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _friendsCard() {
    if (_friends.isEmpty) {
      return AppCard(
        radius: 14,
        child: EmptyState(
          icon: Icons.person_add_alt,
          title: 'У вас пока нет друзей',
          subtitle: 'Добавьте друзей, чтобы приглашать их в комнаты',
          action: PrimaryButton(
            label: 'Найти друзей',
            compact: true,
            height: 40,
            onPressed: () => MainShell.goToTab(context, MainShell.friends),
          ),
        ),
      );
    }
    return AppCard(
      radius: 14,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final f in _friends)
            SizedBox(
              height: 58,
              child: SelectableRow(
                leading: LetterAvatar(name: f.user.name, size: 32, fontSize: 13),
                label: f.user.name,
                selected: _invited.contains(f.user.id),
                onTap: () => setState(() {
                  if (!_invited.remove(f.user.id)) _invited.add(f.user.id);
                }),
              ),
            ),
        ],
      ),
    );
  }
}
