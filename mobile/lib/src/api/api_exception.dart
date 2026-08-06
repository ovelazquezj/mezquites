/// Error de la capa de API REST.
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.body});

  final int statusCode;
  final String message;
  final String? body;

  /// ¿La sesión venció? (CR-035). SOLO 401 a propósito — la pregunta aquí es
  /// "¿se cura volviendo a entrar?", y por eso diverge del `isAuthError` de la
  /// consola (401||403||410): un 403 no se cura re-entrando (permiso denegado;
  /// el motor de subida ya lo trata como `necesitaAtencion`) y un 410 tampoco
  /// (cuenta eliminada, camino D6: borra la cola y cierra la sesión).
  bool get isSessionExpired => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
