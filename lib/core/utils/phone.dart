/// Оставляет только цифры и ведущий «+». Пример: «+7 (777) 123-45-67» -> «+77771234567».
String normalizePhone(String input) {
  final trimmed = input.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

/// Номер считается допустимым, если в нём от 5 до 15 цифр.
bool isValidPhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length >= 5 && digits.length <= 15;
}
