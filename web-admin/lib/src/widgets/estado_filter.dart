import 'package:flutter/material.dart';

/// Filtro geográfico por estado (Q8). El backend filtra por `estado` exacto;
/// aquí se ofrece un campo de texto libre + botón aplicar (no se hardcodea una
/// lista de estados — el escalamiento admite cualquier estado del rango natural).
class EstadoFilter extends StatefulWidget {
  const EstadoFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<EstadoFilter> createState() => _EstadoFilterState();
}

class _EstadoFilterState extends State<EstadoFilter> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final v = _controller.text.trim();
    widget.onChanged(v.isEmpty ? null : v);
  }

  @override
  Widget build(BuildContext context) {
    // Wrap (no Row fijo) para no desbordar en anchos estrechos.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: TextField(
            key: const Key('estado-filter-field'),
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Filtrar por estado (Q8)',
              hintText: 'p.ej. Aguascalientes',
              isDense: true,
            ),
            onSubmitted: (_) => _apply(),
          ),
        ),
        OutlinedButton(
          key: const Key('estado-filter-apply'),
          onPressed: _apply,
          child: const Text('Aplicar'),
        ),
        TextButton(
          onPressed: () {
            _controller.clear();
            widget.onChanged(null);
          },
          child: const Text('Limpiar'),
        ),
      ],
    );
  }
}
