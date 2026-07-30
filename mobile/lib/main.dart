import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'src/app.dart';
import 'src/services/pending/pending_backend.dart';
import 'src/services/pending/pending_store.dart';
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

  // CR-031: almacén de capturas pendientes. Se abre aquí porque es asíncrono
  // (IndexedDB en web, directorio + prefs en nativo) y porque `init()` rescata a la
  // cola lo que hubiera quedado marcado como "subiendo" si la app murió a media
  // subida. Si no se puede abrir NO se impide usar la app (gate #3): se cae a un
  // almacén en memoria, que no sobrevive al cierre pero permite seguir capturando;
  // el hecho viaja en el diagnóstico de "Reportar un problema".
  PendingCaptureStore pendingStore;
  try {
    pendingStore = PendingCaptureStore(crearPendingBackend());
    await pendingStore.init();
  } catch (_) {
    pendingStore = PendingCaptureStore(InMemoryPendingBackend());
    await pendingStore.init();
  }

  runApp(
    ProviderScope(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
        pendingStoreProvider.overrideWithValue(pendingStore),
      ],
      child: const MezquiteApp(),
    ),
  );
}
