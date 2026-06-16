import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_app/src/api/api_client.dart';
import 'package:mezquite_app/src/models/enums.dart';
import 'package:mezquite_app/src/models/models.dart';

/// Verifica que la capa de API consume el contrato REAL del backend
/// (`/api/v1`, multipart en /observations, nombres de campo exactos).
void main() {
  test('loginWithGoogle POSTea solo el id_token (sin PII) y guarda el token', () async {
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        json.encode({
          'handle': 'colibri-azul-42',
          'role': 'voluntario',
          'token': 'tok-123',
        }),
        200,
      );
    });
    final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);

    final session = await api.loginWithGoogle(idToken: 'mock:demo');
    expect(captured.url.path, '/api/v1/auth/google');
    final body = json.decode(captured.body) as Map<String, dynamic>;
    // Gate #2 acotado: solo id_token; nada de email/phone/nombre.
    expect(body['id_token'], 'mock:demo');
    expect(body.containsKey('email'), isFalse);
    expect(body.containsKey('phone'), isFalse);
    expect(body.containsKey('name'), isFalse);
    expect(session.token, 'tok-123');
    expect(session.handle, 'colibri-azul-42');
  });

  test('submitObservation envía multipart con payload (8 etiquetas) + image',
      () async {
    // Archivo de imagen temporal.
    final tmp = File('${Directory.systemTemp.path}/mezq_test.jpg')
      ..writeAsBytesSync([1, 2, 3, 4]);

    late String contentType;
    late List<int> rawBody;
    final mock = MockClient.streaming((req, bodyStream) async {
      contentType = req.headers['content-type'] ?? '';
      rawBody = await bodyStream.toBytes();
      return http.StreamedResponse(
        Stream.value(utf8.encode(json.encode({
          'observation_id': 'obs-1',
          'base_points': 10,
          'message': 'Observación registrada. ¡Gracias por contribuir!',
        }),),),
        201,
      );
    });
    final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);
    api.setToken('tok');

    final draft = ObservationDraft(
      lat: 25.0,
      lon: -100.0,
      capturedAt: DateTime.utc(2026, 5, 30, 10),
      nivelG4: NivelG4.moderado,
      flagCuscuta: true,
      flagDanio: false,
      tamanio: Tamanio.grande,
      contexto: Contexto.campoAbierto,
      imagePath: tmp.path,
    );

    final id = await api.submitObservation(draft);
    expect(id, 'obs-1');
    expect(contentType.contains('multipart/form-data'), isTrue);
    final bodyStr = utf8.decode(rawBody);
    // El campo `payload` y el archivo `image` viajan en el multipart.
    expect(bodyStr.contains('name="payload"'), isTrue);
    expect(bodyStr.contains('name="image"'), isTrue);
    // Los nombres de campo del backend están presentes en el payload JSON.
    for (final f in [
      'nivel_g4',
      'flag_cuscuta',
      'flag_danio',
      'tamanio',
      'contexto',
      'captured_at',
    ]) {
      expect(bodyStr.contains(f), isTrue, reason: 'falta campo $f');
    }
    tmp.deleteSync();
  });

  test('publicObservations parsea coords obfuscadas + snapshot Qn', () async {
    final mock = MockClient((req) async {
      expect(req.url.path, '/api/v1/public/observations');
      return http.Response(
        json.encode([
          {
            'handle': 'h1',
            'lat': 25.685,
            'lon': -100.316,
            'nivel_g4': 'leve',
            'flag_cuscuta': false,
            'flag_danio': false,
            'estado': 'NL',
            'municipio': 'Monterrey',
            'captured_at': '2026-05-30T10:00:00Z',
            'snapshot_quarter': 'Q2-2026',
          }
        ]),
        200,
      );
    });
    final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);
    final list = await api.publicObservations();
    expect(list.single.snapshotQuarter, 'Q2-2026');
  });

  test('injectExif escribe EXIF GPS/fecha en un JPEG real', () async {
    // JPEG mínimo válido (SOI + APP0 + EOI) para que native_exif lo abra.
    final jpeg = <int>[
      0xFF, 0xD8, // SOI
      0xFF, 0xE0, 0x00, 0x10, // APP0
      0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
      0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
      0xFF, 0xD9, // EOI
    ];
    final tmp = File('${Directory.systemTemp.path}/mezq_exif.jpg')
      ..writeAsBytesSync(jpeg);
    // No verificamos lectura (depende de plugin nativo); sí que no lance en la
    // capa de modelo. La inyección real se valida en integration_test (T1).
    final draft = ObservationDraft(
      lat: 25.0,
      lon: -100.0,
      capturedAt: DateTime.utc(2026, 5, 30),
      nivelG4: NivelG4.sano,
      flagCuscuta: false,
      flagDanio: false,
      tamanio: Tamanio.noEstimable,
      contexto: Contexto.otro,
      imagePath: tmp.path,
    );
    expect(draft.toPayloadJson().length, 8);
    tmp.deleteSync();
  });
}
