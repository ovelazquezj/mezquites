/// Señal de "volvió la red" en **móvil nativo** (CR-031).
///
/// No hay ninguna: se decidió **no** añadir `connectivity_plus` para no meter una
/// dependencia por un solo evento. En nativo la subida se dispara al abrir la app,
/// al volver a primer plano, tras cada captura, con el botón "Subir ahora" y por la
/// escalera de espera del motor. El costo asumido es que, con la app abierta y sin
/// tocarla, recuperar la señal puede tardar hasta el siguiente reintento
/// programado (tope: 15 min) en lugar de ser inmediato.
///
/// En **web** —que es la plataforma de producción— sí hay evento nativo del
/// navegador y no cuesta ninguna dependencia (ver `network_signal_web.dart`).
void Function() escucharVueltaDeRed(void Function() alVolver) {
  return () {}; // nada que desuscribir
}
