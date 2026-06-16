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
  group('Login de la consola por usuario/contraseña (CR-002) y gate de rol', () {
    test('login exitoso con rol admin_consorcio autentica', () async {
      final api = _clientReturning(status: 200, body: {
        'handle': 'obs-ADMIN1',
        'role': 'admin_consorcio',
        'token': 'tkn',
      });
      final c = SessionController(api);
      final ok = await c.loginWithPassword(
          username: 'admin1', password: 'secreto');
      expect(ok, isTrue);
      expect(c.state.isAuthenticated, isTrue);
      expect(c.state.isAdmin, isTrue);
    });

    test('login con rol voluntario DENIEGA el acceso a la consola', () async {
      final api = _clientReturning(status: 200, body: {
        'handle': 'obs-VOL1',
        'role': 'voluntario',
        'token': 'tkn',
      });
      final c = SessionController(api);
      final ok = await c.loginWithPassword(
          username: 'vol1', password: 'x');
      expect(ok, isFalse);
      expect(c.state.isAuthenticated, isFalse);
      expect(c.state.error, contains('consola del consorcio'));
    });

    test('login con rol aliado_firmante DENIEGA el acceso a la consola', () async {
      final api = _clientReturning(status: 200, body: {
        'handle': 'obs-ALLY',
        'role': 'aliado_firmante',
        'token': 'tkn',
      });
      final c = SessionController(api);
      final ok = await c.loginWithPassword(
          username: 'ally', password: 'x');
      expect(ok, isFalse);
      expect(c.state.isAuthenticated, isFalse);
    });

    test('credenciales inválidas (401) muestran error sin autenticar', () async {
      final api = _clientReturning(status: 401, body: {'detail': 'x'});
      final c = SessionController(api);
      final ok = await c.loginWithPassword(username: 'x', password: 'bad');
      expect(ok, isFalse);
      expect(c.state.error, isNotNull);
    });

    test('administrador entra y puede gestionar usuarios + emitir veredicto', () async {
      final api = _clientReturning(status: 200, body: {
        'handle': 'obs-ADM',
        'role': 'administrador',
        'token': 'tkn',
      });
      final c = SessionController(api);
      final ok = await c.loginWithPassword(
          username: 'admin', password: 'secreto');
      expect(ok, isTrue);
      expect(c.state.canManageUsers, isTrue);
      expect(c.state.canEmitVerdict, isTrue);
      expect(c.state.canReview, isTrue);
    });

    test('evaluador NO gestiona usuarios pero sí emite veredicto', () async {
      final api = _clientReturning(status: 200, body: {
        'handle': 'obs-EV',
        'role': 'evaluador',
        'token': 'tkn',
      });
      final c = SessionController(api);
      await c.loginWithPassword(username: 'eva', password: 'x');
      expect(c.state.canManageUsers, isFalse);
      expect(c.state.canEmitVerdict, isTrue);
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

    test('analista entra a la consola pero NO emite veredicto (solo lectura)',
        () {
      final api = _clientReturning(status: 200, body: {});
      final c = SessionController(api);
      expect(
          c.loginWithToken(fakeJwt(handle: 'obs-AN', role: 'analista')), isTrue);
      expect(c.state.canReview, isTrue);
      expect(c.state.canEmitVerdict, isFalse);
      expect(c.state.canManageUsers, isFalse);
    });

    test('canSeeRestricted es false para admin_consorcio puro', () {
      final api = _clientReturning(status: 200, body: {});
      final c = SessionController(api);
      c.loginWithToken(fakeJwt(handle: 'obs-A', role: 'admin_consorcio'));
      expect(c.state.canSeeRestricted, isFalse,
          reason: 'gate #5: un admin puro no ve coords exactas');
    });

    test('el body de /auth/login lleva usuario/contraseña; sin email/nombre (gate #2 acotado)',
        () async {
      final rec = RequestRecorder();
      final mock = MockClient((req) async {
        rec.requests.add(req);
        final body = json.decode(req.body) as Map<String, dynamic>;
        expect(body.keys.toSet(), {'username', 'password'});
        for (final pii in ['email', 'phone', 'telefono', 'name', 'nombre']) {
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
      await SessionController(api).loginWithPassword(
          username: 'admin1', password: 'secreto');
      expect(rec.hitPathContaining('/auth/login'), isTrue);
    });
  });
}
