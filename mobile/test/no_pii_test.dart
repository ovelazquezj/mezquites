import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/models/models.dart';

/// Gate #2 ACOTADO (CR-002): identidad real con mínima PII. La app guarda SOLO el handle de
/// presentación + JWT (nunca email/nombre); el login social manda únicamente el ID token.
void main() {
  test('AuthSession.fromToken no contiene campos de PII', () {
    final s = AuthSession.fromToken({
      'handle': 'colibri-azul-42',
      'role': 'voluntario',
      'token': 'tok',
    });
    expect(s.handle, 'colibri-azul-42');
    // El modelo expone solo handle/role/token; sin email/phone/name.
    final fields = s.toString();
    expect(fields.contains('@'), isFalse);
  });

  test('ninguna pantalla de auth/cuenta pide email/teléfono/nombre (gate #2)', () {
    // Escanea SOLO declaraciones de campos de entrada (labelText/hintText) y
    // TextField, ignorando comentarios (donde el gate aparece en negativo) y
    // las cadenas de garantía de privacidad.
    final files = [
      'lib/src/ui/screens/welcome_screen.dart',
      'lib/src/ui/screens/account_screen.dart',
    ];
    final banned = ['email', 'correo', 'teléfono', 'telefono', 'phone',
        'nombre', 'apellido', 'curp',];
    final offenders = <String>[];
    for (final f in files) {
      for (final raw in File(f).readAsLinesSync()) {
        final line = raw.trim();
        if (line.startsWith('//') || line.startsWith('///')) continue;
        final isInputDecl = line.contains('labelText:') ||
            line.contains('hintText:') ||
            line.contains('TextField(');
        if (!isInputDecl) continue;
        final lower = line.toLowerCase();
        for (final term in banned) {
          if (lower.contains(term)) offenders.add('$f: "$line"');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'Campo de entrada pide PII: $offenders');
  });

  test('el payload de /auth/google solo lleva id_token (+ institution_id), sin PII', () {
    // El cuerpo del POST /auth/google no debe incluir email/phone/nombre.
    final src = File('lib/src/api/api_client.dart').readAsStringSync();
    expect(src.contains("'id_token'"), isTrue);
    expect(src.contains("'institution_id'"), isTrue);
    expect(src.contains("'email'"), isFalse);
    expect(src.contains("'phone'"), isFalse);
    expect(src.contains("'name'"), isFalse);
    // El flujo viejo (register/recover/backup) quedó retirado.
    expect(src.contains('/auth/register'), isFalse);
    expect(src.contains('/auth/recover'), isFalse);
  });
}
