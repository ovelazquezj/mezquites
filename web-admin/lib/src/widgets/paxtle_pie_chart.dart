import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../ui/copy.dart';

/// Pastel del nivel de paxtle declarado (CR-034), para el Panel público.
///
/// Come el agregado `distribucion_niveles` de los indicadores (servidor:
/// TODAS las confirmadas — mismo universo que el mapa público, CR-026 — así
/// que ningún tope de lista lo afecta). El nivel es AUTODECLARADO (gate #8).
///
/// Colores: la MISMA rampa de severidad del mapa de calor ([HeatRampTheme],
/// sano→severo), a propósito — una variable, una codificación en todo el
/// producto (y T7: los colores viven en el tema, no aquí). Paleta validada
/// (CVD ΔE 14.8, visión normal 15.8); el amarillo contrasta poco con el
/// fondo, por eso cada rebanada lleva separador de 2 px del color de
/// superficie y la leyenda SIEMPRE muestra conteo y porcentaje (los números
/// completos son legibles sin depender del color).
class PaxtlePieChart extends StatelessWidget {
  const PaxtlePieChart({super.key, required this.conteos});

  /// Conteos por nivel wire (`sano`/`leve`/`moderado`/`severo`) → n.
  final Map<String, num> conteos;

  /// Orden fijo de la escala (= índices 0..3 de la rampa). Nunca se reordena
  /// por magnitud: el color sigue al nivel, no a su tamaño.
  static const nivelesOrdenados = ['sano', 'leve', 'moderado', 'severo'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ramp =
        theme.extension<HeatRampTheme>() ?? HeatRampTheme.defaults;
    Color colorDe(String nivel) =>
        ramp.stops[nivelesOrdenados.indexOf(nivel)];
    final niveles = [
      for (final n in nivelesOrdenados)
        if ((conteos[n] ?? 0) > 0) n,
    ];
    final total =
        niveles.fold<num>(0, (sum, n) => sum + conteos[n]!).toInt();
    if (total == 0) {
      return Text(
        'Aún no hay observaciones confirmadas que graficar.',
        key: const Key('paxtle-pie-empty'),
        style: theme.textTheme.bodyMedium,
      );
    }
    final surface = theme.cardTheme.color ?? theme.colorScheme.surface;
    return Semantics(
      label: 'Gráfico de pastel del nivel de paxtle: '
          '${[for (final n in niveles) '${Copy.nivelG4(n)} ${conteos[n]} de $total'].join(', ')}',
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: CustomPaint(
              key: const Key('paxtle-pie'),
              painter: _PiePainter(
                valores: [for (final n in niveles) conteos[n]!.toDouble()],
                colores: [for (final n in niveles) colorDe(n)],
                separador: surface,
              ),
            ),
          ),
          // Leyenda con conteo y porcentaje: los números exactos siempre
          // visibles (no dependen del color ni de pasar el cursor).
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n in niveles)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colorDe(n),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                              color: theme.colorScheme.outlineVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${Copy.nivelG4(n)} — ${conteos[n]} '
                        '(${(conteos[n]! * 100 / total).round()} %)',
                        key: Key('paxtle-pie-legend-$n'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Total: $total observaciones confirmadas',
                key: const Key('paxtle-pie-total'),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  const _PiePainter({
    required this.valores,
    required this.colores,
    required this.separador,
  });

  final List<double> valores;
  final List<Color> colores;

  /// Color de superficie para el hueco de 2 px entre rebanadas.
  final Color separador;

  @override
  void paint(Canvas canvas, Size size) {
    final total = valores.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final radio = math.min(size.width, size.height) / 2;
    final centro = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: centro, radius: radio - 1);

    // Arranca a las 12 en punto; los niveles van en su orden de escala.
    var inicio = -math.pi / 2;
    for (var i = 0; i < valores.length; i++) {
      final barrido = valores[i] / total * 2 * math.pi;
      final relleno = Paint()
        ..style = PaintingStyle.fill
        ..color = colores[i];
      canvas.drawArc(rect, inicio, barrido, true, relleno);
      inicio += barrido;
    }

    // Separador de 2 px del color de superficie entre rebanadas (y ninguno si
    // solo hay una: sería una raya sobre un círculo completo).
    if (valores.length > 1) {
      final linea = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = separador;
      var angulo = -math.pi / 2;
      for (final v in valores) {
        canvas.drawLine(
          centro,
          centro + Offset(math.cos(angulo), math.sin(angulo)) * (radio - 1),
          linea,
        );
        angulo += v / total * 2 * math.pi;
      }
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.valores != valores ||
      old.colores != colores ||
      old.separador != separador;
}
