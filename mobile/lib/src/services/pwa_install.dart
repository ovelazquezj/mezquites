/// Servicio de instalación PWA (CR-016): expone si la app puede instalarse y lanza el diálogo.
///
/// Import condicional: en web usa `dart:js_interop` (captura de `beforeinstallprompt`); fuera de web
/// (móvil nativo / `flutter test`) usa el stub que reporta "no disponible".
library;

export 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart';
