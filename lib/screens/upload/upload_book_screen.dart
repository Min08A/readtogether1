import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/repos.dart';
import '../../navigation/app_navigator.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/book_text.dart';
import '../../utils/validators.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'upload_success_screen.dart';

/// Экран 23. Upload Book — выбор файла, метаданные, уровень доступа,
/// кнопка «Добавить».
class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({super.key});

  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

enum _Access {
  private('Private', 'Приват', Icons.lock_open_outlined),
  friends('Friends', 'Друзья', Icons.people_outline),
  public('Public', 'Публично', Icons.language);

  const _Access(this.dbValue, this.label, this.icon);
  final String dbValue;
  final String label;
  final IconData icon;
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  static const _maxBytes = 50 * 1024 * 1024;
  static const _formats = ['epub', 'pdf', 'txt'];

  PlatformFile? _file;
  String _title = '';
  String _author = '';
  _Access _access = _Access.friends;
  bool _saving = false;

  Future<void> _pickFile() async {
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _formats,
      );
    } catch (_) {
      if (mounted) {
        AppMessages.error(context, 'Не удалось открыть выбор файла');
      }
      return;
    }
    if (result == null || result.files.isEmpty || !mounted) return;
    final file = result.files.single;
    final ext = (file.extension ?? '').toLowerCase();
    if (!_formats.contains(ext)) {
      AppMessages.error(
          context, 'Неподдерживаемый формат .$ext. Выберите EPUB, PDF или TXT');
      return;
    }
    if (file.size > _maxBytes) {
      AppMessages.error(context,
          'Файл слишком большой (${(file.size / 1024 / 1024).toStringAsFixed(1)} МБ). Максимум — 50 МБ');
      return;
    }
    if (file.path == null) {
      AppMessages.error(context, 'Не удалось прочитать файл');
      return;
    }
    // «Извлечение метаданных»: имя файла вида «Автор - Название.ext».
    final base = p.basenameWithoutExtension(file.name).replaceAll('_', ' ');
    final parts = base.split(' - ');
    setState(() {
      _file = file;
      if (parts.length >= 2) {
        _author = parts.first.trim();
        _title = parts.sublist(1).join(' - ').trim();
      } else {
        _title = base.trim();
        _author = '';
      }
    });
    AppMessages.success(context, 'Файл выбран: ${file.name}');
    if (_author.isEmpty) {
      AppMessages.warning(
          context, 'Автор не найден в метаданных — укажите его вручную');
    }
  }

  Future<void> _editMetadata() async {
    if (_file == null) {
      AppMessages.unavailable(context, 'Сначала выберите файл книги');
      return;
    }
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _MetadataDialog(title: _title, author: _author),
    );
    if (result == null || !mounted) return;
    setState(() {
      _title = result.$1;
      _author = result.$2;
    });
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null) {
      AppMessages.error(context, 'Выберите файл книги (EPUB, PDF или TXT)');
      return;
    }
    if (Validators.bookTitle(_title) != null ||
        Validators.bookAuthor(_author) != null) {
      AppMessages.error(context,
          'Укажите название и автора книги — нажмите на карточку с метаданными');
      return;
    }
    setState(() => _saving = true);
    try {
      final format = file.extension!.toUpperCase();
      final dir = await getApplicationDocumentsDirectory();
      final booksDir = Directory(p.join(dir.path, 'books'));
      if (!await booksDir.exists()) await booksDir.create(recursive: true);
      final target = p.join(booksDir.path,
          '${DateTime.now().millisecondsSinceEpoch}_${file.name}');
      final saved = await File(file.path!).copy(target);
      final pages = await BookContent.estimatePages(saved, format);
      final bookId = await Repos.books.uploadBook(
        userId: Session.instance.userId,
        title: _title,
        author: _author,
        fileUrl: saved.path,
        fileFormat: format,
        pages: pages,
        accessLevel: _access.dbValue,
      );
      if (!mounted) return;
      AppNavigator.replace(context, UploadSuccessScreen(bookId: bookId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppMessages.error(context, 'Не удалось сохранить книгу: $e');
    }
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} КБ';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} МБ';
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const CenteredHeader(
              title: 'Добавить книгу',
              leadingIcon: Icons.cancel_outlined,
              whiteCircle: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  AppCard(
                    radius: 18,
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    onTap: _pickFile,
                    child: Column(
                      children: [
                        Icon(
                          file == null
                              ? Icons.description_outlined
                              : Icons.task_outlined,
                          size: 36,
                          color: file == null
                              ? AppColors.textSecondary
                              : AppColors.genreGreen,
                        ),
                        const SizedBox(height: 12),
                        Text(file == null ? 'Выбрать файл' : file.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: AppTextStyles.sans,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                        const SizedBox(height: 6),
                        Text(
                          file == null
                              ? 'EPUB, PDF, or TXT (max 50MB)'
                              : '${_sizeLabel(file.size)} · нажмите, чтобы заменить',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    radius: 16,
                    padding: const EdgeInsets.all(12),
                    onTap: _editMetadata,
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.chip,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.image_outlined,
                              color: AppColors.textSecondary, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file == null
                                    ? 'Обложка книги / Название / Автор'
                                    : '${_title.isEmpty ? 'Без названия' : _title} / ${_author.isEmpty ? 'Автор?' : _author}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontFamily: AppTextStyles.sans,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                file == null
                                    ? 'извлечено автоматически из метаданных файла'
                                    : 'нажмите, чтобы изменить название и автора',
                                style: AppTextStyles.caption
                                    .copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionLabel('Кто может увидеть эту книгу?'),
                  const SizedBox(height: 12),
                  AppCard(
                    radius: 14,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      children: [
                        for (final a in _Access.values)
                          SelectableRow(
                            leading: Icon(a.icon,
                                size: 21, color: AppColors.textPrimary),
                            label: a.label,
                            selected: _access == a,
                            onTap: () => setState(() => _access = a),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PrimaryButton(
                  label: 'Добавить',
                  compact: true,
                  loading: _saving,
                  onPressed: _submit,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataDialog extends StatefulWidget {
  final String title;
  final String author;
  const _MetadataDialog({required this.title, required this.author});

  @override
  State<_MetadataDialog> createState() => _MetadataDialogState();
}

class _MetadataDialogState extends State<_MetadataDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.title);
  late final _author = TextEditingController(text: widget.author);

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Данные книги', style: AppTextStyles.centeredHeader),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LabeledTextField(
                label: 'Название',
                controller: _title,
                hint: 'Название книги',
                maxLength: 100,
                validator: Validators.bookTitle,
              ),
              const SizedBox(height: 12),
              LabeledTextField(
                label: 'Автор',
                controller: _author,
                hint: 'Имя автора',
                maxLength: 60,
                validator: Validators.bookAuthor,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context)
                  .pop((_title.text.trim(), _author.text.trim()));
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
