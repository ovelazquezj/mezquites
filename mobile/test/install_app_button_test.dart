import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/ui/widgets/install_app_button.dart';

/// CR-016: el botón "Instalar app" es exclusivo de web. En `flutter test` (VM, no navegador) y en
/// móvil nativo NO debe mostrarse: la instalación PWA no aplica fuera del navegador (gate #3: el
/// botón es opcional y jamás bloquea el uso).
void main() {
  testWidgets('InstallAppButton no se muestra fuera de web (no rompe la UI)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: InstallAppButton()),
      ),
    );
    // Fuera de web no hay botón de instalación.
    expect(find.byKey(const Key('install_app')), findsNothing);
  });
}
