// Selector de plataforma de la señal "volvió la red" (CR-031).
//
// - web / PWA: evento `online` de la ventana (network_signal_web.dart). Es la
//   plataforma de PRODUCCIÓN y el evento no cuesta ninguna dependencia nueva.
// - nativo: sin señal (network_signal_io.dart); la subida se dispara al abrir, al
//   volver a primer plano, tras capturar, a mano, o por la escalera de espera.
//
// Se decidió NO añadir `connectivity_plus`: una dependencia por un solo evento que
// además solo informa del estado de la interfaz, no de que haya internet.
export 'network_signal_io.dart'
    if (dart.library.html) 'network_signal_web.dart';
