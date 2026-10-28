import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/validators.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/fill_scroll_view.dart';
import '../../widgets/inputs.dart';

/// Экран 4. Forgot Password — ввод email, отправка ссылки.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _auth = Repos.auth;
  bool _loading = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      AppMessages.error(context, 'Введите корректный email');
      return;
    }
    setState(() => _loading = true);
    final user = await _auth.findByEmail(_email.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (user == null) {
      AppMessages.error(context, 'Аккаунт с таким email не найден');
      return;
    }
    AppMessages.success(
        context, 'Ссылка для сброса пароля отправлена на ${user.email}');
    // В учебной версии нет почтового сервера: «переход по ссылке»
    // имитируется диалогом смены пароля.
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _NewPasswordDialog(email: user.email),
    );
    if (!mounted) return;
    if (changed == true) {
      AppMessages.success(context, 'Пароль изменён. Войдите с новым паролем');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: _autovalidate,
          child: FillScrollView(
            padding: EdgeInsets.zero,
            children: [
              const BackTitleHeader(title: 'Сброс пароля'),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Введите ваш email, и мы отправим вам ссылку для сброса пароля.',
                        style: TextStyle(
                          fontFamily: AppTextStyles.sans,
                          fontSize: 15,
                          height: 1.55,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      LabeledTextField(
                        label: 'Электронная почта',
                        controller: _email,
                        hint: 'name@example.com',
                        maxLength: 100,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        validator: Validators.email,
                        onSubmitted: (_) => _send(),
                      ),
                      const SizedBox(height: 28),
                      PrimaryButton(
                          label: 'Отправить ссылку',
                          onPressed: _send,
                          loading: _loading),
                      const Spacer(),
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Вернуться к входу',
                              style: TextStyle(
                                  fontFamily: AppTextStyles.sans,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Диалог установки нового пароля (имитация перехода по ссылке из письма).
class _NewPasswordDialog extends StatefulWidget {
  final String email;
  const _NewPasswordDialog({required this.email});

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await Repos.auth.resetPassword(widget.email, _password.text);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Новый пароль', style: AppTextStyles.centeredHeader),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Демо-режим: письмо не отправляется по-настоящему. Задайте новый пароль для аккаунта.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 14),
              LabeledTextField(
                label: 'Новый пароль',
                controller: _password,
                hint: 'Минимум 8 символов',
                isPassword: true,
                maxLength: 64,
                validator: Validators.newPassword,
              ),
              const SizedBox(height: 12),
              LabeledTextField(
                label: 'Повторите пароль',
                controller: _confirm,
                hint: 'Повторите пароль',
                isPassword: true,
                maxLength: 64,
                validator: (v) => Validators.confirmPassword(v, _password.text),
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
          onPressed: _save,
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
