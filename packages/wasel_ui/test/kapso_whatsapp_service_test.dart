import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_ui/wasel_ui.dart';

void main() {
  group('KapsoWhatsAppService Tests', () {
    test('normalizePhone handles various Libyan formats correctly', () {
      expect(KapsoWhatsAppService.normalizePhone('0918207786'), '218918207786');
      expect(KapsoWhatsAppService.normalizePhone('+218918207786'), '218918207786');
      expect(KapsoWhatsAppService.normalizePhone('092-123-4567'), '218921234567');
      expect(KapsoWhatsAppService.normalizePhone('218918207786'), '218918207786');
    });

    test('formatDisplayPhone formats 12-digit normalized phone for UI', () {
      expect(KapsoWhatsAppService.formatDisplayPhone('218918207786'), '091 820 7786');
      expect(KapsoWhatsAppService.formatDisplayPhone('0918207786'), '091 820 7786');
    });

    test('WaselUserRole serializes to expected API strings', () {
      expect(WaselUserRole.customer.toApiString(), 'customer');
      expect(WaselUserRole.captain.toApiString(), 'captain');
      expect(WaselUserRole.merchant.toApiString(), 'merchant');
      expect(WaselUserRole.admin.toApiString(), 'admin');
    });

    test('Fallback client-assisted OTP generation and verification', () async {
      // Force non-routable port to trigger immediate client-assisted fallback
      KapsoWhatsAppService.backendBaseUrl = 'http://127.0.0.1:59999';

      final res = await KapsoWhatsAppService.requestOtp(
        phone: '0918207786',
        role: WaselUserRole.customer,
      );

      expect(res.success, isTrue);
      expect(res.normalizedPhone, '218918207786');
      expect(res.otp, isNotNull);
      expect(res.otp!.length, 4);
      expect(res.needsDeeplink, isTrue);
      expect(res.deeplinkUrl, contains('wa.me/218918207786'));

      // Test verifying with wrong OTP
      final wrongRes = await KapsoWhatsAppService.verifyOtp(
        phone: '0918207786',
        enteredOtp: '0000',
        role: WaselUserRole.customer,
      );
      expect(wrongRes.success, isFalse);

      // Test verifying with correct OTP
      final correctRes = await KapsoWhatsAppService.verifyOtp(
        phone: '0918207786',
        enteredOtp: res.otp!,
        role: WaselUserRole.customer,
      );
      expect(correctRes.success, isTrue);
      expect(correctRes.token, isNotNull);
    });
  });
}
