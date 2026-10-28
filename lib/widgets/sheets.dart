import 'package:flutter/material.dart';

import '../models/library_entry.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'common.dart';

/// Пункт списка в нижнем меню.
class SheetAction<T> {
  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;
  final String? subtitle;

  const SheetAction({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
    this.subtitle,
  });
}

/// Нижнее меню со списком действий. Возвращает выбранное значение.
Future<T?> showActionSheet<T>(
  BuildContext context, {
  String? title,
  required List<SheetAction<T>> actions,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(title, style: AppTextStyles.centeredHeader),
              ),
            for (final a in actions)
              ListTile(
                leading: a.icon == null
                    ? null
                    : Icon(a.icon,
                        color: a.destructive
                            ? AppColors.error
                            : AppColors.textPrimary),
                title: Text(
                  a.label,
                  style: AppTextStyles.body.copyWith(
                    color: a.destructive ? AppColors.error : AppColors.textPrimary,
                    fontWeight:
                        a.value == selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                subtitle: a.subtitle == null
                    ? null
                    : Text(a.subtitle!, style: AppTextStyles.caption),
                trailing: selected == null
                    ? null
                    : RadioDot(selected: a.value == selected),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () => Navigator.of(ctx).pop(a.value),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Выбор статуса книги в библиотеке.
Future<LibraryStatus?> showStatusPicker(BuildContext context,
    {LibraryStatus? current, String title = 'Добавить в библиотеку'}) {
  return showActionSheet<LibraryStatus>(
    context,
    title: title,
    selected: current,
    actions: const [
      SheetAction(
          value: LibraryStatus.reading,
          label: 'Читаю',
          icon: Icons.auto_stories_outlined),
      SheetAction(
          value: LibraryStatus.planned,
          label: 'В планах',
          icon: Icons.bookmark_border),
      SheetAction(
          value: LibraryStatus.finished,
          label: 'Закончено',
          icon: Icons.check_circle_outline),
    ],
  );
}
