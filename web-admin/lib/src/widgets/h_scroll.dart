import 'package:flutter/material.dart';

/// Envuelve una tabla ancha en scroll horizontal con **barra siempre visible**
/// (CR-011 #2). En Flutter Web el scroll horizontal no muestra barra por defecto
/// y la tabla se corta a la derecha; este wrapper la hace visible y desplazable.
class HScroll extends StatefulWidget {
  const HScroll({super.key, required this.child});

  final Widget child;

  @override
  State<HScroll> createState() => _HScrollState();
}

class _HScrollState extends State<HScroll> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: widget.child,
      ),
    );
  }
}
