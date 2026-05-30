import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/models/models.dart';

/// Gate #2 (sin PII): el alta es por handle; ningún modelo ni pantalla de
/// registro/cuenta pide email/teléfono/nombre.
void main() {
  test('AuthSession.fromRegister no contiene campos de PII', () {
    final s = AuthSession.fromRegister({
      'handle': 'colibri-azul-42',
      'role': 'voluntario',
      'token': 'tok',
      'backup_code': 'ABCD-1234',
    });
    expect(s.handle, 'colibri-azul-42');
    // El modelo expone solo handle/role/token/backupCode; sin email/phone/name.
    final fields = s.toString();
    expect(fields.contains('@'), isFalse);
  });

  test('ningún campo de entrada pide email/teléfono/nombre (gate #2)', () {
    // Escanea SOLO declaraciones de campos de entrada (labelText/hintText) y
    // TextField, ignorando comentarios (donde el gate aparece en negativo) y
    // las cadenas de garantía de privacidad ("no pedimos correo...").
    final files = [
      'lib/src/ui/screens/register_screen.dart',
      'lib/src/ui/screens/recover_screen.dart',
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

  test('el payload de registro solo lleva institution_id y role', () {
    // El cuerpo del POST /auth/register no debe incluir PII.
    final src = File('lib/src/api/api_client.dart').readAsStringSync();
    expect(src.contains("'institution_id'"), isTrue);
    expect(src.contains("'role': 'voluntario'"), isTrue);
    expect(src.contains("'email'"), isFalse);
    expect(src.contains("'phone'"), isFalse);
  });
}
