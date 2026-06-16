import 'package:flutter/material.dart';

/// Barra superior de marca (CR-005): **emblema del mezquite + " · {título}"** en
/// una sola línea. NO repite la palabra "Mezquite" (el emblema ya es la marca).
/// Conserva las [actions] de cada sección.
class BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandedAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/branding/emblema.png',
            height: 30,
            semanticLabel: 'Mezquite',
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text('· $title', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      actions: actions,
    );
  }
}
