/// «1500 ₸». Если валюта не задана, возвращает просто число.
String formatMoney(double v, [String currency = '']) {
  final n = v.round().toString();
  return currency.trim().isEmpty ? n : '$n ${currency.trim()}';
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String two(int n) => n.toString().padLeft(2, '0');

/// «3 д 04:15:09» / «04:15:09»
String formatDuration(Duration d, {bool withDays = true}) {
  final days = d.inDays;
  final h = d.inHours % 24;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  final hms = '${two(h)}:${two(m)}:${two(s)}';
  return withDays && days > 0 ? '$days д $hms' : hms;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Число календарных дней от [a] до [b] (по датам, без учёта времени суток).
/// В отличие от `Duration.inDays` не ломается при переводе часов (DST).
int daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

const _weekdays = [
  'понедельник',
  'вторник',
  'среда',
  'четверг',
  'пятница',
  'суббота',
  'воскресенье',
];

const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// «понедельник, 9 ноября»
String formatLongDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// «только что», «5 мин назад», «3 ч назад», «вчера», иначе дата.
String formatAgo(DateTime t, DateTime now) {
  final d = now.difference(t);
  if (d.isNegative || d.inMinutes < 1) return 'только что';
  if (d.inMinutes < 60) return '${d.inMinutes} мин назад';
  if (d.inHours < 24) return '${d.inHours} ч назад';
  if (daysBetween(t, now) == 1) return 'вчера';
  return formatDate(t);
}
