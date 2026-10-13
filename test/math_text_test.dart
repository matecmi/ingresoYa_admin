import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/ui/widgets/math_text.dart';

void main() {
  testWidgets('la vista previa dibuja las fórmulas entre \$ como la app', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MathText(r'Área: $a^2$'))),
    );
    expect(find.byType(Math), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MathText('Sin fórmulas'))),
    );
    expect(find.byType(Math), findsNothing);
    expect(find.text('Sin fórmulas'), findsOneWidget);
  });
}
