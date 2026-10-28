import 'package:flutter/material.dart';

import '../../models/settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Доступные шрифты читалки. «Georgia» на Android заменяется Lora.
const readerFonts = ['Inter', 'Georgia', 'Lora'];

TextStyle readerFontStyle(String family) {
  switch (family) {
    case 'Georgia':
      return const TextStyle(
          fontFamily: 'Georgia', fontFamilyFallback: [AppTextStyles.serif]);
    case 'Lora':
      return const TextStyle(fontFamily: AppTextStyles.serif);
    default:
      return const TextStyle(fontFamily: AppTextStyles.sans);
  }
}

/// Цвета фона и текста для темы читалки.
(Color, Color) readerColors(ReaderTheme theme) => switch (theme) {
      ReaderTheme.light => (AppColors.readerLight, const Color(0xFF1E1E1E)),
      ReaderTheme.sepia => (AppColors.readerSepia, const Color(0xFF26231F)),
      ReaderTheme.dark => (AppColors.readerDark, AppColors.readerDarkText),
    };

/// Экран 10. Reader Settings — размер шрифта, шрифт, тема, интервал.
/// Открывается как нижняя панель поверх текста книги.
Future<void> showReaderSettingsSheet(
  BuildContext context, {
  required ReaderSettings settings,
  required ValueChanged<ReaderSettings> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: const Color(0xB3F5F1EB),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) =>
        _ReaderSettingsPanel(initial: settings, onChanged: onChanged),
  );
}

class _ReaderSettingsPanel extends StatefulWidget {
  final ReaderSettings initial;
  final ValueChanged<ReaderSettings> onChanged;

  const _ReaderSettingsPanel({required this.initial, required this.onChanged});

  @override
  State<_ReaderSettingsPanel> createState() => _ReaderSettingsPanelState();
}

class _ReaderSettingsPanelState extends State<_ReaderSettingsPanel> {
  late ReaderSettings _s = widget.initial;

  void _update(ReaderSettings s) {
    setState(() => _s = s);
    widget.onChanged(s);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Настройки чтения',
                      style: TextStyle(
                          fontFamily: AppTextStyles.sans,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                ),
                Material(
                  color: AppColors.chip,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(Icons.cancel_outlined,
                          size: 18, color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('РАЗМЕР ШРИФТА', style: AppTextStyles.fieldLabel),
            Row(
              children: [
                const Text('Aa',
                    style: TextStyle(
                        fontFamily: AppTextStyles.sans,
                        fontSize: 12,
                        color: AppColors.textSecondary)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: AppColors.chip,
                      thumbColor: AppColors.primary,
                      overlayColor: const Color(0x222C3A47),
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      min: 12,
                      max: 28,
                      divisions: 16,
                      value: _s.fontSize.toDouble().clamp(12, 28).toDouble(),
                      onChanged: (v) =>
                          _update(_s.copyWith(fontSize: v.round())),
                    ),
                  ),
                ),
                const Text('Aa',
                    style: TextStyle(
                        fontFamily: AppTextStyles.sans,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(width: 14),
                SizedBox(
                  width: 24,
                  child: Text('${_s.fontSize}',
                      style: const TextStyle(
                          fontFamily: AppTextStyles.sans,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('ШРИФТ', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 10),
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: readerFonts.contains(_s.fontFamily)
                      ? _s.fontFamily
                      : readerFonts.first,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary),
                  dropdownColor: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  items: [
                    for (final f in readerFonts)
                      DropdownMenuItem(
                        value: f,
                        child: Text(f,
                            style: readerFontStyle(f).copyWith(
                                fontSize: 16, color: AppColors.textPrimary)),
                      ),
                  ],
                  onChanged: (f) {
                    if (f != null) _update(_s.copyWith(fontFamily: f));
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text('ТЕМА', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final t in ReaderTheme.values) ...[
                  Expanded(child: _themeOption(t)),
                  if (t != ReaderTheme.values.last) const SizedBox(width: 16),
                ],
              ],
            ),
            const SizedBox(height: 22),
            const Text('МЕЖСТРОЧНЫЙ ИНТЕРВАЛ', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final v in const [1.0, 1.5, 2.0]) ...[
                  _spacingOption(v),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(ReaderTheme t) {
    final selected = _s.readerTheme == t;
    final (bg, _) = readerColors(t);
    return Material(
      color: selected ? AppColors.chip : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _update(_s.copyWith(readerTheme: t)),
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: t == ReaderTheme.dark ? AppColors.readerDark : bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border),
                ),
              ),
              const SizedBox(width: 8),
              Text(t.label,
                  style: TextStyle(
                    fontFamily: AppTextStyles.sans,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spacingOption(double v) {
    final selected = (_s.lineSpacing - v).abs() < 0.01;
    return Material(
      color: selected ? AppColors.primary : AppColors.chip,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _update(_s.copyWith(lineSpacing: v)),
        child: SizedBox(
          width: 32,
          height: 28,
          child: Center(
            child: Text(v.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: AppTextStyles.sans,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textPrimary,
                )),
          ),
        ),
      ),
    );
  }
}
