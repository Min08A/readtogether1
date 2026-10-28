import 'package:flutter/material.dart';

import '../../data/repos.dart';
import '../../data/repositories/stats_repository.dart';
import '../../services/data_bus.dart';
import '../../services/session.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_messages.dart';
import '../../widgets/common.dart';

/// Экран 22. Reading Stats — количество книг, страниц, дней подряд,
/// график чтения по дням, любимые жанры, достижения.
class ReadingStatsScreen extends StatefulWidget {
  const ReadingStatsScreen({super.key});

  @override
  State<ReadingStatsScreen> createState() => _ReadingStatsScreenState();
}

class _ReadingStatsScreenState extends State<ReadingStatsScreen>
    with ReloadOnDataChange {
  ReadingStats? _stats;

  static const _genreColors = [
    AppColors.genreRed,
    AppColors.primary,
    AppColors.genreGreen,
    AppColors.genreGrey,
  ];
  static const _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Future<void> load() async {
    final stats = await Repos.stats.load(Session.instance.userId);
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  String _thousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      body: SafeArea(
        child: Column(
          children: [
            BackTitleHeader(
              title: 'Статистика чтения',
              backBackground: AppColors.surface,
              style: AppTextStyles.headerTitle.copyWith(color: AppColors.primary),
            ),
            Expanded(
              child: s == null
                  ? const LoadingView()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: StatTile(
                                    value: '${s.booksFinished}',
                                    label: 'книги\nпрочитано')),
                            const SizedBox(width: 10),
                            Expanded(
                                child: StatTile(
                                    value: _thousands(s.pagesRead),
                                    label: 'страниц')),
                            const SizedBox(width: 10),
                            Expanded(
                                child: StatTile(
                                    value: '${s.streakDays}',
                                    label: 'дней подряд')),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _chartCard(s),
                        const SizedBox(height: 18),
                        _genresCard(s),
                        const SizedBox(height: 22),
                        const SectionLabel('Достижения'),
                        const SizedBox(height: 10),
                        _achievement(
                          icon: Icons.menu_book_outlined,
                          title: 'Книжный червь',
                          subtitle: 'Прочитано более 10 книг',
                          progress: s.booksFinished,
                          goal: 11,
                        ),
                        const SizedBox(height: 10),
                        _achievement(
                          icon: Icons.local_fire_department_outlined,
                          title: 'Марафонец',
                          subtitle: 'Чтение 7 дней подряд',
                          progress: s.streakDays,
                          goal: 7,
                        ),
                        const SizedBox(height: 10),
                        _achievement(
                          icon: Icons.groups_outlined,
                          title: 'Социальный читатель',
                          subtitle: 'Состоите в 5 комнатах обсуждения',
                          progress: s.roomsJoined,
                          goal: 5,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartCard(ReadingStats s) {
    final maxValue = s.weekdaySessions.fold<int>(0, (a, b) => b > a ? b : a);
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ЧТЕНИЕ ЗА ПОСЛЕДНИЙ МЕСЯЦ', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Tooltip(
                      message: '${_days[i]}: ${s.weekdaySessions[i]} сессий',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 14,
                            height: maxValue == 0
                                ? 4.0
                                : 4 + 96 * s.weekdaySessions[i] / maxValue,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(_days[i],
                              style: AppTextStyles.caption.copyWith(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _genresCard(ReadingStats s) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ЛЮБИМЫЕ ЖАНРЫ', style: AppTextStyles.sectionLabel),
          const SizedBox(height: 14),
          if (s.genres.isEmpty)
            const Text('Добавьте книги в библиотеку, чтобы увидеть статистику',
                style: AppTextStyles.bodySecondary),
          for (var i = 0; i < s.genres.length; i++) ...[
            Row(
              children: [
                Expanded(
                    child: Text(s.genres[i].genre,
                        style: AppTextStyles.body.copyWith(fontSize: 14))),
                Text('${s.genres[i].percent}%',
                    style: const TextStyle(
                        fontFamily: AppTextStyles.sans,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ProgressLine(
              value: s.genres[i].percent / 100,
              height: 6,
              color: _genreColors[i % _genreColors.length],
            ),
            if (i != s.genres.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _achievement({
    required IconData icon,
    required String title,
    required String subtitle,
    required int progress,
    required int goal,
  }) {
    final unlocked = progress >= goal;
    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: AppCard(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        onTap: () => unlocked
            ? AppMessages.success(context, 'Достижение «$title» получено!')
            : AppMessages.info(context,
                '«$title»: прогресс ${progress.clamp(0, goal)} из $goal'),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                  color: AppColors.chip, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.itemTitle.copyWith(fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (!unlocked)
              Text('${progress.clamp(0, goal)}/$goal',
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600))
            else
              const Icon(Icons.verified, size: 18, color: AppColors.genreGreen),
          ],
        ),
      ),
    );
  }
}
