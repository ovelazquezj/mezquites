import 'package:flutter/material.dart';

import 'h_scroll.dart';

/// Tabla con **paginación del lado del cliente** (CR-012). Muestra una página de
/// filas a la vez (def. 10) con selector de filas/página y navegación
/// Anterior/Siguiente. Mantener la página corta hace que la barra de scroll
/// horizontal (HScroll) quede a la vista, sin bajar hasta el último registro.
///
/// CR-033: la página y las filas/página pueden venir **controladas por el
/// padre** ([page]/[perPage] + callbacks). Sirve cuando la tabla vive dentro de
/// un FutureBuilder que la saca del árbol al recargar (p. ej. Revisión tras un
/// veredicto): el estado interno se destruiría con ella, pero el del padre no.
/// Sin esos parámetros se comporta igual que siempre (estado propio).
class PagedTable<T> extends StatefulWidget {
  const PagedTable({
    super.key,
    required this.items,
    required this.columns,
    required this.rowBuilder,
    this.initialPerPage = 10,
    this.page,
    this.onPageChanged,
    this.perPage,
    this.onPerPageChanged,
  });

  final List<T> items;
  final List<DataColumn> columns;
  final DataRow Function(T item) rowBuilder;
  final int initialPerPage;

  /// Página controlada (base 0). Si es null, la tabla guarda la suya.
  final int? page;
  final ValueChanged<int>? onPageChanged;

  /// Filas/página controladas. Si es null, la tabla guarda las suyas.
  final int? perPage;
  final ValueChanged<int>? onPerPageChanged;

  @override
  State<PagedTable<T>> createState() => _PagedTableState<T>();
}

class _PagedTableState<T> extends State<PagedTable<T>> {
  static const _options = [10, 25, 50];
  late int _perPage = widget.initialPerPage;
  int _page = 0;

  void _irAPagina(int p) {
    setState(() {
      if (widget.page == null) _page = p;
    });
    widget.onPageChanged?.call(p);
  }

  void _cambiarPorPagina(int v) {
    setState(() {
      if (widget.perPage == null) _perPage = v;
      if (widget.page == null) _page = 0;
    });
    widget.onPerPageChanged?.call(v);
    // Cambiar el tamaño de página invalida el número de página vigente.
    widget.onPageChanged?.call(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.items.length;
    final perPage = widget.perPage ?? _perPage;
    final pages = total == 0 ? 1 : ((total + perPage - 1) ~/ perPage);
    // Se acota sin avisar al padre: si la lista encogió (p. ej. un veredicto
    // sacó la fila del filtro), se muestra la última página que sí existe.
    var page = widget.page ?? _page;
    if (page >= pages) page = pages - 1;
    if (page < 0) page = 0;
    if (widget.page == null) _page = page;
    final start = page * perPage;
    final end = (start + perPage) > total ? total : (start + perPage);
    final slice = total == 0 ? <T>[] : widget.items.sublist(start, end);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HScroll(
          child: DataTable(
            columns: widget.columns,
            rows: [for (final it in slice) widget.rowBuilder(it)],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text('Filas por página:', style: theme.textTheme.bodySmall),
            DropdownButton<int>(
              key: const Key('paged-per-page'),
              value: _options.contains(perPage) ? perPage : _options.first,
              isDense: true,
              items: [
                for (final o in _options)
                  DropdownMenuItem(value: o, child: Text('$o')),
              ],
              onChanged: (v) => _cambiarPorPagina(v ?? 10),
            ),
            Text(
              total == 0 ? '0 de 0' : '${start + 1}–$end de $total',
              key: const Key('paged-range'),
              style: theme.textTheme.bodySmall,
            ),
            IconButton(
              key: const Key('paged-prev'),
              tooltip: 'Anterior',
              icon: const Icon(Icons.chevron_left),
              onPressed: page > 0 ? () => _irAPagina(page - 1) : null,
            ),
            IconButton(
              key: const Key('paged-next'),
              tooltip: 'Siguiente',
              icon: const Icon(Icons.chevron_right),
              onPressed: page < pages - 1 ? () => _irAPagina(page + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}
