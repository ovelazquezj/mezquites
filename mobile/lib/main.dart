import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'src/app.dart';
import 'src/services/session_store.dart';
import 'src/state/app_config.dart';
import 'src/state/providers.dart';

/// Punto de entrada. Inyecta el almacén de sesión (sin PII) y arranca la app.
///
/// CR-002 (sin Firebase): la inicialización de Google Identity Services es CONDICIONAL al modo
/// `AUTH_MODE=google` (con el Web Client ID de OAuth). En el modo por defecto (`mock`) NO se
/// inicializa GIS, de modo que `flutter build`/`flutter test` funcionan SIN proyecto real (gate #6).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (config.usesGoogleSignIn) {
    // En WEB esto carga el SDK de GIS con el Web Client ID y habilita el botón `renderButton`.
    // Se tolera el fallo para no dejar la app en pantalla negra si falta/yerra la config.
    try {
      await GoogleSignIn.instance.initialize(
        clientId:
            config.googleWebClientId.isEmpty ? null : config.googleWebClientId,
      );
    } catch (_) {
      // Sin GIS disponible: el login social fallará con un error manejable en la UI.
    }
  }

  final store = await SessionStore.create();
  runApp(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
      ],
      child: const MezquiteApp(),
    ),
  );
}
