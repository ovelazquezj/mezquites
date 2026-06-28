import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../services/pwa_install.dart' as pwa;
import '../copy.dart';

/// Botón "Instalar app" (CR-016). Se muestra SOLO en web y solo cuando tiene sentido:
/// - Android / escritorio: aparece cuando el navegador ofrece instalación (`beforeinstallprompt`);
///   al tocarlo lanza el diálogo nativo (funciona aunque el banner automático esté en cooldown).
/// - iOS (Safari): el navegador no permite el botón; muestra instrucciones (Compartir → Agregar a
///   inicio).
/// - Fuera de web, o si la app ya está instalada (standalone): no muestra nada.
///
/// Gate #3: es opcional y NUNCA bloquea ni condiciona el uso de la app.
class InstallAppButton extends StatefulWidget {
  const InstallAppButton({super.key});

  @override
  State<InstallAppButton> createState() => _InstallAppButtonState();
}

class _InstallAppButtonState extends State<InstallAppButton> {
  bool _standalone = false;
  bool _ios = false;
  bool _canInstall = false;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _standalone = pwa.isStandalone();
    _ios = pwa.isIosWeb();
    _canInstall = pwa.canInstall();
    if (kIsWeb && !_standalone) {
      // La disponibilidad puede llegar después de cargar (el evento del navegador es asíncrono).
      _sub = pwa.installabilityChanges().listen((_) {
        if (!mounted) return;
        setState(() {
          _standalone = pwa.isStandalone();
          _canInstall = pwa.canInstall();
        });
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (_ios) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(Copy.installTitle),
          content: const Text(Copy.installIosInstructions),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(Copy.installIosOk),
            ),
          ],
        ),
      );
      return;
    }
    await pwa.promptInstall();
    if (!mounted) return;
    setState(() {
      _standalone = pwa.isStandalone();
      _canInstall = pwa.canInstall();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || _standalone) return const SizedBox.shrink();
    // En iOS siempre ofrecemos la instrucción; en lo demás, solo si hay prompt disponible.
    if (!_ios && !_canInstall) return const SizedBox.shrink();
    return OutlinedButton.icon(
      key: const Key('install_app'),
      onPressed: _onTap,
      icon: const Icon(Icons.install_mobile_outlined),
      label: const Text(Copy.installButton),
    );
  }
}
