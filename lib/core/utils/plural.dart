/// Русское склонение: pluralRu(3, 'день', 'дня', 'дней') -> 'дня'.
String pluralRu(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

String daysWord(int n) => pluralRu(n, 'день', 'дня', 'дней');
