import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/common.dart';

/// Aprendizaje (Q5.C). Contenidos AU2 (placeholders), mide engagement, SIN
/// gating (gate #3): ningún módulo se bloquea por nivel/capacitación. Sin
/// "certificado/tier". Todos los módulos están siempre disponibles.
class LearningScreen extends ConsumerStatefulWidget {
  const LearningScreen({super.key});

  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen> {
  /// Engagement local: módulos abiertos (placeholder de medición AU2/Q6).
  final Set<String> _opened = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandedAppBar(title: Copy.learningTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const InfoNote(Copy.learningNote),
          const SizedBox(height: 8),
          ...LearningModule.placeholders.map(
            (m) => Card(
              key: Key('learning_${m.id}'),
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(m.title),
                subtitle: Text(m.summary),
                trailing: _opened.contains(m.id)
                    ? const Icon(Icons.check_circle_outline)
                    : null,
                // SIN bloqueo: cualquier módulo abre siempre (gate #3).
                onTap: () => setState(() => _opened.add(m.id)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
