import 'package:flutter/material.dart';

/// Цветовая палитра, снятая с макетов Figma (пипеткой по PNG-экспорту).
class AppColors {
  AppColors._();

  /// Основной тёмно-синий: кнопки, активные элементы, прогресс.
  static const Color primary = Color(0xFF2C3A47);

  /// Фон большинства экранов (Home, Login, Discover…).
  static const Color background = Color(0xFFF7F6F2);

  /// Тёплый фон (Onboarding, Upload Success, пустая библиотека, профиль).
  static const Color backgroundWarm = Color(0xFFF5F1EB);

  /// Карточки и поля ввода.
  static const Color surface = Color(0xFFFFFFFF);

  /// Обводка карточек и полей.
  static const Color border = Color(0xFFE6E4DF);

  /// Фон аватаров, чипов, трека прогресса, сегментов.
  static const Color chip = Color(0xFFEAE6DF);

  static const Color textPrimary = Color(0xFF1E1E1E);
  static const Color textSecondary = Color(0xFF7E7D7A);
  static const Color textMuted = Color(0xFF8E8D8A);
  static const Color navInactive = Color(0xFF8E8D8A);

  /// Фон читалки (тема «Сепия» по умолчанию).
  static const Color readerSepia = Color(0xFFFAF8F5);
  static const Color readerLight = Color(0xFFFFFFFF);
  static const Color readerDark = Color(0xFF1F2329);
  static const Color readerDarkText = Color(0xFFE6E3DD);

  /// Круг на экране «Книга добавлена!».
  static const Color successSoft = Color(0xFFE2ECE9);

  /// Цвета диаграммы «Любимые жанры».
  static const Color genreRed = Color(0xFFC86B5D);
  static const Color genreGreen = Color(0xFF4E8C6F);
  static const Color genreGrey = Color(0xFF858480);

  static const Color star = Color(0xFFF2A93B);

  /// Информационные сообщения.
  static const Color success = Color(0xFF3F7D5F);
  static const Color error = Color(0xFFB3403A);
  static const Color warning = Color(0xFFB7791F);
  static const Color info = Color(0xFF46535E);

  /// Затемнение под диалогом приглашения в комнату.
  static const Color dialogBarrier = Color(0x66000000);
}
