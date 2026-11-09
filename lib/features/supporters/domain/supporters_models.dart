/// Человек, которого поддерживает пользователь (видит его сводку).
class SupportedOwner {
  const SupportedOwner({
    required this.ownerId,
    required this.nick,
    required this.smokeFreeDays,
    required this.daysInProgram,
    this.updatedAt,
    this.lastSosAt,
  });

  final String ownerId;
  final String nick;
  final int smokeFreeDays;
  final int daysInProgram;
  final DateTime? updatedAt;
  final DateTime? lastSosAt;

  /// Нажимал ли человек SOS в последние [window] (по умолчанию 2 часа).
  bool sosRecently(DateTime now, [Duration window = const Duration(hours: 2)]) {
    final t = lastSosAt;
    return t != null && now.difference(t) <= window && !t.isAfter(now);
  }

  factory SupportedOwner.fromJson(Map<String, dynamic> j) {
    DateTime? d(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String).toLocal();
    return SupportedOwner(
      ownerId: j['ownerId'] as String,
      nick: (j['nick'] as String?) ?? 'Аноним',
      smokeFreeDays: j['smokeFreeDays'] as int,
      daysInProgram: j['daysInProgram'] as int,
      updatedAt: d('updatedAt'),
      lastSosAt: d('lastSosAt'),
    );
  }
}

/// Близкий, который поддерживает пользователя.
class SupporterInfo {
  const SupporterInfo({
    required this.supporterId,
    required this.nick,
    required this.since,
  });

  final String supporterId;
  final String nick;
  final DateTime since;

  factory SupporterInfo.fromJson(Map<String, dynamic> j) => SupporterInfo(
    supporterId: j['supporterId'] as String,
    nick: (j['nick'] as String?) ?? 'Аноним',
    since: DateTime.parse(j['since'] as String).toLocal(),
  );
}

class CheerMessage {
  const CheerMessage({
    required this.id,
    required this.nick,
    required this.text,
    required this.at,
  });

  final String id;
  final String nick;
  final String text;
  final DateTime at;

  factory CheerMessage.fromJson(Map<String, dynamic> j) => CheerMessage(
    id: j['id'] as String,
    nick: j['nick'] as String,
    text: j['text'] as String,
    at: DateTime.parse(j['at'] as String),
  );
}

/// Что именно уходит на сервер: только три числа, без денег, срывов и дневника.
class ProgressSummary {
  const ProgressSummary({
    required this.smokeFreeDays,
    required this.daysInProgram,
    required this.cigsAvoided,
  });

  final int smokeFreeDays;
  final int daysInProgram;
  final int cigsAvoided;

  Map<String, int> toJson() => {
    'smokeFreeDays': smokeFreeDays,
    'daysInProgram': daysInProgram,
    'cigsAvoided': cigsAvoided,
  };

  @override
  bool operator ==(Object other) =>
      other is ProgressSummary &&
      other.smokeFreeDays == smokeFreeDays &&
      other.daysInProgram == daysInProgram &&
      other.cigsAvoided == cigsAvoided;

  @override
  int get hashCode => Object.hash(smokeFreeDays, daysInProgram, cigsAvoided);
}

/// Быстрые фразы поддержки.
const cheerPresets = [
  'Ты молодец!',
  'Я в тебя верю',
  'Горжусь тобой',
  'Держись, тяга пройдёт',
  'Позвони мне, если тяжело',
];

String supportErrorText(String code) => switch (code) {
  'invalid_code' => 'Код не найден или уже использован.',
  'expired' => 'Срок действия кода истёк. Попроси новый.',
  'own_code' => 'Это твой собственный код.',
  'already_linked' => 'Вы уже связаны.',
  'too_many_supporters' => 'У этого человека уже максимум близких.',
  'rate_limited' => 'Слишком часто. Подожди немного.',
  'network' || 'timeout' => 'Нет связи с сервером.',
  _ => 'Что-то пошло не так. Попробуй ещё раз.',
};
