/// Vocabulario controlado de captura (Q2/Q3). Los `wire` deben coincidir
/// EXACTAMENTE con los `Literal` de `backend/app/schemas.py`.
library;

/// Nivel de infestación G4 (Q3, A2) — 4 opciones con su rango % de copa.
/// Gate #8: AUTODECLARADO; la UI NO afirma que se valida.
enum NivelG4 {
  sano('sano', 'Sano', '0%'),
  leve('leve', 'Leve', '>0% – 25%'),
  moderado('moderado', 'Moderado', '>25% – 50%'),
  severo('severo', 'Severo', '>50%');

  const NivelG4(this.wire, this.label, this.rango);

  /// Valor que viaja al backend (coincide con el `Literal` de schemas.py).
  final String wire;

  /// Etiqueta visible.
  final String label;

  /// Rango % de copa colonizada por paxtle (A2), visible en el selector.
  final String rango;
}

/// Tamaño del árbol (V3) — dropdown obligatorio.
enum Tamanio {
  pequeno('pequeno', 'Pequeño'),
  mediano('mediano', 'Mediano'),
  grande('grande', 'Grande'),
  noEstimable('no_estimable', 'No estimable');

  const Tamanio(this.wire, this.label);

  final String wire;
  final String label;
}

/// Contexto del sitio (V3) — dropdown obligatorio.
enum Contexto {
  campoAbierto('campo_abierto', 'Campo abierto'),
  bordeCultivo('borde_cultivo', 'Borde de cultivo'),
  urbano('urbano', 'Urbano'),
  ripario('ripario', 'Junto a un río o arroyo'),
  otro('otro', 'Otro');

  const Contexto(this.wire, this.label);

  final String wire;
  final String label;
}
