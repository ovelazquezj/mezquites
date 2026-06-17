/// Cadenas de texto de la app. Centralizadas para revisión de copy (gate #1:
/// NADA promete control fitosanitario, reducción de infestación, ni
/// recomendaciones de manejo químico/mecánico).
class Copy {
  Copy._();

  /// Organización responsable del proyecto (decisión del usuario, 2026-06-17).
  /// Centralizado para no repetirlo y poder ajustarlo en un solo lugar. La
  /// denominación legal exacta, domicilio y contacto oficiales siguen pendientes.
  static const orgName = 'Club Rotario Bosques Aguascalientes';

  static const appTitle = 'Mezquite — Ciencia ciudadana';
  static const welcomeSubtitle = 'Ciencia ciudadana';

  // --- Onboarding (CR-003; informativo, omitible, una sola vez · gate #3) ---
  static const onboardingSkip = 'Saltar';
  static const onboardingNext = 'Siguiente';
  static const onboardingStart = 'Comenzar';

  // --- Disclaimer D1 (Q7-D1) ---
  // Texto-base = buenas prácticas de campo de la bitácora (§Q7-D1). El texto
  // FINAL es el anexo del protocolo; este es el texto-base derivable.
  // [PLACEHOLDER_TEXTO_FINAL]: el copy definitivo lo confirma la organización responsable.
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
      'Tus observaciones se aceptan al registrarlas. El equipo del $orgName '
      'las revisa después; aquí ves un resumen de tus aportaciones, nunca el '
      'resultado de una foto en particular.';

  // --- Aprendizaje (Q5.C; sin gating, gate #3) ---
  static const learningTitle = 'Aprendizaje';
  static const learningNote =
      'Contenidos abiertos. Ningún módulo se bloquea: explora a tu ritmo.';

  /// Banner de borrador en el detalle de cada módulo (CR-007). El contenido
  /// formativo es BORRADOR sujeto a revisión de expertos/universidad (AU2/H4);
  /// es informativo y NO es asesoría técnica (gate #1).
  static const learningDraftBanner =
      'BORRADOR sujeto a revisión de expertos académicos (AU2). Es contenido '
      'informativo y educativo, no asesoría técnica ni recomendaciones de manejo.';

  /// Encabezado de la sección de enlaces externos en el detalle.
  static const learningMoreTitle = 'Saber más';

  // --- Perfil / gamificación (Q4) ---
  static const profileTitle = 'Perfil';
  static const rankingsTitle = 'Rankings';
  static const identityNote =
      'Tu etiqueta de identidad reconoce tu trayectoria. No desbloquea '
      'funciones: todas están disponibles desde el primer día.';

  // --- Mapa de calor público (CR-009) ---
  static const dashboardTitle = 'Mapa de observaciones';

  /// Título de la vista de mapa (entrada pública y pestaña "Mapa").
  static const mapTitle = 'Mapa del mezquite';

  /// Nota de obfuscación (gate #5 enmendado: 1 km → 300 m).
  static const obfuscationNote =
      'Las ubicaciones públicas se muestran aproximadas (celda de ~300 m) para '
      'proteger los árboles.';

  /// Entrada pública SIN login desde la Bienvenida (gate #3: abre siempre).
  static const publicMapButton = 'Ver el mapa público';

  /// Botón "ⓘ": abre el panel con disclaimer + indicadores.
  static const mapInfoTooltip = 'Acerca de estos datos';
  static const mapInfoTitle = 'Acerca de estos datos';

  /// Disclaimer del mapa (gates #5/#1). Ubicaciones aproximadas + dato
  /// ciudadano sin validación experta + nivel autodeclarado.
  static const mapDisclaimer =
      'Las ubicaciones son aproximadas (~300 m) para proteger a los árboles; '
      'nunca se muestra la posición exacta. Es un dato de origen ciudadano, sin '
      'validación por expertos, y el nivel de paxtle es autodeclarado por quien '
      'observa. El mapa muestra presencia e impacto del paxtle, no acciones de '
      'control ni de manejo.';

  /// Leyenda del calor (por g4_indice 0..3).
  static const mapLegendTitle = 'Nivel de paxtle (autodeclarado)';
  static const mapEmpty = 'Aún no hay observaciones públicas para mostrar.';
  static const mapError = 'No se pudo cargar el mapa. Intenta de nuevo.';

