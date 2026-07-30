import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_app/src/api/api_client.dart';
import 'package:mezquite_app/src/services/pending/pending_capture.dart';
import 'package:mezquite_app/src/services/pending/pending_store.dart';
import 'package:mezquite_app/src/services/pending/pending_uploader.dart';

/// CR-031 W3 — motor de subida.
///
/// El corazón de este CR: antes, `.catchError((_) {})` hacía que cualquier fallo de
/// subida desapareciera sin rastro. Aquí se fija que cada clase de error tenga su
/// desenlace, que **nada se borre por un fallo**, y que un reintento sobre una
/// respuesta perdida no duplique el mezquite.
void main() {
  const cuenta = 'cuenta-a';
  final bytes = Uint8List.fromList(List<int>.filled(32, 3));
  final reloj = DateTime.utc(2026, 7, 29, 12);

  PendingCapture captura(String id, {int minuto = 0, String accountId = cuenta}) =>
      PendingCapture(
        id: id,
        accountId: accountId,
        lat: 21.88,
        lon: -102.29,
        capturedAt: DateTime.utc(2026, 7, 29, 9, minuto),
        nivelG4: 'leve',
        flagCuscuta: false,
        flagDanio: false,
        tamanio: 'mediano',
        contexto: 'campo_abierto',
      );

  /// Almacén con [ids] ya guardados (con imagen).
  Future<PendingCaptureStore> almacenCon(List<String> ids) async {
    final store = PendingCaptureStore(InMemoryPendingBackend());
    await store.init();
    for (var i = 0; i < ids.length; i++) {
      await store.save(captura(ids[i], minuto: i), bytes);
    }
    return store;
  }

  ApiClient apiQue(
    Future<http.Response> Function(http.BaseRequest req) responder,
  ) =>
      ApiClient(
        baseUrl: 'http://x/api/v1',
        httpClient: MockClient.streaming((req, body) async {
          final r = await responder(req);
          return http.StreamedResponse(
            Stream.value(r.bodyBytes),
            r.statusCode,
            headers: r.headers,
          );
        }),
      );

  http.Response ok201({bool yaExistia = false, String id = 'obs-1'}) => http.Response(
        json.encode({
          'observation_id': id,
          'base_points': 5,
          'message': 'ok',
          'ya_existia': yaExistia,
        }),
        yaExistia ? 200 : 201,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  PendingUploader uploader(PendingCaptureStore store, ApiClient api) =>
      PendingUploader(
        store: store,
        api: api,
        reloj: () => reloj,
        random: Random(1), // jitter determinista
      );

  group('AC6 — sube y borra en orden de captura', () {
    test('drena toda la cola en una pasada y no queda nada', () async {
      final store = await almacenCon(['a', 'b', 'c']);
      final enviadas = <String>[];
      final api = apiQue((req) async {
        enviadas.add('enviada');
        return ok201();
      });

      final run = await uploader(store, api).flush(accountId: cuenta);

      expect(run.subidas, 3);
      expect(run.fallidas, 0);
      expect(run.pendientes, 0);
      expect(enviadas, hasLength(3));
      expect(await store.count(), 0);
      expect(await store.bytesOf('a'), isNull); // la imagen también se fue
    });

    test('manda el client_capture_id y la hora de captura', () async {
      final store = await almacenCon(['a']);
      Map<String, dynamic>? payload;
      final api = apiQue((req) async {
        payload = json.decode(
          (req as http.MultipartRequest).fields['payload']!,
        ) as Map<String, dynamic>;
        return ok201();
      });

      await uploader(store, api).flush(accountId: cuenta);

      expect(payload!['client_capture_id'], 'a');
      expect(payload!['captured_at'], '2026-07-29T09:00:00.000Z');
    });
  });

  group('AC14 — una respuesta perdida NO duplica el mezquite', () {
    test('el reintento recibe 200 + ya_existia y la captura se da por buena',
        () async {
      final store = await almacenCon(['a']);
      var llamadas = 0;
      final api = apiQue((req) async {
        llamadas++;
        // 1º intento: el servidor SÍ la guardó, pero la respuesta se pierde.
        if (llamadas == 1) throw http.ClientException('connection reset');
        // 2º intento: mismo client_capture_id ⇒ el servidor reconoce el reintento.
        return ok201(yaExistia: true, id: 'obs-original');
      });
      final motor = uploader(store, api);

      final primera = await motor.flush(accountId: cuenta);
      expect(primera.subidas, 0);
      expect(primera.fallidas, 1);
      expect(await store.count(), 1, reason: 'se conserva para reintentar');

      // Pasa la espera del backoff.
      final motor2 = PendingUploader(
        store: store,
        api: api,
        reloj: () => reloj.add(const Duration(minutes: 1)),
        random: Random(1),
      );
      final segunda = await motor2.flush(accountId: cuenta);

      expect(segunda.subidas, 1);
      expect(await store.count(), 0, reason: 'ya está a salvo en el servidor');
      expect(llamadas, 2);
    });
  });

  group('AC8 — cada error tiene su desenlace', () {
    test('5xx: reintentable, se conserva y programa espera', () async {
      final store = await almacenCon(['a']);
      final api = apiQue((_) async => http.Response('boom', 503));

      final run = await uploader(store, api).flush(accountId: cuenta);

      expect(run.subidas, 0);
      expect(run.fallidas, 1);
      final tras = (await store.list()).single;
      expect(tras.state, PendingState.enCola);
      expect(tras.intentos, 1);
      expect(tras.ultimoError, contains('503'));
      expect(tras.proximoIntento!.isAfter(reloj), isTrue);
    });

    test('sin red: reintentable', () async {
      final store = await almacenCon(['a']);
      final api = apiQue((_) async => throw http.ClientException('sin red'));

      await uploader(store, api).flush(accountId: cuenta);

      final tras = (await store.list()).single;
      expect(tras.state, PendingState.enCola);
      expect(tras.intentos, 1);
      expect(tras.ultimoError, contains('sin conexión'));
    });

    test('timeout: reintentable, no cuelga el motor', () async {
      final store = await almacenCon(['a']);
      final api = apiQue((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return ok201();
      });
      final motor = PendingUploader(
        store: store,
        api: api,
        timeout: const Duration(milliseconds: 20),
        reloj: () => reloj,
        random: Random(1),
      );

      final run = await motor.flush(accountId: cuenta);

      expect(run.fallidas, 1);
      final tras = (await store.list()).single;
      expect(tras.state, PendingState.enCola);
      expect(tras.ultimoError, contains('timeout'));
    });

    test('422: necesita atención y NO se borra (D1)', () async {
      final store = await almacenCon(['a']);
      final api = apiQue((_) async => http.Response('payload inválido', 422));

      final run = await uploader(store, api).flush(accountId: cuenta);

      expect(run.fallidas, 1);
      expect(run.pendientes, 1);
      final tras = (await store.list()).single;
      expect(tras.state, PendingState.necesitaAtencion);
      expect(tras.ultimoError, contains('422'));
      expect(await store.bytesOf('a'), isNotNull, reason: 'la foto se conserva');
    });

    test('una que necesita atención no atasca a las siguientes', () async {
      final store = await almacenCon(['mala', 'buena']);
      final api = apiQue((req) async {
        final payload = json.decode(
          (req as http.MultipartRequest).fields['payload']!,
        ) as Map<String, dynamic>;
        return payload['client_capture_id'] == 'mala'
            ? http.Response('no', 422)
            : ok201();
      });

      final run = await uploader(store, api).flush(accountId: cuenta);

      expect(run.subidas, 1);
      expect(run.fallidas, 1);
      expect((await store.list()).single.id, 'mala');
    });
  });

  group('AC9/AC17 — 401 conserva, 410 borra', () {
    test('401 pausa la pasada y NO borra nada', () async {
      final store = await almacenCon(['a', 'b']);
      final api = apiQue((_) async => http.Response('token inválido', 401));

      final run = await uploader(store, api).flush(accountId: cuenta);

      expect(run.sesionExpirada, isTrue);
      expect(run.seDetuvo, isTrue);
      expect(run.subidas, 0);
      expect(await store.count(), 2, reason: 'las dos siguen ahí');
      final tras = (await store.list()).first;
      expect(tras.state, PendingState.enCola);
      expect(tras.intentos, 0, reason: 'el problema es la sesión, no la captura');
      expect(tras.proximoIntento, isNull, reason: 'no se castiga con espera');
    });

    test('tras volver a entrar, la misma cola se sube', () async {
      final store = await almacenCon(['a', 'b']);
      var expirado = true;
      final api = apiQue(
        (_) async => expirado ? http.Response('token inválido', 401) : ok201(),
      );

      final primera = await uploader(store, api).flush(accountId: cuenta);
      expect(primera.sesionExpirada, isTrue);

      expirado = false; // el voluntario volvió a entrar
      final segunda = await uploader(store, api).flush(accountId: cuenta);

      expect(segunda.subidas, 2);
      expect(await store.count(), 0);
    });

    test('410 vacía la cola local (D6)', () async {
      final store = await almacenCon(['a', 'b']);
      final api = apiQue((_) async => http.Response('cuenta eliminada', 410));

      final run = await uploader(store, api).flush(accountId: cuenta);

      expect(run.cuentaEliminada, isTrue);
      expect(run.pendientes, 0);
      expect(await store.count(), 0);
      expect(await store.bytesOf('a'), isNull);
    });
  });

  group('casos límite', () {
    test('metadato sin imagen: necesita atención, no se borra', () async {
      // Escenario: el metadato está en el índice pero la foto ya no está en el
      // dispositivo (alguien limpió el almacenamiento por fuera de la app).
      final backend = InMemoryPendingBackend();
      await backend.writeIndex([captura('a').toJson()]); // índice sin blob
      final store = PendingCaptureStore(backend);
      await store.init();

      var llamadas = 0;
      final api = apiQue((_) async {
        llamadas++;
        return ok201();
      });
      final run = await uploader(store, api).flush(accountId: cuenta);

      expect(llamadas, 0, reason: 'no se intenta subir sin imagen');
      expect(run.pendientes, 1, reason: 'no se borra (D1)');
      expect((await store.list()).single.state, PendingState.necesitaAtencion);
    });

    test('D8: no sube una captura de otra cuenta', () async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();
      await store.save(captura('ajena', accountId: 'otra'), bytes);

      var llamadas = 0;
      final api = apiQue((_) async {
        llamadas++;
        return ok201();
      });
      final run = await uploader(store, api).flush(accountId: cuenta);

      expect(llamadas, 0);
      expect(run.pendientes, 1, reason: 'ni se sube ni se borra');
    });

    test('cola vacía: no llama al servidor', () async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();
      var llamadas = 0;
      final api = apiQue((_) async {
        llamadas++;
        return ok201();
      });

      final run = await uploader(store, api).flush(accountId: cuenta);

      expect(llamadas, 0);
      expect(run.subidas, 0);
      expect(run.pendientes, 0);
    });

    test('respeta el backoff: no reintenta antes de tiempo', () async {
      final store = await almacenCon(['a']);
      var llamadas = 0;
      final api = apiQue((_) async {
        llamadas++;
        return http.Response('boom', 503);
      });
      final motor = uploader(store, api);

      await motor.flush(accountId: cuenta);
      expect(llamadas, 1);
      // Misma hora: la captura está esperando su turno.
      await motor.flush(accountId: cuenta);
      expect(llamadas, 1, reason: 'no debe reintentar dentro de la espera');
    });
  });

  group('escalera de espera', () {
    test('crece con los intentos y no pasa del tope', () {
      final motor = PendingUploader(
        store: PendingCaptureStore(InMemoryPendingBackend()),
        api: apiQue((_) async => ok201()),
        random: Random(7),
      );

      final e1 = motor.esperaPara(1);
      final e2 = motor.esperaPara(2);
      final e5 = motor.esperaPara(5);
      final e50 = motor.esperaPara(50);

      expect(e1.inSeconds, greaterThanOrEqualTo(5));
      expect(e1 < e2, isTrue);
      expect(e2 < e5, isTrue);
      // Tope de 15 min + hasta 20 % de aleatoriedad.
      expect(e50.inMinutes, lessThanOrEqualTo(18));
      expect(e50.inMinutes, greaterThanOrEqualTo(15));
    });
  });
}
