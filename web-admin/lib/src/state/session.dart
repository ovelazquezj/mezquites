import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../config.dart';
import '../models/models.dart';
import 'jwt_claims.dart';

/// Provider del [ApiClient] (base URL conmutable por `--dart-define`, gate #6).
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  ref.onDispose(client.close);
  return client;
});

/// Estado de sesión del admin. Sin PII: solo handle + role + token en memoria.
@immutable
class SessionState {
  const SessionState({this.session, this.error});

  final AuthSession? session;
  final String? error;

  bool get isAuthenticated => session != null;
  bool get isAdmin => session?.isAdmin ?? false;

  /// True si el token autenticado puede ver la vista restringida (coords
  /// exactas): rol `aliado_firmante` (la autorización real la impone el backend).
  bool get canSeeRestricted => session?.role == 'aliado_firmante';

  SessionState copyWith({AuthSession? session, String? error}) =>
      SessionState(session: session, error: error);
}

/// Controlador de sesión. Login por handle+código (POST /auth/recover) o token
/// pegado. Aplica el gate de rol: si el rol no es `admin_consorcio`, deniega.
class SessionController extends StateNotifier<SessionState> {
  SessionController(this._api) : super(const SessionState());

  final ApiClient _api;

  /// Login admin sin PII: handle + código de respaldo → token (Bearer).
  /// Deniega si el rol del token no es `admin_consorcio` (gate de acceso admin).
  Future<bool> loginWithBackupCode({
    required String handle,
    required String backupCode,
  }) async {
    try {
      final session = await _api.recover(
        handle: handle.trim(),
        backupCode: backupCode.trim(),
      );
      if (!session.isAdmin) {
        _api.setToken(null);
        state = const SessionState(
          error:
              'Esta cuenta no tiene rol de administración del consorcio. Acceso denegado.',
        );
        return false;
      }
      state = SessionState(session: session);
      return true;
    } on ApiException catch (e) {
      _api.setToken(null);
      state = SessionState(
        error: e.isAuthError
            ? 'Handle o código de respaldo inválido.'
            : 'No se pudo iniciar sesión (${e.statusCode}).',
      );
      return false;
    } catch (_) {
      _api.setToken(null);
      state = const SessionState(
        error: 'No se pudo contactar al backend. Verifica API_BASE_URL.',
      );
      return false;
    }
  }

  /// Login pegando un token Bearer ya emitido. Se leen los claims (handle/role)
  /// sin verificar firma (el backend es autoritativo). Deniega si no es admin.
  bool loginWithToken(String token) {
    final claims = decodeJwtClaims(token.trim());
    if (claims == null) {
      state = const SessionState(error: 'El token no es válido.');
      return false;
    }
    final role = (claims['role'] ?? '') as String;
    final handle = (claims['handle'] ?? '') as String;
    if (role != 'admin_consorcio') {
      state = const SessionState(
        error:
            'El token no corresponde al rol de administración del consorcio. Acceso denegado.',
      );
      return false;
    }
    final session = AuthSession(handle: handle, role: role, token: token.trim());
    _api.setToken(session.token);
    state = SessionState(session: session);
    return true;
  }

  void logout() {
    _api.setToken(null);
    state = const SessionState();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref.watch(apiClientProvider));
});
