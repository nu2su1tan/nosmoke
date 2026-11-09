import '../../profile/domain/profile.dart';
import '../../progress/domain/progress.dart';

String _days(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return 'день';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return 'дня';
  return 'дней';
}

/// Текст, которым пользователь делится с близкими, чтобы получить поддержку.
String buildShareText(Profile p, ProgressSnapshot s) {
  final lines = <String>[];
  if (!s.started) {
    lines.add('Я решил(а) бросить курить и начинаю скоро. Поддержи меня!');
  } else {
    final d = s.smokeFree.inDays;
    lines.add(
      s.streakActive && d > 0
          ? 'Я не курю уже $d ${_days(d)}!'
          : 'Я бросаю курить, и я уже ${s.daysInProgram} ${_days(s.daysInProgram)} в пути!',
    );
    lines.add(
      'Не выкурено сигарет: ${s.cigsAvoided}, сэкономлено: ${p.money(s.moneySaved)}.',
    );
    lines.add('Поддержи меня, мне это важно.');
  }
  lines.add('#NoSmoke');
  return lines.join('\n');
}
