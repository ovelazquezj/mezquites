import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../services/session_store.dart';
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

/// Cliente de la API REST.
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final client = ApiClient(baseUrl: config.apiBaseUrl);
  ref.onDispose(client.close);
  return client;
});

/// Estado de autenticación (sesión seudonimizada). Sin PII.
class AuthController extends StateNotifier<AuthSession?> {
  AuthController(this._api, this._store) : super(_store.loadSession()) {
    if (state != null) _api.setToken(state!.token);
  }

  final ApiClient _api;
  final SessionStore _store;

  /// Alta por handle. Devuelve la sesión con el código de respaldo (una vez).
  Future<AuthSession> register({String? institutionId}) async {
    final session = await _api.register(institutionId: institutionId);
    _api.setToken(session.token);
    await _store.saveSession(session);
    state = session;
    return session;
  }

  Future<void> recover({
    required String handle,
    required String backupCode,
  }) async {
    final session = await _api.recover(handle: handle, backupCode: backupCode);
    _api.setToken(session.token);
    await _store.saveSession(session);
    state = session;
  }

  Future<void> logout() async {
    await _store.clearSession();
    _api.setToken(null);
    state = null;
  }
}

final authProvider =
    StateNotifierProvider<AuthController, AuthSession?>((ref) {
  return AuthController(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
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
