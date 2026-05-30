import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_app/src/models/models.dart';

/// Gate #9 / Q5.A-D1: la app del voluntario NUNCA muestra estado de validación
/// individual. El modelo MineObservation no tiene `validationState`, y el
/// feedback es agregado.
void main() {
  test('MineObservation no expone validation_state', () {
    final o = MineObservation.fromJson({
      'observation_id': 'abc',
      'captured_at': '2026-05-30T12:00:00Z',
      'nivel_g4': 'leve',
      'flag_cuscuta': false,
      'flag_danio': true,
      'tamanio': 'mediano',
      'contexto': 'urbano',
      'estado': 'NL',
      'municipio': 'Monterrey',
    });
    // El único "pending" posible es el local de envío, no validación.
    expect(o.pending, isFalse);
    expect(o.toString().contains('valida'), isFalse);
  });

  test('el código del voluntario no consume validation_state', () {
    // restricted/RestrictedObservation (con validation_state) es para
    // aliado_firmante en el cliente web, NO en esta app móvil.
    final files = [
      'lib/src/models/models.dart',
      'lib/src/api/api_client.dart',
      'lib/src/ui/screens/profile_screen.dart',
      'lib/src/ui/screens/capture_screen.dart',
      'lib/src/ui/screens/observation_form.dart',
    ];
    for (final f in files) {
      final src = File(f).readAsStringSync();
      expect(src.contains('validation_state'), isFalse,
          reason: '$f no debe leer validation_state (gate #9).',);
      expect(src.contains('/restricted'), isFalse,
          reason: '$f no debe consumir /restricted (rol firmante).',);
    }
  });

  test('FeedbackAggregate es agregado (window/total/validas)', () {
    final f = FeedbackAggregate.fromJson({
      'window': 20,
      'total_considered': 8,
      'validas': 6,
      'message': 'De tus últimas 8 observaciones evaluadas, 6 resultaron válidas.',
    });
    expect(f.window, 20);
    expect(f.totalConsidered, 8);
    expect(f.validas, 6);
  });
}
