import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_app/src/api/api_client.dart';
import 'package:mezquite_app/src/api/api_exception.dart';
import 'package:mezquite_app/src/models/enums.dart';
import 'package:mezquite_app/src/models/models.dart';
import 'package:mezquite_app/src/services/session_tracker.dart';

/// CR-035 — detección de la sesión vencida (capa no visual).
///
/// El JWT vence a los 7 días (CR-027) y hasta ahora el vencimiento era invisible
/// con la cola vacía. Aquí se fijan las dos señales: la **proactiva** (leer el
/// `exp` local, sin red) y la **reactiva** (el 401 con token puesto dispara
/// `onSessionExpired`), más que el rastreador de sesión deje de hacer ruido
/// cuando el flag está encendido.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// JWT de utilería: payload real en base64url sin relleno, firma de mentira
  /// (mismo criterio que en producción: la firma la verifica el backend).
  String jwtCon(Map<String, dynamic> claims) {
    final payload = base64Url
        .encode(utf8.encode(json.encode(claims)))
        .replaceAll('=', '');
    return 'cabecera.$payload.firma';
  }

  group('expiryFromJwt', () {
    test('lee el claim exp como fecha UTC', () {
      // 2026-01-01T00:00:00Z = 1767225600 segundos UNIX.
      final token = jwtCon({'sub': 'abc', 'exp': 1767225600});
      expect(
        expiryFromJwt(token),
        DateTime.utc(2026, 1, 1),
      );
    });

    test('sin exp devuelve null', () {
      expect(expiryFromJwt(jwtCon({'sub': 'abc'})), isNull);
    });

    // Espejo del test de `accountIdFromJwt`: tolera basura sin lanzar.
    test('token ilegible devuelve null', () {
      expect(expiryFromJwt('no-es-un-jwt'), isNull);
      expect(expiryFromJwt(''), isNull);
      expect(expiryFromJwt('a.!!!.c'), isNull);
    });
  });

  group('tokenVencido (reloj inyectado)', () {
    final token = jwtCon({'sub': 'abc', 'exp': 1767225600}); // 2026-01-01Z

    test('antes del exp NO está vencido', () {
      expect(
        tokenVencido(token, now: () => DateTime.utc(2025, 12, 31, 23, 59)),
        isFalse,
      );
    });

    test('en el exp exacto y después SÍ está vencido', () {
      expect(
        tokenVencido(token, now: () => DateTime.utc(2026, 1, 1)),
        isTrue,
      );
      expect(
        tokenVencido(token, now: () => DateTime.utc(2026, 7, 1)),
        isTrue,
      );
    });

    test('sin exp legible NUNCA se declara vencido (tolerante)', () {
      expect(
        tokenVencido(jwtCon({'sub': 'abc'}), now: () => DateTime.utc(2030)),
        isFalse,
      );
      expect(
        tokenVencido('basura', now: () => DateTime.utc(2030)),
        isFalse,
      );
    });
  });

  group('ApiException.isSessionExpired', () {
    // SOLO el 401 se cura re-entrando: 403 es permiso denegado (necesita
    // atención), 410 es cuenta eliminada (D6). Tabla al estilo de la consola.
    const casos = {401: true, 403: false, 410: false, 422: false, 500: false};

    casos.forEach((status, esperado) {
      test('$status → $esperado', () {
        expect(ApiException(status, 'x').isSessionExpired, esperado);
      });
    });
  });

  group('ApiClient.onSessionExpired', () {
    test('dispara con token puesto y 401 en un endpoint JSON', () async {
      final api = ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient((req) async => http.Response('no', 401)),
      );
      var disparos = 0;
      api.onSessionExpired = () => disparos++;
      api.setToken('tok');

      await expectLater(api.profile(), throwsA(isA<ApiException>()));
      expect(disparos, 1);
    });

    test('NO dispara sin token: un login fallido no es una sesión vencida',
        () async {
      final api = ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient((req) async => http.Response('no', 401)),
      );
      var disparos = 0;
      api.onSessionExpired = () => disparos++;

      await expectLater(api.profile(), throwsA(isA<ApiException>()));
      expect(disparos, 0);
    });

    test('dispara también en submitObservation (multipart) con 401', () async {
      // MockClient.streaming es OBLIGATORIO para multipart (patrón `apiQue` de
      // cr031_uploader_test).
      final api = ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient.streaming(
          (req, body) async => http.StreamedResponse(
            Stream.value(utf8.encode('no')),
            401,
          ),
        ),
      );
      var disparos = 0;
      api.onSessionExpired = () => disparos++;
      api.setToken('tok');

      final draft = ObservationDraft(
        lat: 21.88,
        lon: -102.29,
        capturedAt: DateTime.utc(2026, 8, 1, 9),
        nivelG4: NivelG4.leve,
        flagCuscuta: false,
        flagDanio: false,
        tamanio: Tamanio.mediano,
        contexto: Contexto.campoAbierto,
        imageBytes: Uint8List.fromList(List<int>.filled(16, 7)),
      );

      await expectLater(
        api.submitObservation(draft),
        throwsA(isA<ApiException>()),
      );
      expect(disparos, 1);
    });
  });

  group('SessionTracker con la sesión vencida', () {
    /// Cliente que cuenta los POST a /me/sessions.
    ({ApiClient api, List<Uri> posts}) apiContador() {
      final posts = <Uri>[];
      final api = ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient((req) async {
          posts.add(req.url);
          return http.Response('{}', 201);
        }),
      );
      return (api: api, posts: posts);
    }

    // Reloj inyectado: 1 hora entre abrir y cerrar el tramo (como cr010).
    final tiempos = [
      DateTime.utc(2026, 8, 1, 9),
      DateTime.utc(2026, 8, 1, 10),
    ];

    test('con el predicado en true NO envía el tramo', () async {
      final c = apiContador();
      var i = 0;
      final tracker = SessionTracker(
        c.api,
        now: () => tiempos[i++],
        sesionVencida: () => true,
      );
      tracker.start();
      await tracker.stop();

      expect(c.posts, isEmpty, reason: 'el backend lo rechazaría con otro 401');
      expect(tracker.lastSent, isNull);
    });

    test('con el predicado en false envía como siempre', () async {
      final c = apiContador();
      var i = 0;
      final tracker = SessionTracker(
        c.api,
        now: () => tiempos[i++],
        sesionVencida: () => false,
      );
      tracker.start();
      await tracker.stop();

      expect(c.posts, hasLength(1));
      expect(c.posts.single.path, '/api/v1/me/sessions');
      expect(tracker.lastSent, isNotNull);
    });
  });
}
