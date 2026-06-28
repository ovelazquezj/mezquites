import 'package:google_sign_in/google_sign_in.dart';

/// Servicio de "Entrar con Google" (CR-002), SIN Firebase: usa **Google Identity Services (GIS)**.
/// El OAuth se configuró directo en Google Cloud (APIs y servicios), no en Firebase.
///
/// Devuelve un **ID token de Google** (`iss=accounts.google.com`, `aud=Web Client ID`) que el backend
/// verifica (`POST /auth/google`). La app NO lee ni guarda email/nombre del usuario de Google
/// (gate #2 acotado): solo entrega el ID token y persiste el JWT + el handle de presentación que
/// devuelve el backend.
///
/// Dos implementaciones, seleccionadas por `AppConfig.usesGoogleSignIn`:
/// - [MockGoogleAuthService] (por defecto): offline, sin red. Devuelve un token de prueba
///   (`mock:<sub>`) que el MockAuthProvider del backend acepta. Permite compilar y correr los tests
///   SIN proyecto real (gate #6).
/// - [GisGoogleAuthService] (real): Google Identity Services. En **móvil nativo** usa
///   `authenticate()`. En **WEB** NO se usa `signIn()`: el login va por el botón GIS (`renderButton`)
///   + `authenticationEvents` (ver `WelcomeScreen`), porque GIS no permite iniciar sesión desde una
///   UI propia en el navegador.
abstract class GoogleAuthService {
  /// Inicia el flujo de Google y devuelve el ID token, o `null` si el usuario canceló.
  Future<String?> signIn();

  /// Cierra la sesión del proveedor (no toca el JWT del backend).
  Future<void> signOut();
}

/// Implementación de prueba/dev: sin red, sin Google. Determinista.
class MockGoogleAuthService implements GoogleAuthService {
  MockGoogleAuthService({this.subject = 'demo'});

  /// `sub` opaco simulado; el token resultante es `mock:<subject>`.
  final String subject;

  @override
  Future<String?> signIn() async => 'mock:$subject';

  @override
  Future<void> signOut() async {}
}

/// Implementación real con Google Identity Services (sin Firebase).
///
/// NOTA: en WEB el login se hace con el botón GIS (`renderButton`) + `authenticationEvents`
/// (ver `WelcomeScreen`); `signIn()` aquí es el camino de **móvil nativo** (`authenticate()`),
/// que no se compila/usa en el build web actual.
class GisGoogleAuthService implements GoogleAuthService {
  @override
  Future<String?> signIn() async {
    // Móvil nativo: dispara el flujo de Google y devuelve el ID token. En WEB esta llamada no se
    // usa (GIS no permite `authenticate()` desde el navegador; se usa el botón renderizado).
    final account = await GoogleSignIn.instance.authenticate();
    return account.authentication.idToken;
  }

  @override
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
  }
}
