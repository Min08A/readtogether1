import 'package:flutter/material.dart';

import '../models/reading_room.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_messages.dart';

/// «Огонёк» серии, как в TikTok.
/// Оранжевый — серия продлена сегодня; серый с часами — под угрозой.
class StreakFlame extends StatelessWidget {
  final StreakInfo streak;
  final double size;
  final bool showZero;
  final String? explanation;

  const StreakFlame({
    super.key,
    required this.streak,
    this.size = 16,
    this.showZero = false,
    this.explanation,
  });

  static const _activeGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFFE5452E), Color(0xFFFF9F1C), Color(0xFFFFD166)],
  );

  static const _riskGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFF8E8D8A), Color(0xFFB9B7B2)],
  );

  @override
  Widget build(BuildContext context) {
    if (!streak.isAlive && !showZero) return const SizedBox.shrink();
    final active = streak.activeToday;
    return GestureDetector(
      onTap: () => showStreakInfo(context, streak, explanation: explanation),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (rect) =>
                (active ? _activeGradient : _riskGradient).createShader(rect),
            blendMode: BlendMode.srcIn,
            child: Icon(Icons.local_fire_department_rounded,
                size: size, color: Colors.white),
          ),
          const SizedBox(width: 2),
          Text(
            '${streak.days}',
            style: TextStyle(
              fontFamily: AppTextStyles.sans,
              fontSize: size * 0.8,
              fontWeight: FontWeight.w700,
              color: active ? const Color(0xFFE5452E) : AppColors.textSecondary,
            ),
          ),
          if (streak.isAlive && !active) ...[
            const SizedBox(width: 1),
            Icon(Icons.hourglass_bottom_rounded,
                size: size * 0.7, color: AppColors.textSecondary),
          ],
        ],
      ),
    );
  }
}

/// Объяснение, как работает огонёк.
Future<void> showStreakInfo(BuildContext context, StreakInfo streak,
    {String? explanation}) {
  final status = !streak.isAlive
      ? 'Серии пока нет. Читайте каждый день, чтобы зажечь огонёк!'
      : streak.activeToday
          ? 'Сегодня серия уже продлена — так держать! 🔥'
          : 'Огонёк под угрозой ⏳ Сегодня ещё не читали — почитайте хотя бы пару страниц до конца дня, иначе серия обнулится.';
  return AppMessages.alert(
    context,
    title: '🔥 ${streak.days} ${_days(streak.days)} подряд',
    message:
        '${explanation ?? 'Огонёк показывает, сколько дней подряд продолжается серия чтения.'}\n\n$status',
  );
}

String _days(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'день';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'дня';
  return 'дней';
}

/// Плашка вместо сообщения/закладки со спойлером.
class SpoilerPlate extends StatelessWidget {
  final int chapter;
  final VoidCallback onReveal;

  const SpoilerPlate({super.key, required this.chapter, required this.onReveal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_off_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Спойлер · глава $chapter',
                    style: AppTextStyles.itemTitle.copyWith(fontSize: 13)),
                Text('Дочитайте до главы $chapter, чтобы открыть',
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          TextButton(
            onPressed: onReveal,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Показать',
                style: TextStyle(
                    fontFamily: AppTextStyles.sans,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Подтверждение раскрытия спойлера (предупреждение).
Future<bool> confirmRevealSpoiler(BuildContext context, int chapter) {
  return AppMessages.confirm(
    context,
    title: 'Показать спойлер?',
    message:
        'Сообщение относится к главе $chapter — вы её ещё не прочитали. Оно может раскрыть сюжет.',
    confirmText: 'Показать',
    cancelText: 'Не надо',
  );
}

/// Реакции под сообщением + кнопка добавления.
class ReactionBar extends StatelessWidget {
  final List<ReactionCount> reactions;
  final ValueChanged<String> onToggle;
  final VoidCallback onAdd;

  const ReactionBar({
    super.key,
    required this.reactions,
    required this.onToggle,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final r in reactions)
            _chip(
              child: Text('${r.emoji} ${r.count}',
                  style: TextStyle(
                      fontFamily: AppTextStyles.sans,
                      fontSize: 12.5,
                      fontWeight: r.mine ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.textPrimary)),
              highlighted: r.mine,
              onTap: () => onToggle(r.emoji),
            ),
          _chip(
            child: const Icon(Icons.add_reaction_outlined,
                size: 15, color: AppColors.textSecondary),
            highlighted: false,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }

  Widget _chip(
      {required Widget child,
      required bool highlighted,
      required VoidCallback onTap}) {
    return Material(
      color: highlighted ? const Color(0xFFE3E8EE) : AppColors.background,
      shape: StadiumBorder(
        side: BorderSide(
            color: highlighted ? AppColors.primary : AppColors.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: child,
        ),
      ),
    );
  }
}

/// Выбор реакции (долгое нажатие на сообщение).
Future<String?> showReactionPicker(BuildContext context, List<String> emojis) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Реакция', style: AppTextStyles.centeredHeader),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final e in emojis)
                  InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => Navigator.of(ctx).pop(e),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(e, style: const TextStyle(fontSize: 30)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Цитата из книги внутри сообщения.
class QuoteBlock extends StatelessWidget {
  final String quote;
  final int? page;

  const QuoteBlock({super.key, required this.quote, this.page});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: const BoxDecoration(
        color: AppColors.backgroundWarm,
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('«$quote»',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: AppTextStyles.serif,
                  fontStyle: FontStyle.italic,
                  fontSize: 13.5,
                  height: 1.3,
                  color: AppColors.textPrimary)),
          if (page != null)
            Text('стр. $page',
                style: AppTextStyles.caption.copyWith(fontSize: 11)),
        ],
      ),
    );
  }
}

/// Цвет и подпись темпа участника.
(String, Color) paceLabel(PaceStatus pace) => switch (pace) {
      PaceStatus.ahead => ('впереди графика', AppColors.genreGreen),
      PaceStatus.onTrack => ('по графику', AppColors.textSecondary),
      PaceStatus.behind => ('отстаёт', AppColors.genreRed),
      PaceStatus.unknown => ('', AppColors.textSecondary),
    };
