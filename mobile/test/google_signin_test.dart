import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mezquite_app/src/api/api_client.dart';
import 'package:mezquite_app/src/services/google_auth_service.dart';
import 'package:mezquite_app/src/services/session_store.dart';
import 'package:mezquite_app/src/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CR-002 — AC6: "Entrar con Google" (flujo mockeado). La app NO tiene código de respaldo ni QR.

/// Servicio de Google falso: devuelve un ID token fijo o simula cancelación.
class FakeGoogleAuthService implements GoogleAuthService {
  FakeGoogleAuthService({this.idToken = 'mock:tester'});
  final String? idToken;
  int signInCalls = 0;
  int signOutCalls = 0;

  @override
  Future<String?> signIn() async {
    signInCalls++;
    return idToken;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SessionStore> freshStore() async {
    SharedPreferences.setMockInitialValues({});
    return SessionStore.create();
  }

  test('signInWithGoogle manda el id_token y persiste la sesión (AC6)', () async {
    final store = await freshStore();
    final google = FakeGoogleAuthService(idToken: 'mock:tester');
    late http.Request captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(
        json.encode({'handle': 'obs-XYZ', 'role': 'voluntario', 'token': 'tk'}),
        200,
      );
    });
    final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);
    final controller = AuthController(api, google, store);

    final outcome = await controller.signInWithGoogle();
    expect(outcome, GoogleSignInOutcome.success);
    expect(google.signInCalls, 1);
    expect(captured.url.path, '/api/v1/auth/google');
    final body = json.decode(captured.body) as Map<String, dynamic>;
    expect(body['id_token'], 'mock:tester');
    // No PII en el cuerpo.
    expect(body.containsKey('email'), isFalse);
    expect(body.containsKey('name'), isFalse);
    // La sesión persistida solo lleva handle/role/token.
    expect(controller.state?.handle, 'obs-XYZ');
    expect(store.loadSession()?.token, 'tk');
  });

  test('cancelar el diálogo de Google no autentica (sin error)', () async {
    final store = await freshStore();
    final google = FakeGoogleAuthService(idToken: null); // canceló
    final mock = MockClient((req) async => http.Response('{}', 200));
    final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);
    final controller = AuthController(api, google, store);

    final outcome = await controller.signInWithGoogle();
    expect(outcome, GoogleSignInOutcome.cancelled);
    expect(controller.state, isNull);
  });

  test('error de red devuelve outcome.error sin autenticar', () async {
    final store = await freshStore();
    final google = FakeGoogleAuthService(idToken: 'mock:tester');
    final mock = MockClient((req) async => http.Response('boom', 500));
    final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);
    final controller = AuthController(api, google, store);

    final outcome = await controller.signInWithGoogle();
    expect(outcome, GoogleSignInOutcome.error);
    expect(controller.state, isNull);
  });

  test('logout cierra Google y limpia la sesión', () async {
    final store = await freshStore();
    final google = FakeGoogleAuthService(idToken: 'mock:tester');
    final mock = MockClient(
      (req) async => http.Response(
        json.encode({'handle': 'obs-A', 'role': 'voluntario', 'token': 'tk'}),
        200,
      ),
    );
    final api = ApiClient(baseUrl: 'http://x/api/v1', httpClient: mock);
    final controller = AuthController(api, google, store);

    await controller.signInWithGoogle();
    await controller.logout();
    expect(google.signOutCalls, 1);
    expect(controller.state, isNull);
    expect(store.loadSession(), isNull);
  });

  test('MockGoogleAuthService devuelve un token mock determinista (offline, gate #6)',
      () async {
    final svc = MockGoogleAuthService(subject: 'alice');
    expect(await svc.signIn(), 'mock:alice');
  });
}
