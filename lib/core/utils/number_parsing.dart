/// Разбирает число так, как его пишут люди: «2 000», «1 500,50», «1,5».
/// Возвращает null, если это не число.
double? parseDecimal(String input) {
  final cleaned = input.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  return double.tryParse(cleaned);
}
