import 'package:flutter/cupertino.dart';

import '../../../app/session.dart';
import '../../../core/ui/app_banner.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_colors.dart';
import '../../../core/ui/app_section.dart';
import '../../../core/ui/app_type.dart';
import '../../plan/domain/entitlements.dart';
import '../../plan/presentation/paywall_screen.dart';
import '../data/health_source.dart';

/// Вкладка «Показатели»: реальные изменения пульса покоя и активности.
class HealthMetricsTab extends StatelessWidget {
  const HealthMetricsTab({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final t = context.type;
    return ListenableBuilder(
      listenable: Listenable.merge([s.healthData, s.plan]),
      builder: (context, _) {
        final h = s.healthData;
        if (!s.plan.can(PremiumFeature.healthMetrics)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppBanner(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                title: 'Показатели здоровья в NoSmoke+',
                body:
                    'Смотри, как менялся твой пульс покоя и активность после отказа от курения.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: AppButton(
                  label: 'Подробнее',
                  style: AppButtonStyle.outlined,
                  compact: true,
                  expand: false,
                  onPressed: () => requirePremium(
                    context,
                    s.plan,
                    PremiumFeature.healthMetrics,
                  ),
                ),
              ),
            ],
          );
        }
        if (!h.connected) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Покажем реальный прогресс', style: t.headline),
                const SizedBox(height: 8),
                Text(
                  'Подключи Apple Health или Health Connect: мы только читаем '
                  'пульс покоя и шаги и сравниваем период до отказа с последними '
                  'двумя неделями. Данные остаются на устройстве.',
                  style: t.callout,
                ),
                if (h.access == HealthAccess.denied) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Доступ не выдан. Разреши чтение в настройках здоровья.',
                    style: t.caption.copyWith(color: context.colors.accent),
                  ),
                ],
                if (h.access == HealthAccess.unavailable) ...[
                  const SizedBox(height: 12),
                  Text(
                    'На этом устройстве данные о здоровье недоступны.',
                    style: t.caption.copyWith(color: context.colors.accent),
                  ),
                ],
                const SizedBox(height: 16),
                AppButton(
                  key: const Key('health-connect'),
                  label: 'Подключить здоровье',
                  icon: CupertinoIcons.heart_fill,
                  onPressed: () => h.connect(s.profile.quitDate),
                ),
              ],
            ),
          );
        }
        if (h.loading && h.trend.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        final tr = h.trend;
        if (tr.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Text(
              'Пока мало данных. Нужно хотя бы 3 дня с пульсом или шагами '
              'после отказа от курения.',
              style: t.callout,
            ),
          );
        }
        return AppSection(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          header: 'За последние 2 недели',
          footer:
              'Сравнение с двумя неделями до отказа. Это не медицинская оценка.',
          children: [
            if (tr.hasHeartRate)
              _Metric(
                title: 'Пульс покоя',
                value: '${tr.restingHrAfter!.round()} уд/мин',
                delta: tr.heartRateDelta,
                unit: 'уд/мин',
                lowerIsBetter: true,
              ),
            if (tr.hasSteps)
              _Metric(
                title: 'Шагов в день',
                value: '${tr.stepsAfter!.round()}',
                delta: tr.stepsDelta,
                unit: '',
                lowerIsBetter: false,
              ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.title,
    required this.value,
    required this.delta,
    required this.unit,
    required this.lowerIsBetter,
  });

  final String title;
  final String value;
  final double? delta;
  final String unit;
  final bool lowerIsBetter;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = context.colors;
    final d = delta;
    final good = d == null ? null : (lowerIsBetter ? d < 0 : d > 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.label),
          const SizedBox(height: 8),
          Text(value, style: t.numeral),
          if (d != null && d.abs() >= 1) ...[
            const SizedBox(height: 6),
            Text(
              '${d > 0 ? '+' : '−'}${d.abs().round()}${unit.isEmpty ? '' : ' $unit'} к периоду до отказа',
              style: t.callout.copyWith(
                color: good == true ? c.ink : c.inkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
