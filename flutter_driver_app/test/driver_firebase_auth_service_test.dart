import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_captain_app/services/driver_firebase_auth_service.dart';

void main() {
  group('DriverFirebaseAuthService - Captain Phone Normalization & Validation', () {
    test('normalizes standard Libyan mobile numbers for captains', () {
      expect(DriverFirebaseAuthService.normalizeLibyanPhone('0912223344'), '+218912223344');
      expect(DriverFirebaseAuthService.normalizeLibyanPhone('0925556677'), '+218925556677');
      expect(DriverFirebaseAuthService.normalizeLibyanPhone('0948889900'), '+218948889900');
    });

    test('handles spaces, dashes, and country codes', () {
      expect(DriverFirebaseAuthService.normalizeLibyanPhone('091 222 3344'), '+218912223344');
      expect(DriverFirebaseAuthService.normalizeLibyanPhone('+218912223344'), '+218912223344');
      expect(DriverFirebaseAuthService.normalizeLibyanPhone('00218912223344'), '+218912223344');
    });

    test('normalizes Arabic-Indic numerals', () {
      expect(DriverFirebaseAuthService.normalizeLibyanPhone('٠٩١٢٢٢٣٣٤٤'), '+218912223344');
    });

    test('validates captain mobile numbers', () {
      expect(DriverFirebaseAuthService.isValidLibyanPhone('0912223344'), isTrue);
      expect(DriverFirebaseAuthService.isValidLibyanPhone('0925556677'), isTrue);
      expect(DriverFirebaseAuthService.isValidLibyanPhone('0948889900'), isTrue);
      expect(DriverFirebaseAuthService.isValidLibyanPhone('12345'), isFalse);
      expect(DriverFirebaseAuthService.isValidLibyanPhone('0901234567'), isFalse);
    });
  });
}
