import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/state/session.dart';

import 'helpers.dart';

ApiClient _clientReturning({
  required int status,
  required Map<String, dynamic> body,
  RequestRecorder? rec,
}) {
  final mock = MockClient((req) async {
    rec?.requests.add(req);
    return http.Response(json.encode(body), status,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

void main() {
  group('Login admin sin PII (gate #2) y gate de rol', () {
    test('recover exitoso con rol admin_consorcio autentica', () async {
      final api = _clientReturning(status: 200, body: {
        'handle': 'obs-ADMIN1',
        'role': 'admin_consorcio',
        'token': 'tkn',
      });
      final c = SessionController(api);
      final ok = await c.loginWithBackupCode(
          handle: 'obs-ADMIN1', backupCode: 'MZQ-AAAA-BBBB');
      expect(ok, isTrue);
      expect(c.state.isAuthenticated, isTrue);
      expect(c.state.isAdmin, isTrue);
    });

    test('recover con rol voluntario DENIEGA el acceso admin', () async {
      final api = _clientReturning(status: 200, body: {
        'handle': 'obs-VOL1',
        'role': 'voluntario',
        'token': 'tkn',
      });
      final c = SessionController(api);
      final ok = await c.loginWithBackupCode(
          handle: 'obs-VOL1', backupCode: 'MZQ-AAAA-BBBB');
      expect(ok, isFalse);
      expect(c.state.isAuthenticated, isFalse);
      expect(c.state.error, contains('administración del consorcio'));
    });

    test('recover con rol aliado_firmante DENIEGA el acceso admin', () async {
      final api = _clientReturning(status: 200, body: {
        'handle': 'obs-ALLY',
        'role': 'aliado_firmante',
        'token': 'tkn',
      });
      final c = SessionController(api);
      final ok = await c.loginWithBackupCode(
          handle: 'obs-ALLY', backupCode: 'MZQ-AAAA-BBBB');
      expect(ok, isFalse);
      expect(c.state.isAuthenticated, isFalse);
    });

    test('credenciales inválidas (401) muestran error sin autenticar', () async {
      final api = _clientReturning(status: 401, body: {'detail': 'x'});
      final c = SessionController(api);
      final ok = await c.loginWithBackupCode(
          handle: 'obs-X', backupCode: 'bad');
      expect(ok, isFalse);
      expect(c.state.error, isNotNull);
    });

    test('token pegado de admin autentica; token de no-admin se rechaza', () {
      final api = _clientReturning(status: 200, body: {});
      final c = SessionController(api);

      expect(
          c.loginWithToken(
              fakeJwt(handle: 'obs-A', role: 'admin_consorcio')),
          isTrue);
      expect(c.state.isAdmin, isTrue);

      c.logout();
      expect(
          c.loginWithToken(fakeJwt(handle: 'obs-V', role: 'voluntario')),
          isFalse);
      expect(c.state.isAuthenticated, isFalse);
    });

    test('canSeeRestricted es false para admin_consorcio puro', () {
      final api = _clientReturning(status: 200, body: {});
      final c = SessionController(api);
      c.loginWithToken(fakeJwt(handle: 'obs-A', role: 'admin_consorcio'));
      expect(c.state.canSeeRestricted, isFalse,
          reason: 'gate #5: un admin puro no ve coords exactas');
    });

    test('el body de /auth/recover NO contiene campos de PII (gate #2)',
        () async {
      final rec = RequestRecorder();
      final mock = MockClient((req) async {
        rec.requests.add(req);
        // Capturamos el cuerpo enviado.
        final body = json.decode(req.body) as Map<String, dynamic>;
        // Solo handle + backup_code; nada de email/teléfono/nombre.
        expect(body.keys.toSet(), {'handle', 'backup_code'});
        for (final pii in ['email', 'phone', 'telefono', 'name', 'nombre',
          'password', 'contrasena']) {
          expect(body.containsKey(pii), isFalse);
        }
        return http.Response(
            json.encode({
              'handle': 'obs-ADMIN1',
              'role': 'admin_consorcio',
              'token': 'tkn'
            }),
            200,
            headers: {'content-type': 'application/json'});
      });
      final api =
          ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
      await SessionController(api).loginWithBackupCode(
          handle: 'obs-ADMIN1', backupCode: 'MZQ-AAAA-BBBB');
      expect(rec.hitPathContaining('/auth/recover'), isTrue);
    });
  });
}
