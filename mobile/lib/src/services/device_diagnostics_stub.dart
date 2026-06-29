import 'package:flutter/foundation.dart' show defaultTargetPlatform;

/// Stub no-web del diagnóstico de dispositivo (CR-019): fuera del navegador no hay user-agent,
/// así que va vacío y la plataforma es la de Flutter (`android`/`ios`/...). Mantiene los tests de
/// VM compilando/corriendo.
({String userAgent, String platform}) deviceDiagnostics() => (
      userAgent: '',
      platform: defaultTargetPlatform.name,
    );
