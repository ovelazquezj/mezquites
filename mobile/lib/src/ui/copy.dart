/// Cadenas de texto de la app. Centralizadas para revisión de copy (gate #1:
/// NADA promete control fitosanitario, reducción de infestación, ni
/// recomendaciones de manejo químico/mecánico).
class Copy {
  Copy._();

  static const appTitle = 'Mezquite — Ciencia ciudadana';
  static const welcomeSubtitle = 'Ciencia ciudadana';

  // --- Onboarding (CR-003; informativo, omitible, una sola vez · gate #3) ---
  static const onboardingSkip = 'Saltar';
  static const onboardingNext = 'Siguiente';
  static const onboardingStart = 'Comenzar';

  // --- Disclaimer D1 (Q7-D1) ---
  // Texto-base = buenas prácticas de campo de la bitácora (§Q7-D1). El texto
  // FINAL es el anexo del protocolo; este es el texto-base derivable.
  // [PLACEHOLDER_TEXTO_FINAL]: el copy definitivo lo confirma el consorcio.
  static const disclaimerTitle = 'Antes de salir a campo';
  static const disclaimerBody =
      'Gracias por sumarte como observador voluntario. Unas buenas prácticas '
      'de campo para cuidarte:\n\n'
      '• No entres a propiedad privada sin permiso.\n'
      '• Mantente atento a la fauna del lugar: abejas, víboras y alacranes.\n'
      '• Hidrátate y protégete del sol.\n\n'
      'Esta app sirve para registrar y compartir observaciones del mezquite. '
      'No ofrece recomendaciones de manejo ni de control.';
  static const disclaimerDismiss = 'Entendido';

  // --- Boundary-safe (gate #1) ---
  static const aboutBoundary =
      'Este proyecto es de observación y ciencia ciudadana. Documentamos el '
      'estado del mezquite y del paxtle para generar conocimiento abierto. '
      'La app no recomienda tratamientos ni acciones de manejo.';

  // --- Captura ---
  static const captureTitle = 'Nueva observación';
  static const captureCameraOnly =
      'La foto se toma con la cámara del dispositivo. No se admiten imágenes '
      'de la galería.';
  static const captureNivelLabel = 'Nivel de paxtle (parte de la copa cubierta)';
  static const captureNivelHint = 'Lo estimas tú a ojo; no se revisa.';
  static const captureCuscutaLabel = '¿Cúscuta visible?';
  static const captureDanioLabel = '¿Signos de daño? (defoliación / ramas muertas)';
  static const captureTamanioLabel = 'Tamaño del árbol';
  static const captureContextoLabel = 'Contexto del sitio';
  static const captureSubmit = 'Registrar observación';
  // Revisión humana (CR-001): toda observación se acepta al instante.
  static const captureQueued =
      'Observación registrada y aceptada. ¡Gracias por contribuir!';

  // --- Resumen agregado de aportaciones (CR-001) ---
  static const feedbackTitle = 'Tu aporte';
  static const feedbackNote =
      'Tus observaciones se aceptan al registrarlas. El equipo del consorcio '
      'las revisa después; aquí ves un resumen de tus aportaciones, nunca el '
      'resultado de una foto en particular.';

  // --- Aprendizaje (Q5.C; sin gating, gate #3) ---
  static const learningTitle = 'Aprendizaje';
  static const learningNote =
      'Contenidos abiertos. Ningún módulo se bloquea: explora a tu ritmo.';

  // --- Perfil / gamificación (Q4) ---
  static const profileTitle = 'Perfil';
  static const rankingsTitle = 'Rankings';
  static const identityNote =
      'Tu etiqueta de identidad reconoce tu trayectoria. No desbloquea '
      'funciones: todas están disponibles desde el primer día.';

  // --- Dashboards cliente ---
  static const dashboardTitle = 'Mapa de observaciones';
  static const obfuscationNote =
      'Las ubicaciones públicas se muestran aproximadas (celda de ~1 km) para '
      'proteger los árboles.';

