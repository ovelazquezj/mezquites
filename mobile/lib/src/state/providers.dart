import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/google_auth_service.dart';
import '../services/session_store.dart';
import '../services/session_tracker.dart';
import '../theme/design_tokens.dart';
import 'app_config.dart';

/// Configuración (inyectable en pruebas vía override).
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// Tokens del design system, cargados del asset (override en pruebas).
final designTokensProvider = FutureProvider<DesignTokens>(
  (ref) => DesignTokens.load(),
);

/// Almacén de sesión local (override en pruebas).
final sessionStoreProvider = Provider<SessionStore>(
  (ref) => throw UnimplementedError('inyectar SessionStore en main()/pruebas'),
);

/// Estado del onboarding (CR-003): `true` = ya visto (no se vuelve a mostrar).
/// Informativo, omitible y una sola vez (gate #3); el flag es booleano local
/// sin PII (gate #2). Inicializa desde el [SessionStore] y persiste al marcarlo.
class OnboardingController extends StateNotifier<bool> {
  OnboardingController(this._store) : super(_store.onboardingSeen);

  final SessionStore _store;

  Future<void> markSeen() async {
    if (state) return;
    await _store.markOnboardingSeen();
    state = true;
  }
}

final onboardingSeenProvider =
    StateNotifierProvider<OnboardingController, bool>((ref) {
  return OnboardingController(ref.watch(sessionStoreProvider));
});

/// Cliente de la API REST.
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ApiClient(baseUrl: config.apiBaseUrl);
  ref.onDispose(client.close);
  return client;
});

/// Servicio de "Entrar con Google" (CR-002, sin Firebase), conmutable por `AUTH_MODE` (gate #6).
/// Por defecto MOCK (offline); con `AUTH_MODE=google` usa Google Identity Services. Override en pruebas.
final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.usesGoogleSignIn) {
    return GisGoogleAuthService();
  }
  return MockGoogleAuthService();
});

/// Resultado del intento de login social.
enum GoogleSignInOutcome { success, cancelled, error }

/// Rastreador de tiempo de sesión (CR-010 #7). Se arranca al hacer login y se
/// detiene (enviando el tramo en curso) al cerrar sesión.
final sessionTrackerProvider = Provider<SessionTracker>((ref) {
  return SessionTracker(ref.watch(apiClientProvider));
});

/// Estado de autenticación del voluntario (CR-002). Identidad real por Google; la app guarda solo
/// el handle de presentación + JWT (gate #2 acotado, sin email/nombre).
class AuthController extends StateNotifier<AuthSession?> {
  AuthController(this._api, this._google, this._store, this._tracker)
      : super(_store.loadSession()) {
    if (state != null) {
      _api.setToken(state!.token);
      // Sesión restaurada al arranque: empieza a contar tiempo (CR-010 #7).
      _tracker.start();
    }
  }

  final ApiClient _api;
  final GoogleAuthService _google;
  final SessionStore _store;
  final SessionTracker _tracker;

  /// "Entrar con Google": abre el flujo (móvil nativo / mock), manda el ID token al backend y guarda
  /// el JWT. Devuelve [GoogleSignInOutcome.cancelled] si el usuario cerró el diálogo de Google.
  /// En WEB-real el token llega por evento GIS; ver [completeGoogleSignIn].
  Future<GoogleSignInOutcome> signInWithGoogle({String? institutionId}) async {
    try {
      final idToken = await _google.signIn();
      if (idToken == null) return GoogleSignInOutcome.cancelled;
      return completeGoogleSignIn(idToken, institutionId: institutionId);
    } catch (_) {
      return GoogleSignInOutcome.error;
    }
  }

  /// Completa el login con un **ID token de Google ya obtenido**: lo manda al backend, guarda el JWT
  /// y arranca el conteo de sesión. Lo usa el flujo WEB (botón GIS), donde el token llega por
  /// `authenticationEvents` en vez de una llamada directa a `signIn()`.
  Future<GoogleSignInOutcome> completeGoogleSignIn(
    String idToken, {
    String? institutionId,
  }) async {
    try {
      final session = await _api.loginWithGoogle(
        idToken: idToken,
        institutionId: institutionId,
      );
      _api.setToken(session.token);
      await _store.saveSession(session);
      state = session;
      // Arranca el conteo de tiempo de sesión (CR-010 #7).
      _tracker.start();
      return GoogleSignInOutcome.success;
    } catch (_) {
      return GoogleSignInOutcome.error;
    }
  }

  Future<void> logout() async {
    // Cierra y envía el tramo de sesión en curso antes de soltar el token.
    await _tracker.stop();
    await _google.signOut();
    await _store.clearSession();
    _api.setToken(null);
    state = null;
  }
}

final authProvider =
    StateNotifierProvider<AuthController, AuthSession?>((ref) {
  return AuthController(
    ref.watch(apiClientProvider),
    ref.watch(googleAuthServiceProvider),
    ref.watch(sessionStoreProvider),
    ref.watch(sessionTrackerProvider),
  );
});

/// Cola local de observaciones "pendientes" (fire-and-forget, Q5.A).
///
/// Al enviar, encolamos localmente como `pending` y disparamos el POST sin
/// bloquear la UI. NUNCA reflejamos estado de validación individual (gate #9):
/// `pending` solo significa "aún en envío", no "en validación".
class PendingQueue extends StateNotifier<List<MineObservation>> {
  PendingQueue() : super(const []);

  void add(MineObservation obs) => state = [obs, ...state];

  void remove(String id) =>
      state = state.where((o) => o.observationId != id).toList();
}

final pendingQueueProvider =
    StateNotifierProvider<PendingQueue, List<MineObservation>>(
  (ref) => PendingQueue(),
);

// --- Datos remotos (FutureProviders) ---

final profileProvider = FutureProvider.autoDispose<Profile>(
  (ref) => ref.watch(apiClientProvider).profile(),
);

final feedbackProvider = FutureProvider.autoDispose<FeedbackAggregate>(
  (ref) => ref.watch(apiClientProvider).feedback(),
);

final myObservationsProvider =
    FutureProvider.autoDispose<List<MineObservation>>(
  (ref) => ref.watch(apiClientProvider).myObservations(),
);

final rankingsPeriodProvider = StateProvider<String>((ref) => 'all');

final rankingsProvider = FutureProvider.autoDispose<Rankings>((ref) {
  final period = ref.watch(rankingsPeriodProvider);
  return ref.watch(apiClientProvider).rankings(period: period);
});

final publicObservationsProvider =
    FutureProvider.autoDispose<List<PublicObservation>>(
  (ref) => ref.watch(apiClientProvider).publicObservations(),
);

final publicIndicatorsProvider = FutureProvider.autoDispose<Indicators>(
  (ref) => ref.watch(apiClientProvider).publicIndicators(),
);

/// Celdas del mapa de calor público (CR-009). Sin auth: alimenta la vista
/// "Mapa" (con o sin sesión). Celdas de binning de agregación (~300 m).
final publicGridProvider = FutureProvider.autoDispose<List<GridCell>>(
  (ref) => ref.watch(apiClientProvider).publicGrid(),
);

/// Comprobante de participación AGREGADO (CR-010 #7): capturas, horas, sesiones
/// y rango de fechas. Sin PII (gate #2); descriptivo (gate #1).
final evidenceProvider = FutureProvider.autoDispose<Evidence>(
  (ref) => ref.watch(apiClientProvider).evidence(),
);
