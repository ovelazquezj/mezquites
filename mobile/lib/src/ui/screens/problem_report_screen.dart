import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/device_diagnostics.dart';
import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/common.dart';

/// Reportar un problema (CR-019): el voluntario describe una falla (cámara, etc.) y se envía un
/// diagnóstico técnico SIN PII al backend.
///
/// Gate #2: solo viajan `userAgent`/`platform`/`appVersion` + nota libre y, si aplica, el detalle
/// del último error; nunca email/nombre. Gate #3: funciona sin iniciar sesión (auth opcional en el
/// cliente). [prefillContext] etiqueta el origen del reporte (def. 'general'); [errorDetail] lo
/// rellena quien abre la pantalla (p. ej. el fallo de cámara).
class ProblemReportScreen extends ConsumerStatefulWidget {
  const ProblemReportScreen({super.key, this.prefillContext, this.errorDetail});

  final String? prefillContext;
  final String? errorDetail;

  @override
  ConsumerState<ProblemReportScreen> createState() =>
      _ProblemReportScreenState();
}

class _ProblemReportScreenState extends ConsumerState<ProblemReportScreen> {
  final _noteCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final diag = deviceDiagnostics();
    try {
      await ref.read(apiClientProvider).submitProblemReport(
            note: _noteCtrl.text.trim(),
            context: widget.prefillContext ?? 'general',
            errorDetail: widget.errorDetail,
            userAgent: diag.userAgent,
            platform: diag.platform,
            appVersion: Copy.appVersion,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Copy.reportSent)),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(Copy.reportFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandedAppBar(title: Copy.reportTitle),
      body: ListView(
        key: const Key('report_content'),
        padding: const EdgeInsets.all(16),
        children: [
          // Intro siempre visible: explica qué se envía (gate #2).
          const InfoNote(Copy.reportIntro, dismissible: false),
          const SizedBox(height: 16),
          // Nota OPCIONAL: el reporte se puede enviar vacío (solo diagnóstico).
          TextField(
            key: const Key('report_note_field'),
            controller: _noteCtrl,
            enabled: !_sending,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: Copy.reportNoteLabel,
              hintText: Copy.reportNoteHint,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('report_send'),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_sending ? Copy.reportSending : Copy.reportSend),
            ),
          ),
        ],
      ),
    );
  }
}