  // --- Cuenta (sin PII, gate #2) ---
  static const accountTitle = 'Tu cuenta';
  static const noPiiNote =
      'No pedimos correo, teléfono ni nombre. Te identificas con un nombre de '
      'usuario.';
  static const backupTitle = 'Guarda tu código de respaldo';
  static const backupNote =
      'Este código (y su QR) es la ÚNICA forma de recuperar tu cuenta. '
      'Guárdalo en un lugar seguro. No lo volveremos a mostrar.';

  // --- Ayuda ---
  static const helpTitle = 'Ayuda';

  /// Etiqueta de identidad L3 → texto legible (Q4).
  static String identityLabel(String key) =>
      const {
        'nuevo_observador': 'Nuevo observador',
        'observador': 'Observador',
        'observador_experimentado': 'Observador experimentado',
        'veterano_del_mezquite': 'Veterano del mezquite',
      }[key] ??
      key;

  /// Insignia → texto legible (Q4).
  static String badge(String key) =>
      const {
        'primera_observacion': 'Primera observación',
        'explorador': 'Explorador',
        'observador_dedicado': 'Observador dedicado',
        'centinela_del_mezquite': 'Centinela del mezquite',
      }[key] ??
      key;

  /// Nivel G4 (wire) → texto legible.
  static String nivelG4(String wire) =>
      const {
        'sano': 'Sano',
        'leve': 'Leve',
        'moderado': 'Moderado',
        'severo': 'Severo',
      }[wire] ??
      wire;

  static const periodLabels = {
    'all': 'Histórico',
    'month': 'Mes',
    'quarter': 'Trimestre',
    'year': 'Año',
  };
}

/// Una página del onboarding (CR-003 §5.5). El acento se nombra por su token
/// semántico (`blue`/`accent`/`secondary`) para resolverlo desde el design
/// system (T7) y NO hardcodear colores en la UI (sin hex literal).
class OnboardingPageData {
  const OnboardingPageData({
    required this.eyebrow,
    required this.title,
    required this.accentToken,
    required this.body,
  });

  final String eyebrow;
  final String title;
  final String accentToken;
  final String body;

  /// Contenido EXACTO del CR-003 §5.5. El onboarding es informativo, omitible y
  /// se muestra una sola vez (gate #3): no bloquea funcionalidad ni certifica.
  static const pages = <OnboardingPageData>[
    OnboardingPageData(
      eyebrow: 'PASO 1 · MESES 1-6',
      title: 'Concientizar',
      accentToken: 'blue', // #2E6FB7
      body:
          'Registra mezquites de tu comunidad con la app y activa censos base '
          'en preparatorias piloto.',
    ),
    OnboardingPageData(
      eyebrow: 'PASO 2 · MESES 7-14',
      title: 'Capacitar',
      accentToken: 'accent', // green #5C9A3A
      body:
          'Toma microcursos y forma redes estudiantiles para validar daños por '
          'paxtle con evidencia.',
    ),
    OnboardingPageData(
      eyebrow: 'PASO 3 · MESES 15-24',
      title: 'Combatir',
      accentToken: 'secondary', // gold #E0A21A
      body:
          'Articula con autoridades el manejo fitosanitario coordinado en las '
          'zonas críticas identificadas.',
    ),
  ];
}

/// Módulo de Aprendizaje (placeholder AU2). Mide engagement; SIN gating.
class LearningModule {
  const LearningModule({
    required this.id,
    required this.title,
    required this.summary,
  });

  final String id;
  final String title;
  final String summary;

  // [PLACEHOLDER_AU2]: el contenido formativo real lo produce AU2 (Q5.C-D1).
  static const placeholders = <LearningModule>[
    LearningModule(
      id: 'mod_que_es',
      title: '¿Qué es el mezquite?',
      summary: 'Conoce al árbol que documentamos y su papel en el ecosistema.',
    ),
    LearningModule(
      id: 'mod_paxtle',
      title: 'Reconocer el paxtle',
      summary: 'Cómo identificar visualmente la presencia y cobertura de paxtle.',
    ),
    LearningModule(
      id: 'mod_escala',
      title: 'La escala de observación',
      summary: 'Sano, leve, moderado, severo: cómo estimar el % de copa.',
    ),
    LearningModule(
      id: 'mod_buena_foto',
      title: 'Una buena foto',
      summary: 'Encuadre, luz y distancia para que tu observación sea útil.',
    ),
  ];
}
