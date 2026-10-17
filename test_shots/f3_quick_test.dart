import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot_harness.dart';

const _route =
    '/questions/quick?course=qa-fis&topic=qa-fis-t1&subtopic=qa-fis-t1-s1&part=qa-fis-t1-s1-p1';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('carga rápida vacía', (t) async {
    await shot(
      t,
      name: 'f3_quick_vacia',
      location: _route,
      db: await sampleDb(),
    );
  });

  testWidgets('carga rápida con pregunta pegada', (t) async {
    await shot(
      t,
      name: 'f3_quick',
      location: _route,
      db: await sampleDb(),
      size: const Size(1440, 1100),
      act: (t) async {
        await t.enterText(
          find.byType(TextField).first,
          'Un auto parte del reposo y acelera a razón de 3 m/s². ¿Qué rapidez '
          'tiene a los 4 s?\na) 7 m/s  b) 12 m/s  c) 9 m/s  d) 3/4 m/s  '
          'e) 15 m/s\nClave: b\nSolución: v = v0 + a·t = 0 + 3·4 = 12 m/s',
        );
      },
    );
  });

  testWidgets('carga rápida como editor', (t) async {
    await shot(
      t,
      name: 'f3_quick_editor',
      location: _route,
      db: await sampleDb(),
      session: editorSession(),
      act: (t) async {
        await t.enterText(
          find.byType(TextField).first,
          'Un móvil parte del reposo con a = 2 m/s². ¿Qué distancia recorre en 5 s?\n'
          'A) 10 m\nB) 25 m\nC) 50 m\nD) 5 m',
        );
      },
    );
  });
}
