/// Cadenas de texto de la app. Centralizadas para revisión de copy (gate #1:
/// NADA promete control fitosanitario, reducción de infestación, ni
/// recomendaciones de manejo químico/mecánico).
class Copy {
  Copy._();

  /// Organización responsable del proyecto (decisión del usuario, 2026-06-17).
  /// Centralizado para no repetirlo y poder ajustarlo en un solo lugar. Domicilio y
  /// contacto oficiales (CR-006): Paseo de la Asunción #305, Jardines de Aguascalientes,
  /// C.P. 20270, Aguascalientes, México · contacto@rescatando-el-mezquite.org.
  static const orgName = 'Club Rotario Bosques Aguascalientes';

  static const appTitle = 'Mezquite — Ciencia ciudadana';
  static const welcomeSubtitle = 'Ciencia ciudadana';

  // --- Acerca de / licencia (CR-013) ---
  /// Nombre del proyecto que muestra "Acerca de".
  static const projectName = 'Mezquite — Ciencia ciudadana del mezquite';

  /// Versión visible del piloto. Es la etiqueta de release que pidió el usuario;
  /// el semver técnico del build vive en `pubspec.yaml`.
  static const appVersion = 'beta-2606';

  /// Titular del copyright: la organización responsable ($orgName). La autoría
  /// (desarrollo) se acredita aparte a su autor, con su correo de contacto.
  static const copyrightNotice = '© 2026 $orgName';
  static const authorName = 'Omar Velázquez';
  static const authorEmail = 'contacto@rescatando-el-mezquite.org';

  /// Pantalla "Acerca de".
  static const aboutTitle = 'Acerca de';
  static const aboutVersionLabel = 'Versión';
  static const aboutAuthorLabel = 'Desarrollo';
  static const aboutLicenseLabel = 'Licencia';
  static const aboutLicenseValue = 'MIT';
  static const aboutLicenseNote =
      'Software libre bajo licencia MIT. El código y esta documentación se '
      'distribuyen tal cual, sin garantía. Consulta el archivo LICENSE del '
      'proyecto para el texto completo.';
  static const aboutLicensesButton = 'Ver licencias de terceros';

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

  // --- Cámara web robusta (CR-018): preview con getUserMedia + errores claros ---
  static const cameraStarting = 'Abriendo la cámara…';
  static const cameraTakePhoto = 'Tomar foto';
  static const cameraSwitch = 'Cambiar cámara';
  static const cameraRetry = 'Reintentar';
  static const cameraOpen = 'Abrir cámara';
  static const cameraPermissionDenied =
      'No diste permiso para la cámara. Actívalo en los ajustes del navegador y '
      'vuelve a intentar.';
  static const cameraNotFound = 'No se encontró una cámara en este dispositivo.';
  static const cameraInUse =
      'La cámara está en uso por otra app. Ciérrala y vuelve a intentar.';
  static const cameraGenericError =
      'No se pudo abrir la cámara. Reintenta; si sigue fallando, repórtalo con el '
      'botón de abajo.';
  static const cameraDesktopNote =
      'Esta página es para teléfono o tablet. Ábrela en tu celular para tomar la '
      'foto con la cámara.';
  static const captureNivelLabel = 'Nivel de paxtle (parte de la copa cubierta)';
  static const captureNivelHint = 'Lo estimas tú a ojo; no se revisa.';
  static const captureCuscutaLabel = '¿Cúscuta visible?';
  static const captureDanioLabel = '¿Signos de daño? (defoliación / ramas muertas)';
  static const captureTamanioLabel = 'Tamaño del árbol';
  static const captureContextoLabel = 'Contexto del sitio';

