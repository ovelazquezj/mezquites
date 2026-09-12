import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../models/models.dart';
import '../state/session.dart';
import '../ui/copy.dart';
import '../widgets/geo_filter.dart';

/// Indicadores organizacionales (Q6 amendment): captura MANUAL en la web admin
/// (mesas formales, aliados firmantes, eventos W3, menciones/coberturas).
///
/// **SIN lógica de umbrales/aprobación (U1, gate boundary):** solo registro y
/// visualización. No hay metas, semáforos ni juicio de aprobación/reprobación.
///
/// **CR-042** corrige dos cosas que reportó el usuario:
///   1. *"Los indicadores desaparecen."* La pantalla guardaba una lista local
///      ("Capturados en esta sesión") y **nunca leía del servidor**; como el
///      `HomeShell` monta las pantallas con `_screens[_index]` (no un
///      `IndexedStack`), salir de la sección destruía el `State` y con él la
///      lista. Los datos sí estaban guardados. Ahora la lista **viene del
///      servidor** y se recarga tras cada alta, edición o borrado.
///   2. *"Tres casilleros y solo el primero es intuitivo."* El tercero decía
///      "Estado (opcional)" pero pedía la **entidad federativa** (es el filtro
///      geográfico del panel público) y era texto libre, así que ahí se escribía
///      lo que había pasado. Ahora la entidad es una **lista** (obligatoria) y
///      "¿Qué pasó?" tiene su propio campo.
class OrgIndicatorsScreen extends ConsumerStatefulWidget {
  const OrgIndicatorsScreen({super.key});

  @override
  ConsumerState<OrgIndicatorsScreen> createState() =>
      _OrgIndicatorsScreenState();
}

class _OrgIndicatorsScreenState extends ConsumerState<OrgIndicatorsScreen> {
  OrganizationalIndicatorKey _key = OrganizationalIndicatorKey.all.first;

  /// Arranca en "1": el caso normal es registrar **un** evento, una mesa, una
  /// mención. Dejarlo vacío obligaba a teclear siempre lo mismo.
  final _valueCtrl = TextEditingController(text: '1');
  final _descripcionCtrl = TextEditingController();
  String? _entidad;

  bool _busy = false;

