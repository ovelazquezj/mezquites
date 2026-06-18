import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezquite_web_admin/src/widgets/paged_table.dart';

/// CR-012 #1/#2: las tablas paginan del lado del cliente (def. 10 filas/página).
void main() {
  Widget wrap(List<int> items) => MaterialApp(
        home: Scaffold(
          body: PagedTable<int>(
            items: items,
            columns: const [DataColumn(label: Text('n'))],
            rowBuilder: (i) => DataRow(cells: [DataCell(Text('row-$i'))]),
          ),
        ),
      );

  testWidgets('muestra 10 filas por página y el rango', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrap(List<int>.generate(25, (i) => i)));
    await tester.pumpAndSettle();

    // Página 1: filas 0–9 visibles, 10 no.
    expect(find.text('row-0'), findsOneWidget);
    expect(find.text('row-9'), findsOneWidget);
    expect(find.text('row-10'), findsNothing);
    expect(find.text('1–10 de 25'), findsOneWidget);
  });

  testWidgets('"Siguiente" avanza de página', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrap(List<int>.generate(25, (i) => i)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('paged-next')));
    await tester.pumpAndSettle();

    expect(find.text('row-0'), findsNothing);
    expect(find.text('row-10'), findsOneWidget);
    expect(find.text('11–20 de 25'), findsOneWidget);
  });
}