  // --- Ubicación de la captura ---
  // CR-036: se retiran `captureEstadoLabel`, `captureMunicipioLabel` y `captureMunicipioHint`.
  // El voluntario ya no selecciona el lugar: lo deriva el servidor de las coordenadas y aquí solo
  // se le muestra, sin pedirle nada.
  static const captureUbicacionTitulo = 'Ubicación y momento';
  static const captureUbicacionResolviendo = 'Ubicando el lugar…';
  static const captureUbicacionSinResolver =
      'La ubicación se determinará al enviar.';

  // --- Revisión de la foto antes de enviarla (CR-037) ---
  //
  // El voluntario NUNCA veía la fotografía que acababa de tomar: ni al capturar los
  // datos ni después. El primer humano que la miraba era quien revisaba en la consola,
  // y para entonces la observación ya estaba enviada. Estos textos acompañan la
  // miniatura que cierra ese hueco.
  //
  // ⚠️ Gate #9: hablan de la FOTO (mirarla, ampliarla, repetirla), nunca de su suerte
  // en revisión. "Repetir foto" vuelve a la cámara: jamás abre la galería (gate #4).

  static const captureFotoTitulo = 'Revisa tu foto';
  static const captureFotoAmpliar = 'Toca la foto para verla en grande';
  static const captureFotoRepetir = 'Repetir foto';
  static const captureFotoCerrar = 'Cerrar';

  /// La imagen no se pudo decodificar. El recuadro conserva su tamaño igual (alto fijo),
  /// así que el aviso no descuadra el formulario.
  static const captureFotoError = 'No se pudo mostrar la foto.';

  static const captureSubmit = 'Registrar observación';

  // --- Confirmación del envío (CR-031) ---
  //
  // Aquí vivía un solo mensaje —"Observación registrada y aceptada"— que se
  // mostraba ANTES de que el servidor respondiera. Si la subida fallaba, el
  // voluntario ya había leído que todo salió bien. Ahora hay dos mensajes y cada
  // uno se muestra cuando de verdad corresponde.
  //
  // ⚠️ Gate #9 / Q5.A-D1: "guardada" y "registrada" hablan de **transporte**, no de
  // revisión. Los tres estados que el voluntario debe distinguir son:
  // en tu teléfono → subida (en revisión) → confirmada. Ningún texto de esta
  // sección puede insinuar un veredicto.

  /// Se guardó en el dispositivo y aún no ha llegado al servidor.
  static const captureSavedOffline =
      'Guardada en tu teléfono. Se enviará sola cuando haya internet.';

  /// El servidor confirmó la recepción.
  static const captureUploaded = 'Observación registrada. ¡Gracias por contribuir!';

  /// No se pudo ni guardar en el teléfono (almacenamiento lleno o no disponible).
  /// Es el único caso que debe alarmar: la captura no está a salvo en ningún sitio.
  static const captureSaveFailed =
      'No se pudo guardar la observación en tu teléfono. Revisa el espacio '
      'disponible e inténtalo de nuevo.';

  // --- Resumen agregado de aportaciones (CR-001) ---
  static const feedbackTitle = 'Tu aporte';
  static const feedbackNote =
      'Tus observaciones se registran al instante y el equipo del $orgName las '
      'revisa después; cuentan como válidas una vez confirmadas. Aquí ves un '
      'resumen de tus aportaciones, nunca el resultado de una foto en particular.';

  // --- Capturas por subir (CR-031; decisión D5: solo contador, sin lista) ---

  /// Contador de pendientes. Dice "por subir" y nunca "por revisar" (gate #9).
  static String pendingCount(int n) =>
      n == 1 ? '1 observación por subir' : '$n observaciones por subir';

  static const pendingUploadNow = 'Subir ahora';
  static const pendingUploading = 'Subiendo…';

  /// Explica que no hay nada que hacer: se envían solas.
  static const pendingNote =
      'Se envían solas cuando hay internet. No hace falta que hagas nada; '
      'puedes seguir capturando sin conexión.';

  /// Aviso al acumular muchas (D2). NUNCA impide capturar (gate #3).
  static String pendingWarning(int n) =>
      'Llevas $n observaciones sin subir. Cuando tengas internet, abre la app un '
      'momento para que se envíen.';

