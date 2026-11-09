import '../../../core/utils/plural.dart';
import 'coach_models.dart';

const crisisReply =
    'Мне очень жаль, что тебе сейчас так тяжело. Это важнее, чем сигареты. '
    'Пожалуйста, поговори прямо сейчас с близким человеком или позвони в '
    'экстренную службу своей страны. Ты не один(а), и помощь есть.';

final _crisis = RegExp(
  r'(суицид|самоубий|покончить с собой|убить себя|не хочу жить|навредить себе|причинить себе вред)',
  caseSensitive: false,
);

/// Сообщения о кризисе обрабатываются без модели и без сети.
bool isCrisisMessage(String text) => _crisis.hasMatch(text);

enum CoachIntent {
  crisis,
  relapse,
  craving,
  stress,
  sleep,
  alcohol,
  weight,
  medical,
  thanks,
  other,
}

CoachIntent detectIntent(String text) {
  final t = text.toLowerCase();
  bool has(List<String> words) => words.any(t.contains);
  if (isCrisisMessage(t)) return CoachIntent.crisis;
  if (has(['сорвал', 'закурил', 'выкурил', 'курнул'])) {
    return CoachIntent.relapse;
  }
  if (has(['тянет', 'тяга', 'хочу курить', 'хочется курить', 'хочу сигарет'])) {
    return CoachIntent.craving;
  }
  if (has(['стресс', 'нервн', 'тревог', 'злюсь', 'переживаю'])) {
    return CoachIntent.stress;
  }
  if (has(['уснуть', 'сон', 'бессонн', 'не сплю'])) return CoachIntent.sleep;
  if (has(['алкогол', 'пиво', 'вино', 'выпил', 'пью'])) {
    return CoachIntent.alcohol;
  }
  if (has(['вес', 'поправ', 'аппетит', 'толст'])) return CoachIntent.weight;
  if (has(['лекарств', 'пластыр', 'таблетк', 'никотинозамест', 'врач'])) {
    return CoachIntent.medical;
  }
  if (has(['спасибо', 'благодар'])) return CoachIntent.thanks;
  return CoachIntent.other;
}

/// Офлайн-коуч: работает без сети и ключей. Ответы составляются из данных
/// пользователя по понятным правилам; это не ИИ и не медицинский совет.
class LocalCoach {
  const LocalCoach();

  String reply(String userText, CoachContext c) {
    switch (detectIntent(userText)) {
      case CoachIntent.crisis:
        return crisisReply;
      case CoachIntent.relapse:
        return _relapse(c);
      case CoachIntent.craving:
        return _craving(c);
      case CoachIntent.stress:
        return 'Стресс — самый частый повод закурить. Дай себе три минуты: '
            'вдох на 4 счёта, выдох на 6, десять раз. Потом выпей воды и '
            'выйди на воздух.${_helper(c, 'Раньше тебе помогало')}';
      case CoachIntent.sleep:
        return 'Сон может ухудшиться на первой-второй неделе, потом он '
            'выравнивается. Не пей кофе после обеда, выходи на вечернюю '
            'прогулку и ложись в одно и то же время. Если бессонница '
            'затягивается, обсуди это с врачом.';
      case CoachIntent.alcohol:
        return 'Алкоголь — один из самых сильных триггеров. Первые недели '
            'лучше избегать его или держать план: заранее реши, что будешь '
            'делать, когда захочется закурить, и не оставайся у курящей '
            'компании.';
      case CoachIntent.weight:
        return 'Небольшая прибавка веса бывает, но она проходит, а вред от '
            'курения остаётся. Замени перекур прогулкой, держи под рукой '
            'овощи и воду. Это не причина возвращаться к сигаретам.';
      case CoachIntent.medical:
        return 'Про никотинзаместительную терапию и лекарства лучше '
            'поговорить с врачом: он подберёт безопасный вариант. Я не врач '
            'и не могу назначать препараты.';
      case CoachIntent.thanks:
        return 'Рад(а) помочь. Ты делаешь важное дело. Я рядом, если снова '
            'станет тяжело.';
      case CoachIntent.other:
        return 'Расскажи, что сейчас происходит: тянет курить, был срыв или '
            'просто тяжёлый день? Выбери подсказку ниже или напиши своими '
            'словами. Ты уже ${c.smokeFreeDays > 0 ? '${c.smokeFreeDays} ${daysWord(c.smokeFreeDays)} без сигарет' : 'в пути ${c.daysInProgram} ${daysWord(c.daysInProgram)}'}.';
    }
  }

  String _craving(CoachContext c) {
    final parts = <String>[
      'Тяга длится 3–5 минут, а потом ослабевает. Давай переждём её вместе.',
      '1) Сделай 10 медленных вдохов: на 4 счёта вдох, на 6 выдох.',
      '2) Выпей стакан воды маленькими глотками.',
    ];
    final h = _helper(c, '3) В прошлые разы помогало');
    parts.add(h.isEmpty ? '3) Займи руки и выйди из комнаты.' : h.trim());
    if (c.motivation != null) {
      parts.add('Помни, зачем ты это делаешь: ${c.motivation}.');
    }
    if (c.smokeFreeDays > 0) {
      parts.add(
        'Ты уже ${c.smokeFreeDays} ${daysWord(c.smokeFreeDays)} без сигарет. '
        'Не обнуляй это ради одной тяги.',
      );
    }
    return parts.join('\n');
  }

  String _relapse(CoachContext c) {
    return 'Спасибо, что написал(а) об этом честно. Срыв — не провал и не '
        'конец пути: ты не обнулил(а) всё, что сделал(а) '
        '(${c.daysInProgram} ${daysWord(c.daysInProgram)} в программе). '
        'Выброси оставшиеся сигареты, запиши в дневник, что спровоцировало '
        'срыв, и продолжай с сегодняшнего дня.'
        '${c.topTrigger == null ? '' : ' Твой главный триггер: ${c.topTrigger!.label.toLowerCase()}. Подготовь на него замену.'}';
  }

  String _helper(CoachContext c, String prefix) =>
      c.topHelper == null ? '' : ' $prefix: ${c.topHelper!.toLowerCase()}.';
}
