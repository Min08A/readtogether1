import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Типографика приложения. Inter — основной шрифт интерфейса,
/// Lora — шрифт с засечками для логотипа, названий книг и имён.
class AppTextStyles {
  AppTextStyles._();

  static const String sans = 'Inter';
  static const String serif = 'Lora';

  /// Логотип «ReadTogether» на Onboarding.
  static const TextStyle logo = TextStyle(
    fontFamily: serif,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  /// Курсивный логотип на экране входа.
  static const TextStyle logoItalic = TextStyle(
    fontFamily: serif,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    color: AppColors.primary,
  );

  /// Крупный заголовок вкладки: «Поиск», «Моя библиотека», «Друзья».
  static const TextStyle screenTitle = TextStyle(
    fontFamily: sans,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  /// Заголовок рядом с кнопкой «назад»: «Регистрация», «Сброс пароля».
  static const TextStyle headerTitle = TextStyle(
    fontFamily: sans,
    fontSize: 23,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// Центрированный заголовок: «Создать Reading Room», «Добавить книгу».
  static const TextStyle centeredHeader = TextStyle(
    fontFamily: sans,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Подписи разделов: «ПРОДОЛЖИТЬ ЧТЕНИЕ», «ДРУЗЬЯ ЧИТАЮТ».
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  /// Подпись над полем ввода: «ЭЛЕКТРОННАЯ ПОЧТА».
  static const TextStyle fieldLabel = TextStyle(
    fontFamily: sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );

  static const TextStyle body = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    color: AppColors.textPrimary,
    height: 1.35,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    color: AppColors.textMuted,
  );

  static const TextStyle hint = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    color: AppColors.textMuted,
  );

  static const TextStyle button = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle itemTitle = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Название книги с засечками: «1984».
  static const TextStyle bookTitleSerif = TextStyle(
    fontFamily: serif,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle bookTitleSans = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle author = TextStyle(
    fontFamily: sans,
    fontSize: 12.5,
    color: AppColors.textSecondary,
  );
}
