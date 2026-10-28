import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Информационные сообщения приложения: успех, ошибка, предупреждение,
/// информация, недоступное действие и диалоги подтверждения.
class AppMessages {
  AppMessages._();

  static void success(BuildContext context, String text) =>
      _show(context, text, AppColors.success, Icons.check_circle_outline);

  static void error(BuildContext context, String text) =>
      _show(context, text, AppColors.error, Icons.error_outline);

  static void warning(BuildContext context, String text) =>
      _show(context, text, AppColors.warning, Icons.warning_amber_rounded);

  static void info(BuildContext context, String text) =>
      _show(context, text, AppColors.info, Icons.info_outline);

  /// Сообщение при попытке выполнить недоступное действие.
  static void unavailable(BuildContext context, String text) =>
      _show(context, text, AppColors.info, Icons.block);

  static void _show(
      BuildContext context, String text, Color color, IconData icon) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontFamily: AppTextStyles.sans,
                      color: Colors.white,
                      fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  /// Диалог подтверждения. Возвращает true, если пользователь согласился.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Подтвердить',
    String cancelText = 'Отмена',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: AppTextStyles.centeredHeader.copyWith(fontSize: 18)),
        content: Text(message, style: AppTextStyles.bodySecondary),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText,
                style: const TextStyle(
                    fontFamily: AppTextStyles.sans,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? AppColors.error : AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmText,
                style: const TextStyle(
                    fontFamily: AppTextStyles.sans,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Простое информационное окно с одной кнопкой.
  static Future<void> alert(BuildContext context,
      {required String title, required String message}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: AppTextStyles.centeredHeader.copyWith(fontSize: 18)),
        content: Text(message, style: AppTextStyles.bodySecondary),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
