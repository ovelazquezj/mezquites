import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_web_admin/src/api/api_exception.dart';

/// CR-031 (AC18) — la consola trata el **410** como error de autenticación.
///
/// El backend pasó a responder 410 Gone cuando el token es válido pero la cuenta
/// ya no existe (cancelación ARCO), para que la app del voluntario distinga
/// "vuelve a entrar" (conservar las capturas sin subir) de "esta cuenta se
/// eliminó" (borrarlas). Ese cambio es global: también lo ve la consola. Sin
/// incluir el 410 aquí, a un usuario de consola dado de baja le saldría un error
/// genérico en vez de volver al login.
void main() {
  group('CR-031 — ApiException.isAuthError', () {
    test('410 (cuenta eliminada) cuenta como error de autenticación', () {
      expect(ApiException(410, 'cuenta eliminada').isAuthError, isTrue);
    });

    test('401 y 403 siguen siendo error de autenticación', () {
      expect(ApiException(401, 'token inválido').isAuthError, isTrue);
      expect(ApiException(403, 'rol insuficiente').isAuthError, isTrue);
    });

    test('otros códigos NO son error de autenticación', () {
      for (final code in [400, 404, 409, 422, 500, 503]) {
        expect(
          ApiException(code, 'x').isAuthError,
          isFalse,
          reason: '$code no debe mandar al login',
        );
      }
    });
  });
}
