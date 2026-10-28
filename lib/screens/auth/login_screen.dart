import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../data/seed_data.dart';
import '../../navigation/app_navigator.dart';
import '../../navigation/main_shell.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/validators.dart';
import '../../widgets/buttons.dart';
import '../../widgets/fill_scroll_view.dart';
import '../../widgets/inputs.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// Экран 2. Login — email, пароль, вход, «Забыли пароль?», регистрация.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _auth = Repos.auth;
  bool _loading = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      AppMessages.error(context, 'Проверьте правильность заполнения полей');
      return;
    }
    setState(() => _loading = true);
    final existing = await _auth.findByEmail(_email.text);
    final user = existing == null
        ? null
        : await _auth.login(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (existing == null) {
      AppMessages.error(context, 'Аккаунт с таким email не найден');
      return;
    }
    if (user == null) {
      AppMessages.error(context, 'Неверный пароль. Попробуйте ещё раз');
      return;
    }
    await Session.instance.login(user.id);
    await Session.instance.setOnboardingDone();
    if (!mounted) return;
    MainShell.currentTab.value = MainShell.home;
    AppMessages.success(context, 'С возвращением, ${user.name}!');
    AppNavigator.resetTo(context, const MainShell());
  }

  /// Долгое нажатие на логотип заполняет демо-аккаунт (для защиты работы).
  void _fillDemo() {
    _email.text = SeedData.demoEmail;
    _password.text = SeedData.demoPassword;
    AppMessages.info(context, 'Заполнены данные демо-аккаунта');
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
            children: [
              const SizedBox(height: 50),
              GestureDetector(
                onLongPress: _fillDemo,
                child: const Text('ReadTogether',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.logoItalic),
              ),
              const SizedBox(height: 2),
              const Text(
                'Добро пожаловать!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTextStyles.sans,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 30),
              LabeledTextField(
                label: 'Электронная почта',
                controller: _email,
                hint: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                validator: Validators.email,
              ),
              const SizedBox(height: 18),
              LabeledTextField(
                label: 'Пароль',
                controller: _password,
                hint: 'Введите пароль',
                isPassword: true,
                maxLength: 64,
                textInputAction: TextInputAction.done,
                validator: Validators.loginPassword,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Войти', onPressed: _login, loading: _loading),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Забыли пароль?',
                onPressed: () =>
                    AppNavigator.push(context, const ForgotPasswordScreen()),
              ),
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
                      const TextSpan(text: 'Нет аккаунта? '),
                      TextSpan(
                        text: 'Зарегистрироваться',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => AppNavigator.replace(
                              context, const RegisterScreen()),
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
    );
  }
}
