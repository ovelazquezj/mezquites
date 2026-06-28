/// Botón oficial de "Entrar con Google" (Google Identity Services) — SOLO web.
///
/// En web, GIS obliga a usar el botón que renderiza su propio SDK (`renderButton`); no se puede
/// iniciar sesión desde un botón propio. Fuera de web (móvil nativo / `flutter test`) devuelve un
/// widget vacío: el login nativo va por `GoogleAuthService.signIn()`.
///
/// Import condicional para NO arrastrar `package:google_sign_in_web/web_only.dart` en builds no-web
/// ni en las pruebas (que corren en la VM de Dart, no en navegador).
library;

export 'google_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart';
