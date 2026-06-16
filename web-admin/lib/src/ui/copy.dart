/// Textos y etiquetas legibles de la web admin. Centralizados para humanizar el
/// copy y traducir los valores "wire"/claves del backend que, de otro modo, se
/// mostrarían crudos (snake_case) al usuario.
///
/// Gates: nada promete control fitosanitario/reducción de infestación (gate #1);
/// la validación automática solo confirma es-árbol + presencia de parásitos
/// (gate #8); las vistas públicas nunca prometen más fino que ~1 km (gate #5).
class Copy {
  Copy._();

  // --- Navegación / títulos generales ---
  static const navPublic = 'Panel público';
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

  // --- Revisión humana (CR-001) ---
  static const reviewIntro =
      'Revisa las fotos que envían las personas voluntarias y decide si '
      'quedan en el panel público. Por defecto toda observación queda aceptada '
      'y visible; aquí puedes confirmarla o retirarla.';
  static const reviewQueueEmpty = 'No hay observaciones para este filtro.';
  static const reviewConfirm = 'Confirmar';
  static const reviewReject = 'Retirar';
  static const reviewNoteLabel = 'Nota (opcional)';
  static const reviewHistoryTitle = 'Historial de revisión';
  static const reviewNoHistory = 'Sin revisiones aún.';
  static const reviewOpenDetail = 'Abrir';
  static const reviewConfirmed = 'Observación confirmada.';
  static const reviewRejected = 'Observación retirada del panel público.';
  static const reviewLocationNote =
      'Por privacidad de los árboles, aquí solo ves estado y municipio, '
      'nunca la ubicación exacta.';
  static const monitorIntro =
      'Métricas de la revisión de observaciones. Solo consulta.';

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
    'observaciones_validadas': 'Observaciones válidas',
    'instituciones_activas': 'Instituciones activas',
    // educativo
    'distribucion_identidad_e3': 'Distribución por nivel de observador',
    'tasa_validacion_promedio': 'Proporción de observaciones válidas',
    // ecológico
    'arboles_unicos': 'Árboles distintos',
    'arboles_serie_temporal': 'Árboles con seguimiento en el tiempo',
    'cobertura_municipios': 'Municipios cubiertos',
    'distribucion_niveles': 'Distribución por nivel de paxtle',
    // organizacional (Q6 amendment)
    'mesas_formales_autoridades': 'Mesas formales con autoridades',
    'aliados_firmantes_coords': 'Aliados firmantes con acceso a ubicación exacta',
    'eventos_w3': 'Eventos realizados',
    'menciones_mediaticas': 'Menciones en medios',
  };

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

  /// Respaldo: convierte una clave snake_case en algo legible
  /// (`cobertura_municipios` → `Cobertura municipios`).
  static String _humanizeKey(String key) {
    if (key.isEmpty) return key;
    final spaced = key.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
