import 'dart:convert';

import '../../../core/utils/formatters.dart';

enum QuitMode { cold, gradual }

enum Trigger {
  coffee('Кофе'),
  stress('Стресс'),
  alcohol('Алкоголь'),
  afterMeal('После еды'),
  workBreak('Перерыв на работе'),
  company('Компания'),
  boredom('Скука');

  const Trigger(this.label);
  final String label;
}

enum Motivation {
  health('Здоровье'),
  family('Семья'),
  money('Деньги'),
  sport('Спорт'),
  pregnancy('Беременность'),
  freedom('Свобода от зависимости');

  const Motivation(this.label);
  final String label;
}

class Profile {
  const Profile({
    required this.cigsPerDay,
    required this.packPrice,
    required this.cigsPerPack,
    required this.yearsSmoking,
    required this.triggers,
    required this.motivations,
    required this.motivationText,
    required this.quitMode,
    required this.quitDate,
    this.currency = '',
  });

  final int cigsPerDay;
  final double packPrice;
  final int cigsPerPack;
  final int yearsSmoking;
  final Set<Trigger> triggers;
  final Set<Motivation> motivations;
  final String motivationText;
  final QuitMode quitMode;
  final DateTime quitDate;

  /// Валюта, которую выбрал пользователь («₸», «₽», «\$»…). Пусто — не задана.
  final String currency;

  double get pricePerCig => packPrice / cigsPerPack;
  double get dailyCost => pricePerCig * cigsPerDay;
  double get monthlySavings => dailyCost * 30;
  double get yearlySavings => dailyCost * 365;

  /// Стоит ли предложить консультацию врача (НЗТ).
  bool get suggestDoctor => cigsPerDay > 20 || yearsSmoking > 10;

  /// График постепенного снижения: лимит сигарет в день по неделям.
  /// Например, 20 -> [16, 12, 8, 4, 0].
  List<int> get gradualSchedule => buildGradualSchedule(cigsPerDay);

  /// Дата, с которой лимит становится 0 (для «сразу» — дата старта).
  DateTime get fullQuitDate {
    final weeks = quitMode == QuitMode.cold ? 0 : gradualSchedule.length - 1;
    final d = _dateOnly(quitDate);
    return DateTime(d.year, d.month, d.day + weeks * 7);
  }

  /// Лимит на [day] для режима «постепенно». Для «сразу» всегда 0.
  /// До даты старта возвращает текущую норму.
  int dailyLimit(DateTime day) {
    if (quitMode == QuitMode.cold) {
      return day.isBefore(_dateOnly(quitDate)) ? cigsPerDay : 0;
    }
    final days = daysBetween(quitDate, day);
    if (days < 0) return cigsPerDay;
    final schedule = gradualSchedule;
    final week = days ~/ 7;
    return week >= schedule.length ? 0 : schedule[week];
  }

  Profile copyWith({String? currency}) => Profile(
    cigsPerDay: cigsPerDay,
    packPrice: packPrice,
    cigsPerPack: cigsPerPack,
    yearsSmoking: yearsSmoking,
    triggers: triggers,
    motivations: motivations,
    motivationText: motivationText,
    quitMode: quitMode,
    quitDate: quitDate,
    currency: currency ?? this.currency,
  );

  /// Деньги в валюте пользователя.
  String money(double v) => formatMoney(v, currency);

  Map<String, dynamic> toJson() => {
    'cigsPerDay': cigsPerDay,
    'packPrice': packPrice,
    'cigsPerPack': cigsPerPack,
    'yearsSmoking': yearsSmoking,
    'triggers': triggers.map((e) => e.name).toList(),
    'motivations': motivations.map((e) => e.name).toList(),
    'motivationText': motivationText,
    'quitMode': quitMode.name,
    'quitDate': quitDate.toIso8601String(),
    'currency': currency,
  };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    cigsPerDay: j['cigsPerDay'] as int,
    packPrice: (j['packPrice'] as num).toDouble(),
    cigsPerPack: j['cigsPerPack'] as int,
    yearsSmoking: j['yearsSmoking'] as int,
    triggers: {
      for (final n in j['triggers'] as List) Trigger.values.byName(n as String),
    },
    motivations: {
      for (final n in j['motivations'] as List)
        Motivation.values.byName(n as String),
    },
    motivationText: j['motivationText'] as String,
    quitMode: QuitMode.values.byName(j['quitMode'] as String),
    quitDate: DateTime.parse(j['quitDate'] as String),
    currency: j['currency'] as String? ?? '',
  );

  String encode() => jsonEncode(toJson());
  factory Profile.decode(String s) =>
      Profile.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Снижение за 5 равных ступеней по неделям, последняя — 0.
List<int> buildGradualSchedule(int cigsPerDay) {
  if (cigsPerDay <= 0) return [0];
  const steps = 5;
  final result = <int>[];
  for (var i = 1; i <= steps; i++) {
    final v = (cigsPerDay * (steps - i) / steps).round();
    if (result.isEmpty || v < result.last) result.add(v);
  }
  return result;
}
