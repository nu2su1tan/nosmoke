import '../../diary/domain/craving_entry.dart';
import '../../relapse/domain/relapse.dart';

enum ChallengeKind {
  /// Дней подряд без срывов (серия сбрасывается срывом).
  noRelapseDays,

  /// Сколько раз удалось пережить тягу (записи дневника «справился»).
  cravingsOvercome,
}

class ChallengeDef {
  const ChallengeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.goal,
  });

  final String id;
  final String title;
  final String description;
  final ChallengeKind kind;
  final int goal;

  String get unit => switch (kind) {
    ChallengeKind.noRelapseDays => 'дн.',
    ChallengeKind.cravingsOvercome => 'раз',
  };
}

const challengeDefs = <ChallengeDef>[
  ChallengeDef(
    id: 'week',
    title: 'Неделя без срывов',
    description: '7 дней подряд без срывов',
    kind: ChallengeKind.noRelapseDays,
    goal: 7,
  ),
  ChallengeDef(
    id: 'two_weeks',
    title: 'Две недели без срывов',
    description: '14 дней подряд без срывов',
    kind: ChallengeKind.noRelapseDays,
    goal: 14,
  ),
  ChallengeDef(
    id: 'month',
    title: 'Месяц без срывов',
    description: '30 дней подряд без срывов',
    kind: ChallengeKind.noRelapseDays,
    goal: 30,
  ),
  ChallengeDef(
    id: 'cravings_10',
    title: '10 побед над тягой',
    description: 'Отметь в дневнике 10 раз, когда справился(ась)',
    kind: ChallengeKind.cravingsOvercome,
    goal: 10,
  ),
  ChallengeDef(
    id: 'cravings_30',
    title: '30 побед над тягой',
    description: 'Отметь в дневнике 30 раз, когда справился(ась)',
    kind: ChallengeKind.cravingsOvercome,
    goal: 30,
  ),
];

ChallengeDef? challengeById(String id) {
  for (final d in challengeDefs) {
    if (d.id == id) return d;
  }
  return null;
}

/// Челлендж, в который вступил пользователь.
class JoinedChallenge {
  const JoinedChallenge({
    required this.id,
    required this.joinedAt,
    this.completedAt,
  });

  final String id;
  final DateTime joinedAt;
  final DateTime? completedAt;

  JoinedChallenge copyWith({DateTime? completedAt}) => JoinedChallenge(
    id: id,
    joinedAt: joinedAt,
    completedAt: completedAt ?? this.completedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'joinedAt': joinedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory JoinedChallenge.fromJson(Map<String, dynamic> j) => JoinedChallenge(
    id: j['id'] as String,
    joinedAt: DateTime.parse(j['joinedAt'] as String),
    completedAt: j['completedAt'] == null
        ? null
        : DateTime.parse(j['completedAt'] as String),
  );
}

/// Текущий прогресс по челленджу (в единицах цели), не больше цели.
int challengeProgress(
  ChallengeDef def,
  DateTime joinedAt,
  List<Relapse> relapses,
  List<CravingEntry> diary,
  DateTime now,
) {
  final value = switch (def.kind) {
    ChallengeKind.noRelapseDays => () {
      var start = joinedAt;
      for (final r in relapses) {
        if (r.at.isAfter(start) && !r.at.isAfter(now)) start = r.at;
      }
      return now.isBefore(start) ? 0 : now.difference(start).inDays;
    }(),
    ChallengeKind.cravingsOvercome =>
      diary
          .where(
            (e) => e.overcame && !e.at.isBefore(joinedAt) && !e.at.isAfter(now),
          )
          .length,
  };
  return value > def.goal ? def.goal : value;
}
