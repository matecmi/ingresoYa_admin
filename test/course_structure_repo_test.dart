import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/course_structure_repo.dart';
import 'package:ingresoya_admin/src/domain/syllabus_parser.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

void main() {
  test(
    'partes nuevas reciben la plantilla del curso; mover y duplicar',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = CourseStructureRepo(db);
      await db.collection(AppEnv.coursesCollection).doc('c').set({
        'name': 'Física',
      });
      await repo.setPartTemplate('c', 'tpl-parte');
      final t = await repo.addTopic('c', 'Cinemática');
      final s = await repo.addSubtopic('c', t, 'MRUV');
      final ids = await repo.addParts('c', t, s, [
        'Aceleración',
        'Ecuaciones',
        '',
      ]);
      expect(ids.length, 2);

      Future<List<Map<String, dynamic>>> parts() async {
        final snap = await repo.subtopicRef('c', t, s).get();
        final list =
            (snap.data()!['listPart'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
              ..sort(
                (a, b) => (a['order'] as int).compareTo(b['order'] as int),
              );
        return list;
      }

      var list = await parts();
      expect(list.map((p) => p['name']), ['Aceleración', 'Ecuaciones']);
      expect(list.every((p) => p['examTemplateId'] == 'tpl-parte'), isTrue);

      await repo.movePart('c', t, s, ids[1], -1);
      list = await parts();
      expect(list.map((p) => p['name']), ['Ecuaciones', 'Aceleración']);

      await repo.duplicatePart('c', t, s, ids[0]);
      await repo.patchPart('c', t, s, ids[0], {'active': false});
      list = await parts();
      expect(list.last['name'], 'Aceleración (copia)');
      expect(list.firstWhere((p) => p['id'] == ids[0])['active'], false);
    },
  );

  test('pegar un temario y copiar la estructura a otro curso', () async {
    final db = FakeFirebaseFirestore();
    final repo = CourseStructureRepo(db);
    final counts = await repo.createFromSyllabus(
      'a',
      parseSyllabus(
        'Dinámica\n  Newton\n    Primera ley\n    Segunda ley\n  Rozamiento',
      ),
    );
    expect(counts.summary, 'Se crearán 1 tema(s), 2 subtema(s) y 2 parte(s)');
    final copy = await repo.structureOf('a');
    expect(copy.single.children.first.children.map((p) => p.name), [
      'Primera ley',
      'Segunda ley',
    ]);
    await repo.createFromSyllabus('b', copy);
    final b = await repo.structureOf('b');
    expect(b.single.name, 'Dinámica');
    expect(b.single.children.length, 2);
  });
}
