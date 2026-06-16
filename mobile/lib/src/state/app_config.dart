/// Configuración de la app (sin secretos; sin PII).
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.authMode});

  /// Base de la API REST. En emulador Android, `10.0.2.2` mapea al host.
  /// Sobreescribible en build con --dart-define=API_BASE_URL=...
  final String apiBaseUrl;

  /// Modo de autenticación (CR-002, salvaguarda gate #6): `mock` (por defecto, sin red ni
  /// google-services.json) | `firebase` (real, requiere proyecto Firebase + google-services.json).
  /// Sobreescribible con --dart-define=AUTH_MODE=firebase.
  final String authMode;

  bool get usesFirebase => authMode.toLowerCase() == 'firebase';

  static const _defaultBase = 'http://10.0.2.2:8000/api/v1';

  factory AppConfig.fromEnvironment() => const AppConfig(
        apiBaseUrl: String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _defaultBase,
        ),
        authMode: String.fromEnvironment('AUTH_MODE', defaultValue: 'mock'),
      );
}
