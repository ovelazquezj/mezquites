import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Persistencia local de la sesión seudonimizada (gate #2: SIN PII) y de banderas
/// de UI (disclaimer visto). Solo guarda handle/role/token y NUNCA el código de
/// respaldo en claro.
class SessionStore {
  SessionStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kHandle = 'session_handle';
  static const _kRole = 'session_role';
  static const _kToken = 'session_token';
  static const _kDisclaimerSeen = 'disclaimer_seen';
  static const _kOnboardingSeen = 'onboarding_seen';

  static Future<SessionStore> create() async =>
      SessionStore(await SharedPreferences.getInstance());

  Future<void> saveSession(AuthSession s) async {
    await _prefs.setString(_kHandle, s.handle);
    await _prefs.setString(_kRole, s.role);
    await _prefs.setString(_kToken, s.token);
  }

  AuthSession? loadSession() {
    final handle = _prefs.getString(_kHandle);
    final role = _prefs.getString(_kRole);
    final token = _prefs.getString(_kToken);
    if (handle == null || role == null || token == null) return null;
    // CR-031: el `account_id` se deriva del propio token, así que no hace falta
    // guardarlo aparte (ni migrar las sesiones ya persistidas).
    return AuthSession(
      handle: handle,
      role: role,
      token: token,
      accountId: accountIdFromJwt(token),
    );
  }

  Future<void> clearSession() async {
    await _prefs.remove(_kHandle);
    await _prefs.remove(_kRole);
    await _prefs.remove(_kToken);
  }

  // --- Disclaimer D1 (Q7): visto una sola vez; persiste tras descarte ---

  bool get disclaimerSeen => _prefs.getBool(_kDisclaimerSeen) ?? false;

  Future<void> markDisclaimerSeen() async =>
      _prefs.setBool(_kDisclaimerSeen, true);

  // --- Onboarding CR-003: informativo, omitible, una sola vez (gate #3) ---
  // El flag es un booleano local (sin PII, gate #2): solo marca "ya visto".

  bool get onboardingSeen => _prefs.getBool(_kOnboardingSeen) ?? false;

  Future<void> markOnboardingSeen() async =>
      _prefs.setBool(_kOnboardingSeen, true);

  /// Serialización mínima para depuración (sin PII).
  String debugDump() => json.encode({
        'has_session': loadSession() != null,
        'disclaimer_seen': disclaimerSeen,
        'onboarding_seen': onboardingSeen,
      });
}