  /// Aviso insistente (D2, umbral alto).
  static String pendingWarningHigh(int n) =>
      'Llevas $n observaciones sin subir. Busca una conexión pronto para no '
      'acumular más en el teléfono.';

  /// Umbrales de aviso (D2). Ajustables en un solo sitio.
  static const pendingWarnAt = 50;
  static const pendingWarnHighAt = 150;

  /// La sesión venció (401): la cola NO se pierde.
  static const pendingSessionExpired =
      'Tu sesión expiró. Vuelve a entrar y tus observaciones se enviarán solas; '
      'no se ha perdido ninguna.';

  // --- Sesión vencida (CR-035) ---
  // Gate #9: estos textos hablan de entrar/guardar/enviar, JAMÁS de "revisión"
  // ni veredictos — son avisos de sesión/subida, no de validación.

  /// Banner global, no descartable: la sesión venció pero nada se bloquea.
  static const sessionExpiredBanner =
      'Tu sesión expiró. Puedes seguir capturando: todo se guarda en tu '
      'teléfono. Cuando tengas internet, vuelve a entrar para que se envíe.';

  /// Botón del banner y de la tarjeta de pendientes.
  static const sessionExpiredRelogin = 'Volver a entrar';

  /// SnackBar tras capturar con la sesión vencida: no promete que "se enviará
  /// sola" (con 401 no se enviará hasta volver a entrar).
  static const captureSavedSessionExpired =
      'Guardada en tu teléfono. Vuelve a entrar para que se envíe.';

  /// Alguna quedó marcada para revisar por el equipo (error permanente).
  static String pendingNeedsAttention(int n) => n == 1
      ? '1 observación no se pudo enviar. Repórtalo con el botón de "Reportar un '
          'problema" para que el equipo la recupere.'
      : '$n observaciones no se pudieron enviar. Repórtalo con el botón de '
          '"Reportar un problema" para que el equipo las recupere.';

  /// Advertencia al cerrar sesión con pendientes (D3). Se permite salir.
  static String logoutWithPending(int n) => n == 1
      ? 'Tienes 1 observación sin subir. Se queda guardada y se enviará cuando '
          'vuelvas a entrar.'
      : 'Tienes $n observaciones sin subir. Se quedan guardadas y se enviarán '
          'cuando vuelvas a entrar.';

  static const logoutConfirm = 'Cerrar sesión';
  static const logoutCancel = 'Cancelar';

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

  /// Tarjeta "Tu actividad" (CR-030). El primer renglón es el **total subido**:
  /// es lo que el voluntario cuenta en campo y lo que buscaba sin encontrarlo.
  /// Los demás renglones siguen el criterio de CR-026 (solo confirmadas), y por
  /// eso lo dicen en la etiqueta: dos números distintos con nombres distintos.
  static const activityTitle = 'Tu actividad';
  static const activitySubidas = 'Observaciones subidas';
  static const activityConfirmadas = 'Confirmadas por revisión';
  static const activityArboles = 'Árboles distintos confirmados';
  static const activityPuntos = 'Puntos';

  /// Nota que explica la brecha entre subidas y confirmadas. Solo aparece cuando
  /// hay algo en cola; si todo está revisado, sobra.
  static String activityEnRevision(int enRevision) => enRevision == 1
      ? '1 de tus observaciones sigue en revisión. Las insignias, los puntos y '
          'el mapa cuentan las confirmadas.'
      : '$enRevision de tus observaciones siguen en revisión. Las insignias, '
          'los puntos y el mapa cuentan las confirmadas.';
  static const identityNote =
      'Tu etiqueta de identidad reconoce tu trayectoria. No desbloquea '
      'funciones: todas están disponibles desde el primer día.';

  // --- Mapa público del mezquite (CR-009 · CR-025) ---
  static const dashboardTitle = 'Mapa de observaciones';