  /// Niveles de la leyenda (verde → rojo), 0..3.
  static const mapLegendLevels = ['Sano', 'Leve', 'Moderado', 'Severo'];

  /// Indicadores numéricos detrás del botón "ⓘ".
  static const mapIndicatorsTitle = 'Indicadores';

  // --- Cuenta + login (CR-002: identidad real con mínima PII, gate #2 acotado) ---
  static const accountTitle = 'Tu cuenta';
  static const noPiiNote =
      'Tu cuenta se identifica con un usuario público. No guardamos tu correo '
      'ni tu nombre: solo el identificador de tu cuenta de Google.';
  static const signInWithGoogle = 'Entrar con Google';
  static const googleSignInNote =
      'Entras con tu cuenta de Google. No guardamos tu correo ni tu nombre: '
      'solo un identificador para reconocerte la próxima vez.';
  static const loginError =
      'No pudimos iniciar sesión. Revisa tu conexión e inténtalo de nuevo.';

  // --- Ayuda ---
  static const helpTitle = 'Ayuda';

  // --- Legal: Términos y Aviso de privacidad (CR-006 §4.3) ---
  // BORRADOR sujeto a revisión legal de la organización responsable. Texto en español acorde a
  // la LFPDPPP. La FUENTE canónica vive en docs/legal/ (web-admin); esta es la
  // copia que la app muestra al voluntario. Gate #2 acotado (CR-002): la app
  // guarda solo el id opaco del proveedor; sin email/nombre/teléfono.
  static const legalTitle = 'Términos y privacidad';

  /// Enlace discreto en la Bienvenida, cerca de "Entrar con Google".
  static const legalConsentNote =
      'Al continuar aceptas los Términos y el Aviso de privacidad.';

  /// Aviso visible de que el texto es un borrador (no asesoría legal).
  static const legalDraftBanner =
      'BORRADOR sujeto a revisión legal del $orgName. Es un texto informativo, '
      'no asesoría legal, y no condiciona el uso de la app.';

  static const termsTitle = 'Términos y condiciones';
  static const termsBody =
      'Bienvenida o bienvenido al proyecto de ciencia ciudadana del mezquite '
      '(Prosopis laevigata). Al usar esta app participas como observadora u '
      'observador voluntario.\n\n'
      '1. Qué es. La app sirve para registrar y compartir observaciones del '
      'mezquite y del paxtle, con fines de conocimiento abierto. No ofrece '
      'recomendaciones de manejo, control ni tratamientos.\n\n'
      '2. Participación abierta. No hay niveles, certificaciones ni candados: '
      'todas las funciones están disponibles desde el primer día.\n\n'
      '3. Tu cuenta. Entras con tu cuenta de Google. No guardamos tu correo ni '
      'tu nombre; solo conservamos un identificador opaco para reconocerte la '
      'próxima vez.\n\n'
      '4. Tus aportaciones. Las observaciones que registras (foto, ubicación '
      'aproximada y tus estimaciones) se integran a un conjunto de datos de '
      'ciencia ciudadana de uso público y abierto.\n\n'
      '5. Buen uso. Registra observaciones reales y de buena fe; no entres a '
      'propiedad privada sin permiso y cuida tu seguridad en campo.\n\n'
      '6. Cambios. Estos términos pueden actualizarse; te avisaremos dentro de '
      'la app cuando haya cambios relevantes.';

