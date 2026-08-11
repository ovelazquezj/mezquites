import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/models/enums.dart';
import 'package:mezquite_app/src/services/pending/pending_backend_io.dart';
import 'package:mezquite_app/src/services/pending/pending_capture.dart';
import 'package:mezquite_app/src/services/pending/pending_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CR-031 W2 — almacén persistente de capturas.
///
/// La lógica de la cola (orden, estados, "nunca borrar solo") se prueba contra el
/// backend en memoria; el backend NATIVO se prueba contra un directorio temporal
/// real. El backend de IndexedDB —que es el de producción— no se puede ejercitar
/// aquí: `flutter test` corre sobre la VM de Dart, no en un navegador. Por eso la
/// costura de plataforma se dejó reducida a cuatro primitivas sin decisiones.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cuenta = 'cuenta-a';
  final bytes = Uint8List.fromList(List<int>.filled(64, 7));

  PendingCapture captura(
    String id, {
    required DateTime capturedAt,
    String accountId = cuenta,
  }) =>
      PendingCapture(
        id: id,
        accountId: accountId,
        lat: 21.88,
        lon: -102.29,
        capturedAt: capturedAt,
        nivelG4: 'leve',
        flagCuscuta: false,
        flagDanio: true,
        tamanio: 'mediano',
        contexto: 'campo_abierto',
        gpsAccuracyM: 8.0,
      );

  group('AC5 — la captura sobrevive al cierre de la app', () {
    test('el índice y la imagen se releen desde el mismo almacén', () async {
      final backend = InMemoryPendingBackend();
      final store = PendingCaptureStore(backend);
      await store.init();
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29, 10)), bytes);

      // Un "reinicio" = una instancia nueva sobre el MISMO almacén.
      final store2 = PendingCaptureStore(backend);
      await store2.init();
      final lista = await store2.list();

      expect(lista, hasLength(1));
      expect(lista.single.id, 'a');
      expect(await store2.bytesOf('a'), bytes);
    });

    test('la imagen se guarda de verdad, no solo el metadato', () async {
      final backend = InMemoryPendingBackend();
      final store = PendingCaptureStore(backend);
      await store.init();
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29)), bytes);
      expect(backend.blobsGuardados, 1);
    });

    test('guardar dos veces la misma captura no la duplica en la cola', () async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();
      final c = captura('a', capturedAt: DateTime(2026, 7, 29));
      await store.save(c, bytes);
      await store.save(c, bytes);
      expect(await store.count(), 1);
    });
  });

  group('AC6 — se sube en orden de captura', () {
    test('next() devuelve la más antigua, no la primera guardada', () async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();
      // Se guardan al revés a propósito.
      await store.save(captura('nueva', capturedAt: DateTime(2026, 7, 29, 18)), bytes);
      await store.save(captura('vieja', capturedAt: DateTime(2026, 7, 29, 9)), bytes);

      expect((await store.list()).map((c) => c.id), ['vieja', 'nueva']);
      expect((await store.next(accountId: cuenta))!.id, 'vieja');
    });

    test('respeta el backoff: no devuelve una cuyo próximo intento es futuro',
        () async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();
      final ahora = DateTime(2026, 7, 29, 12);
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29, 9)), bytes);
      await store.update(
        (await store.list()).single.copyWith(
              proximoIntento: ahora.add(const Duration(minutes: 5)),
            ),
      );

      expect(await store.next(accountId: cuenta, ahora: ahora), isNull);
      expect(
        (await store.next(
          accountId: cuenta,
          ahora: ahora.add(const Duration(minutes: 6)),
        ))!
            .id,
        'a',
      );
    });

    test('una que necesita atención no bloquea la cola', () async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();
      await store.save(captura('mala', capturedAt: DateTime(2026, 7, 29, 9)), bytes);
      await store.save(captura('buena', capturedAt: DateTime(2026, 7, 29, 10)), bytes);
      await store.update(
        (await store.list()).first.copyWith(state: PendingState.necesitaAtencion),
      );

      expect((await store.next(accountId: cuenta))!.id, 'buena');
      // Pero sigue contando como pendiente: el contador no miente (D5).
      expect(await store.count(), 2);
    });
  });

  group('D1 — nada se borra automáticamente', () {
    test('una captura que falla muchas veces sigue en la cola', () async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29)), bytes);

      for (var i = 1; i <= 25; i++) {
        await store.update(
          (await store.list()).single.copyWith(intentos: i, ultimoError: 'sin red'),
        );
      }

      final tras = await store.list();
      expect(tras, hasLength(1));
      expect(tras.single.intentos, 25);
      expect(await store.bytesOf('a'), isNotNull); // la foto tampoco se fue
    });

    test('delete() sí borra metadato e imagen (uso tras subida confirmada)',
        () async {
      final backend = InMemoryPendingBackend();
      final store = PendingCaptureStore(backend);
      await store.init();
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29)), bytes);
      await store.delete('a');

      expect(await store.count(), 0);
      expect(backend.blobsGuardados, 0);
    });
  });

  group('D6 — clearAll ante cuenta eliminada (410)', () {
    test('vacía metadatos e imágenes', () async {
      final backend = InMemoryPendingBackend();
      final store = PendingCaptureStore(backend);
      await store.init();
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29, 9)), bytes);
      await store.save(captura('b', capturedAt: DateTime(2026, 7, 29, 10)), bytes);

      await store.clearAll();

      expect(await store.count(), 0);
      expect(backend.blobsGuardados, 0);
    });
  });

  group('D8 — un dispositivo, un voluntario', () {
    test('no se sube una captura de otra cuenta, ni se borra', () async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();
      await store.save(
        captura('ajena', capturedAt: DateTime(2026, 7, 29, 9), accountId: 'otra'),
        bytes,
      );
      await store.save(captura('mia', capturedAt: DateTime(2026, 7, 29, 10)), bytes);

      // La ajena es más antigua, pero next() la salta: subirla la atribuiría a
      // quien tiene la sesión abierta.
      expect((await store.next(accountId: cuenta))!.id, 'mia');
      expect((await store.ajenas(cuenta)).map((c) => c.id), ['ajena']);
      expect(await store.count(), 2); // sigue ahí (D1)
    });
  });

  group('`subiendo` no sobrevive a un reinicio', () {
    test('init() devuelve a la cola lo que quedó marcado como subiendo', () async {
      final backend = InMemoryPendingBackend();
      final store = PendingCaptureStore(backend);
      await store.init();
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29)), bytes);
      await store.update(
        (await store.list()).single.copyWith(state: PendingState.subiendo),
      );

      // La app "muere" y vuelve a abrir.
      final store2 = PendingCaptureStore(backend);
      await store2.init();

      expect((await store2.list()).single.state, PendingState.enCola);
      expect((await store2.next(accountId: cuenta))!.id, 'a');
    });
  });

  group('serialización', () {
    test('ida y vuelta conserva las etiquetas y la hora de CAPTURA', () {
      final c = captura('a', capturedAt: DateTime.utc(2026, 7, 29, 15, 20)).copyWith(
        intentos: 3,
        ultimoError: 'timeout',
        state: PendingState.necesitaAtencion,
      );
      final ida = PendingCapture.fromJson(
        json.decode(json.encode(c.toJson())) as Map<String, dynamic>,
      );

      expect(ida.id, c.id);
      expect(ida.accountId, cuenta);
      expect(ida.capturedAt.toUtc(), DateTime.utc(2026, 7, 29, 15, 20));
      expect(ida.nivelG4, 'leve');
      expect(ida.flagDanio, isTrue);
      expect(ida.gpsAccuracyM, 8.0);
      expect(ida.intentos, 3);
      expect(ida.state, PendingState.necesitaAtencion);
    });

    test('AC7 — el borrador rehidratado lleva la hora de captura, no la de subida',
        () {
      final capturadaEl = DateTime.utc(2026, 7, 29, 9, 30);
      final draft = captura('a', capturedAt: capturadaEl).toDraft(bytes);

      expect(draft.capturedAt, capturadaEl);
      expect(draft.toPayloadJson()['captured_at'], '2026-07-29T09:30:00.000Z');
      // Y lleva el sello de idempotencia que espera el backend (W1).
      expect(draft.toPayloadJson()['client_capture_id'], 'a');
      expect(draft.nivelG4, NivelG4.leve);
      expect(draft.tamanio, Tamanio.mediano);
      expect(draft.contexto, Contexto.campoAbierto);
      expect(draft.imageBytes, bytes);
    });

    test('un índice ilegible no tumba el arranque', () {
      expect(decodeIndex('esto no es json'), isEmpty);
      expect(decodeIndex(null), isEmpty);
      expect(decodeIndex('{"no":"es una lista"}'), isEmpty);
    });

    test('una entrada corrupta no esconde a las demás', () async {
      final backend = InMemoryPendingBackend();
      await backend.writeIndex([
        {'id': 'corrupta'}, // le faltan campos obligatorios
        captura('buena', capturedAt: DateTime(2026, 7, 29)).toJson(),
      ]);
      final store = PendingCaptureStore(backend);
      await store.init();

      expect((await store.list()).map((c) => c.id), ['buena']);
    });
  });

  group('client_capture_id', () {
    test('tiene forma de UUID v4 y no se repite', () {
      final ids = {for (var i = 0; i < 200; i++) nuevoClientCaptureId()};
      expect(ids, hasLength(200));
      final uuidV4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      for (final id in ids) {
        expect(uuidV4.hasMatch(id), isTrue, reason: '$id no es UUID v4');
      }
    });
  });

  group('diagnóstico para "Reportar un problema" (AC21)', () {
    test('resume pendientes, atención, intentos y persistencia, sin PII', () async {
      final store = PendingCaptureStore(InMemoryPendingBackend());
      await store.init();
      await store.save(captura('a', capturedAt: DateTime.utc(2026, 7, 29, 9)), bytes);
      await store.save(captura('b', capturedAt: DateTime.utc(2026, 7, 29, 10)), bytes);
      await store.update(
        (await store.list()).first.copyWith(
              state: PendingState.necesitaAtencion,
              intentos: 4,
              ultimoError: 'HTTP 422',
            ),
      );

      final d = await store.diagnostico();
      expect(d['pendientes'], 2);
      expect(d['necesitan_atencion'], 1);
      expect(d['intentos_maximos'], 4);
      expect(d['ultimo_error'], 'HTTP 422');
      expect(d['almacenamiento_persistente'], isFalse); // backend en memoria
      expect(d['mas_antigua'], '2026-07-29T09:00:00.000Z');
      // Gate #2: nada de identidad en el diagnóstico.
      expect(d.keys, isNot(contains('account_id')));
      expect(json.encode(d), isNot(contains(cuenta)));
    });
  });

  group('backend NATIVO sobre un directorio real', () {
    late Directory temp;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      temp = await Directory.systemTemp.createTemp('mezquite-pendientes-test');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('escribe el JPEG en disco y lo relee', () async {
      final backend = IoPendingBackend(
        directorio: temp,
        prefs: await SharedPreferences.getInstance(),
      );
      final store = PendingCaptureStore(backend);
      await store.init();
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29)), bytes);

      final archivo = File('${temp.path}${Platform.pathSeparator}pendientes'
          '${Platform.pathSeparator}a.jpg');
      expect(await archivo.exists(), isTrue, reason: 'la foto debe estar en disco');
      expect(await archivo.readAsBytes(), bytes);
      expect(await store.bytesOf('a'), bytes);
      expect(backend.persistente, isTrue);
    });

    test('sobrevive a un reinicio con el mismo directorio y prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = PendingCaptureStore(
        IoPendingBackend(directorio: temp, prefs: prefs),
      );
      await store.init();
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29)), bytes);

      final store2 = PendingCaptureStore(
        IoPendingBackend(directorio: temp, prefs: prefs),
      );
      await store2.init();

      expect((await store2.list()).single.id, 'a');
      expect(await store2.bytesOf('a'), bytes);
    });

    test('delete() borra también el archivo', () async {
      final prefs = await SharedPreferences.getInstance();
      final store = PendingCaptureStore(
        IoPendingBackend(directorio: temp, prefs: prefs),
      );
      await store.init();
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29)), bytes);
      await store.delete('a');

      final archivo = File('${temp.path}${Platform.pathSeparator}pendientes'
          '${Platform.pathSeparator}a.jpg');
      expect(await archivo.exists(), isFalse);
      expect(await store.count(), 0);
    });

    test('bytesOf devuelve null si el archivo ya no está (no revienta)', () async {
      final prefs = await SharedPreferences.getInstance();
      final backend = IoPendingBackend(directorio: temp, prefs: prefs);
      final store = PendingCaptureStore(backend);
      await store.init();
      await store.save(captura('a', capturedAt: DateTime(2026, 7, 29)), bytes);
      // Alguien limpió el almacenamiento del teléfono por fuera de la app.
      await backend.deleteBlob('a');

      expect(await store.bytesOf('a'), isNull);
      expect(await store.count(), 1); // el metadato sigue: no se pierde en silencio
    });
  });
}
