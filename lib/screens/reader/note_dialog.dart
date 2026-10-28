import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/repos.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/book_text.dart';
import '../../utils/validators.dart';
import '../../widgets/inputs.dart';

/// Диалог добавления заметки. Возвращает true, если заметка сохранена.
Future<bool> showAddNoteDialog(
  BuildContext context, {
  required int bookId,
  required int maxPage,
  int? initialPage,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _AddNoteDialog(
      bookId: bookId,
      maxPage: maxPage,
      initialPage: initialPage,
    ),
  );
  return result ?? false;
}

class _AddNoteDialog extends StatefulWidget {
  final int bookId;
  final int maxPage;
  final int? initialPage;

  const _AddNoteDialog({
    required this.bookId,
    required this.maxPage,
    this.initialPage,
  });

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _page =
      TextEditingController(text: widget.initialPage?.toString() ?? '');
  final _text = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _page.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final page = int.parse(_page.text.trim());
    await Repos.marks.addNote(
      userId: Session.instance.userId,
      bookId: widget.bookId,
      chapter: BookContent.chapterOf(page),
      page: page,
      content: _text.text,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Новая заметка', style: AppTextStyles.centeredHeader),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LabeledTextField(
                label: 'Страница (1–${widget.maxPage})',
                controller: _page,
                hint: 'Номер страницы',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 5,
                validator: (v) =>
                    Validators.intInRange(v, 1, widget.maxPage, field: 'Номер страницы'),
              ),
              const SizedBox(height: 12),
              LabeledTextField(
                label: 'Текст заметки',
                controller: _text,
                hint: 'Ваши мысли о прочитанном…',
                maxLines: 4,
                maxLength: 500,
                validator: Validators.noteText,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

/// Диалог «Перейти к странице». Возвращает номер страницы или null.
Future<int?> showGoToPageDialog(BuildContext context,
    {required int current, required int maxPage}) {
  final controller = TextEditingController(text: '$current');
  final formKey = GlobalKey<FormState>();
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Перейти к странице', style: AppTextStyles.centeredHeader),
      content: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: PlainTextField(
          controller: controller,
          hint: '1–$maxPage',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 5,
          validator: (v) =>
              Validators.intInRange(v, 1, maxPage, field: 'Номер страницы'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Отмена',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(ctx).pop(int.parse(controller.text.trim()));
            }
          },
          child: const Text('Перейти'),
        ),
      ],
    ),
  );
}
