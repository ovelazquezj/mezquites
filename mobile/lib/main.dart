import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/services/session_store.dart';
import 'src/state/providers.dart';

/// Punto de entrada. Inyecta el almacén de sesión (sin PII) y arranca la app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
