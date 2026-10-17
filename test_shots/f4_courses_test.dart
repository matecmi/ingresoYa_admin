import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot_harness.dart';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('inicio con salud', (t) async {
    await shot(
      t,
      name: 'f4_inicio',
      location: '/',
      db: await sampleDb(),
      size: const Size(1440, 1300),
    );
  });

  testWidgets('estructura del curso', (t) async {
    await shot(
      t,
      name: 'f4_estructura',
      location: '/courses/qa-fis',
      db: await sampleDb(),
      size: const Size(1440, 1400),
    );
  });

  testWidgets('estructura curso real', (t) async {
    await shot(
      t,
      name: 'f4_estructura_rm',
      location: '/courses/4e6eadf3-5e27-430b-8170-9b34930382a2',
      db: await sampleDb(),
      size: const Size(1440, 1100),
    );
  });

  testWidgets('editor de parte', (t) async {
    await shot(
      t,
      name: 'f4_parte',
      location:
          '/courses/qa-fis/part/qa-fis-t1-s1-p1?topic=qa-fis-t1&subtopic=qa-fis-t1-s1',
      db: await sampleDb(),
    );
  });

  testWidgets('pegar temario', (t) async {
    await shot(
      t,
      name: 'f4_temario',
      location: '/courses/qa-fis',
      db: await sampleDb(),
      act: (t) async {
        await t.tap(find.text('Pegar un temario'));
        await t.pump(const Duration(milliseconds: 300));
        await t.enterText(
          find.byType(TextField).last,
          'Dinámica\n  Leyes de Newton\n    Primera ley\n    Segunda ley\n  Rozamiento',
        );
      },
    );
  });
}
