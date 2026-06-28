import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Servicio de instalación PWA (CR-016) — implementación WEB.
///
/// El navegador entrega el evento `beforeinstallprompt` una sola vez; un script en `index.html` lo
/// captura (preventDefault) y lo guarda en `window`, exponiendo funciones que llamamos aquí. Así el
/// botón propio "Instalar app" puede lanzar el diálogo nativo aunque el banner automático de Chrome
/// esté en cooldown. iOS no soporta el evento ⇒ se detecta y se muestran instrucciones manuales.

@JS('pwaPromptInstall')
external JSPromise<JSString> _promptInstallJs();

@JS('pwaIsStandalone')
external JSBoolean _isStandaloneJs();

@JS('pwaCanInstall')
external JSBoolean _canInstallJs();

/// `true` si la app ya corre instalada (display-mode standalone, o `navigator.standalone` en iOS).
bool isStandalone() => _isStandaloneJs().toDart;

/// `true` si el navegador ofrece instalación ahora (hay un `beforeinstallprompt` capturado).
bool canInstall() => _canInstallJs().toDart;

/// `true` en Safari de iOS/iPadOS (no hay `beforeinstallprompt`: la instalación es manual).
bool isIosWeb() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  final isIDevice =
      ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  // iPadOS 13+ se presenta como "Macintosh" con pantalla táctil.
  final isIpadOs =
      ua.contains('macintosh') && web.window.navigator.maxTouchPoints > 1;
  return isIDevice || isIpadOs;
}

/// Lanza el diálogo nativo de instalación y devuelve el desenlace (`accepted`/`dismissed`/`unavailable`).
Future<String> promptInstall() async {
  final result = await _promptInstallJs().toDart;
  return result.toDart;
}

/// Notifica cuando cambia la disponibilidad de instalación (evento del navegador o "instalada").
Stream<void> installabilityChanges() {
  final controller = StreamController<void>.broadcast();
  final handler = ((web.Event _) => controller.add(null)).toJS;
  web.window.addEventListener('pwa-install-available', handler);
  web.window.addEventListener('pwa-installed', handler);
  controller.onCancel = () {
    web.window.removeEventListener('pwa-install-available', handler);
    web.window.removeEventListener('pwa-installed', handler);
  };
  return controller.stream;
}
