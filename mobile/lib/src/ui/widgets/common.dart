import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../copy.dart';

/// Tarjeta de sección minimalista (baja densidad). Usa solo tokens del tema.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title!, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Fila de estadística clave/valor.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleLarge),
        ],
      ),
    );
  }
}

/// Banner informativo (usa color semántico `info` del tema vía secondary/tertiary).
///
/// CR-021: es **descartable** (botón "X") y recuerda el descarte entre sesiones
/// (SharedPreferences, también en web vía localStorage). Una vez cerrado no
/// reaparece. Es informativo (gate #3): cerrarlo NO bloquea ninguna función.
/// El identificador de persistencia es [id]; si se omite, se deriva del texto
/// (si el texto cambia, el aviso reaparece, lo cual es deseable).
class InfoNote extends StatefulWidget {
  const InfoNote(this.text, {super.key, this.dismissible = true, this.id});

  final String text;

  /// Si es `false`, no muestra la "X" ni persiste (siempre visible).
  final bool dismissible;

  /// Identificador estable para recordar el descarte. Si es null, se deriva del texto.
  final String? id;

  @override
  State<InfoNote> createState() => _InfoNoteState();
}

class _InfoNoteState extends State<InfoNote> {
  static const _prefix = 'infonote_dismissed_';

  /// Cache en memoria de los ids ya descartados (se carga una sola vez de prefs).
  static Set<String>? _dismissed;

  bool _hidden = false;

  String get _key => widget.id ?? 'h${widget.text.hashCode}';

  @override
  void initState() {
    super.initState();
    if (widget.dismissible) _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    // Defensivo: en pruebas de widget sin mock de SharedPreferences, getInstance()
    // lanza; en ese caso tratamos el aviso como NO descartado (se muestra, como antes).
    try {
      if (_dismissed == null) {
        final prefs = await SharedPreferences.getInstance();
        _dismissed = prefs
            .getKeys()
            .where((k) => k.startsWith(_prefix) && (prefs.getBool(k) ?? false))
            .map((k) => k.substring(_prefix.length))
            .toSet();
      }
    } catch (_) {
      _dismissed ??= <String>{};
    }
    if (!mounted) return;
    if (_dismissed!.contains(_key)) setState(() => _hidden = true);
  }

  Future<void> _dismiss() async {
    setState(() => _hidden = true);
    (_dismissed ??= <String>{}).add(_key);
    // Persistir es best-effort: si el plugin no está disponible no rompemos la UI.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix$_key', true);
    } catch (_) {/* sin persistencia (p. ej. en pruebas); el descarte vive en memoria */}
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.tertiary, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.text, style: theme.textTheme.bodySmall)),
          if (widget.dismissible) ...[
            const SizedBox(width: 4),
            InkWell(
              key: const Key('info_note_dismiss'),
              onTap: _dismiss,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Tooltip(
                  message: Copy.dismissNote,
                  child: Icon(Icons.close,
                      size: 16, color: theme.colorScheme.tertiary),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sello de "última actualización Qn" para vistas de datos.
class SnapshotStamp extends StatelessWidget {
  const SnapshotStamp(this.quarter, {super.key});

  final String quarter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Última actualización: $quarter',
      key: const Key('snapshot_stamp'),
      style: theme.textTheme.bodySmall,
    );
  }
}
