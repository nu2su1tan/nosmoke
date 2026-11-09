import '../../../core/utils/plural.dart';
import '../../profile/domain/profile.dart';
import '../../progress/domain/progress.dart';

/// Данные, которые показывает виджет на главном экране.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String unit;
  final String subtitle;

  Map<String, String> toMap() => {
    'title': title,
    'value': value,
    'unit': unit,
    'subtitle': subtitle,
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetSnapshot &&
      other.title == title &&
      other.value == value &&
      other.unit == unit &&
      other.subtitle == subtitle;

  @override
  int get hashCode => Object.hash(title, value, unit, subtitle);
}

WidgetSnapshot buildWidgetSnapshot(
  Profile p,
  ProgressSnapshot s,
  DateTime now,
) {
  if (!s.started) {
    return const WidgetSnapshot(
      title: 'NoSmoke',
      value: '—',
      unit: '',
      subtitle: 'Скоро старт',
    );
  }
  if (s.streakActive) {
    final d = s.smokeFree.inDays;
    return WidgetSnapshot(
      title: 'Без сигарет',
      value: '$d',
      unit: daysWord(d),
      subtitle: 'Сэкономлено: ${p.money(s.moneySaved)}',
    );
  }
  final limit = p.dailyLimit(now);
  return WidgetSnapshot(
    title: 'Лимит на сегодня',
    value: '$limit',
    unit: pluralRu(limit, 'сигарета', 'сигареты', 'сигарет'),
    subtitle: 'Дней в программе: ${s.daysInProgram}',
  );
}
