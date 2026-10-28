import 'package:flutter/material.dart';

import '../screens/friends/friends_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../widgets/app_bottom_nav.dart';

/// Главный экран с нижней навигацией (4 вкладки).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Текущая вкладка. Доступна из любого экрана, чтобы нижняя навигация
  /// на вложенных экранах (Discover, Уведомления…) могла переключать вкладки.
  static final ValueNotifier<int> currentTab = ValueNotifier<int>(0);

  static const int home = 0;
  static const int library = 1;
  static const int friends = 2;
  static const int profile = 3;

  /// Вернуться к главному экрану и открыть вкладку [index].
  static void goToTab(BuildContext context, int index) {
    currentTab.value = index;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  @override
  void initState() {
    super.initState();
    MainShell.currentTab.addListener(_onTab);
  }

  @override
  void dispose() {
    MainShell.currentTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final index = MainShell.currentTab.value;
    return PopScope(
      // Кнопка «назад» на вкладке, отличной от «Главное», возвращает на неё.
      canPop: index == MainShell.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) MainShell.currentTab.value = MainShell.home;
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: const [
            HomeScreen(),
            LibraryScreen(),
            FriendsScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: index,
          onTap: (i) => MainShell.currentTab.value = i,
        ),
      ),
    );
  }
}

/// Нижняя навигация для вложенных экранов (Discover, Уведомления, Активность,
/// Найти друзей, Профиль друга, Настройки) — как на макетах.
class NestedBottomNav extends StatelessWidget {
  final int highlighted;
  const NestedBottomNav({super.key, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return AppBottomNav(
      currentIndex: highlighted,
      onTap: (i) => MainShell.goToTab(context, i),
    );
  }
}
