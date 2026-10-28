import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../data/repositories/auth_repository.dart';
import '../../models/app_user.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/validators.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';

/// Экран 19. Edit Profile — имя, email, био, «Сохранить».
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _bio = TextEditingController();
  final _auth = Repos.auth;
  AppUser? _user;
  bool _saving = false;
  bool _allowPop = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _auth.getUser(Session.instance.userId).then((u) {
      if (!mounted || u == null) return;
      setState(() {
        _user = u;
        _name.text = u.name;
        _email.text = u.email;
        _bio.text = u.bio ?? '';
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _bio.dispose();
    super.dispose();
  }

  bool get _dirty {
    final u = _user;
    if (u == null) return false;
    return _name.text.trim() != u.name ||
        _email.text.trim().toLowerCase() != u.email ||
        _bio.text.trim() != (u.bio ?? '');
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_dirty) {
      AppMessages.info(context, 'Изменений нет — сохранять нечего');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      AppMessages.error(context, 'Исправьте ошибки в полях профиля');
      return;
    }
    setState(() => _saving = true);
    try {
      await _auth.updateProfile(
        userId: Session.instance.userId,
        name: _name.text,
        email: _email.text,
        bio: _bio.text,
      );
      if (!mounted) return;
      AppMessages.success(context, 'Профиль сохранён');
      _close();
    } on EmailTakenException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppMessages.error(context, e.toString());
    }
  }

  Future<void> _onPopBlocked() async {
    final leave = await AppMessages.confirm(
      context,
      title: 'Отменить изменения?',
      message: 'Несохранённые изменения профиля будут потеряны.',
      confirmText: 'Выйти без сохранения',
      cancelText: 'Остаться',
      destructive: true,
    );
    if (leave && mounted) _close();
  }

  /// Закрыть экран, сняв блокировку PopScope.
  void _close() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          AppMessages.warning(context, 'Есть несохранённые изменения');
          _onPopBlocked();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundWarm,
        body: SafeArea(
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            onChanged: () => setState(() {}),
            child: Column(
              children: [
                BackTitleHeader(
                  title: 'Профиль',
                  style: AppTextStyles.headerTitle
                      .copyWith(color: AppColors.primary),
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    children: [
                      Center(
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: Stack(
                            children: [
                              LetterAvatar(
                                name: _name.text.isEmpty ? '?' : _name.text,
                                size: 98,
                                fontSize: 32,
                                whiteBorder: true,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 4,
                                child: GestureDetector(
                                  onTap: () => AppMessages.unavailable(context,
                                      'Загрузка фото профиля будет доступна после подключения файлового хранилища'),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2.5),
                                    ),
                                    child: const Icon(Icons.photo_camera,
                                        size: 13, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      LabeledTextField(
                        label: 'Имя',
                        controller: _name,
                        maxLength: 30,
                        textCapitalization: TextCapitalization.words,
                        validator: Validators.name,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Email',
                        controller: _email,
                        maxLength: 100,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Био',
                        controller: _bio,
                        hint: 'Расскажите о себе...',
                        maxLines: 4,
                        maxLength: 200,
                        validator: Validators.bio,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: PrimaryButton(
                      label: 'Сохранить', loading: _saving, onPressed: _save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
