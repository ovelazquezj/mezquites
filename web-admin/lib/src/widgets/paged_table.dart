import 'package:flutter/material.dart';

import 'h_scroll.dart';

/// Tabla con **paginación del lado del cliente** (CR-012). Muestra una página de
/// filas a la vez (def. 10) con selector de filas/página y navegación
/// Anterior/Siguiente. Mantener la página corta hace que la barra de scroll
/// horizontal (HScroll) quede a la vista, sin bajar hasta el último registro.
class PagedTable<T> extends StatefulWidget {
  const PagedTable({
    super.key,
    required this.items,
    required this.columns,
    required this.rowBuilder,
    this.initialPerPage = 10,
  });

  final List<T> items;
  final List<DataColumn> columns;
  final DataRow Function(T item) rowBuilder;
  final int initialPerPage;

  @override
  State<PagedTable<T>> createState() => _PagedTableState<T>();
}

class _PagedTableState<T> extends State<PagedTable<T>> {
  static const _options = [10, 25, 50];
  late int _perPage = widget.initialPerPage;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.items.length;
    final pages = total == 0 ? 1 : ((total + _perPage - 1) ~/ _perPage);
    if (_page >= pages) _page = pages - 1;
    if (_page < 0) _page = 0;
    final start = _page * _perPage;
    final end = (start + _perPage) > total ? total : (start + _perPage);
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
              value: _perPage,
              isDense: true,
              items: [
                for (final o in _options)
                  DropdownMenuItem(value: o, child: Text('$o')),
              ],
              onChanged: (v) => setState(() {
                _perPage = v ?? 10;
                _page = 0;
              }),
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
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
            ),
            IconButton(
              key: const Key('paged-next'),
              tooltip: 'Siguiente',
              icon: const Icon(Icons.chevron_right),
              onPressed: _page < pages - 1 ? () => setState(() => _page++) : null,
            ),
          ],
        ),
      ],
    );
  }
}