  /// Título de la vista de mapa (entrada pública y pestaña "Mapa").
  static const mapTitle = 'Mapa del mezquite';

  /// Nota del mapa público: presenta las observaciones ciudadanas del mezquite.
  static const obfuscationNote =
      'El mapa muestra las observaciones ciudadanas del mezquite.';

  /// Selector de vista del mapa (calor ⇄ ubicaciones exactas). Default: calor.
  static const mapModeHeat = 'Mapa de calor';
  static const mapModeExact = 'Ubicaciones exactas';

  /// Título del popup de una celda del mapa de calor.
  static const mapCellTitle = 'Celda del mapa de calor';

  /// Popup de un árbol en el modo de ubicaciones exactas.
  static const mapTreeTitle = 'Mezquite observado';
  static const mapTreeNivel = 'Nivel de paxtle';
  static const mapTreePaxtle = 'Paxtle';
  static const mapTreeCuscuta = 'Cúscuta';
  static const mapTreeFecha = 'Fecha';
  static const mapTreeUbicacion = 'Ubicación';

  /// Entrada pública SIN login desde la Bienvenida (gate #3: abre siempre).
  static const publicMapButton = 'Ver el mapa público';

  /// Instalación como PWA (CR-016). Botón propio "Instalar app" + instrucción iOS.
  static const installButton = 'Instalar app';
  static const installTitle = 'Instalar la app';
  static const installIosInstructions =
      'En iPhone o iPad: toca el botón Compartir (el cuadro con la flecha ↑) '
      'en la barra de Safari y elige "Agregar a inicio".';
  static const installIosOk = 'Entendido';

  /// Botón "ⓘ": abre el panel con disclaimer + indicadores.
  static const mapInfoTooltip = 'Acerca de estos datos';
  static const mapInfoTitle = 'Acerca de estos datos';

  /// Disclaimer del mapa (gate #1). Dato ciudadano sin validación experta +
  /// nivel de paxtle autodeclarado + sin acciones de control ni de manejo.
  static const mapDisclaimer =
      'Es un dato de origen ciudadano, sin validación por expertos, y el nivel '
      'de paxtle es autodeclarado por quien observa. El mapa muestra presencia '
      'e impacto del paxtle, no acciones de control ni de manejo.';

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

  // --- Registrar nueva institución (CR-010 #6) ---
  static const institutionSectionTitle = 'Institución';
  static const institutionSectionNote =
      'La afiliación se elige al crear la cuenta. Si tu institución no aparecía, '
      'puedes registrarla; el consorcio la revisará antes de mostrarla a todos.';
  static const institutionRequestButton = 'Registrar nueva institución';
  static const institutionRequestTitle = 'Registrar institución';
  static const institutionRequestNameLabel = 'Nombre de la institución';
  static const institutionRequestEstadoLabel = 'Estado';
  static const institutionRequestSubmit = 'Enviar solicitud';
  static const institutionRequestCancel = 'Cancelar';
  static const institutionRequestNameRequired = 'Escribe el nombre.';
  static const institutionRequestOk =
      'Solicitud enviada. El consorcio revisará tu institución.';
  static const institutionRequestError =
      'No se pudo enviar la solicitud. Intenta de nuevo.';

  // --- Antiduplicados (CR-028) ---
  // El nombre escrito ya estaba en el catálogo: se elige esa en vez de registrar una gemela.
  static String institutionAlreadyInList(String name) =>
      '"$name" ya está en la lista. La seleccionamos por ti.';
  // El backend detectó que ya existía (p. ej. otra persona la registró y aún no se aprueba).
  static const institutionRequestAlreadyExisted =
      'Esa institución ya estaba registrada. Quedaste afiliado a ella.';

