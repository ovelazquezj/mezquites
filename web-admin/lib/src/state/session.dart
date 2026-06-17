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

  /// Capacidades de revisión humana (CR-001). La autorización real la impone el backend.
  bool get canReview => session?.canReview ?? false;
  bool get canEmitVerdict => session?.canEmitVerdict ?? false;

  /// Gestión de usuarios de backend (CR-002): SOLO `administrador`.
  bool get canManageUsers => session?.canManageUsers ?? false;

  /// Cancelación ARCO de cuentas (CR-006): SOLO `administrador`.
  bool get canDeleteAccounts => session?.canDeleteAccounts ?? false;

  SessionState copyWith({AuthSession? session, String? error}) =>
      SessionState(session: session, error: error);
}

/// Controlador de sesión. Login por usuario + contraseña (POST /auth/login, CR-002) o token
/// pegado. Aplica el gate de rol: si el rol no entra a la consola de administración, deniega.
class SessionController extends StateNotifier<SessionState> {
  SessionController(this._api) : super(const SessionState());

  final ApiClient _api;

  /// Login de la consola: usuario + contraseña → token (Bearer).
  /// Deniega si el rol no entra a la consola de administración (gate de acceso).
  Future<bool> loginWithPassword({
    required String username,
    required String password,
  }) async {
    try {
      final session = await _api.login(
        username: username.trim(),
        password: password,
      );
      if (!session.canEnterAdminConsole) {
        _api.setToken(null);
        state = const SessionState(
          error:
              'Esta cuenta no tiene permisos para la consola de administración.',
        );
        return false;
      }
      state = SessionState(session: session);
      return true;
    } on ApiException catch (e) {
      _api.setToken(null);
      state = SessionState(
        error: e.isAuthError
            ? 'Usuario o contraseña inválidos.'
            : 'No se pudo iniciar sesión. Inténtalo de nuevo.',
      );
      return false;
    } catch (_) {
      _api.setToken(null);
      state = const SessionState(
        error: 'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
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
    final session = AuthSession(handle: handle, role: role, token: token.trim());
    if (!session.canEnterAdminConsole) {
      state = const SessionState(
        error:
            'El token no corresponde a un rol de la consola de administración. Acceso denegado.',
      );
      return false;
    }
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
