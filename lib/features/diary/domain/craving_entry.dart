import '../../profile/domain/profile.dart';

/// Чем пользователь справлялся с тягой (быстрый выбор в SOS и дневнике).
const copingActions = [
  'Вода',
  'Прогулка',
  'Дыхание',
  'Жвачка',
  'Звонок другу',
  'Приседания',
  'Умывание',
];

class CravingEntry {
  const CravingEntry({
    required this.id,
    required this.at,
    this.trigger,
    this.intensity = 3,
    this.overcame = true,
    this.note = '',
    this.helped = '',
  });

  final String id;
  final DateTime at;
  final Trigger? trigger;

  /// Сила тяги 1..5.
  final int intensity;
  final bool overcame;
  final String note;

  /// Что помогло справиться (пусто, если не отмечено).
  final String helped;

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'trigger': trigger?.name,
    'intensity': intensity,
    'overcame': overcame,
    'note': note,
    'helped': helped,
  };

  factory CravingEntry.fromJson(Map<String, dynamic> j) {
    final t = j['trigger'] as String?;
    return CravingEntry(
      id: j['id'] as String,
      at: DateTime.parse(j['at'] as String),
      trigger: t == null ? null : Trigger.values.byName(t),
      intensity: j['intensity'] as int,
      overcame: j['overcame'] as bool,
      note: j['note'] as String? ?? '',
      helped: j['helped'] as String? ?? '',
    );
  }
}
