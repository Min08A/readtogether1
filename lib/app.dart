import 'package:flutter/material.dart';

import 'navigation/main_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'services/session.dart';
import 'theme/app_theme.dart';

class ReadTogetherApp extends StatelessWidget {
  const ReadTogetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Session.instance;
    final Widget home;
    if (session.isLoggedIn) {
      home = const MainShell();
    } else if (!session.onboardingDone) {
      home = const OnboardingScreen();
    } else {
      home = const LoginScreen();
    }
    return MaterialApp(
      title: 'ReadTogether',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home,
    );
  }
}
