import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Нижняя навигация: Главное, Библиотека, Друзья, Профиль.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (Icons.home_outlined, 'Главное'),
    (Icons.menu_book_outlined, 'Библиотека'),
    (Icons.people_outline, 'Друзья'),
    (Icons.person_outline, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _items[i].$1,
                          size: 23,
                          color: i == currentIndex
                              ? AppColors.primary
                              : AppColors.navInactive,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _items[i].$2,
                          style: TextStyle(
                            fontFamily: AppTextStyles.sans,
                            fontSize: 11,
                            fontWeight: i == currentIndex
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == currentIndex
                                ? AppColors.textPrimary
                                : AppColors.navInactive,
                          ),
                        ),
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
