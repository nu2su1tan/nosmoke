import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_progress_bar.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_segmented.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/ui/large_title_page.dart';
import '../../../core/widgets/tick_builder.dart';
import '../../../app/session.dart';
import '../../achievements/domain/achievements.dart';
import '../../health_data/presentation/health_metrics_tab.dart';
import '../../progress/domain/progress.dart';
import '../domain/health_milestones.dart';

/// Три раздела под сегмент-переключателем: таймлайн здоровья, достижения и
/// показатели из Apple Health / Health Connect.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key, required this.session});

  final Session session;

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return LargeTitlePage(
      title: 'Здоровье',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: AppSegmented(
              labels: const ['Таймлайн', 'Достижения', 'Показатели'],
              index: _tab,
              onChanged: (i) {
                setState(() => _tab = i);
                if (i == 2) s.healthData.refresh(s.profile.quitDate);
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _tab == 2
              ? HealthMetricsTab(session: s)
              : ListenableBuilder(
                  listenable: Listenable.merge([s.relapses, s.smoked]),
                  builder: (context, _) => TickBuilder(
                    interval: const Duration(seconds: 30),
                    builder: (context, now) {
                      final snap = s.progressNow(now);
                      return _tab == 0
                          ? _Timeline(s: snap)
                          : _Achievements(s: snap);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.s});

  final ProgressSnapshot s;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final next = nextMilestone(s.smokeFree);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!s.streakActive) ...[
            Text(
              'Таймлайн запустится, когда начнётся полный отказ.',
              style: t.callout,
            ),
            const SizedBox(height: 16),
          ],
          for (var i = 0; i < healthMilestones.length; i++)
            _TimelineItem(
              m: healthMilestones[i],
              done: s.smokeFree >= healthMilestones[i].after,
              isNext: identical(healthMilestones[i], next) && s.streakActive,
              isLast: i == healthMilestones.length - 1,
              progress: milestoneProgress(s.smokeFree),
              colors: c,
            ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.m,
    required this.done,
    required this.isNext,
    required this.isLast,
    required this.progress,
    required this.colors,
  });

  final HealthMilestone m;
  final bool done;
  final bool isNext;
  final bool isLast;
  final double progress;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  key: Key('milestone-${done ? 'done' : 'todo'}'),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? colors.ink : Colors.transparent,
                    border: Border.all(
                      color: done ? colors.ink : colors.hairline,
                      width: 1.5,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1, color: colors.hairline)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    style: t.headline.copyWith(
                      color: done || isNext ? colors.ink : colors.inkTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.description,
                    style: t.callout.copyWith(
                      color: done || isNext
                          ? colors.inkSecondary
                          : colors.inkTertiary,
                    ),
                  ),
                  if (isNext) ...[
                    const SizedBox(height: 12),
                    AppProgressBar(value: progress),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Achievements extends StatelessWidget {
  const _Achievements({required this.s});

  final ProgressSnapshot s;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final list = computeAchievements(s);
    final unlocked = list.where((a) => a.unlocked).length;
    return AppSection(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      header: 'Получено $unlocked из ${list.length}',
      children: [
        for (final a in list)
          AppRow(
            key: Key(
              'achievement-${a.id}-${a.unlocked ? 'unlocked' : 'locked'}',
            ),
            dimmed: !a.unlocked,
            leading: Icon(
              a.unlocked ? CupertinoIcons.rosette : CupertinoIcons.lock,
              size: 22,
              color: a.unlocked ? c.ink : c.inkTertiary,
            ),
            title: a.title,
            subtitle: a.description,
          ),
      ],
    );
  }
}
