import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/pending/network_signal.dart';
import '../../state/providers.dart';
import 'capture_screen.dart';
import 'heat_map_screen.dart';
import 'learning_screen.dart';
import 'profile_screen.dart';

/// Contenedor principal con navegación inferior (minimalista, baja densidad).
/// Ningún destino se bloquea por nivel (gate #3): todo está disponible.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int _index = 0;

  /// Para dejar de escuchar el evento `online` del navegador (CR-031).
  void Function()? _dejarDeEscucharRed;

  /// Disparadores de la subida diferida (CR-031 W3/W4). El motor no tiene bucle
  /// propio a propósito: se despierta con hechos que ya ocurren en la app.
  ///
  /// 1. **Al montar la sesión** (aquí): sube lo que quedó de la vez anterior.
  /// 2. **Al volver a primer plano**: el caso típico de "salí al campo sin señal y
  ///    al llegar abro la app".
  /// 3. **Al volver la red** (`online`, solo web / PWA).
  /// 4. Tras cada captura y con el botón "Subir ahora" (en sus propias pantallas).
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dejarDeEscucharRed = escucharVueltaDeRed(_intentarSubir);
    // Tras el primer frame: el provider ya está listo y no se toca estado durante
    // el build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _intentarSubir());
  }

  @override
  void dispose() {
    _dejarDeEscucharRed?.call();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _intentarSubir();
  }

  void _intentarSubir() {
    if (!mounted) return;
    // Sin await: subir nunca debe bloquear la interfaz (gate #3).
    ref.read(pendingQueueProvider.notifier).subirAhora();
  }

  static const _screens = <Widget>[
    CaptureScreen(),
    LearningScreen(),
    // Pestaña "Mapa": la MISMA pantalla de calor que la entrada pública, ahora
    // con sesión (los datos públicos son los mismos; CR-009).
    HeatMapScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        key: const Key('home_nav'),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Observar',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Aprender',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
