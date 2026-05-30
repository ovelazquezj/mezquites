/// Error de la API REST. Lleva el código HTTP para que la UI distinguya
/// 401/403 (rol/credencial) de otros fallos.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.body});

  final int statusCode;
  final String message;
  final String? body;

  /// True si es un fallo de autorización (token inválido o rol insuficiente).
  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
