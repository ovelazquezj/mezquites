import 'dart:async';
import 'dart:math';

import '../../api/api_client.dart';
import '../../api/api_exception.dart';
import 'pending_capture.dart';
import 'pending_store.dart';

/// Cómo terminó un intento de subida (CR-031 W3).
enum UploadOutcome {
  /// El servidor la aceptó (201) o reconoció el reintento (200 + `ya_existia`).
  /// En los dos casos la captura ya está a salvo y se borra del teléfono.
  guardadaEnServidor,

  /// Falló por algo que puede arreglarse solo: sin red, timeout, 5xx, 429.
  /// Vuelve a la cola con espera creciente.
  reintentable,

  /// El servidor la rechazó por el contenido (422). Reintentar no cambiaría nada.
  /// Se marca y **no se borra** (decisión D1).
  necesitaAtencion,

  /// 401: la sesión venció. La cola se **pausa** y se conserva intacta.
  sesionExpirada,

  /// 410: la cuenta ya no existe (cancelación ARCO). La cola local se **borra**
  /// (decisión D6).
  cuentaEliminada,
}

/// Resumen de una pasada del motor.
class UploadRun {
  const UploadRun({
    required this.subidas,
    required this.fallidas,
    required this.pendientes,
    this.sesionExpirada = false,
    this.cuentaEliminada = false,
  });

  final int subidas;
  final int fallidas;

  /// Cuántas quedan en el dispositivo al terminar la pasada.
  final int pendientes;

  final bool sesionExpirada;
  final bool cuentaEliminada;

  bool get seDetuvo => sesionExpirada || cuentaEliminada;
}

/// Sube las capturas guardadas, en serie y en orden de captura (CR-031 W3).
///
/// Reglas que implementa (y que las pruebas fijan):
///
/// - **Una a la vez.** Un teléfono en campo tiene poco enlace de subida; lanzar
///   varias en paralelo alarga todas y no acelera ninguna.
/// - **Espera creciente** entre reintentos (5 s → 15 s → 1 min → 5 min → 15 min,
///   con tope y un poco de aleatoriedad) para no machacar la red ni la batería.
/// - **Clasifica el error en vez de tragárselo.** Es la corrección de fondo: antes,
///   `.catchError((_) {})` hacía que cualquier fallo desapareciera sin rastro.
/// - **Nunca borra por un fallo.** Solo se borra tras confirmación del servidor
///   (D1). Un 401 pausa; un 410 —y solo un 410— vacía la cola (D6).
/// - **Timeout propio.** El cliente HTTP no lo trae; sin él, una subida colgada
///   dejaría el motor bloqueado para siempre.
///
/// No depende de Riverpod ni de Flutter: se prueba con un cliente HTTP simulado y
/// un reloj inyectado.
class PendingUploader {
  PendingUploader({
    required PendingCaptureStore store,
    required ApiClient api,
    Duration timeout = const Duration(seconds: 60),
    DateTime Function()? reloj,
    Random? random,
  })  : _store = store,
        _api = api,
        _timeout = timeout,
        _reloj = reloj ?? DateTime.now,
        _random = random ?? Random();

  final PendingCaptureStore _store;
  final ApiClient _api;
  final Duration _timeout;
  final DateTime Function() _reloj;
  final Random _random;

  bool _enCurso = false;

  /// True mientras hay una pasada en marcha (lo usa la UI para el indicador).
  bool get enCurso => _enCurso;

