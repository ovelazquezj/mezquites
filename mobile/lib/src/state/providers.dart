import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/google_auth_service.dart';
import '../services/pending/pending_capture.dart';
import '../services/pending/pending_store.dart';
import '../services/pending/pending_uploader.dart';
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

/// Almacén persistente de capturas pendientes (CR-031). Se inyecta desde `main()`
/// porque su apertura es asíncrona, igual que [sessionStoreProvider].
final pendingStoreProvider = Provider<PendingCaptureStore>(
  (ref) => throw UnimplementedError(
    'inyectar PendingCaptureStore en main()/pruebas',
  ),
);

/// Motor de subida (CR-031 W3).
final pendingUploaderProvider = Provider<PendingUploader>((ref) {
  return PendingUploader(
    store: ref.watch(pendingStoreProvider),
    api: ref.watch(apiClientProvider),
  );
});

/// Lo que la UI necesita saber de la cola (CR-031). Decisión **D5**: solo cifras,
/// sin lista por foto.
class PendingQueueState {
  const PendingQueueState({
    this.pendientes = 0,
    this.necesitanAtencion = 0,
    this.subiendo = false,
    this.sesionExpirada = false,
  });

  /// Total por subir. Incluye las que necesitan atención: el número no miente.
  final int pendientes;

  final int necesitanAtencion;
  final bool subiendo;

  /// True tras un 401. La cola **sigue intacta**; solo hace falta volver a entrar.
  final bool sesionExpirada;

  bool get hayPendientes => pendientes > 0;

  PendingQueueState copyWith({
    int? pendientes,
    int? necesitanAtencion,
    bool? subiendo,
    bool? sesionExpirada,
  }) =>
      PendingQueueState(
        pendientes: pendientes ?? this.pendientes,
        necesitanAtencion: necesitanAtencion ?? this.necesitanAtencion,
        subiendo: subiendo ?? this.subiendo,
        sesionExpirada: sesionExpirada ?? this.sesionExpirada,
      );
}

/// Guarda las capturas y las va subiendo (CR-031). Sustituye a la `PendingQueue`
/// en memoria que nadie leía y que perdía la foto al cerrar la app.
class PendingQueueController extends StateNotifier<PendingQueueState> {
  PendingQueueController({
    required PendingCaptureStore store,
    required PendingUploader uploader,
    required String? Function() accountId,
    required void Function() onCuentaEliminada,
  })  : _store = store,
        _uploader = uploader,
        _accountId = accountId,
        _onCuentaEliminada = onCuentaEliminada,
        super(const PendingQueueState());

  final PendingCaptureStore _store;
  final PendingUploader _uploader;
  final String? Function() _accountId;
  final void Function() _onCuentaEliminada;

  /// Relee las cifras del almacén (no toca la red).
  Future<void> refresh() async {
    final capturas = await _store.list();
    if (!mounted) return;
    state = state.copyWith(
      pendientes: capturas.length,
      necesitanAtencion: capturas
          .where((c) => c.state == PendingState.necesitaAtencion)
          .length,
    );
  }

  /// Guarda una captura recién tomada y dispara la subida.
  ///
  /// Devuelve `true` si el servidor la confirmó en el acto; `false` si quedó
  /// guardada esperando conexión. El llamador usa eso para decir la verdad en
  /// pantalla en vez de dar por buena una subida que no ocurrió.
  Future<bool> registrar(ObservationDraft draft) async {
    final cuenta = _accountId();
    final captura = PendingCapture.fromDraft(
      draft,
      id: draft.clientCaptureId ?? nuevoClientCaptureId(),
      accountId: cuenta ?? '',
    );
    final bytes = draft.imageBytes;
    if (bytes == null) {
      // No debería pasar: la captura web y la nativa entregan bytes. Si pasa, es
      // mejor fallar visiblemente que perder la foto en silencio.
      throw StateError('la captura no trae bytes de imagen');
    }
    await _store.save(captura, bytes);
    await refresh();
    final run = await subirAhora();
    return run != null && run.subidas > 0;
  }

  /// Fuerza una pasada del motor. `null` si no hay sesión.
  Future<UploadRun?> subirAhora() async {
    final cuenta = _accountId();
    if (cuenta == null) return null;
    state = state.copyWith(subiendo: true);
    UploadRun run;
    try {
      run = await _uploader.flush(accountId: cuenta);
    } finally {
      if (mounted) state = state.copyWith(subiendo: false);
    }
    if (!mounted) return run;
    if (run.cuentaEliminada) {
      // D6: la cola ya la vació el motor; aquí se cierra la sesión.
      state = const PendingQueueState();
      _onCuentaEliminada();
      return run;
    }
    state = state.copyWith(sesionExpirada: run.sesionExpirada);
    await refresh();
    return run;
  }

  /// Tras volver a entrar: se limpia el aviso y se reintenta.
  Future<void> sesionRenovada() async {
    if (mounted) state = state.copyWith(sesionExpirada: false);
    await subirAhora();
  }
}

final pendingQueueProvider =
    StateNotifierProvider<PendingQueueController, PendingQueueState>((ref) {
  final controller = PendingQueueController(
    store: ref.watch(pendingStoreProvider),
    uploader: ref.watch(pendingUploaderProvider),
    accountId: () => ref.read(authProvider)?.accountId,
    onCuentaEliminada: () => ref.read(authProvider.notifier).logout(),
  );
  // Al construirse, publica lo que ya hubiera guardado de una sesión anterior.
  controller.refresh();
  return controller;
});

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
  // CR-034: trae TODO paginando contra el backend; el limit fijo escondía
  // árboles del mapa al rebasarlo.
  (ref) => ref.watch(apiClientProvider).publicObservationsAll(),
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
