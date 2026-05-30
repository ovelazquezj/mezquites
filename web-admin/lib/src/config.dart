/// Configuración de entorno (gate #6: paridad de entornos).
///
/// `API_BASE_URL` es configurable por `--dart-define`; el default es **dev local
/// sin nube** (`http://localhost:8000/api/v1`). Pasar a stg/prod no requiere
/// cambios de código, solo otro `--dart-define`.
///
/// Ej.: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000/api/v1`
class AppConfig {
  const AppConfig._();

  /// Base de la API REST `/api/v1`, sin barra final.
  /// Default dev: backend FastAPI local, sin nube (paridad de entornos).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
}
