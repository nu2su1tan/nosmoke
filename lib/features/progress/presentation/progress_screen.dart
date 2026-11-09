import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../app/session.dart';
import '../../../core/ui/app_banner.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_progress_bar.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/ui/large_title_page.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/plural.dart';
import '../../../core/widgets/tick_builder.dart';
import '../../coach/presentation/coach_screen.dart';
import '../../diary/domain/diary_insights.dart';
import '../../goals/domain/savings_goal.dart';
import '../../goals/presentation/goal_sheet.dart';
import '../../health/domain/health_milestones.dart';
import '../../plan/domain/maintenance.dart';
import '../../profile/domain/profile.dart';
import '../../relapse/presentation/relapse_sheet.dart';
import '../../smoked/domain/smoked_entry.dart';
import '../../sos/presentation/sos_screen.dart';
import '../../weekly_report/presentation/weekly_report_screen.dart';
import '../domain/progress.dart';
import '../domain/week.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return ListenableBuilder(
      listenable: Listenable.merge([
        s.relapses,
        s.smoked,
        s.diary,
        s.goals,
        s.supporters,
      ]),
      builder: (context, _) => TickBuilder(
        builder: (context, now) {
          final snap = s.progressNow(now);
          final profile = s.profile;
          final t = context.type;
          final risk = upcomingRisk(s.diary.insights, now);
          final unread = s.supporters.unread;
          final inRamp = snap.started && !snap.streakActive;
          return LargeTitlePage(
            title: 'Сегодня',
            bottomPadding: 24,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Text(formatLongDate(now), style: t.label),
                    ),
                    _Hero(profile: profile, s: snap, now: now),
                    if (risk != null)
                      AppBanner(
                        accent: true,
                        title: risk.title,
                        body: risk.body,
                        onTap: () => _openSos(context),
                      ),
                    if (unread.isNotEmpty)
                      AppBanner(
                        title: '${unread.first.nick}: «${unread.first.text}»',
                        body: unread.length > 1
                            ? 'И ещё сообщений: ${unread.length - 1}'
                            : 'Сообщение от близкого',
                        onClose: s.supporters.markRead,
                      ),
                    if (isMaintenance(snap)) _MaintenanceCard(now: now),
                    if (snap.started) _Stats(s: snap, profile: profile),
                    if (inRamp) _TodayLimit(session: s, now: now),
                    _WeekStrip(
                      days: computeWeek(profile, s.relapses.items, now),
                    ),
                    if (snap.started && snap.streakActive)
                      _NextMilestone(s: snap),
                    if (snap.started) _GoalSection(session: s, saved: snap),
                    if (profile.motivationText.isNotEmpty)
                      AppSection(
                        header: 'Твоя причина',
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              '«${profile.motivationText}»',
                              style: t.headline,
                            ),
                          ),
                        ],
                      ),
                    AppSection(
                      header: 'Поддержка',
                      children: [
                        AppRow(
                          title: 'Поговорить с коучем',
                          subtitle: 'Подскажет, что делать прямо сейчас',
                          leading: const Icon(
                            CupertinoIcons.chat_bubble_2,
                            size: 22,
                          ),
                          trailing: const _Chevron(),
                          onTap: () => openCoach(context, s),
                        ),
                        if (snap.started)
                          AppRow(
                            title: 'Итоги недели',
                            subtitle: 'Победы, триггеры, экономия',
                            leading: const Icon(
                              CupertinoIcons.chart_bar,
                              size: 22,
                            ),
                            trailing: const _Chevron(),
                            onTap: () => openWeeklyReport(context, s),
                          ),
                      ],
                    ),
                    if (snap.started)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Center(
                          child: AppButton(
                            label: 'Я сорвался(ась)',
                            style: AppButtonStyle.text,
                            expand: false,
                            onPressed: () => showRelapseSheet(
                              context,
                              profile: profile,
                              relapses: s.relapses,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            bottom: _SosBar(onPressed: () => _openSos(context)),
          );
        },
      ),
    );
  }

  void _openSos(BuildContext context) => openSos(context, session: session);
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => Icon(
    CupertinoIcons.chevron_right,
    size: 14,
    color: context.colors.inkTertiary,
  );
}

