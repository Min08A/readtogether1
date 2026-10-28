import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Круглый аватар с первой буквой имени.
class LetterAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double? fontSize;
  final bool whiteBorder;

  const LetterAvatar({
    super.key,
    required this.name,
    this.size = 32,
    this.fontSize,
    this.whiteBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final letter = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.chip,
        shape: BoxShape.circle,
        border: whiteBorder
            ? Border.all(color: Colors.white, width: size > 60 ? 3 : 1.5)
            : null,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: AppTextStyles.sans,
          fontSize: fontSize ?? size * 0.42,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Ряд перекрывающихся аватаров («Читают: 3 друга»).
class AvatarStack extends StatelessWidget {
  final List<String> names;
  final double size;

  const AvatarStack({super.key, required this.names, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final shown = names.take(4).toList();
    return SizedBox(
      width: shown.isEmpty ? 0.0 : size + (shown.length - 1) * size * 0.7,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * size * 0.7,
              child: LetterAvatar(
                  name: shown[i], size: size, fontSize: 12, whiteBorder: true),
            ),
        ],
      ),
    );
  }
}

/// Обложка книги: картинка из assets или сгенерированная обложка
/// (для загруженных пользователем книг без обложки).
class BookCover extends StatelessWidget {
  final Book book;
  final double width;
  final double height;
  final double radius;
  final bool shadow;

  const BookCover({
    super.key,
    required this.book,
    required this.width,
    required this.height,
    this.radius = 4,
    this.shadow = false,
  });

  static const _palette = [
    Color(0xFF2C3A47),
    Color(0xFF7A4E3B),
    Color(0xFF4E8C6F),
    Color(0xFF8A6D3B),
    Color(0xFF5B5F97),
    Color(0xFFC86B5D),
  ];

  @override
  Widget build(BuildContext context) {
    final cover = book.coverUrl;
    final Widget content;
    if (cover != null && cover.startsWith('assets/')) {
      content = Image.asset(
        cover,
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _generated(),
      );
    } else {
      content = _generated();
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? const [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 10,
                    offset: Offset(0, 4)),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }

  Widget _generated() {
    final color = _palette[book.id % _palette.length];
    final small = width < 70;
    return Container(
      width: width,
      height: height,
      color: color,
      padding: EdgeInsets.all(small ? 4.0 : 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: small ? 3 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppTextStyles.serif,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: small ? 8 : (width / 9).clamp(10, 18).toDouble(),
              height: 1.15,
            ),
          ),
          if (!small) ...[
            const SizedBox(height: 6),
            Container(width: 24, height: 1, color: const Color(0x99FFFFFF)),
            const SizedBox(height: 6),
            Text(
              book.author,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTextStyles.sans,
                color: const Color(0xDDFFFFFF),
                fontSize: (width / 14).clamp(7, 12).toDouble(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Тонкая полоса прогресса чтения.
class ProgressLine extends StatelessWidget {
  final double value;
  final double height;
  final Color color;
  final Color track;

  const ProgressLine({
    super.key,
    required this.value,
    this.height = 4,
    this.color = AppColors.primary,
    this.track = AppColors.chip,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Подпись раздела заглавными буквами с необязательным действием справа.
class SectionLabel extends StatelessWidget {
  final String text;
  final String? actionText;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  const SectionLabel(
    this.text, {
    super.key,
    this.actionText,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
              child: Text(text.toUpperCase(), style: AppTextStyles.sectionLabel)),
          if (actionText != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(actionText!,
                    style: const TextStyle(
                        fontFamily: AppTextStyles.sans,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Белая карточка со скруглением и тонкой обводкой.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.onLongPress,
    this.radius = 16,
    this.color = AppColors.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Круглый индикатор выбора: залитый тёмный круг или пустое кольцо.
class RadioDot extends StatelessWidget {
  final bool selected;
  final double size;

  const RadioDot({super.key, required this.selected, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: 1.4,
        ),
      ),
    );
  }
}

/// Строка списка выбора: иконка/аватар + подпись + RadioDot справа.
class SelectableRow extends StatelessWidget {
  final Widget? leading;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showDivider;

  const SelectableRow({
    super.key,
    this.leading,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Text(label,
                  style: AppTextStyles.body.copyWith(fontSize: 15)),
            ),
            RadioDot(selected: selected),
          ],
        ),
      ),
    );
  }
}

/// Чип жанра (Onboarding, Discover).
class GenreChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const GenreChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTextStyles.sans,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Иконка-заглушка «уголок» из макетов (Onboarding, пустая библиотека).
class CornerMark extends StatelessWidget {
  final double size;
  final Color color;

  const CornerMark({super.key, this.size = 30, this.color = AppColors.primary});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _CornerPainter(color),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final r = size.width * 0.18;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter old) => old.color != color;
}

/// Пустое состояние списка.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: AppColors.chip, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.textSecondary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: AppTextStyles.itemTitle.copyWith(fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Плитка со значением и подписью (Профиль, Статистика).
class StatTile extends StatelessWidget {
  final String value;
  final String label;

  const StatTile({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontFamily: AppTextStyles.sans,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                  fontFamily: AppTextStyles.sans,
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.25)),
        ],
      ),
    );
  }
}

/// Индикатор загрузки по центру.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));
}

/// Шапка экрана: кнопка «назад» + заголовок слева (Регистрация, Профиль…).
class BackTitleHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Color backBackground;
  final Widget? trailing;
  final TextStyle? style;

  const BackTitleHeader({
    super.key,
    required this.title,
    this.onBack,
    this.backBackground = AppColors.chip,
    this.trailing,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _BackButtonCircle(
              onBack: onBack ?? () => Navigator.of(context).maybePop(),
              background: backBackground),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style ?? AppTextStyles.headerTitle),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _BackButtonCircle extends StatelessWidget {
  final VoidCallback onBack;
  final Color background;
  const _BackButtonCircle({required this.onBack, required this.background});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onBack,
        child: const SizedBox(
          width: 32,
          height: 32,
          child: Icon(Icons.arrow_back, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Шапка с центрированным заголовком и стрелкой в круге слева
/// (Создать Reading Room, Reading Room, Book Details).
class CenteredHeader extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final IconData leadingIcon;
  final VoidCallback? onLeading;
  final Widget? trailing;
  final bool whiteCircle;

  const CenteredHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.leadingIcon = Icons.arrow_circle_left_outlined,
    this.onLeading,
    this.trailing,
    this.whiteCircle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SizedBox(
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: titleWidget ??
                  Text(title ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.centeredHeader),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: whiteCircle ? AppColors.surface : Colors.transparent,
                shape: CircleBorder(
                  side: whiteCircle
                      ? const BorderSide(color: AppColors.border)
                      : BorderSide.none,
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onLeading ?? () => Navigator.of(context).maybePop(),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(leadingIcon,
                        size: whiteCircle ? 22.0 : 26.0,
                        color: AppColors.textPrimary),
                  ),
                ),
              ),
            ),
            if (trailing != null)
              Align(alignment: Alignment.centerRight, child: trailing!),
          ],
        ),
      ),
    );
  }
}
