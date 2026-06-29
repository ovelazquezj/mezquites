import 'package:flutter/foundation.dart';

/// ¿La app corre en un navegador de **teléfono/tablet**? (detección por user-agent).
///
/// CR-018: esta señal **ya NO compuerta la cámara**. Antes deshabilitaba el botón de
/// captura cuando el user-agent no se reconocía como iOS/Android (algunos Honor caían
/// aquí ⇒ botón muerto). Ahora la captura web intenta `getUserMedia` en cualquier
/// dispositivo con soporte (ver `capture_service_web.dart` / `capture_pane_web.dart`),
/// así que nada se bloquea por UA (gate #3). Se conserva solo como pista informativa.
///
/// En web, Flutter fija `defaultTargetPlatform` según el `userAgent` del navegador
/// (iOS/Android en móvil; otro en escritorio). No usa `dart:html`, así que compila
/// en todas las plataformas (en nativo `kIsWeb` es `false`).
bool isMobileWebBrowser() =>
    kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);
