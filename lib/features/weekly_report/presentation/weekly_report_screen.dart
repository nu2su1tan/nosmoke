import 'package:flutter/cupertino.dart';

import '../../../app/session.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_progress_bar.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_type.dart';
import '../../../core/ui/large_title_page.dart';
import '../../../core/utils/formatters.dart';
import '../../plan/domain/entitlements.dart';
import '../../plan/presentation/paywall_screen.dart';
import '../domain/weekly_report.dart';

Future<void> openWeeklyReport(BuildContext context, Session session) async {
  if (!await requirePremium(
    context,
    session.plan,
    PremiumFeature.weeklyReport,
  )) {
    return;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => WeeklyReportScreen(session: session),
    ),
  );
}

class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key, required this.session, this.now});

  final Session session;

  /// Для тестов: фиксированное «сейчас».
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = context.type;
    final c = context.colors;
    final r = buildWeeklyReport(
      s.profile,
      s.relapses.items,
      s.diary.entries,
      s.smoked.items,
      now ?? DateTime.now(),
    );
    final range = '${formatDate(r.from)} — ${formatDate(r.to)}';
    return ModalPage(
      title: 'Итоги недели',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text(range, style: t.label),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${r.cleanDays}',
                key: const Key('report-clean-days'),
                style: t.display.copyWith(fontSize: 96),
              ),
              Text(
                ' из ${r.daysInWindow}',
                style: t.headline.copyWith(color: c.inkSecondary),
              ),
            ],
          ),
          Text('ДНЕЙ БЕЗ СРЫВОВ', style: t.label),
          const SizedBox(height: 8),
          AppProgressBar(
            value: r.daysInWindow == 0 ? 0 : r.cleanDays / r.daysInWindow,
          ),
          AppSection(
            padding: const EdgeInsets.only(top: 28),
            children: [
              _Row('Не выкурено', '${r.cigsAvoided}'),
              _Row('Сэкономлено', s.profile.money(r.moneySaved)),
              _Row(
                'Тяга пережита',
                r.cravings == 0 ? '—' : '${r.overcame} из ${r.cravings}',
              ),
              if (r.relapses > 0) _Row('Срывов', '${r.relapses}'),
              if (r.hardestWeekdayName != null)
                _Row('Самый тяжёлый день', r.hardestWeekdayName!),
              if (r.topTrigger != null)
                _Row('Главный триггер', r.topTrigger!.label),
              if (r.topHelper != null)
                _Row('Чаще всего помогало', r.topHelper!),
            ],
          ),
          AppSection(
            padding: const EdgeInsets.only(top: 24),
            header: 'На следующую неделю',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  r.suggestion,
                  style: t.headline.copyWith(fontSize: 19),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Поделиться итогами',
            icon: CupertinoIcons.share,
            onPressed: () =>
                s.services.sharer.shareText(buildWeeklyShareText(s.profile, r)),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Text(label, style: t.body)),
          Text(value, style: t.bodyStrong),
        ],
      ),
    );
  }
}
