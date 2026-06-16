import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Servicio de "Entrar con Google" (CR-002), CONMUTABLE (salvaguarda gate #6).
///
/// Devuelve un **ID token** que el backend verifica (`POST /auth/google`). La app NO lee ni guarda
/// email/nombre del usuario de Google (gate #2 acotado): solo entrega el ID token y persiste el JWT
/// + el handle de presentación que devuelve el backend.
///
/// Dos implementaciones, seleccionadas por `AppConfig.authMode`:
/// - [MockGoogleAuthService] (por defecto): offline, sin red ni `google-services.json`. Devuelve un
///   token de prueba (`mock:<sub>`) que el MockAuthProvider del backend acepta. Permite compilar y
///   correr `flutter build apk` / los tests SIN un proyecto Firebase real.
/// - [FirebaseGoogleAuthService] (real): usa Firebase Auth + Google Sign-In. Requiere los
///   prerrequisitos del usuario (proyecto Firebase, `google-services.json`, huellas SHA).
abstract class GoogleAuthService {
  /// Inicia el flujo de Google y devuelve el ID token, o `null` si el usuario canceló.
  Future<String?> signIn();

  /// Cierra la sesión del proveedor (no toca el JWT del backend).
  Future<void> signOut();
}

/// Implementación de prueba/dev: sin red, sin Firebase. Determinista.
class MockGoogleAuthService implements GoogleAuthService {
  MockGoogleAuthService({this.subject = 'demo'});

  /// `sub` opaco simulado; el token resultante es `mock:<subject>`.
  final String subject;

  @override
  Future<String?> signIn() async => 'mock:$subject';

  @override
  Future<void> signOut() async {}
}

/// Implementación real con Firebase Auth + Google Sign-In.
///
/// NOTA: se construye solo cuando `AUTH_MODE=firebase` y la init de Firebase ya ocurrió (ver
/// `main.dart`). No se referencia en el camino por defecto, así que el modo mock no necesita
/// `google-services.json`.
class FirebaseGoogleAuthService implements GoogleAuthService {
  FirebaseGoogleAuthService({GoogleSignIn? googleSignIn, FirebaseAuth? auth})
      : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']),
        _auth = auth ?? FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn;
  final FirebaseAuth _auth;

  @override
  Future<String?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // el usuario canceló
    final googleAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    // Entregamos el ID token de Firebase para que el backend lo verifique (aud/iss/sub).
    return userCredential.user?.getIdToken();
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
