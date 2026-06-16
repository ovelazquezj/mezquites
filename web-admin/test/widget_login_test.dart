import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mezquite_web_admin/src/screens/login_screen.dart';

/// CR-002 — AC7 (parte): el login de la consola usa **usuario + contraseña**.
void main() {
  testWidgets('Login de la consola ofrece usuario y contraseña (CR-002)',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoginScreen()),
    ));

    // Campos visibles por defecto: usuario y contraseña.
    expect(find.byKey(const Key('login-username')), findsOneWidget);
    expect(find.byKey(const Key('login-password')), findsOneWidget);
    // Ya NO hay campo de código de respaldo.
    expect(find.byKey(const Key('login-backup-code')), findsNothing);

    // El acceso por token está oculto tras "Opciones avanzadas".
    expect(find.byKey(const Key('login-token')), findsNothing);
    final advanced = find.text('Opciones avanzadas');
    await tester.ensureVisible(advanced);
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-token')), findsOneWidget);

    // No debe existir ningún campo etiquetado como PII de más (correo/teléfono/nombre).
    for (final pii in ['Email', 'Correo', 'Teléfono', 'Nombre']) {
      expect(find.widgetWithText(TextField, pii), findsNothing,
          reason: 'gate #2 acotado: sin PII de más en el login ($pii)');
    }
  });
}