  /// Escalera de espera por nº de intentos ya fallidos.
  ///
  /// El primer reintento es rápido (5 s) porque el caso más común es un bache de
  /// segundos; a partir de ahí crece para que un voluntario sin señal durante horas
  /// no gaste batería intentando cada 5 segundos. El tope es 15 min: más allá, la
  /// app ya se habrá reabierto o habrá vuelto a primer plano, y eso también dispara
  /// una pasada.
  static const escaleraEspera = <Duration>[
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  Duration esperaPara(int intentos) {
    final i = intentos <= 0 ? 0 : intentos - 1;
    final base = escaleraEspera[i.clamp(0, escaleraEspera.length - 1)];
    // Aleatoriedad de hasta un 20 %: si varios voluntarios pierden la red al mismo
    // tiempo (un camión saliendo de cobertura), no vuelven todos en el mismo
    // instante.
    final jitter = (base.inMilliseconds * 0.2 * _random.nextDouble()).round();
    return base + Duration(milliseconds: jitter);
  }

  /// Intenta subir **todas** las pendientes de [accountId], en orden de captura.
  ///
  /// Devuelve un resumen. Es reentrante-segura: si ya hay una pasada en curso,
  /// devuelve el estado actual sin lanzar otra.
  Future<UploadRun> flush({required String accountId}) async {
    if (_enCurso) {
      return UploadRun(
        subidas: 0,
        fallidas: 0,
        pendientes: await _store.count(),
      );
    }
    _enCurso = true;
    var subidas = 0;
    var fallidas = 0;
    try {
      while (true) {
        final siguiente = await _store.next(accountId: accountId, ahora: _reloj());
        if (siguiente == null) break;

        final resultado = await _intentar(siguiente);
        if (resultado == UploadOutcome.guardadaEnServidor) {
          subidas++;
          continue;
        }
        if (resultado == UploadOutcome.cuentaEliminada) {
          // D6: esa cuenta pidió dejar de existir; sus capturas no se conservan.
          await _store.clearAll();
          return UploadRun(
            subidas: subidas,
            fallidas: fallidas,
            pendientes: 0,
            cuentaEliminada: true,
          );
        }
        if (resultado == UploadOutcome.sesionExpirada) {
          // La cola queda intacta: perder capturas por un token vencido sería el
          // mismo error de antes con otro disfraz.
          return UploadRun(
            subidas: subidas,
            fallidas: fallidas,
            pendientes: await _store.count(),
            sesionExpirada: true,
          );
        }
        fallidas++;
        // Reintentable o necesita atención: en ambos casos deja de ser elegible
        // ahora mismo, así que el bucle avanzará a la siguiente o terminará.
      }
    } finally {
      _enCurso = false;
    }
    return UploadRun(
      subidas: subidas,
      fallidas: fallidas,
      pendientes: await _store.count(),
    );
  }

  /// Un intento sobre una captura concreta. Deja el almacén consistente siempre.
  Future<UploadOutcome> _intentar(PendingCapture captura) async {
    final bytes = await _store.bytesOf(captura.id);
    if (bytes == null) {
      // Metadato sin imagen: no hay nada que subir y reintentar no la va a traer.
      // No se borra (D1): queda visible en el contador y en el diagnóstico.
      await _store.update(
        captura.copyWith(
          state: PendingState.necesitaAtencion,
          ultimoError: 'falta la imagen en el dispositivo',
          limpiarProximoIntento: true,
        ),
      );
      return UploadOutcome.necesitaAtencion;
    }

    await _store.update(captura.copyWith(state: PendingState.subiendo));

    try {
      await _api.submitObservation(captura.toDraft(bytes)).timeout(_timeout);
      // 201 o 200+ya_existia: en ambos casos ya está en el servidor.
      await _store.delete(captura.id);
      return UploadOutcome.guardadaEnServidor;
    } on ApiException catch (e) {
      return _clasificarHttp(captura, e);
    } catch (e) {
      // Sin red, DNS, timeout, socket cerrado: el caso de campo. Reintentable.
      return _marcarReintentable(captura, _resumirError(e));
    }
  }

  Future<UploadOutcome> _clasificarHttp(
    PendingCapture captura,
    ApiException e,
  ) async {
    if (e.statusCode == 401) {
      // Vuelve a la cola tal cual: ni intentos ni espera, porque el problema no es
      // esta captura sino la sesión.
      await _store.update(
        captura.copyWith(
          state: PendingState.enCola,
          ultimoError: 'sesión vencida (401)',
          limpiarProximoIntento: true,
        ),
      );
      return UploadOutcome.sesionExpirada;
    }
    if (e.statusCode == 410) {
      return UploadOutcome.cuentaEliminada;
    }
    if (e.statusCode == 422 || e.statusCode == 400 || e.statusCode == 403) {
      // El servidor no la quiere por su contenido o por permisos: reintentar
      // idéntico no cambia nada.
      await _store.update(
        captura.copyWith(
          state: PendingState.necesitaAtencion,
          intentos: captura.intentos + 1,
          ultimoError: 'el servidor la rechazó (HTTP ${e.statusCode})',
          limpiarProximoIntento: true,
        ),
      );
      return UploadOutcome.necesitaAtencion;
    }
    // 5xx, 429 y cualquier otro: puede arreglarse solo.
    return _marcarReintentable(captura, 'HTTP ${e.statusCode}');
  }

  Future<UploadOutcome> _marcarReintentable(
    PendingCapture captura,
    String error,
  ) async {
    final intentos = captura.intentos + 1;
    await _store.update(
      captura.copyWith(
        state: PendingState.enCola,
        intentos: intentos,
        ultimoError: error,
        proximoIntento: _reloj().add(esperaPara(intentos)),
      ),
    );
    return UploadOutcome.reintentable;
  }

  /// Mensaje corto y sin datos personales para el diagnóstico.
  String _resumirError(Object e) {
    if (e is TimeoutException) return 'timeout de subida';
    final texto = e.runtimeType.toString();
    return 'sin conexión ($texto)';
  }
}
