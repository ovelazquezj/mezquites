/// Textos y etiquetas legibles de la web admin. Centralizados para humanizar el
/// copy y traducir los valores "wire"/claves del backend que, de otro modo, se
/// mostrarían crudos (snake_case) al usuario.
///
/// Gates: nada promete control fitosanitario/reducción de infestación (gate #1);
/// la calidad la decide una persona en la web admin —sin validación automática—
/// (gates #8/#9 enmendados por CR-001). La ubicación exacta del mezquite es
/// información pública (CR-025).
class Copy {
  Copy._();

  /// Organización responsable del proyecto (decisión del usuario, 2026-06-17).
  /// Centralizado para no repetirlo y poder ajustarlo en un solo lugar. La
  /// denominación legal exacta, domicilio y contacto oficiales siguen pendientes.
  static const orgName = 'Club Rotario Bosques Aguascalientes';

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

  // --- Navegación / títulos generales ---
  static const navPublic = 'Panel público';
  // Mapa de calor público en la consola (CR-010 #2).
  static const navMap = 'Mapa';
  // Datos y descarga del analista (CR-010 #3).
  static const navData = 'Datos y descargas';
  static const navInstitutions = 'Instituciones';
  static const navAllies = 'Aliados firmantes';
  static const navIndicators = 'Indicadores';
  static const navSnapshots = 'Cortes trimestrales';
  static const navRestricted = 'Panel con ubicación exacta';
  // Revisión humana (CR-001).
  static const navReview = 'Revisión de observaciones';
  static const navMonitor = 'Monitor de revisión';
  // Gestión de usuarios (CR-002, solo administrador).
  static const navUsers = 'Usuarios del equipo';
  // Cancelación de cuenta — derecho ARCO (CR-006, solo administrador).
  static const navAccounts = 'Eliminar cuenta';
  // Reportes de problemas (CR-019, admin_consorcio/administrador).
  static const navProblems = 'Reportes';
  // Términos y Aviso de privacidad (CR-006).
  static const navLegal = 'Legal';
  // Acerca de (CR-013): nombre, versión y créditos. Visible a toda la consola.
  static const navAbout = 'Acerca de';

  // --- ARCO: eliminar cuenta (CR-006, solo administrador) ---
  static const accountsIntro =
      'Una persona puede pedir que eliminemos su cuenta (derecho de cancelación '
      'de la LFPDPPP). Al hacerlo, su identidad se borra y sus observaciones se '
      'vuelven anónimas: el dato ecológico se conserva en el panel público, pero '
      'ya no queda ligado a esa persona. Esta acción no se puede deshacer.';
  static const accountsSearchLabel = 'Buscar por usuario o handle';
  static const accountsSearch = 'Buscar';
  static const accountsEmpty = 'No se encontraron cuentas con ese criterio.';
  static const accountsDelete = 'Eliminar cuenta';
  static const accountsReasonLabel = 'Motivo (para el registro de auditoría)';
  static const accountsReasonHint =
      'No incluyas datos personales; queda en la bitácora de auditoría.';
  static const accountsConfirmTitle = '¿Eliminar esta cuenta?';
  static const accountsConfirmCancel = 'Cancelar';
  static const accountsConfirmOk = 'Sí, eliminar';

  // --- Legal: Términos y Aviso de privacidad (CR-006; APROBADOS, CR-020) ---
  static const legalIntro =
      'Términos y Condiciones y Aviso de privacidad del piloto, aprobados por el '
      '$orgName. La versión completa vive en docs/legal/.';
  static const legalTermsTitle = 'Términos y Condiciones';
  static const legalPrivacyTitle = 'Aviso de privacidad';

  // --- Revisión humana (CR-001) ---
  static const reviewIntro =
      'Revisa las fotos que envían las personas voluntarias y decide si '
      'quedan en el panel público. Por defecto toda observación queda aceptada '
      'y visible; aquí puedes confirmarla o retirarla.';
  static const reviewQueueEmpty = 'No hay observaciones para este filtro.';
  static const reviewConfirm = 'Confirmar';
  static const reviewReject = 'Retirar';
  // Tercer veredicto (CR-010 #4): regresa la observación al estado por defecto.
  static const reviewReopen = 'Volver a aceptada';
  static const reviewReopened = 'Observación de nuevo aceptada (visible en público).';
  static const reviewImageError = 'No se pudo cargar la imagen.';

  // --- CR-029: veredicto idempotente + visor con zoom ---
  /// El backend no registró nada porque la observación ya estaba en ese estado.
  static const reviewNoChange =
      'La observación ya estaba en ese estado; no se registró un veredicto nuevo.';
  static String reviewCurrentState(String estado) =>
      'Estado actual: $estado. El veredicto que ya corresponde aparece deshabilitado.';
  static const reviewZoomHint = 'Clic en la foto para ampliarla';
  static const reviewZoomControls =
      'Arrastra para mover · doble clic para acercar · Esc para cerrar';
  static const reviewNoteLabel = 'Nota (opcional)';
  static const reviewHistoryTitle = 'Historial de revisión';
  static const reviewNoHistory = 'Sin revisiones aún.';
  static const reviewOpenDetail = 'Abrir';
  static const reviewConfirmed = 'Observación confirmada.';
  static const reviewRejected = 'Observación retirada del panel público.';
  static const reviewLocationNote =
      'En la revisión ves el estado y el municipio de cada observación.';
  static const monitorIntro =
      'Métricas de la revisión de observaciones. Solo consulta.';

