import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_customer_app/services/firebase_auth_service.dart';

void main() {
  group('FirebaseAuthService - Libyan Phone Normalization', () {
    test('normalizes standard 10-digit Libyan numbers with leading 0', () {
      expect(FirebaseAuthService.normalizeLibyanPhone('0911234567'), '+218911234567');
      expect(FirebaseAuthService.normalizeLibyanPhone('0927654321'), '+218927654321');
      expect(FirebaseAuthService.normalizeLibyanPhone('0945551234'), '+218945551234');
      expect(FirebaseAuthService.normalizeLibyanPhone('0950009988'), '+218950009988');
    });

    test('normalizes numbers with spaces and dashes', () {
      expect(FirebaseAuthService.normalizeLibyanPhone('091 123 4567'), '+218911234567');
      expect(FirebaseAuthService.normalizeLibyanPhone('092-765-4321'), '+218927654321');
      expect(FirebaseAuthService.normalizeLibyanPhone('(091) 1234567'), '+218911234567');
    });

    test('normalizes numbers starting with 9 without 0', () {
      expect(FirebaseAuthService.normalizeLibyanPhone('911234567'), '+218911234567');
      expect(FirebaseAuthService.normalizeLibyanPhone('927654321'), '+218927654321');
    });

    test('normalizes numbers with international prefixes', () {
      expect(FirebaseAuthService.normalizeLibyanPhone('+218911234567'), '+218911234567');
      expect(FirebaseAuthService.normalizeLibyanPhone('00218911234567'), '+218911234567');
      expect(FirebaseAuthService.normalizeLibyanPhone('218911234567'), '+218911234567');
    });

    test('normalizes Arabic-Indic numerals', () {
      expect(FirebaseAuthService.normalizeLibyanPhone('٠٩١١٢٣٤٥٦٧'), '+218911234567');
      expect(FirebaseAuthService.normalizeLibyanPhone('٠٩٢ ٧٦٥ ٤٣٢١'), '+218927654321');
    });

    test('validates valid Libyan mobile numbers', () {
      expect(FirebaseAuthService.isValidLibyanPhone('0911234567'), isTrue);
      expect(FirebaseAuthService.isValidLibyanPhone('0921234567'), isTrue);
      expect(FirebaseAuthService.isValidLibyanPhone('0941234567'), isTrue);
      expect(FirebaseAuthService.isValidLibyanPhone('+218911234567'), isTrue);
    });

    test('rejects invalid or too short numbers', () {
      expect(FirebaseAuthService.isValidLibyanPhone('12345'), isFalse);
      expect(FirebaseAuthService.isValidLibyanPhone('0901234567'), isFalse); // invalid prefix
      expect(FirebaseAuthService.isValidLibyanPhone('0971234567'), isFalse); // invalid prefix
      expect(FirebaseAuthService.isValidLibyanPhone(''), isFalse);
    });

    test('formats Libyan phone for UI display', () {
      expect(FirebaseAuthService.formatDisplayPhone('0911234567'), '091 123 4567');
      expect(FirebaseAuthService.formatDisplayPhone('+218927654321'), '092 765 4321');
    });
  });
}
