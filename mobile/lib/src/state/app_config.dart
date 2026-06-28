/// Configuración de la app (sin secretos; sin PII).
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.authMode,
    required this.googleWebClientId,
  });

  /// Base de la API REST. En emulador Android, `10.0.2.2` mapea al host.
  /// Sobreescribible en build con --dart-define=API_BASE_URL=...
  final String apiBaseUrl;

  /// Modo de autenticación (CR-002, salvaguarda gate #6): `mock` (por defecto, sin red) | `google`
  /// (real, Google Identity Services SIN Firebase; requiere el Web Client ID de OAuth de Google
  /// Cloud). `firebase` se acepta como alias histórico de `google`. Sobreescribible con
  /// --dart-define=AUTH_MODE=google.
  final String authMode;

  /// ID de cliente OAuth 2.0 de tipo "Aplicación web" de Google Cloud
  /// (`...apps.googleusercontent.com`). Necesario en WEB para inicializar GIS y renderizar el botón
  /// de "Entrar con Google" (gate #2: es un identificador público, no PII ni secreto).
  /// Sobreescribible con --dart-define=GOOGLE_WEB_CLIENT_ID=...
  final String googleWebClientId;

  /// `true` si se usa el login real con Google (GIS). En este modo, en WEB se renderiza el botón GIS
  /// y se envía el ID token de Google al backend; en `mock` se usa el servicio offline.
  bool get usesGoogleSignIn =>
      authMode.toLowerCase() == 'google' || authMode.toLowerCase() == 'firebase';

  static const _defaultBase = 'http://10.0.2.2:8000/api/v1';

  factory AppConfig.fromEnvironment() => const AppConfig(
        apiBaseUrl: String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _defaultBase,
        ),
        authMode: String.fromEnvironment('AUTH_MODE', defaultValue: 'mock'),
        googleWebClientId:
            String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: ''),
      );
}
