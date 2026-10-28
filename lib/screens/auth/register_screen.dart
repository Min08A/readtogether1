import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../data/repositories/auth_repository.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/validators.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/fill_scroll_view.dart';
import '../../widgets/inputs.dart';
import 'login_screen.dart';

/// Экран 3. Register — имя, email, пароль, подтверждение.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      AppNavigator.replace(context, const LoginScreen());
    }
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      AppMessages.error(context, 'Заполните все поля корректно');
      return;
    }
    setState(() => _loading = true);
    try {
      final id = await Repos.auth.register(
        name: _name.text,
        email: _email.text,
        password: _password.text,
        favoriteGenres: Session.instance.pendingGenres,
      );
      await Session.instance.login(id);
      await Session.instance.setOnboardingDone();
      if (!mounted) return;
      MainShell.currentTab.value = MainShell.home;
      AppMessages.success(context, 'Аккаунт создан. Добро пожаловать!');
      AppNavigator.resetTo(context, const MainShell());
    } on EmailTakenException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppMessages.error(context, e.toString());
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
              BackTitleHeader(title: 'Регистрация', onBack: _back),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Имя',
                        controller: _name,
                        hint: 'Как вас зовут?',
                        maxLength: 30,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        validator: Validators.name,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Электронная почта',
                        controller: _email,
                        hint: 'name@example.com',
                        maxLength: 100,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Пароль',
                        controller: _password,
                        hint: 'Создайте пароль',
                        isPassword: true,
                        maxLength: 64,
                        textInputAction: TextInputAction.next,
                        validator: Validators.newPassword,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Подтвердите пароль',
                        controller: _confirm,
                        hint: 'Повторите пароль',
                        isPassword: true,
                        maxLength: 64,
                        textInputAction: TextInputAction.done,
                        validator: (v) =>
                            Validators.confirmPassword(v, _password.text),
                        onSubmitted: (_) => _register(),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                          label: 'Создать аккаунт',
                          onPressed: _register,
                          loading: _loading),
                      const Spacer(),
                      const SizedBox(height: 24),
                      Center(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                                fontFamily: AppTextStyles.sans,
                                fontSize: 13.5,
                                color: AppColors.textSecondary),
                            children: [
                              const TextSpan(text: 'Уже есть аккаунт? '),
                              TextSpan(
                                text: 'Войти',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => AppNavigator.replace(
                                      context, const LoginScreen()),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
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
