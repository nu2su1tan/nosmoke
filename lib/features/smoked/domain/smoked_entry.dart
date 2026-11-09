import '../../../core/utils/formatters.dart';

/// Одна выкуренная сигарета в рамках плана постепенного отказа.
class SmokedEntry {
  const SmokedEntry({required this.at});

  final DateTime at;

  Map<String, dynamic> toJson() => {'at': at.toIso8601String()};

  factory SmokedEntry.fromJson(Map<String, dynamic> j) =>
      SmokedEntry(at: DateTime.parse(j['at'] as String));
}

/// Сколько сигарет записано за конкретный день.
int smokedOn(List<SmokedEntry> entries, DateTime day) =>
    entries.where((e) => dateOnly(e.at) == dateOnly(day)).length;

/// Состояние дневного лимита.
enum LimitState {
  /// Есть запас.
  ok,

  /// Остался последний шаг до лимита.
  last,

  /// Лимит исчерпан: следующая сигарета выйдет за план (срыв).
  reached,
}

LimitState limitState(int smoked, int limit) {
  if (smoked >= limit) return LimitState.reached;
  if (smoked == limit - 1) return LimitState.last;
  return LimitState.ok;
}
