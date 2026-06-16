import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/services/session_store.dart';
import 'src/state/app_config.dart';
import 'src/state/providers.dart';

/// Punto de entrada. Inyecta el almacén de sesión (sin PII) y arranca la app.
///
/// CR-002: la inicialización de Firebase es CONDICIONAL al modo `AUTH_MODE=firebase`. En el modo
/// por defecto (`mock`) NO se llama a `Firebase.initializeApp()`, de modo que `flutter build apk` y
/// la ejecución funcionan SIN `google-services.json` ni un proyecto Firebase real (gate #6).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (config.usesFirebase) {
    // Requiere los prerrequisitos del usuario (proyecto Firebase + google-services.json).
    // Se tolera el fallo para no dejar la app en pantalla negra si falta la config real.
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Sin Firebase real: el login social fallará con un error manejable en la UI.
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