  // --- Mapa de calor en la consola (CR-010 #2) ---
  static const mapIntro =
      'Mapa de calor de las observaciones confirmadas. Severidad autodeclarada '
      'por quien observa; sin validación experta.';
  static const mapError = 'No se pudo cargar el mapa. Inténtalo de nuevo.';
  static const mapLegendTitle = 'Nivel de paxtle (autodeclarado)';
  static const mapLegendLevels = ['Sano', 'Leve', 'Moderado', 'Severo'];
  static const mapCellTitle = 'Celda del mapa de calor';
  static const mapCellObs = 'Observaciones';
  static const mapCellPaxtle = 'Con paxtle';
  static const mapCellCuscuta = 'Con cúscuta';
  static const mapCellNivel = 'Nivel de paxtle (promedio)';

  // --- Mapa: modo de ubicación exacta (CR-025, información pública) ---
  static const mapModeHeat = 'Mapa de calor';
  static const mapModeExact = 'Ubicaciones exactas';
  static const mapExactPopupTitle = 'Árbol (ubicación exacta)';
  static const mapExactPopupLat = 'Latitud';
  static const mapExactPopupLon = 'Longitud';
  static const mapExactError =
      'No se pudieron cargar las ubicaciones exactas. Inténtalo de nuevo.';

  // --- Mapa: filtro por estado de revisión (CR-026) ---
  static const mapFilterLabel = 'Mostrar';
  static const mapFilterConfirmadas = 'Confirmadas (lo que ve el público)';
  static const mapFilterPendientes = 'Pendientes de revisión';
  static const mapFilterRechazadas = 'Rechazadas';
  static const mapFilterTodas = 'Todas';
  static const mapFilterNote =
      'El mapa público solo muestra observaciones confirmadas. Aquí puedes ver '
      'además las que siguen en revisión o fueron rechazadas.';

  // --- Datos y descargas del analista (CR-010 #3) ---
  static const dataIntro =
      'Tabla de observaciones para análisis. Muestra estado y municipio de cada '
      'observación. Severidad autodeclarada; sin validación experta.';
  static const dataFilterEstadoRevision = 'Estado de revisión';
  static const dataFilterMunicipio = 'Municipio';
  static const dataFilterNivel = 'Nivel de paxtle';
  static const dataFilterDesde = 'Desde (AAAA-MM-DD)';
  static const dataFilterHasta = 'Hasta (AAAA-MM-DD)';
  static const dataApplyFilters = 'Aplicar filtros';
  static const dataClearFilters = 'Limpiar';
  static const dataDownloadCsv = 'Descargar CSV';

  // --- Reporte de participación por día (CR-026, para las universidades) ---
  static const dataDownloadParticipationCsv = 'Descargar participación por día';
  static const dataParticipationNote =
      'El reporte de participación trae, por día y voluntario, sus sesiones y '
      'horas junto a cuántas observaciones quedaron confirmadas, rechazadas o '
      'pendientes de revisión. Las horas miden tiempo con la app abierta, no '
      'trabajo en campo: úsalas como referencia, no como constancia.';
  static const dataDownloadDone = 'CSV descargado.';
  static const dataDownloadError = 'No se pudo descargar el CSV. Inténtalo de nuevo.';
  static const dataEmpty = 'No hay observaciones para estos filtros.';
  static const dataSummaryTotal = 'Total de observaciones';
  static const dataSummaryByRevision = 'Por estado de revisión';
  static const dataSummaryByNivel = 'Por nivel de paxtle';
  static const dataSummaryByMunicipio = 'Por municipio';
  // Aviso para roles con ubicación exacta: el CSV trae las coordenadas (CR-025).
  static const dataExactNote =
      'El CSV que descargues incluye la latitud y longitud exactas de cada árbol.';

  // --- Reportes de problemas (CR-019, admin) ---
  static const problemsTitle = 'Reportes de problemas';
  static const problemsIntro =
      'Avisos de problemas que envían las personas usuarias desde las apps. '
      'Márcalos como "Visto" cuando los estés atendiendo y como "Resuelto" '
      'cuando queden arreglados.';
  static const problemsRefresh = 'Actualizar';
  static const problemsLoadError =
      'No se pudieron cargar los reportes. Inténtalo de nuevo.';
  static const problemsEmpty = 'No hay reportes de problemas por ahora.';
  static const problemsViewDetail = 'Ver detalle';
  static const problemsMarkSeen = 'Visto';
  static const problemsMarkResolved = 'Resuelto';
  static const problemsMarkedSeen = 'Reporte marcado como visto.';
  static const problemsMarkedResolved = 'Reporte marcado como resuelto.';
  static const problemsActionError =
      'No se pudo actualizar el reporte. Inténtalo de nuevo.';
  static const problemsAnon = 'Anónimo';
  static const problemsDetailTitle = 'Detalle del reporte';
  static const problemsNoMessage = 'Sin mensaje.';
  static const problemsNoDetail = 'No hay detalle técnico para este reporte.';
  static const problemsDetailLabel = 'Detalle técnico';
  static const problemsMessageLabel = 'Mensaje';
  static const problemsContextLabel = 'Contexto';
  static const problemsDateLabel = 'Fecha';
  static const problemsUserLabel = 'Usuario';
  static const problemsBrowserLabel = 'Navegador';
  static const problemsPlatformLabel = 'Plataforma';
  static const problemsVersionLabel = 'Versión';
  static const problemsStatusLabel = 'Estado';

