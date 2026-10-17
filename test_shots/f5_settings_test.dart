import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot_harness.dart';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('rankings', (t) async {
    await shot(
      t,
      name: 'f5_rankings',
      location: '/settings',
      db: await sampleDb(),
      size: const Size(1440, 1300),
    );
  });

  testWidgets('rankings con cambio', (t) async {
    await shot(
      t,
      name: 'f5_rankings_cambio',
      location: '/settings',
      db: await sampleDb(),
      size: const Size(1440, 1100),
      act: (t) async {
        await t.tap(find.text('Competitivo'));
      },
    );
  });

  testWidgets('reto', (t) async {
    await shot(
      t,
      name: 'f5_reto',
      location: '/settings',
      db: await sampleDb(),
      act: (t) async => t.tap(find.text('Reto del día').first),
    );
  });

  testWidgets('buscar', (t) async {
    await shot(
      t,
      name: 'f5_buscar',
      location: '/settings',
      db: await sampleDb(),
      act: (t) async => t.enterText(find.byType(TextField).first, 'reloj'),
    );
  });

  testWidgets('editor sin permiso', (t) async {
    await shot(
      t,
      name: 'f5_lectura',
      location: '/settings',
      db: await sampleDb(),
      session: editorSession(),
    );
  });
}
