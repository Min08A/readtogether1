import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Основная тёмная кнопка: «Войти», «Начать», «Создать аккаунт»…
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  /// true — кнопка по ширине содержимого («Добавить», «Создать» на макетах).
  final bool compact;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.compact = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: AppTextStyles.button.copyWith(color: Colors.white)),
            ],
          );
    return SizedBox(
      width: compact ? null : double.infinity,
      height: height,
      child: Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: loading ? null : onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 18.0 : 16.0),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// Светлая кнопка с обводкой: «Добавить в библиотеку», «В библиотеку»,
/// «Загрузить книгу», «Отклонить».
class OutlinedAppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  /// true — тёмная обводка (Upload Success, пустая библиотека),
  /// false — светлая обводка (Book Details, Room Invite).
  final bool darkBorder;
  final double height;

  const OutlinedAppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.darkBorder = false,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: darkBorder ? Colors.transparent : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: darkBorder ? AppColors.primary : AppColors.border,
            width: darkBorder ? 1.4 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Center(
            child: Text(label,
                style:
                    AppTextStyles.button.copyWith(color: AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}

/// Маленькая кнопка внутри карточек: «Принять», «Отклонить», «Добавить»,
/// «Отправлено», «Редактировать».
enum SmallButtonStyle { filled, soft, outlined, disabled, white }

class SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final SmallButtonStyle style;
  final double height;
  final double fontSize;

  const SmallButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = SmallButtonStyle.filled,
    this.height = 28,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.primary;
    Color fg = Colors.white;
    BorderSide side = BorderSide.none;
    switch (style) {
      case SmallButtonStyle.filled:
        bg = AppColors.primary;
        fg = Colors.white;
      case SmallButtonStyle.soft:
        bg = AppColors.chip;
        fg = AppColors.textPrimary;
      case SmallButtonStyle.outlined:
        bg = AppColors.surface;
        fg = AppColors.textPrimary;
        side = const BorderSide(color: AppColors.primary, width: 1.2);
      case SmallButtonStyle.disabled:
        bg = AppColors.chip;
        fg = AppColors.textSecondary;
      case SmallButtonStyle.white:
        bg = AppColors.surface;
        fg = AppColors.textPrimary;
        side = const BorderSide(color: AppColors.border);
    }
    return SizedBox(
      height: height,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(height / 3.5), side: side),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 3.5),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Text(label,
                  style: TextStyle(
                      fontFamily: AppTextStyles.sans,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: fg)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Круглая кнопка-иконка: «назад», поиск, колокольчик, настройки.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color background;
  final Color iconColor;
  final bool bordered;
  final String? tooltip;

  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 34,
    this.iconSize = 18,
    this.background = AppColors.chip,
    this.iconColor = AppColors.textPrimary,
    this.bordered = false,
    this.tooltip,
  });

  /// Кнопка «назад» в светлом круге (Регистрация, Сброс пароля).
  const CircleIconButton.back({
    super.key,
    required this.onTap,
    this.background = AppColors.chip,
    this.size = 34,
  })  : icon = Icons.arrow_back,
        iconSize = 18,
        iconColor = AppColors.textPrimary,
        bordered = false,
        tooltip = 'Назад';

  /// Кнопка «назад» в виде стрелки в круге (Book Details, Reader).
  const CircleIconButton.backOutlined({
    super.key,
    required this.onTap,
    this.background = Colors.transparent,
    this.size = 34,
  })  : icon = Icons.arrow_circle_left_outlined,
        iconSize = 26,
        iconColor = AppColors.textPrimary,
        bordered = false,
        tooltip = 'Назад';

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: background,
      shape: CircleBorder(
        side: bordered
            ? const BorderSide(color: AppColors.border)
            : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
