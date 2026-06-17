import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Rampa de severidad del mapa de calor (CR-009/CR-010 #2), expuesta por el tema
/// para no hardcodear colores en la UI (T7). Son 4 paradas (0..3 = sano, leve,
/// moderado, severo): verde → amarillo → naranja → rojo. Es severidad
/// AUTODECLARADA (gate #8): el color comunica intensidad, no un veredicto experto.
/// Mismo patrón que `mobile/lib/src/theme/app_theme.dart`.
@immutable
class HeatRampTheme extends ThemeExtension<HeatRampTheme> {
  const HeatRampTheme({required this.stops});

  /// Las 4 paradas del degradado, de sano (0) a severo (3).
  final List<Color> stops;

  /// Color del calor para un índice 0..3 (interpolación lineal por tramos).
  Color colorFor(double g4Indice) {
    final v = g4Indice.clamp(0.0, 3.0);
    final i = v.floor().clamp(0, stops.length - 2);
    final t = v - i;
    return Color.lerp(stops[i], stops[i + 1], t)!;
  }

  /// Paleta por defecto (la única; vive en el tema, no en los widgets).
  static const defaults = HeatRampTheme(stops: [
    Color(0xFF2E7D32), // 0 sano     — verde
    Color(0xFFFBC02D), // 1 leve     — amarillo
    Color(0xFFEF6C00), // 2 moderado — naranja
    Color(0xFFC62828), // 3 severo   — rojo
  ]);

  @override
  HeatRampTheme copyWith({List<Color>? stops}) =>
      HeatRampTheme(stops: stops ?? this.stops);

  @override
  HeatRampTheme lerp(ThemeExtension<HeatRampTheme>? other, double t) {
    if (other is! HeatRampTheme) return this;
    return HeatRampTheme(
      stops: [
        for (var i = 0; i < stops.length; i++)
          Color.lerp(stops[i], other.stops[i], t)!,
      ],
    );
  }
}

/// Genera el [ThemeData] de Flutter EXCLUSIVAMENTE desde [DesignTokens] (T7).
///
/// Estética minimalista tipo eBird, baja densidad. No hay colores ni medidas
/// literales aquí: todo proviene del design system (`design-tokens.json`).
/// Mismo patrón que `mobile/lib/src/theme/app_theme.dart`, reimplementado para
/// la web admin (no se comparte código con el móvil).
class AppTheme {
  AppTheme(this.tokens);

  final DesignTokens tokens;

  Color _c(String s) => Color(tokens.color(s));

  FontWeight _w(int weight) {
    const map = {
      400: FontWeight.w400,
      500: FontWeight.w500,
      600: FontWeight.w600,
      700: FontWeight.w700,
    };
    return map[weight] ?? FontWeight.w400;
  }

  TextStyle _textStyle(String scale, {Color? color}) {
    final t = tokens.typeToken(scale);
    return TextStyle(
      fontSize: t.size,
      fontWeight: _w(t.weight),
      height: t.line / t.size,
      color: color,
    );
  }

  ThemeData build() {
    final primary = _c('primary');
    final secondary = _c('secondary');
    final accent = _c('accent');
    final background = _c('background');
    final surface = _c('color.neutral.surface');
    final text = _c('text');
    final textMuted = _c('text_muted');
    final onPrimary = _c('on_primary');

    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: text,
      tertiary: accent,
      onTertiary: onPrimary,
      error: const Color(0xFFB3261E),
      onError: onPrimary,
      surface: surface,
      onSurface: text,
      surfaceContainerLowest: background,
    );

    final radiusMd = tokens.radius('md');
    final radiusLg = tokens.radius('lg');
    final radiusPill = tokens.radius('pill');
    final spacingMd = tokens.spacing('md');
    final spacingSm = tokens.spacing('sm');

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      extensions: const [HeatRampTheme.defaults],
      scaffoldBackgroundColor: background,
      fontFamily: tokens.fontFamilyBase,
      visualDensity: VisualDensity.comfortable,
      textTheme: TextTheme(
        displayLarge: _textStyle('display', color: text),
        titleLarge: _textStyle('title', color: text),
        bodyLarge: _textStyle('body', color: text),
        bodyMedium: _textStyle('body', color: text),
        labelMedium: _textStyle('caption', color: textMuted),
        bodySmall: _textStyle('caption', color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: tokens.elevation('card'),
        centerTitle: false,
        titleTextStyle: _textStyle('title', color: onPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: tokens.elevation('card'),
        margin: EdgeInsets.symmetric(vertical: spacingSm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: tokens.elevation('card'),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing('lg'),
            vertical: spacingMd,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
          textStyle: _textStyle('body').copyWith(fontWeight: _w(600)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: _c('color.neutral.ink_300')),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: _c('color.neutral.ink_300')),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withValues(alpha: 0.18),
        elevation: tokens.elevation('card'),
        selectedLabelTextStyle: _textStyle('caption', color: primary),
        unselectedLabelTextStyle: _textStyle('caption', color: textMuted),
        selectedIconTheme: IconThemeData(color: primary),
        unselectedIconTheme: IconThemeData(color: textMuted),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: _textStyle('caption', color: textMuted)
            .copyWith(fontWeight: _w(600)),
        dataTextStyle: _textStyle('body', color: text),
      ),
      dividerTheme: DividerThemeData(color: _c('color.neutral.ink_300')),
    );
  }
}
