class Relapse {
  const Relapse({required this.at, this.count = 1, this.note = ''});

  final DateTime at;
  final int count;
  final String note;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'count': count,
    'note': note,
  };

  factory Relapse.fromJson(Map<String, dynamic> j) => Relapse(
    at: DateTime.parse(j['at'] as String),
    count: j['count'] as int,
    note: j['note'] as String? ?? '',
  );
}
