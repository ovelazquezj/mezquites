import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezquite_web_admin/src/screens/login_screen.dart';

void main() {
  testWidgets('Login admin no ofrece campos de PII (gate #2)', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginScreen()),
    ));

    // Campos esperados: handle, código de respaldo, token. NADA de email/pass.
    expect(find.byKey(const Key('login-handle')), findsOneWidget);
    expect(find.byKey(const Key('login-backup-code')), findsOneWidget);
    expect(find.byKey(const Key('login-token')), findsOneWidget);

    // No debe existir ningún campo etiquetado como PII.
    for (final pii in ['Email', 'Correo', 'Contraseña', 'Password', 'Teléfono',
      'Nombre']) {
      expect(find.widgetWithText(TextField, pii), findsNothing,
          reason: 'gate #2: sin PII en el login ($pii)');
    }
  });
}