  static const privacyTitle = 'Aviso de privacidad';
  static const privacyBody =
      'Este Aviso de privacidad describe, en términos de la Ley Federal de '
      'Protección de Datos Personales en Posesión de los Particulares '
      '(LFPDPPP), cómo se tratan tus datos en este proyecto.\n\n'
      'Datos que se recaban. De la persona voluntaria solo se conserva un '
      'identificador opaco entregado por tu proveedor de identidad (Google). '
      'No guardamos tu correo, tu nombre, tu teléfono ni otros datos que te '
      'identifiquen directamente.\n\n'
      'Finalidad. Tus datos se usan únicamente para la ciencia ciudadana del '
      'mezquite: registrar observaciones, atribuir tus aportaciones de forma '
      'seudónima y generar conocimiento abierto sobre el estado del mezquite y '
      'del paxtle.\n\n'
      'No venta ni cesión indebida. No vendemos tus datos ni los cedemos para '
      'fines ajenos al proyecto.\n\n'
      'Ubicación aproximada. Las ubicaciones que se muestran públicamente se '
      'difuminan a una celda de aproximadamente 300 m para proteger los árboles. '
      'Las coordenadas exactas solo se comparten con el aliado firmante del '
      'sitio correspondiente.\n\n'
      'Conservación. El identificador de tu cuenta se conserva mientras tu '
      'cuenta exista. Las observaciones (dato ecológico) se conservan de forma '
      'seudónima incluso si tu cuenta se elimina.\n\n'
      'Derechos ARCO. Tienes derecho a Acceder, Rectificar, Cancelar (eliminar) '
      'y Oponerte al tratamiento de tus datos. Hoy, la eliminación de cuenta la '
      'ejecuta el $orgName a petición tuya: al eliminar tu cuenta se borra tu '
      'identificador y tus observaciones quedan anonimizadas, conservando solo '
      'el dato ecológico.\n\n'
      'Cómo ejercer tus derechos. Solicita el ejercicio de tus derechos ARCO a '
      'través del $orgName, en el contacto indicado abajo.\n\n'
      'Contacto. Para dudas sobre privacidad o para ejercer tus derechos, '
      'escribe al $orgName: privacidad@proyecto-mezquite.org '
      '(contacto provisional, pendiente de confirmación).';

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
          'Tu evidencia ciudadana llega a las mesas con autoridades y expertos, '
          'que coordinan el manejo en las zonas más afectadas. La app documenta '
          'e informa; no aplica tratamientos.',
    ),
  ];
}

/// Módulo de Aprendizaje (CR-007). Mide engagement; SIN gating (gate #3).
///
/// El cuerpo del módulo NO vive aquí: se renderiza desde un asset markdown
/// bundleado (`assetPath`). La fuente única del contenido es `docs/learning/`,
/// que el orquestador copia a `mobile/assets/learning/` en la integración; en
/// dev/tests usamos stubs breves (ver `mobile/assets/learning/`). El contenido
/// es BORRADOR (AU2/H4) y la UI solo lo renderiza (gates #1/#8).
class LearningModule {
  const LearningModule({
    required this.id,
    required this.title,
    required this.summary,
    required this.assetPath,
  });

  final String id;
  final String title;
  final String summary;

  /// Ruta del markdown bundleado que la pantalla de detalle renderiza.
  final String assetPath;

  /// Los 7 módulos de "Aprender" (CR-007 §3). Ids/assets EXACTOS: el orquestador
  /// reemplaza los stubs de `assets/learning/<id>.md` por el contenido real de
  /// `docs/learning/<id>.md` (misma convención de nombres).
  static const placeholders = <LearningModule>[
    LearningModule(
      id: 'mod_que_es',
      title: '¿Qué es el mezquite?',
      summary: 'Conoce al árbol que documentamos y su papel en el ecosistema.',
      assetPath: 'assets/learning/mod_que_es.md',
    ),
    LearningModule(
      id: 'mod_paxtle',
      title: 'Reconocer el paxtle (heno motita)',
      summary: 'Cómo identificar visualmente la presencia y cobertura de paxtle.',
      assetPath: 'assets/learning/mod_paxtle.md',
    ),
    LearningModule(
      id: 'mod_cuscuta',
      title: 'Reconocer la cúscuta',
      summary: 'Hilos amarillos/anaranjados que sí extraen savia del mezquite.',
      assetPath: 'assets/learning/mod_cuscuta.md',
    ),
    LearningModule(
      id: 'mod_escala',
      title: 'La escala de observación (G4)',
      summary: 'Sano, leve, moderado, severo: cómo estimar el % de copa a ojo.',
      assetPath: 'assets/learning/mod_escala.md',
    ),
    LearningModule(
      id: 'mod_buena_foto',
      title: 'Una buena foto',
      summary: 'Encuadre, luz y distancia para que tu observación sea útil.',
      assetPath: 'assets/learning/mod_buena_foto.md',
    ),
    LearningModule(
      id: 'mod_ciencia_ciudadana',
      title: '¿Por qué participar?',
      summary: 'Tus observaciones forman un dataset abierto para el ${Copy.orgName}.',
      assetPath: 'assets/learning/mod_ciencia_ciudadana.md',
    ),
    LearningModule(
      id: 'mod_que_no_hace',
      title: 'Qué hace y qué NO hace la app',
      summary: 'Documentamos y educamos; no controlamos plagas ni damos recetas.',
      assetPath: 'assets/learning/mod_que_no_hace.md',
    ),
  ];
}