  List<OrganizationalIndicator> _registros = const [];
  bool _cargando = true;
  bool _errorCarga = false;

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _recargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = false;
    });
    try {
      final lista =
          await ref.read(apiClientProvider).listOrganizationalIndicators();
      if (!mounted) return;
      setState(() {
        _registros = lista;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorCarga = true;
        _cargando = false;
      });
    }
  }

  Future<void> _submit() async {
    final value = double.tryParse(_valueCtrl.text.trim());
    if (value == null) {
      _snack(Copy.orgValueInvalid);
      return;
    }
    final entidad = _entidad;
    // El botón ya está deshabilitado sin entidad; esto es el cinturón: el
    // backend responde 422 y el mensaje crudo no le diría nada a nadie.
    if (entidad == null || entidad.isEmpty) {
      _snack(Copy.orgEntidadRequerida);
      return;
    }
    final descripcion = _descripcionCtrl.text.trim();

    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).addOrganizationalIndicator(
            key: _key.key,
            value: value,
            estado: entidad,
            descripcion: descripcion.isEmpty ? null : descripcion,
          );
      if (mounted) {
        setState(() {
          _valueCtrl.text = '1';
          _descripcionCtrl.clear();
        });
      }
      await _recargar();
      _snack(Copy.orgAdded);
    } on ApiException catch (_) {
      _snack(Copy.orgAddError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editar(
      OrganizationalIndicator r, List<String> entidades) async {
    final cambio = await showDialog<_EdicionIndicador>(
      context: context,
      builder: (ctx) => _EditarIndicadorDialog(
        registro: r,
        entidades: entidades,
      ),
    );
    if (cambio == null) return; // cancelado

    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).patchOrganizationalIndicator(
            id: r.id,
            value: cambio.value,
            estado: cambio.estado,
            descripcion: cambio.descripcion,
          );
      await _recargar();
      _snack(Copy.orgEdited);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        await _recargar();
        _snack(Copy.orgGone);
      } else {
        _snack(Copy.orgEditError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _eliminar(OrganizationalIndicator r) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('org-delete-dialog'),
        title: const Text(Copy.orgDeleteTitle),
        content: Text(Copy.orgDeleteBody(
          indicador: Copy.indicatorLabel(r.key),
          cantidad: _fmtCantidad(r.value),
          entidad: r.estado,
        )),
        actions: [
          TextButton(
            key: const Key('org-delete-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(Copy.orgDeleteCancel),
          ),
          FilledButton(
            key: const Key('org-delete-ok'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(Copy.orgDeleteOk),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).deleteOrganizationalIndicator(id: r.id);
      await _recargar();
      _snack(Copy.orgDeleted);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        await _recargar();
        _snack(Copy.orgGone);
      } else {
        _snack(Copy.orgDeleteError);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Suma por clave, en el orden del catálogo. Es lo que el panel público
  /// publica: varios registros de la misma clave se suman, no se reemplazan.
  Map<String, double> get _totales {
    final suma = <String, double>{};
    for (final r in _registros) {
      suma[r.key] = (suma[r.key] ?? 0) + r.value;
    }
    final ordenado = <String, double>{};
    for (final k in OrganizationalIndicatorKey.all) {
      if (suma.containsKey(k.key)) ordenado[k.key] = suma[k.key]!;
    }
    // Claves que el catálogo de la consola todavía no conoce: se muestran al
    // final en vez de desaparecer del total.
    for (final e in suma.entries) {
      ordenado.putIfAbsent(e.key, () => e.value);
    }
    return ordenado;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // El catálogo de entidades lo sirve el backend desde CR-036: aquí no se fija
    // ninguna lista, solo se le añade "Otro" para lo que no cae en una entidad
    // (nacional, en línea, fuera del país).
    final estadosAsync = ref.watch(geoEstadosProvider);
    final entidades = <String>[
      ...estadosAsync.maybeWhen(
        data: (lista) => lista.map((e) => e.estado),
        orElse: () => const <String>[],
      ),
      Copy.orgEntidadOtro,
    ];
    final cargandoEntidades = estadosAsync.isLoading;
    final errorEntidades = estadosAsync.hasError;

    final puedeRegistrar = !_busy && _entidad != null;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(Copy.orgTitle, style: theme.textTheme.displayLarge),
        const SizedBox(height: 8),
        Text(
          Copy.orgIntro,
          key: const Key('org-u1-note'),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Copy.orgFormTitle, style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    SizedBox(
                      width: 320,
                      child:
                          DropdownButtonFormField<OrganizationalIndicatorKey>(
                        key: const Key('org-key'),
                        value: _key,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: Copy.orgKeyLabel),
                        items: [
                          for (final k in OrganizationalIndicatorKey.all)
                            DropdownMenuItem(value: k, child: Text(k.label)),
                        ],
                        onChanged: (v) => setState(() => _key = v ?? _key),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        key: const Key('org-value'),
                        controller: _valueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: Copy.orgValueLabel,
                          // La ayuda cambia con el indicador elegido: dice qué
                          // se está contando exactamente.
                          helperText: _key.ayuda,
                          helperMaxLines: 3,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: TextField(
                        key: const Key('org-descripcion'),
                        controller: _descripcionCtrl,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: Copy.orgDescripcionLabel,
                          hintText: Copy.orgDescripcionHint,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            key: const Key('org-entidad'),
                            value: _entidad,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: Copy.orgEntidadLabel,
                              hintText: Copy.orgEntidadHint,
                            ),
                            items: [
                              for (final e in entidades)
                                DropdownMenuItem(value: e, child: Text(e)),
                            ],
                            // Mientras el catálogo carga no se puede elegir; el
                            // valor viaja tal cual al backend.
                            onChanged: cargandoEntidades
                                ? null
                                : (v) => setState(() => _entidad = v),
                          ),
                          if (errorEntidades)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                Copy.orgEntidadLoadError,
                                key: const Key('org-entidad-error'),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        key: const Key('org-submit'),
                        onPressed: puedeRegistrar ? _submit : null,
                        child: const Text(Copy.orgSubmit),
                      ),
                    ),
                  ],
                ),
                if (_entidad == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      Copy.orgEntidadRequerida,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _listaCard(theme, entidades),
      ],
    );
  }

  Widget _listaCard(ThemeData theme, List<String> entidades) {
    final totales = _totales;
    return Card(
      key: const Key('org-lista'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(Copy.orgListTitle,
                      style: theme.textTheme.titleLarge),
                ),
                IconButton(
                  key: const Key('org-reload'),
                  tooltip: Copy.orgReload,
                  icon: const Icon(Icons.refresh),
                  onPressed: _cargando ? null : _recargar,
                ),
              ],
            ),
            Text(Copy.orgListIntro, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            if (_cargando)
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(Copy.orgLoading, style: theme.textTheme.bodyMedium),
                ],
              )
            else if (_errorCarga)
              Text(
                Copy.orgLoadError,
                key: const Key('org-error'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              )
            else if (_registros.isEmpty)
              Text(
                Copy.orgEmpty,
                key: const Key('org-vacio'),
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              Text(Copy.orgTotalsTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final t in totales.entries)
                    Text(
                      '${Copy.indicatorLabel(t.key)}: ${_fmtCantidad(t.value)}',
                      key: Key('org-total-${t.key}'),
                      style: theme.textTheme.bodyLarge,
                    ),
                ],
              ),
              const Divider(height: 24),
              for (final r in _registros)
                _RegistroRow(
                  registro: r,
                  busy: _busy,
                  onEdit: () => _editar(r, entidades),
                  onDelete: () => _eliminar(r),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un registro capturado, con sus dos acciones. Va en un [Wrap] para que en
/// pantallas angostas los botones bajen de línea en vez de desbordarse.
class _RegistroRow extends StatelessWidget {
  const _RegistroRow({
    required this.registro,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final OrganizationalIndicator registro;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = registro;
    final descripcion = (r.descripcion ?? '').trim();

    return Padding(
      key: Key('org-row-${r.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${Copy.indicatorLabel(r.key)}: ${_fmtCantidad(r.value)}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${r.estado} · ${_fmtFecha(r.createdAt)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  descripcion.isEmpty ? Copy.orgNoDescripcion : descripcion,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            key: Key('org-edit-${r.id}'),
            icon: const Icon(Icons.edit_outlined),
            label: const Text(Copy.orgEdit),
            onPressed: busy ? null : onEdit,
          ),
          OutlinedButton.icon(
            key: Key('org-delete-${r.id}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text(Copy.orgDelete),
            onPressed: busy ? null : onDelete,
          ),
        ],
      ),
    );
  }
}

/// Lo que devuelve el diálogo de edición al confirmar. `null` desde `showDialog`
/// significa que se canceló (y entonces no se manda nada).
class _EdicionIndicador {
  const _EdicionIndicador({
    required this.value,
    required this.estado,
    required this.descripcion,
  });

  final double value;
  final String estado;

  /// Cadena vacía = se borró la descripción (viaja igual, para poder quitarla).
  final String descripcion;
}

/// Corrige cantidad, descripción y entidad de un registro ya guardado. El
/// **indicador no se cambia**: mover un número de una categoría a otra sin
/// rastro sería reescribir el histórico; para eso se borra y se recaptura.
class _EditarIndicadorDialog extends StatefulWidget {
  const _EditarIndicadorDialog({
    required this.registro,
    required this.entidades,
  });

  final OrganizationalIndicator registro;
  final List<String> entidades;

  @override
  State<_EditarIndicadorDialog> createState() => _EditarIndicadorDialogState();
}

class _EditarIndicadorDialogState extends State<_EditarIndicadorDialog> {
  late final TextEditingController _valueCtrl;
  late final TextEditingController _descripcionCtrl;
  late String _entidad;
  String? _error;

  @override
  void initState() {
    super.initState();
    _valueCtrl =
        TextEditingController(text: _fmtCantidad(widget.registro.value));
    _descripcionCtrl =
        TextEditingController(text: widget.registro.descripcion ?? '');
    _entidad = widget.registro.estado;
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  /// El valor guardado puede no estar en el catálogo (los registros viejos
  /// tenían texto libre). Se conserva como opción para no perderlo al editar.
  List<String> get _opciones => [
        if (_entidad.isNotEmpty && !widget.entidades.contains(_entidad))
          _entidad,
        ...widget.entidades,
      ];

  void _confirmar() {
    final value = double.tryParse(_valueCtrl.text.trim());
    if (value == null) {
      setState(() => _error = Copy.orgValueInvalid);
      return;
    }
    Navigator.of(context).pop(_EdicionIndicador(
      value: value,
      estado: _entidad,
      descripcion: _descripcionCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('org-edit-dialog'),
      title: const Text(Copy.orgEditTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Copy.indicatorLabel(widget.registro.key),
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const Key('org-edit-value'),
              controller: _valueCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: Copy.orgValueLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('org-edit-descripcion'),
              controller: _descripcionCtrl,
              minLines: 1,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: Copy.orgDescripcionLabel,
              ),
            ),
            DropdownButtonFormField<String>(
              key: const Key('org-edit-entidad'),
              value: _opciones.contains(_entidad) ? _entidad : null,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: Copy.orgEntidadLabel),
              items: [
                for (final e in _opciones)
                  DropdownMenuItem(value: e, child: Text(e)),
              ],
              onChanged: (v) => setState(() => _entidad = v ?? _entidad),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('org-edit-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Copy.orgEditCancel),
        ),
        FilledButton(
          key: const Key('org-edit-ok'),
          onPressed: _confirmar,
          child: const Text(Copy.orgEditOk),
        ),
      ],
    );
  }
}

/// Cantidad legible: los enteros se muestran sin ".0" (las cantidades reales son
/// conteos, pero el backend las guarda como número con decimales).
String _fmtCantidad(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

String _fmtFecha(DateTime d) {
  final l = d.toLocal();
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${dos(l.month)}-${dos(l.day)} ${dos(l.hour)}:${dos(l.minute)}';
}
