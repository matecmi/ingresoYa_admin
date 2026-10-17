import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot_harness.dart';

Future<FakeFirebaseFirestore> historyDb() async {
  final db = await sampleDb();
  final col = db.collection('iya-admin-audit-test');
  final now = DateTime.now();
  Future<void> add(int minutesAgo, Map<String, Object?> data) => col.add({
    'at': Timestamp.fromDate(now.subtract(Duration(minutes: minutesAgo))),
    ...data,
  });
  await add(5, {
    'actor': {'email': 'kevin@ingresoya.test', 'type': 'user'},
    'kind': 'update',
    'section': 'settings',
    'kindKey': 'config',
    'title': 'Configuración · Rankings y reto del día',
    'path': 'iya-config-test/rankings',
    'changes': [
      {'field': 'league.promotePercent', 'before': '15', 'after': '20'},
    ],
    'before': {'a': 1},
    'after': {'a': 2},
  });
  await add(70, {
    'actor': {'email': 'kevin@ingresoya.test', 'type': 'user'},
    'kind': 'update',
    'section': 'questions',
    'kindKey': 'questions',
    'title': 'Pregunta «Sinónimo de LACÓNICO»',
    'path': 'iya-questions-test/q1',
    'statusBefore': 'published',
    'statusAfter': 'retired',
    'changes': [
      {'field': 'status', 'before': 'published', 'after': 'retired'},
    ],
    'before': {'status': 'published'},
    'after': {'status': 'retired'},
  });
  await add(140, {
    'actor': {'email': 'lucia@ingresoya.test', 'type': 'user'},
    'kind': 'update',
    'section': 'courses',
    'kindKey': 'subtopics',
    'title': 'Subtema «MRUV»',
    'path': 'iya-courses-test/c/topics/t/subtopics/s',
    'changes': [
      {'field': 'listPart «Caída libre».active', 'before': 'Sí', 'after': 'No'},
    ],
    'before': {'a': 1},
    'after': {'a': 2},
  });
  await add(60 * 26, {
    'actor': {'type': 'system', 'email': ''},
    'kind': 'create',
    'section': 'staff',
    'kindKey': 'staff',
    'title': 'Personal «lucia@ingresoya.test»',
    'path': 'iya-admin-staff-test/l',
    'changes': [
      {'field': 'roleId', 'before': '—', 'after': 'editor'},
    ],
    'before': null,
    'after': {'roleId': 'editor'},
  });
  return db;
}

void main() {
  setUpAll(loadShotFonts);

  testWidgets('historial', (t) async {
    await shot(
      t,
      name: 'f6_historial',
      location: '/history',
      db: await historyDb(),
    );
  });

  testWidgets('historial archivado', (t) async {
    await shot(
      t,
      name: 'f6_archivado',
      location: '/history',
      db: await historyDb(),
      act: (t) async => t.tap(find.textContaining('LACÓNICO')),
    );
  });
}