  // --- Evidencia / comprobante de participación (CR-010 #7; CR-026) ---
  static const evidenceTitle = 'Mi participación';
  static const evidenceNote =
      'Este es un resumen de tu participación, útil como comprobante. Es '
      'descriptivo: cuenta tus aportaciones, sin acciones de manejo.';
  /// CR-030: el total subido va PRIMERO y como cifra propia. Es el número que el
  /// voluntario cuenta en campo; si solo ve el confirmado, concluye que la app
  /// dejó de registrarle.
  static const evidenceSubidas = 'Observaciones subidas';
  static const evidenceCapturas = 'Observaciones válidas registradas';

  /// CR-026: la diferencia entre lo subido y lo válido es, casi siempre, cola de
  /// revisión. Sin esta línea el voluntario lee "me rechazaron" y no es cierto.
  static const evidenceCapturasNota =
      'Solo se cuentan las observaciones que el equipo del $orgName ya revisó y '
      'confirmó. Las que subiste hace poco pueden seguir en revisión.';

  /// Pie que explica la brecha. CR-030: [pendientes] viene del servidor, así que
  /// ya no incluye las que no se pudieron confirmar.
  static String evidencePendientes(int pendientes, int totales) =>
      pendientes == 1
          ? 'De tus $totales subidas, 1 sigue en revisión.'
          : 'De tus $totales subidas, $pendientes siguen en revisión.';

  static const evidenceSesiones = 'Sesiones';
  static const evidenceRango = 'Periodo de actividad';
  static const evidenceSinRango = 'Aún sin actividad registrada.';
  static const evidenceError = 'No se pudo cargar tu participación.';
  static const evidenceOpen = 'Mi participación';

  // --- Ayuda ---
  static const helpTitle = 'Ayuda';

  /// Tooltip del botón "X" que oculta un aviso informativo (CR-021).
  static const dismissNote = 'Ocultar';

  // --- Reportar un problema (CR-019): diagnóstico sin PII ---
  static const reportButton = 'Reportar un problema';
  static const reportTitle = 'Reportar un problema';
  static const reportIntro =
      'Cuéntanos qué pasó. Se enviará información técnica de tu dispositivo '
      '(navegador, versión de la app y el último error) para ayudarnos a '
      'corregirlo. No incluimos tu nombre ni tu correo.';
  static const reportNoteLabel = 'Describe el problema (opcional)';
  static const reportNoteHint = 'Ej.: "Al tocar Tomar foto no abre la cámara".';
  static const reportSend = 'Enviar reporte';
  static const reportSending = 'Enviando…';
  static const reportSent = '¡Gracias! Recibimos tu reporte.';
  static const reportFailed =
      'No se pudo enviar el reporte. Revisa tu conexión e inténtalo de nuevo.';

  // --- Legal: Términos y Aviso de privacidad (CR-006 §4.3) ---
  // APROBADOS por la organización responsable (CR-020): Aviso de privacidad
  // (2026-06-25) y Términos (2026-06-27). Texto en español acorde a la LFPDPPP.
  // La FUENTE canónica vive en docs/legal/ (sincronizada con las páginas públicas
  // de Caddy); esta es la copia que la app muestra al voluntario. Gate #2 acotado
  // (CR-002): la app guarda solo el id opaco del proveedor; sin email/nombre/teléfono.
  static const legalTitle = 'Términos y privacidad';

  /// Enlace discreto en la Bienvenida, cerca de "Entrar con Google".
  static const legalConsentNote =
      'Al continuar aceptas los Términos y el Aviso de privacidad.';

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
      'y tus estimaciones) se integran a un conjunto de datos de ciencia '
      'ciudadana de uso público y abierto.\n\n'
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
      'Ubicación de las observaciones. La ubicación de cada mezquite que '
      'registras forma parte del conjunto de datos abierto del proyecto y se '
      'muestra públicamente en el mapa.\n\n'
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
      'escribe al $orgName (Paseo de la Asunción #305, Jardines de '
      'Aguascalientes, C.P. 20270, Aguascalientes, México): '
      'contacto@rescatando-el-mezquite.org.';

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
