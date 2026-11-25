import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasel_ui/wasel_ui.dart';

void main() {
  group('TelegramAuthService Tests', () {
    test('normalizePhone handles various Libyan formats correctly', () {
      expect(TelegramAuthService.normalizePhone('0918207786'), '218918207786');
      expect(TelegramAuthService.normalizePhone('+218 92 555 0001'), '218925550001');
      expect(TelegramAuthService.normalizePhone('00218941234567'), '218941234567');
      expect(TelegramAuthService.normalizePhone('918207786'), '218918207786');
    });

    test('requestOtp, session polling, and verifyOtp against mock Telegram backend', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));

      bool verifiedFlag = false;
      server.listen((HttpRequest req) async {
        final bodyStr = await utf8.decoder.bind(req).join();
        req.response.headers.contentType = ContentType.json;

        if (req.uri.path == '/api/v1/auth/telegram/send-otp') {
          final parsed = jsonDecode(bodyStr) as Map<String, dynamic>;
          expect(parsed['phone'], '218918207786');
          expect(parsed['role'], 'captain');
          req.response.write(jsonEncode({
            'success': true,
            'mode': 'bot_verification_required',
            'sessionId': 'tg_abc123',
            'normalizedPhone': '218918207786',
            'botUsername': 'WaselNalutbot',
            'deeplinkUrl': 'https://t.me/WaselNalutbot?start=auth_tg_abc123',
            'nativeUri': 'tg://resolve?domain=WaselNalutbot&start=auth_tg_abc123',
            'expiresInSeconds': 300,
          }));
        } else if (req.uri.path == '/api/v1/auth/telegram/session-status') {
          if (!verifiedFlag) {
            req.response.write(jsonEncode({'success': true, 'verified': false, 'expired': false}));
          } else {
            req.response.write(jsonEncode({
              'success': true,
              'verified': true,
              'data': {
                'token': 'tg-jwt-token',
                'user': {'id': 'u1', 'full_name': 'خليفة', 'role': 'captain'},
                'driver': {'id': 'driver_nalut_01', 'full_name': 'خالد الكاتب'}
              }
            }));
          }
        } else if (req.uri.path == '/api/v1/auth/telegram/verify-otp') {
          req.response.write(jsonEncode({
            'success': true,
            'verified': true,
            'data': {
              'isNewUser': false,
              'token': 'tg-otp-jwt',
              'user': {'id': 'u1', 'full_name': 'خليفة'}
            }
          }));
        }
        await req.response.close();
      });

      final prevUrl = TelegramAuthService.backendBaseUrl;
      TelegramAuthService.backendBaseUrl = 'http://${server.address.address}:${server.port}';
      addTearDown(() => TelegramAuthService.backendBaseUrl = prevUrl);

      final otpRes = await TelegramAuthService.requestOtp(
        phone: '0918207786',
        role: WaselUserRole.captain,
      );
      expect(otpRes.success, true);
      expect(otpRes.needsBotTap, true);
      expect(otpRes.sessionId, 'tg_abc123');

      final pending = await TelegramAuthService.checkSessionStatus(sessionId: 'tg_abc123');
      expect(pending.verified, false);

      verifiedFlag = true;
      final confirmed = await TelegramAuthService.checkSessionStatus(sessionId: 'tg_abc123');
      expect(confirmed.success, true);
      expect(confirmed.verified, true);
      expect(confirmed.token, 'tg-jwt-token');
      expect(confirmed.driverData?['id'], 'driver_nalut_01');

      final manualRes = await TelegramAuthService.verifyOtp(phone: '0918207786', enteredOtp: '4829');
      expect(manualRes.success, true);
      expect(manualRes.token, 'tg-otp-jwt');
    });
  });
}
