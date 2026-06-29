/// Diagnóstico de dispositivo SIN PII (CR-019): identifica navegador/plataforma para los reportes
/// de problemas. Gate #2: nunca recoge email/nombre; el user-agent es metadato técnico aceptable.
///
/// Import condicional (igual que `pwa_install.dart`): en web usa `package:web`
/// (`navigator.userAgent`); fuera de web (móvil nativo / `flutter test`) el stub reporta la
/// plataforma de Flutter y deja el user-agent vacío.
library;

export 'device_diagnostics_stub.dart'
    if (dart.library.js_interop) 'device_diagnostics_web.dart';
