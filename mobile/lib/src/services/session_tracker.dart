import 'package:flutter/widgets.dart';

import '../api/api_client.dart';

/// Rastrea el **tiempo de sesión** del voluntario (CR-010 #7) usando el ciclo
/// de vida de la app: cuenta el tiempo en *foreground* entre inicio/fin de
/// sesión o entre `resumed` y `paused/inactive`, y lo envía a
/// `POST /me/sessions` `{started_at, ended_at}`.
///
/// Gate #2: solo viajan tiempos (el backend asocia por la cuenta del token);
/// nunca PII. Fire-and-forget: un fallo de red NO interrumpe al usuario.
///
/// Reloj inyectable ([now]) para pruebas deterministas.
class SessionTracker with WidgetsBindingObserver {
  SessionTracker(this._api, {DateTime Function()? now, this.sesionVencida})
      : _now = now ?? DateTime.now;

  final ApiClient _api;
  final DateTime Function() _now;

  /// CR-035: con la sesión vencida no tiene sentido enviar el tramo — el
  /// backend lo rechazaría con otro 401. El **primer** 401 sí llega a pasar
  /// (ese POST es un disparador reactivo válido del aviso de sesión); con el
  /// flag ya encendido se deja de hacer ruido. Tras volver a entrar el flag se
  /// apaga y el envío se reanuda solo.
  final bool Function()? sesionVencida;

  /// Inicio del tramo de foreground en curso (null = no hay tramo abierto).
  DateTime? _segmentStart;

  /// Tramos abiertos cuando hay login; cerrados/enviados al pausar o cerrar
  /// sesión. Para pruebas: el último rango enviado.
  ({DateTime startedAt, DateTime endedAt})? lastSent;

  bool _active = false;

  /// ¿Hay un tramo de foreground abierto? (visible para pruebas).
  bool get isOpen => _segmentStart != null;

  /// Empieza a rastrear (llamar tras un login exitoso). Registra el observer
  /// del ciclo de vida y abre el primer tramo.
  void start() {
    if (_active) return;
    _active = true;
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  /// Detiene el rastreo (llamar al cerrar sesión): cierra y envía el tramo
  /// abierto y se desregistra del ciclo de vida.
  Future<void> stop() async {
    if (!_active) return;
    await _close();
    WidgetsBinding.instance.removeObserver(this);
    _active = false;
  }

  void _open() {
    _segmentStart ??= _now();
  }

  /// Cierra el tramo abierto y lo envía. No lanza: el fallo de red es silencioso.
  Future<void> _close() async {
    final start = _segmentStart;
    if (start == null) return;
    _segmentStart = null;
    final end = _now();
    // Tramos de duración no positiva no se envían (ruido).
    if (!end.isAfter(start)) return;
    // Sesión vencida: el tramo se cierra pero NO se envía (CR-035). El tiempo
    // se pierde — aceptable, la sesión es inválida.
    if (sesionVencida?.call() == true) return;
    lastSent = (startedAt: start, endedAt: end);
    try {
      await _api.postSession(startedAt: start, endedAt: end);
    } catch (_) {
      // Fire-and-forget: el tiempo se pierde, pero no se interrumpe al usuario.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_active) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _open();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Cierra y envía el tramo en foreground (no esperamos el future aquí).
        _close();
        break;
    }
  }
}
