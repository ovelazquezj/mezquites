import 'package:web/web.dart' as web;

/// Implementación WEB del diagnóstico de dispositivo (CR-019): toma el user-agent del navegador
/// como dato técnico (gate #2: no es PII personal) y reporta la plataforma como `web`.
({String userAgent, String platform}) deviceDiagnostics() => (
      userAgent: web.window.navigator.userAgent,
      platform: 'web',
    );
