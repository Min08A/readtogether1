import 'package:flutter/material.dart';

import '../../navigation/app_navigator.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../utils/genres.dart';
import '../../widgets/buttons.dart';
import '../../widgets/common.dart';
import '../../widgets/fill_scroll_view.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Экран 1. Onboarding — выбор любимых жанров, кнопка «Начать».
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Выбор по умолчанию — как на макете.
  final Set<String> _selected = {'Фикшн', 'Фантазия', 'Sci-Fi', 'Классика'};

  void _toggle(String genre) {
    setState(() {
      if (!_selected.remove(genre)) _selected.add(genre);
    });
  }

  Future<void> _start() async {
    if (_selected.isEmpty) {
      AppMessages.error(context, 'Выберите хотя бы один любимый жанр');
      return;
    }
    Session.instance.pendingGenres =
        Genres.all.where(_selected.contains).toList();
    await Session.instance.setOnboardingDone();
    if (!mounted) return;
    AppNavigator.replace(context, const RegisterScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      body: SafeArea(
        child: FillScrollView(
          children: [
            const SizedBox(height: 24),
            const Text('ReadTogether',
                textAlign: TextAlign.center, style: AppTextStyles.logo),
            const SizedBox(height: 22),
            Center(
              child: Container(
                width: 98,
                height: 98,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.only(left: 36, top: 44),
                child: const Align(
                  alignment: Alignment.topLeft,
                  child: CornerMark(size: 30),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Читайте вместе с друзьями',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTextStyles.sans,
                fontSize: 25,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Делитесь прогрессом, обсуждайте книги и создавайте читательские комнаты',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTextStyles.sans,
                fontSize: 14.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            const Text('ВЫБЕРИТЕ ЛЮБИМЫЕ ЖАНРЫ',
                style: AppTextStyles.fieldLabel),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final g in Genres.all)
                  GenreChip(
                    label: g,
                    selected: _selected.contains(g),
                    onTap: () => _toggle(g),
                  ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Начать', onPressed: _start, height: 50),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () async {
                  await Session.instance.setOnboardingDone();
                  if (!context.mounted) return;
                  AppNavigator.replace(context, const LoginScreen());
                },
                child: const Text('У меня уже есть аккаунт',
                    style: TextStyle(
                        fontFamily: AppTextStyles.sans,
                        color: AppColors.textSecondary,
                        fontSize: 13.5)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
