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

  /// Reconstruye el valor a partir de su `wire` (CR-031: una captura guardada en
  /// el dispositivo se rehidrata para subirla más tarde). Lanza si no existe: un
  /// `wire` desconocido significa dato corrupto, y fallar es mejor que subir una
  /// etiqueta inventada.
  static NivelG4 byWire(String wire) => values.firstWhere((v) => v.wire == wire);
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

  /// Ver [NivelG4.byWire] (CR-031).
  static Tamanio byWire(String wire) => values.firstWhere((v) => v.wire == wire);
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

  /// Ver [NivelG4.byWire] (CR-031).
  static Contexto byWire(String wire) => values.firstWhere((v) => v.wire == wire);
}
