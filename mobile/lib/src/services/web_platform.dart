import 'package:flutter/foundation.dart';

/// ¿La app corre en un navegador de **teléfono/tablet**? (CR-005, gate #4 W0=a).
///
/// En web, Flutter fija `defaultTargetPlatform` según el `userAgent` del navegador
/// (iOS/Android en móvil; otro en escritorio). No usa `dart:html`, así que compila
/// en todas las plataformas (en nativo `kIsWeb` es `false`).
bool isMobileWebBrowser() =>
    kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);
