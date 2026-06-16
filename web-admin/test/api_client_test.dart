import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_web_admin/src/api/api_client.dart';
import 'package:mezquite_web_admin/src/api/api_exception.dart';

import 'helpers.dart';

/// MockClient que registra peticiones y responde según ruta.
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
  group('Contrato REST de la web admin (refleja backend/app/routers)', () {
    test('captura de indicador organizacional hace el POST correcto', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(json.encode({'id': '1', 'key': 'eventos_w3'}),
            201, headers: {'content-type': 'application/json'});
      });
      await api.addOrganizationalIndicator(
          key: 'eventos_w3', value: 3, estado: 'Aguascalientes');

      expect(rec.requests, hasLength(1));
      final req = rec.requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/admin/indicators/organizational');
      final body = _jsonBody(req);
      expect(body['key'], 'eventos_w3');
      expect(body['value'], 3);
      expect(body['estado'], 'Aguascalientes');
    });

    test('promover aliado firmante hace POST /admin/allies con handle', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(
            json.encode({'handle': 'obs-X', 'role': 'aliado_firmante'}), 200,
            headers: {'content-type': 'application/json'});
      });
      await api.addAlly(handle: 'obs-X');
      final req = rec.requests.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/admin/allies');
      expect(_jsonBody(req)['handle'], 'obs-X');
    });

    test('institución: alta y "solicitar agregar" (request_only)', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(
            json.encode({
              'id': '1',
              'name': 'Prepa X',
              'estado': null,
              'status': 'solicitada'
            }),
            201,
            headers: {'content-type': 'application/json'});
      });
      await api.addInstitution(name: 'Prepa X', requestOnly: true);
      final req = rec.requests.single;
      expect(req.url.path, '/api/v1/admin/institutions');
      expect(_jsonBody(req)['request_only'], isTrue);
    });

    test('snapshot trimestral hace POST /admin/snapshots', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(
            json.encode({
              'quarter': 'Q2-2026',
              'created_at': '2026-05-30T00:00:00Z',
              'observations_total': 42
            }),
            201,
            headers: {'content-type': 'application/json'});
      });
      final res = await api.createSnapshot();
      expect(rec.requests.single.url.path, '/api/v1/admin/snapshots');
      expect(res.quarter, 'Q2-2026');
      expect(res.observationsTotal, 42);
    });

    test('lista F3 lee GET /admin/institutions (aprobadas + solicitadas)',
        () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(
            json.encode([
              {'id': '1', 'name': 'A', 'estado': 'Ags', 'status': 'aprobada'},
              {'id': '2', 'name': 'B', 'estado': null, 'status': 'solicitada'},
            ]),
            200,
            headers: {'content-type': 'application/json'});
      });
      final rows = await api.listInstitutions();
      expect(rec.requests.single.url.path, '/api/v1/admin/institutions');
      expect(rows, hasLength(2));
      expect(rows.where((i) => i.isRequested), hasLength(1));
    });

    test('filtro geográfico (Q8): estado viaja como query param', () async {
      final rec = RequestRecorder();
      final api = _client(rec);
      await api.publicObservations(estado: 'Aguascalientes');
      expect(rec.requests.single.url.queryParameters['estado'],
          'Aguascalientes');
    });
  });

  group('Obfuscación / roles (gate #5)', () {
    test('publicObservations NUNCA llama a /restricted', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        // /public/indicators responde objeto; el resto, lista vacía.
        if (req.url.path.endsWith('/public/indicators')) {
          return http.Response(
              json.encode({
                'snapshot_quarter': 'Q2-2026',
                'caveat': 'caveat',
                'social': {},
                'educativo': {},
                'ecologico': {},
                'organizacional': {}
              }),
              200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'});
      });
      await api.publicObservations();
      await api.publicIndicators();
      expect(rec.hitPathContaining('/restricted'), isFalse,
          reason: 'la vista pública jamás pide coords exactas');
      expect(rec.hitPathContaining('/public/observations'), isTrue);
    });

    test('restricted devuelve 403 sin rol → ApiException auth', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(json.encode({'detail': 'forbidden'}), 403,
            headers: {'content-type': 'application/json'});
      });
      await expectLater(
        api.restrictedObservations(),
        throwsA(isA<ApiException>()
            .having((e) => e.isAuthError, 'isAuthError', isTrue)),
      );
      expect(rec.requests.single.url.path, '/api/v1/restricted/observations');
    });
  });

  group('ARCO — cancelación de cuenta (CR-006, solo administrador)', () {
    test('searchAccounts hace GET /admin/accounts con handle', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(
            json.encode([
              {
                'id': 'a1',
                'handle': 'obs-juan',
                'role': 'voluntario',
                'auth_provider': 'social_google',
                'has_email': false,
                'observations': 3,
              }
            ]),
            200,
            headers: {'content-type': 'application/json'});
      });
      final rows = await api.searchAccounts(handle: 'juan');
      final req = rec.requests.single;
      expect(req.method, 'GET');
      expect(req.url.path, '/api/v1/admin/accounts');
      expect(req.url.queryParameters['handle'], 'juan');
      expect(rows, hasLength(1));
      expect(rows.single.handle, 'obs-juan');
      expect(rows.single.observations, 3);
    });

    test('deleteAccount hace DELETE /admin/accounts/{id} con motivo', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(
            json.encode({
              'deleted_account_id': 'a1',
              'observations_anonymized': 5,
              'message': 'Cuenta eliminada y observaciones anonimizadas.',
            }),
            200,
            headers: {'content-type': 'application/json'});
      });
      final res = await api.deleteAccount(
          accountId: 'a1', reason: 'solicitud del titular');
      final req = rec.requests.single;
      expect(req.method, 'DELETE');
      expect(req.url.path, '/api/v1/admin/accounts/a1');
      expect(_jsonBody(req)['reason'], 'solicitud del titular');
      expect(res.observationsAnonymized, 5);
    });

    test('deleteAccount 403 (rol insuficiente) → ApiException auth', () async {
      final rec = RequestRecorder();
      final api = _client(rec, responder: (req) {
        return http.Response(json.encode({'detail': 'forbidden'}), 403,
            headers: {'content-type': 'application/json'});
      });
      await expectLater(
        api.deleteAccount(accountId: 'a1'),
        throwsA(isA<ApiException>()
            .having((e) => e.isAuthError, 'isAuthError', isTrue)),
      );
    });
  });
}