/// Режим закрепления: 90+ дней без срывов.
class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // Совет меняется раз в день и не повторяется подряд.
    final tip =
        maintenanceTips[daysBetween(DateTime(2026), now) %
            maintenanceTips.length];
    return AppBanner(title: 'Режим закрепления · ${tip.title}', body: tip.body);
  }
}

/// «Выкурено сегодня» в режиме постепенного отказа.
class _TodayLimit extends StatelessWidget {
  const _TodayLimit({required this.session, required this.now});

  final Session session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = context.colors;
    final limit = session.profile.dailyLimit(now);
    final count = session.smoked.countOn(now);
    final state = limitState(count, limit);
    return AppSection(
      header: 'Выкурено сегодня',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$count',
                    key: const Key('smoked-count'),
                    style: t.numeral.copyWith(
                      color: state == LimitState.reached ? c.accent : c.ink,
                    ),
                  ),
                  Text(
                    ' / $limit',
                    style: t.headline.copyWith(color: c.inkSecondary),
                  ),
                  const Spacer(),
                  if (count > 0)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: () => session.smoked.undoLastOn(now),
                      child: Text('Отменить', style: t.callout),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              AppProgressBar(
                value: limit == 0 ? 1 : count / limit,
                color: state == LimitState.reached ? c.accent : null,
              ),
              const SizedBox(height: 8),
              Text(switch (state) {
                LimitState.ok => 'Всё по плану. Так держать!',
                LimitState.last =>
                  'Осталась последняя на сегодня. Попробуй оттянуть её.',
                LimitState.reached =>
                  'Лимит на сегодня закончился. Ещё одна сигарета считается срывом.',
              }, style: t.callout),
              const SizedBox(height: 12),
              AppButton(
                label: state == LimitState.reached
                    ? 'Я выкурил(а) ещё одну'
                    : 'Записать сигарету',
                style: state == LimitState.reached
                    ? AppButtonStyle.outlined
                    : AppButtonStyle.filled,
                compact: true,
                expand: false,
                onPressed: () async {
                  if (state == LimitState.reached) {
                    // Сверх лимита: это срыв, обрабатываем мягко.
                    await showRelapseSheet(
                      context,
                      profile: session.profile,
                      relapses: session.relapses,
                    );
                  } else {
                    await session.smoked.add();
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Цель накопления.
class _GoalSection extends StatelessWidget {
  const _GoalSection({required this.session, required this.saved});

  final Session session;
  final ProgressSnapshot saved;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = context.colors;
    final goal = session.goals.goal;
    final profile = session.profile;
    if (goal == null) {
      return AppSection(
        header: 'Цель',
        children: [
          AppRow(
            title: 'Поставить цель',
            subtitle: 'На что копишь? Деньги станут ближе',
            leading: const Icon(CupertinoIcons.flag, size: 22),
            trailing: const _Chevron(),
            onTap: () => showGoalSheet(context, session),
          ),
        ],
      );
    }
    final status = goalStatus(
      goal,
      saved.moneySaved,
      saved.streakActive ? profile.dailyCost : 0,
    );
    return AppSection(
      header: 'Цель',
      children: [
        AppRow(
          title: goal.title,
          trailing: const _Chevron(),
          onTap: () => showGoalSheet(context, session),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppProgressBar(
                value: status.fraction,
                color: status.reached ? c.positive : null,
              ),
              const SizedBox(height: 8),
              Text(
                status.reached
                    ? 'Цель достигнута! ${profile.money(goal.target)} накоплено.'
                    : '${profile.money(saved.moneySaved)} из ${profile.money(goal.target)}'
                          '${status.daysLeft == null ? '' : ' · осталось примерно ${status.daysLeft} ${daysWord(status.daysLeft!)}'}',
                style: t.callout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Закреплённая внизу кнопка SOS.
class _SosBar extends StatelessWidget {
  const _SosBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.hairline, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: AppButton(
          height: 48,
          label: 'Хочу курить — помогите',
          icon: CupertinoIcons.exclamationmark_circle_fill,
          style: AppButtonStyle.danger,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.profile, required this.s, required this.now});

  final Profile profile;
  final ProgressSnapshot s;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = context.type;

    late final String caption;
    late final String big;
    late final String unit;
    String? clock;
    late final String small;
    if (!s.started) {
      caption = 'До старта';
      final left = daysBetween(now, profile.quitDate);
      big = '$left';
      unit = daysWord(left);
      small = 'Старт: ${formatDate(profile.quitDate)}';
    } else if (s.streakActive) {
      caption = 'Без сигарет';
      final d = s.smokeFree.inDays;
      big = '$d';
      unit = daysWord(d);
      clock = formatDuration(s.smokeFree, withDays: false);
      small =
          'День программы: ${s.daysInProgram + 1}'
          '${s.relapseCount > 0 ? ' · срывов: ${s.relapseCount}' : ''}';
    } else {
      caption = 'Лимит на сегодня';
      final limit = profile.dailyLimit(now);
      big = '$limit';
      unit = pluralRu(limit, 'сигарета', 'сигареты', 'сигарет');
      small =
          'День программы: ${s.daysInProgram + 1}. '
          'Совсем бросаешь ${formatDate(profile.fullQuitDate)}.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: t.label),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(big, style: t.display),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                unit,
                style: t.headline.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          if (clock != null) ...[
            const SizedBox(height: 12),
            Text(
              clock,
              style: t.headline.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: context.colors.inkSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(small, style: t.callout),
        ],
      ),
    );
  }
}

/// Семь последних дней: заливка — день без срывов, красный — срыв.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});

  final List<WeekDay> days;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 1, color: c.hairline),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Semantics(
                    label:
                        '${formatLongDate(d.date)}: ${switch (d.state) {
                          DayState.clean => 'без срывов',
                          DayState.relapse => 'срыв',
                          DayState.notStarted => 'до старта',
                        }}',
                    child: Column(
                      children: [
                        Text(
                          d.letter,
                          style: t.label.copyWith(
                            color: d.isToday ? c.ink : c.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _DayDot(day: d),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day});

  final WeekDay day;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = switch (day.state) {
      DayState.clean => c.positive,
      DayState.relapse => c.accent,
      DayState.notStarted => Colors.transparent,
    };
    return Container(
      key: Key('week-${day.state.name}${day.isToday ? '-today' : ''}'),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: day.state == DayState.notStarted
            ? Border.all(color: c.hairline, width: 1.2)
            : (day.isToday ? Border.all(color: c.bg, width: 3) : null),
        boxShadow: day.isToday && day.state != DayState.notStarted
            ? [BoxShadow(color: fill, spreadRadius: 2)]
            : null,
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.s, required this.profile});

  final ProgressSnapshot s;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final life = s.lifeRegained;
    final lifeText = life.inDays >= 1
        ? '${life.inDays}д ${life.inHours % 24}ч'
        : '${life.inHours}ч ${life.inMinutes % 60}м';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        children: [
          Container(height: 1, color: c.hairline),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stat(value: profile.money(s.moneySaved), label: 'Сэкономлено'),
                VerticalDivider(width: 1, thickness: 0.5, color: c.hairline),
                _Stat(value: '${s.cigsAvoided}', label: 'Не выкурено'),
                VerticalDivider(width: 1, thickness: 0.5, color: c.hairline),
                _Stat(value: lifeText, label: 'Жизни вернулось'),
              ],
            ),
          ),
          const Hairline(),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: t.numeral.copyWith(fontSize: 26)),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: t.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextMilestone extends StatelessWidget {
  const _NextMilestone({required this.s});

  final ProgressSnapshot s;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final next = nextMilestone(s.smokeFree);
    return AppSection(
      header: next == null
          ? 'Все вехи здоровья пройдены'
          : 'Следующая веха · ${next.title}',
      children: [
        if (next != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppProgressBar(value: milestoneProgress(s.smokeFree)),
                const SizedBox(height: 12),
                Text(next.description, style: t.callout),
              ],
            ),
          ),
      ],
    );
  }
}
