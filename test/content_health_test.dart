import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/content_health_repo.dart';
import 'package:ingresoya_admin/src/domain/content_health.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

Map<String, Object> part(
  String id, {
  String template = 'tpl',
  bool full = true,
}) => {
  'id': id,
  'name': 'Parte $id',
  'active': true,
  'examTemplateId': template,
  if (full) ...{
    'linkVideo': 'https://youtu.be/x',
    'content': 'Lección',
    'summary': 'Resumen',
    'examples': [
      {'id': 'e1'},
      {'id': 'e2'},
    ],
  },
};

void main() {
  test(
    'detecta partes sin examen, con preguntas insuficientes y sin video',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection(AppEnv.examTemplatesCollection).doc('tpl').set({
        'title': 'Examen de parte',
        'questionCount': 3,
        'status': 'published',
        'active': true,
        'purpose': 'part_completion',
        'mode': 'dynamic',
      });
      final course = db.collection(AppEnv.coursesCollection).doc('c1');
      await course.set({'name': 'Física', 'active': true});
      final topic = course.collection('topics').doc('t1');
      await topic.set({'name': 'Cinemática'});
      await topic.collection('subtopics').doc('s1').set({
        'name': 'MRUV',
        'masteryTemplateId': 'dom',
        'listPart': [
          part('ok'),
          part('falta', full: false),
          part('sin', template: ''),
          {...part('oculta', template: ''), 'active': false},
        ],
      });
      for (var i = 0; i < 3; i++) {
        await db.collection(AppEnv.questionsCollection).add({
          'status': 'published',
          'partIds': ['ok'],
        });
      }
      await db.collection(AppEnv.questionsCollection).add({
        'status': 'published',
        'partIds': ['falta'],
      });
      await db.collection(AppEnv.questionsCollection).add({
        'status': 'draft',
        'partIds': ['falta'],
      });

      final report = await ContentHealthRepo(db).load();
      expect(report.parts.map((p) => p.part.id), ['ok', 'falta', 'sin']);
      expect(report.part('ok')!.ready, isTrue);
      expect(report.part('ok')!.examLabel, '3/3');

      final falta = report.part('falta')!;
      expect(falta.blocking, isTrue);
      expect(falta.issues.first.missingQuestions, 2);
      expect(falta.elements[PartElement.video], ElementState.missing);
      expect(falta.issues.last.severity, HealthSeverity.quality);

      expect(
        report.part('sin')!.issues.first.title,
        contains('no tiene examen'),
      );
      expect(report.blocking.length, 2);
      expect(report.readyParts, 1);
      expect(report.blockingByCourse(), {'c1': 2});
    },
  );
}
