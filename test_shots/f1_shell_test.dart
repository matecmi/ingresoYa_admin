import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot_harness.dart';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('inicio', (t) async {
    await shot(
      t,
      name: 'f1_inicio',
      location: '/',
      db: FakeFirebaseFirestore(),
    );
  });

  testWidgets('ayuda', (t) async {
    await shot(
      t,
      name: 'f1_ayuda',
      location: '/questions',
      db: await sampleDb(),
      act: (t) async => t.tap(find.text('?')),
    );
  });

  for (final route in [
    '/courses',
    '/questions',
    '/exam-templates',
    '/universities',
    '/professions',
    '/settings',
  ]) {
    testWidgets('ruta $route', (t) async {
      await shot(
        t,
        name: 'f1${route.replaceAll('/', '_')}',
        location: route,
        db: await sampleDb(),
      );
    });
  }

  testWidgets('angosto', (t) async {
    await shot(
      t,
      name: 'f1_angosto',
      location: '/',
      db: await sampleDb(),
      size: const Size(420, 860),
    );
  });

  testWidgets('hoja curso', (t) async {
    await shot(
      t,
      name: 'f1_hoja_curso',
      location: '/courses',
      db: await sampleDb(),
      act: (t) async => t.tap(find.text('Aritmética (QA)')),
    );
  });

  testWidgets('crear pregunta', (t) async {
    await shot(
      t,
      name: 'f1_crear_pregunta',
      location: '/questions',
      db: await sampleDb(),
      act: (t) async => t.tap(find.text('Crear')),
    );
  });

  testWidgets('universidad', (t) async {
    await shot(
      t,
      name: 'f1_hoja_universidad',
      location: '/universities',
      db: await sampleDb(),
      act: (t) async => t.tap(find.textContaining('UNPRG').first),
    );
  });
}
