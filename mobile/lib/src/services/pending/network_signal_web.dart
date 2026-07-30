import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Señal de "volvió la red" en el **navegador / PWA** (CR-031).
///
/// El evento `online` de la ventana es gratis: `package:web` ya era dependencia
/// (CR-016 lo usa para el botón "Instalar app"), así que no hace falta
/// `connectivity_plus`.
///
/// ⚠️ `online` dice que hay **interfaz de red**, no que haya internet: el caso
/// clásico es el wifi cautivo de un hotel o una escuela. Por eso se usa solo como
/// **despertador** del motor de subida; quien decide si hay conexión de verdad es
/// el POST. Si falla, el motor lo trata como reintentable y vuelve a esperar.
///
/// Devuelve la función para dejar de escuchar.
void Function() escucharVueltaDeRed(void Function() alVolver) {
  final listener = (web.Event _) => alVolver();
  final jsListener = listener.toJS;
  web.window.addEventListener('online', jsListener);
  return () => web.window.removeEventListener('online', jsListener);
}
