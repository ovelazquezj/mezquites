import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/session.dart';

/// Catálogo de entidades federativas (CR-036). Se pide una vez y se reusa en las pantallas.
final geoEstadosProvider = FutureProvider<List<GeoEstado>>(
  (ref) => ref.read(apiClientProvider).geoEstados(),
);

/// Municipios de una entidad. `family` por clave: cada estado se pide una sola vez y queda
/// cacheado, así cambiar de estado ida y vuelta no repite la petición.
final geoMunicipiosProvider =
    FutureProvider.family<List<GeoMunicipio>, String>(
  (ref, cveEnt) => ref.read(apiClientProvider).geoMunicipios(cveEnt: cveEnt),
);

/// Selección geográfica: entidad y, opcionalmente, municipio dentro de ella.
@immutable
class GeoSeleccion {
  const GeoSeleccion({this.cveEnt, this.cveMun, this.estado, this.municipio});

  final String? cveEnt;
  final String? cveMun;

  /// Nombres, solo para mostrarlos. Los filtros viajan por clave.
  final String? estado;
  final String? municipio;

  bool get vacia => cveEnt == null;

  @override
  bool operator ==(Object other) =>
      other is GeoSeleccion && other.cveEnt == cveEnt && other.cveMun == cveMun;

  @override
  int get hashCode => Object.hash(cveEnt, cveMun);
}

/// Filtro geográfico de dos niveles: **estado → municipio**, poblados desde `/geo/*`.
///
/// Sustituye al `EstadoFilter` de texto libre. Aquel se escribió cuando el dataset era de un solo
/// estado y una lista hardcodeada habría contradicho el escalamiento (Q8); ahora el catálogo lo
/// sirve el servidor, así que el selector puede ser cerrado sin fijar nada en el cliente.
///
/// **El municipio depende del estado a propósito.** Los nombres de municipio se repiten entre
/// entidades —"Jesús María" existe en Aguascalientes, Jalisco y Nayarit—, así que un selector de
/// municipios "de todo el país" produciría listas ambiguas. Pedir el estado primero también es lo
/// que hace inequívoca la clave que viaja al backend.
class GeoFilter extends ConsumerWidget {
  const GeoFilter({
    super.key,
    required this.value,
    required this.onChanged,
    this.mostrarMunicipio = true,
  });

  final GeoSeleccion value;
  final ValueChanged<GeoSeleccion> onChanged;

  /// El mapa filtra solo por estado; las tablas bajan a municipio.
  final bool mostrarMunicipio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estados = ref.watch(geoEstadosProvider);

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: estados.when(
            loading: () => const LinearProgressIndicator(),
            // Si el catálogo no carga, el filtro se apaga en vez de bloquear la pantalla: los
            // datos se siguen viendo completos, que es el comportamiento previo a este CR.
            error: (_, __) => const Text('Catálogo de estados no disponible'),
            data: (lista) => DropdownButtonFormField<String?>(
              key: const Key('geo-filter-estado'),
              value: value.cveEnt,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Estado',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Todos los estados'),
                ),
                for (final e in lista)
                  DropdownMenuItem<String?>(
                    value: e.cveEnt,
                    child: Text(e.estado),
                  ),
              ],
              onChanged: (cve) {
                // Cambiar de estado SIEMPRE limpia el municipio: conservarlo dejaría activo un
                // filtro por una clave que no pertenece al estado nuevo y la tabla saldría vacía
                // sin explicación.
                final nombre =
                    lista.where((e) => e.cveEnt == cve).map((e) => e.estado).firstOrNull;
                onChanged(GeoSeleccion(cveEnt: cve, estado: nombre));
              },
            ),
          ),
        ),
        if (mostrarMunicipio && value.cveEnt != null)
          SizedBox(
            width: 260,
            child: ref.watch(geoMunicipiosProvider(value.cveEnt!)).when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const Text('Municipios no disponibles'),
                  data: (municipios) => DropdownButtonFormField<String?>(
                    key: const Key('geo-filter-municipio'),
                    value: value.cveMun,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Municipio',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos los municipios'),
                      ),
                      for (final m in municipios)
                        DropdownMenuItem<String?>(
                          value: m.cveMun,
                          child: Text(m.municipio),
                        ),
                    ],
                    onChanged: (cveMun) {
                      final nombre = municipios
                          .where((m) => m.cveMun == cveMun)
                          .map((m) => m.municipio)
                          .firstOrNull;
                      onChanged(GeoSeleccion(
                        cveEnt: value.cveEnt,
                        estado: value.estado,
                        cveMun: cveMun,
                        municipio: nombre,
                      ));
                    },
                  ),
                ),
          ),
        if (!value.vacia)
          TextButton(
            key: const Key('geo-filter-clear'),
            onPressed: () => onChanged(const GeoSeleccion()),
            child: const Text('Limpiar'),
          ),
      ],
    );
  }
}
