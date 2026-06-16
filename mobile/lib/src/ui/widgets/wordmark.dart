import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../state/providers.dart';

/// Wordmark "Mezquite" en la serif oficial de marca (CR-003).
///
/// La familia serif se declara como token tipográfico (`font_family_wordmark`,
/// hoy "Fraunces") y se sirve con `google_fonts`. SOLO se aplica al wordmark; el
/// resto del texto sigue en la sans del design system (T7). El color por defecto
/// es `primary` (navy) salvo que se indique [color].
class Wordmark extends ConsumerWidget {
  const Wordmark({
    super.key,
    this.fontSize,
    this.color,
    this.text = 'Mezquite',
  });

  final double? fontSize;
  final Color? color;
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = ref.watch(designTokensProvider).valueOrNull;
    final family = tokens?.fontFamilyWordmark ?? 'Fraunces';
    final effectiveColor = color ?? theme.colorScheme.primary;
    final size = fontSize ?? theme.textTheme.displayLarge?.fontSize ?? 28;

    return Text(
      text,
      key: const Key('wordmark'),
      style: GoogleFonts.getFont(
        family,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: effectiveColor,
        height: 1.05,
      ),
    );
  }
}
