/// Catálogo de estados/municipios para la captura (CR-010 #5).
///
/// Gate #8: estado/municipio son AUTODECLARADOS. La app **auto-detecta** el
/// municipio desde el GPS de la captura por cercanía al centroide (lookup local,
/// sin red) y lo **preselecciona**; el usuario puede corregirlo. La derivación
/// fina por `admin_boundary` vive en el backend (respaldo).
///
/// Centroides aproximados (lat/lon) de las 11 cabeceras municipales de
/// Aguascalientes. Sirven solo para preseleccionar el municipio más cercano;
/// NO son límites oficiales (eso lo decide el backend / `admin_boundary`).
library;

import 'dart:math' as math;

/// Estado por defecto del piloto.
const String kEstadoDefault = 'Aguascalientes';

/// Estados disponibles en el selector. Hoy solo el estado del piloto; se deja
/// como lista para que crezca sin tocar la UI.
const List<String> kEstados = <String>[kEstadoDefault];

/// Un municipio con su centroide (para la auto-detección por cercanía).
class Municipio {
  const Municipio(this.nombre, this.lat, this.lon);

  final String nombre;
  final double lat;
  final double lon;
}

/// Los 11 municipios de Aguascalientes con el centroide de su cabecera.
/// Coordenadas aproximadas (grados decimales).
const List<Municipio> kMunicipiosAguascalientes = <Municipio>[
  Municipio('Aguascalientes', 21.8853, -102.2916),
  Municipio('Asientos', 22.2380, -102.0890),
  Municipio('Calvillo', 21.8470, -102.7190),
  Municipio('Cosío', 22.3660, -102.3020),
  Municipio('Jesús María', 21.9610, -102.3430),
  Municipio('Pabellón de Arteaga', 22.1490, -102.2740),
  Municipio('Rincón de Romos', 22.2300, -102.3170),
  Municipio('San José de Gracia', 22.1490, -102.4130),
  Municipio('Tepezalá', 22.2230, -102.1700),
  Municipio('El Llano', 21.8910, -101.9760),
  Municipio('San Francisco de los Romo', 22.0780, -102.2680),
];

/// Nombres de los municipios (para el dropdown), en el orden del catálogo.
List<String> municipiosDe(String estado) {
  if (estado == kEstadoDefault) {
    return kMunicipiosAguascalientes.map((m) => m.nombre).toList();
  }
  return const <String>[];
}

/// Devuelve el nombre del municipio más cercano al punto [lat]/[lon] dentro del
/// [estado], o `null` si no hay catálogo para ese estado. Cercanía por distancia
/// euclidiana sobre el plano lat/lon (suficiente a escala estatal; sin red).
String? municipioMasCercano({
  required double lat,
  required double lon,
  String estado = kEstadoDefault,
}) {
  final municipios =
      estado == kEstadoDefault ? kMunicipiosAguascalientes : const <Municipio>[];
  if (municipios.isEmpty) return null;
  Municipio mejor = municipios.first;
  double mejorDist = double.infinity;
  for (final m in municipios) {
    final dLat = m.lat - lat;
    final dLon = m.lon - lon;
    final dist = math.sqrt(dLat * dLat + dLon * dLon);
    if (dist < mejorDist) {
      mejorDist = dist;
      mejor = m;
    }
  }
  return mejor.nombre;
}
