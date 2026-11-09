import 'package:flutter_test/flutter_test.dart';
import 'package:nosmoke/core/utils/formatters.dart';
import 'package:nosmoke/core/utils/phone.dart';

void main() {
  group('phone', () {
    test('normalize keeps digits and a leading plus', () {
      expect(normalizePhone('+7 (777) 123-45-67'), '+77771234567');
      expect(normalizePhone('8 777 123 45 67'), '87771234567');
      expect(normalizePhone('  +1-800-555  '), '+1800555');
    });

    test('validation', () {
      expect(isValidPhone('+7 777 123 45 67'), isTrue);
      expect(isValidPhone('12345'), isTrue);
      expect(isValidPhone('1234'), isFalse);
      expect(isValidPhone(''), isFalse);
      expect(isValidPhone('abc'), isFalse);
      expect(isValidPhone('1234567890123456'), isFalse);
    });
  });

  group('money', () {
    test('formats with the user currency', () {
      expect(formatMoney(1499.6, '₸'), '1500 ₸');
      expect(formatMoney(10, ' сом '), '10 сом');
    });

    test('no currency -> plain number', () {
      expect(formatMoney(10), '10');
      expect(formatMoney(10, '  '), '10');
    });
  });
}
