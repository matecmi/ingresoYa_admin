import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/content_health_repo.dart';
import 'package:ingresoya_admin/src/domain/content_health.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

/// Lo que guarda `refreshContentHealth` (functions/src/content_health.ts).
Map<String, dynamic> facts(
  String id, {
  String template = 'tpl',
  bool full = true,
}) => {
  'id': id,
  'name': 'Parte $id',
  'order': '1',
  'tpl': template,
  'video': full,
  'content': full,
  'summary': full,
  'points': false,
  'examples': full ? 2 : 0,
  'flash': false,
  'res': false,
  'quiz': false,
};

Map<String, dynamic> report({int computedAtMs = 1000, int? dirtyAtMs}) => {
  'schemaVersion': 1,
  'computedAtMs': computedAtMs,
  'dirtyAtMs': ?dirtyAtMs,
  'templates': {
    'tpl': {'title': 'Examen de parte', 'n': 3, 'pass': 60, 'ok': true},
  },
  'published': {'ok': 3, 'falta': 1},
  'courses': [
    {
      'id': 'c1',
      'name': 'Física',
      'topics': [
        {
          'id': 't1',
          'name': 'Cinemática',
          'subtopics': [
            {
              'id': 's1',
              'name': 'MRUV',
              'mastery': true,
              'parts': [
                facts('ok'),
                facts('falta', full: false),
                facts('sin', template: ''),
              ],
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  test('aplica las reglas al reporte que guarda el servidor', () {
    final health = ContentHealthRepo.reportFromFacts(report());
    expect(health.parts.map((p) => p.part.id), ['ok', 'falta', 'sin']);
    expect(health.part('ok')!.ready, isTrue);
    expect(health.part('ok')!.examLabel, '3/3');
    expect(health.part('ok')!.elements[PartElement.lesson], ElementState.ready);
    final falta = health.part('falta')!;
    expect(falta.blocking, isTrue);
    expect(falta.issues.first.missingQuestions, 2);
    expect(falta.elements[PartElement.video], ElementState.missing);
    expect(falta.issues.last.severity, HealthSeverity.quality);
    expect(health.part('sin')!.issues.first.title, contains('no tiene examen'));
    expect(health.blocking.length, 2);
    expect(health.readyParts, 1);
    expect(health.blockingByCourse(), {'c1': 2});
    expect(health.checkedAt.millisecondsSinceEpoch, 1000);
  });

  test(
    'una lectura si está al día; recalcula si está marcado o se pide',
    () async {
      final db = FakeFirebaseFirestore();
      final doc = db
          .collection(AppEnv.adminReportsCollection)
          .doc(AppEnv.contentHealthDocument);
      var calls = 0;
      final repo = ContentHealthRepo(
        db,
        refresher: () async {
          calls++;
          return report(computedAtMs: 5000);
        },
      );
      // Sin reporte todavía: lo calcula el servidor.
      expect((await repo.load()).checkedAt.millisecondsSinceEpoch, 5000);
      expect(calls, 1);
      await doc.set(report());
      expect((await repo.load()).checkedAt.millisecondsSinceEpoch, 1000);
      expect(calls, 1);
      // Un disparador lo marcó como desactualizado.
      await doc.set(report(dirtyAtMs: 2000));
      await repo.load();
      expect(calls, 2);
      // «Revisar ahora» y después de guardar desde el admin.
      await doc.set(report());
      await repo.load(force: true);
      repo.markStale();
      await repo.load();
      expect(calls, 4);
      await repo.load();
      expect(calls, 4);
    },
  );

  test('preguntas por parte desde el índice del curso', () async {
    final db = FakeFirebaseFirestore();
    final col = db.collection(AppEnv.questionIndexCollection);
    await col.doc('c1').set({
      'q': {
        'q1': {
          'v': 1,
          'p': ['ok', 'falta'],
        },
        'q2': {
          'v': 1,
          'p': ['ok'],
        },
        'q3': {'v': 1},
      },
    });
    await col.doc('c2').set({
      'q': {
        'q4': {
          'v': 1,
          'p': ['otra'],
        },
      },
    });
    final repo = ContentHealthRepo(db);
    expect(await repo.publishedByPart(courseId: 'c1'), {'ok': 2, 'falta': 1});
    expect(await repo.publishedByPart(), {'ok': 2, 'falta': 1, 'otra': 1});
    expect(await repo.publishedByPart(courseId: 'nuevo'), isEmpty);
  });
}
