/// Configuración de la app (sin secretos; sin PII).
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// Base de la API REST. En emulador Android, `10.0.2.2` mapea al host.
  /// Sobreescribible en build con --dart-define=API_BASE_URL=...
  final String apiBaseUrl;

  static const _defaultBase = 'http://10.0.2.2:8000/api/v1';

  factory AppConfig.fromEnvironment() => const AppConfig(
        apiBaseUrl: String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: _defaultBase,
        ),
      );
}
