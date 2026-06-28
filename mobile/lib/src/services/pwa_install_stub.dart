/// Stub no-web del servicio de instalación PWA (CR-016): fuera del navegador no hay instalación,
/// así que todo es "no disponible". El botón "Instalar app" no se muestra (ver InstallAppButton).
bool isStandalone() => false;

bool canInstall() => false;

bool isIosWeb() => false;

Future<String> promptInstall() async => 'unavailable';

Stream<void> installabilityChanges() => const Stream<void>.empty();
