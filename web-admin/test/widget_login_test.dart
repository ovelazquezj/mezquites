import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezquite_web_admin/src/screens/login_screen.dart';

void main() {
  testWidgets('Login admin no ofrece campos de PII (gate #2)', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginScreen()),
    ));

    // Campos visibles por defecto: usuario y código de respaldo. NADA de
    // email/pass.
    expect(find.byKey(const Key('login-handle')), findsOneWidget);
    expect(find.byKey(const Key('login-backup-code')), findsOneWidget);

    // El acceso por token está oculto tras "Opciones avanzadas" (no aparece de
    // entrada para no confundir al usuario no experto).
    expect(find.byKey(const Key('login-token')), findsNothing);
    final advanced = find.text('Opciones avanzadas');
    await tester.ensureVisible(advanced);
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-token')), findsOneWidget);

    // No debe existir ningún campo etiquetado como PII.
    for (final pii in ['Email', 'Correo', 'Contraseña', 'Password', 'Teléfono',
      'Nombre']) {
      expect(find.widgetWithText(TextField, pii), findsNothing,
          reason: 'gate #2: sin PII en el login ($pii)');
    }
  });
}
