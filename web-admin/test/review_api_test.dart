import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';

import 'helpers.dart';

ApiClient _client(RequestRecorder rec,
    {http.Response Function(http.BaseRequest req)? responder}) {
  final mock = MockClient((req) async {
    rec.requests.add(req);
    if (responder != null) return responder(req);
    return http.Response('[]', 200,
        headers: {'content-type': 'application/json'});
  });
  return ApiClient(baseUrl: 'http://localhost:8000/api/v1', httpClient: mock);
}

Map<String, dynamic> _jsonBody(http.BaseRequest req) =>
    json.decode((req as http.Request).body) as Map<String, dynamic>;

void main() {
  group('Contrato REST de revisión humana (CR-001)', () {
    test('reviewQueue pasa filtros y NO pide coords exactas', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(
            json.encode([
              {
                'observation_id': 'o1',
                'handle': 'obs-A',
                'captured_at': '2026-06-15T12:00:00Z',
                'estado_revision': 'aceptada',
                'nivel_g4': 'leve',
                'flag_cuscuta': false,
                'flag_danio': false,
                'tamanio': 'mediano',
                'contexto': 'campo_abierto',
                'estado': 'Aguascalientes',
                'municipio': 'Centro'
              }
            ]),
            200,
            headers: {'content-type': 'application/json'});
      });
      final rows = await api.reviewQueue(estadoRevision: 'aceptada');
      final req = rec.requests.single;
      expect(req.url.path, '/api/v1/review/queue');
      expect(req.url.queryParameters['estado_revision'], 'aceptada');
      expect(rows.single.estadoRevision, 'aceptada');
      // El cliente jamás pide la vista restringida en la cola de revisión.
      expect(rec.hitPathContaining('/restricted'), isFalse);
    });

    test('reviewQueueAll recorre offsets hasta la página corta (CR-033)',
        () async {
      Map<String, dynamic> fila(int i) => {
            'observation_id': 'o$i',
            'handle': 'obs-A',
            'captured_at': '2026-06-15T12:00:00Z',
            'estado_revision': 'aceptada',
            'nivel_g4': 'leve',
            'flag_cuscuta': false,
            'flag_danio': false,
            'tamanio': 'mediano',
            'contexto': 'campo_abierto',
            'estado': 'Aguascalientes',
            'municipio': 'Centro'
          };
      final rec = RequestRecorder();
      // 1150 filas en el backend: página llena (1000) + página corta (150).
      final api = _client(rec, responder: (req) {
        final offset = int.parse(req.url.queryParameters['offset'] ?? '0');
        final n = offset == 0 ? 1000 : 150;
        return http.Response(
            json.encode([for (var i = 0; i < n; i++) fila(offset + i)]), 200,
            headers: {'content-type': 'application/json'});
      });
      final rows = await api.reviewQueueAll(estadoRevision: 'aceptada');
      // Trae TODO, no un tope arbitrario (el bug era un limit fijo de 200).
      expect(rows.length, 1150);
      expect(rows.first.observationId, 'o0');
      expect(rows.last.observationId, 'o1149');
      expect(rec.requests.length, 2);
      expect(rec.requests[0].url.queryParameters['limit'], '1000');
      expect(rec.requests[0].url.queryParameters['offset'], '0');
      expect(rec.requests[1].url.queryParameters['offset'], '1000');
      // El filtro viaja en TODAS las páginas.
      expect(rec.requests[1].url.queryParameters['estado_revision'], 'aceptada');
    });

    test('submitVerdict hace POST con veredicto y nota', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(
            json.encode({
              'observation_id': 'o1',
              'estado_revision': 'rechazada',
              'message': 'retirada'
            }),
            200,
            headers: {'content-type': 'application/json'});
      });
      await api.submitVerdict(
          observationId: 'o1', veredicto: 'rechazada', nota: 'borrosa');
      final req = rec.requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/review/observations/o1/verdict');
      final body = _jsonBody(req);
      expect(body['veredicto'], 'rechazada');
      expect(body['nota'], 'borrosa');
    });

    test('reviewDetail lee historial', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(
            json.encode({
              'observation_id': 'o1',
              'handle': 'obs-A',
              'captured_at': '2026-06-15T12:00:00Z',
              'estado_revision': 'rechazada',
              'nivel_g4': 'leve',
              'flag_cuscuta': false,
              'flag_danio': false,
              'tamanio': 'mediano',
              'contexto': 'campo_abierto',
              'estado': 'Ags',
              'municipio': 'Centro',
              'historial': [
                {
                  'veredicto': 'rechazada',
                  'nota': 'borrosa',
                  'reviewer_handle': 'obs-EV',
                  'created_at': '2026-06-15T13:00:00Z'
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'});
      });
      final d = await api.reviewDetail('o1');
      expect(rec.requests.single.url.path, '/api/v1/review/observations/o1');
      expect(d.historial.single.reviewerHandle, 'obs-EV');
      expect(d.historial.single.veredicto, 'rechazada');
    });

    test('reviewStats lee métricas', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(
            json.encode({
              'aceptadas': 4,
              'confirmadas': 2,
              'rechazadas': 1,
              'total': 7,
              'pendientes_de_revision': 4,
              'revisiones_totales': 3
            }),
            200,
            headers: {'content-type': 'application/json'});
      });
      final s = await api.reviewStats();
      expect(rec.requests.single.url.path, '/api/v1/review/stats');
      expect(s.total, 7);
      expect(s.pendientesDeRevision, 4);
    });
  });
}