  /// Estado de un reporte de problema (wire del backend) → etiqueta legible.
  static String problemStatus(String wire) =>
      const {
        'nuevo': 'Nuevo',
        'visto': 'Visto',
        'resuelto': 'Resuelto',
      }[wire] ??
      wire;

  /// Etiqueta legible de las claves de indicadores que entrega el backend
  /// (`/public/indicators`). Si una clave no está mapeada, se humaniza el
  /// snake_case como respaldo en vez de mostrarlo crudo.
  static String indicatorLabel(String key) =>
      _indicatorLabels[key] ?? _humanizeKey(key);

  static const _indicatorLabels = <String, String>{
    // social
    'registrados': 'Personas registradas',
    'activos_30d': 'Activos (últimos 30 días)',
    'observaciones_totales': 'Observaciones totales',
    'observaciones_confirmadas': 'Observaciones confirmadas',
    // CR-030 añadió el total crudo; sin etiqueta salía "Observaciones capturadas"
    // sin explicar la diferencia con las confirmadas (CR-034).
    'observaciones_capturadas': 'Observaciones subidas (incluye las no revisadas)',
    'instituciones_activas': 'Instituciones activas',
    // educativo
    'distribucion_identidad_e3': 'Distribución por nivel de observador',
    'proporcion_no_rechazadas': 'Proporción de observaciones no retiradas',
    'proporcion_confirmada': 'Avance de revisión',
    // ecológico
    'arboles_unicos': 'Árboles distintos',
    'arboles_serie_temporal': 'Árboles con seguimiento en el tiempo',
    'cobertura_municipios': 'Municipios cubiertos',
    'distribucion_niveles': 'Distribución por nivel de paxtle',
    // organizacional (Q6 amendment)
    'mesas_formales_autoridades': 'Mesas formales con autoridades',
    'aliados_firmantes_coords': 'Aliados firmantes con convenio',
    'eventos_w3': 'Eventos realizados',
    'menciones_mediaticas': 'Menciones en medios',
  };

  /// Etiqueta de identidad E3/L3 (wire del backend) → legible (CR-034: el
  /// desglose del panel público la mostraba cruda dentro de un `{...}`).
  static String identidadE3(String wire) =>
      const {
        'nuevo_observador': 'Nuevo observador',
        'observador': 'Observador',
        'observador_experimentado': 'Observador experimentado',
        'veterano_del_mezquite': 'Veterano del mezquite',
      }[wire] ??
      _humanizeKey(wire);

  /// Nivel de paxtle (wire del backend) → etiqueta legible.
  static String nivelG4(String wire) =>
      const {
        'sano': 'Sano',
        'leve': 'Leve',
        'moderado': 'Moderado',
        'severo': 'Severo',
      }[wire] ??
      wire;

  /// Estado de revisión (wire del backend, CR-001) → etiqueta legible.
  static String estadoRevision(String wire) =>
      const {
        'aceptada': 'Aceptada',
        'confirmada': 'Confirmada',
        'rechazada': 'Retirada',
      }[wire] ??
      wire;

  /// Situación de una institución (wire) → etiqueta legible.
  static String institutionStatus(String wire) =>
      const {
        'aprobada': 'Aprobada',
        'solicitada': 'Solicitada',
      }[wire] ??
      wire;

  /// Rol (clave del backend) → etiqueta legible. **Cosmético:** unifica cómo se
  /// muestran los roles en la consola; no cambia claves, poderes ni gating.
  /// `administrador` y `admin_consorcio` siguen siendo roles distintos (de ahí
  /// nombres distinguibles). Respaldo: humaniza el snake_case si falta la clave.
  static String roleLabel(String wire) =>
      _roleLabels[wire] ?? _humanizeKey(wire);

  static const _roleLabels = <String, String>{
    'voluntario': 'Voluntario',
    'aliado_firmante': 'Aliado firmante',
    'administrador': 'Administrador general',
    'admin_consorcio': 'Administrador de la organización',
    'evaluador': 'Evaluador',
    'analista': 'Analista',
  };

  /// Respaldo: convierte una clave snake_case en algo legible
  /// (`cobertura_municipios` → `Cobertura municipios`).
  static String _humanizeKey(String key) {
    if (key.isEmpty) return key;
    final spaced = key.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
