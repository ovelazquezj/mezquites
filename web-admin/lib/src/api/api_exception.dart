/// Error de la API REST. Lleva el código HTTP para que la UI distinguya
/// 401/403 (rol/credencial) de otros fallos.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.body});

  final int statusCode;
  final String message;
  final String? body;

  /// True si es un fallo de autorización (token inválido o rol insuficiente).
  ///
  /// CR-031 añade el **410**: el backend lo devuelve cuando el token es válido pero la cuenta ya no
  /// existe (cancelación ARCO). Sin incluirlo aquí, a un usuario de consola cuya cuenta se eliminara
  /// le saldría un error genérico en vez de volver al login.
  bool get isAuthError =>
      statusCode == 401 || statusCode == 403 || statusCode == 410;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
