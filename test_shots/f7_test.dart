import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shot_harness.dart';

const _q1 = '111bdfd7-93b3-45e4-bc49-aaf47c0620e2';
const _q2 = '1c91831a-e734-4c5f-8d90-1c134506472b';

Future<FakeFirebaseFirestore> qualityDb() async {
  final db = await sampleDb();
  final stats = db.collection('iya-question-stats-test');
  await stats.doc('${_q1}_1').set({
    'questionId': _q1,
    'version': 1,
    'answered': 41,
    'blank': 2,
    'correct': 3,
    'correctAlternativeId': '614c5701-d950-4a25-ab62-e518cfa3ae73',
    'labels': {
      '614c5701-d950-4a25-ab62-e518cfa3ae73': 'A',
      '6b37504d-1975-4f1f-8843-e262413c718d': 'B',
      '127e72b0-a62a-42ef-b478-c8bb8f23de79': 'C',
      '677bdc7a-3f92-43a3-b876-2f68058654f3': 'D',
      '7f722aea-1524-4afb-a778-f50073b3497c': 'E',
    },
    'byAlternative': {
      '614c5701-d950-4a25-ab62-e518cfa3ae73': 3,
      '6b37504d-1975-4f1f-8843-e262413c718d': 4,
      '127e72b0-a62a-42ef-b478-c8bb8f23de79': 32,
      '677bdc7a-3f92-43a3-b876-2f68058654f3': 2,
    },
  });
  await stats.doc('${_q2}_1').set({
    'questionId': _q2,
    'version': 1,
    'answered': 23,
    'blank': 0,
    'correct': 2,
    'correctAlternativeId': 'dfea1d41-8312-4983-b38d-9234a5d6850d',
    'labels': {
      '4b29a365-f8e8-4301-a178-263ea9d8ef61': 'A',
      'e2f3e931-1c22-43bf-9de4-bea699730eae': 'B',
      'dfea1d41-8312-4983-b38d-9234a5d6850d': 'C',
      '1e0035d2-9a2a-4b32-b6a0-3f4fccaff7fa': 'D',
    },
    'byAlternative': {
      '4b29a365-f8e8-4301-a178-263ea9d8ef61': 5,
      'e2f3e931-1c22-43bf-9de4-bea699730eae': 6,
      'dfea1d41-8312-4983-b38d-9234a5d6850d': 2,
      '1e0035d2-9a2a-4b32-b6a0-3f4fccaff7fa': 10,
    },
  });
  await stats.doc('_cursor').set({'updatedAt': Timestamp.now()});
  return db;
}

Future<FakeFirebaseFirestore> studentDb() async {
  final db = await sampleDb();
  final user = db.collection('iya-profile-test').doc('gdGu');
  await user.set({
    'profile': {
      'userName': 'Fútbol En Vivo Mas',
      'email': 'futbolenvivomas@gmail.com',
      'universityAcronym': 'UNPRG',
      'professionName': 'Ingeniería Civil',
    },
  });
  await user.collection('xp').doc('current').set({
    'total': 440,
    'rankStep': 2,
    'week': {'key': '2026-10-12', 'xp': 120},
  });
  await user.collection('ranking').doc('current').set({
    'alias': 'Oso_Civil_26',
    'hidden': false,
    'stage': 0,
  });
  final now = DateTime.now().millisecondsSinceEpoch;
  final events = [
    ('simulator_session', 10, 0),
    ('correct_answers', 2, 60),
    ('part_passed', 40, 1500),
  ];
  for (final (i, (type, xp, minutes)) in events.indexed) {
    await user.collection('xpEvents').doc('e$i').set({
      'type': type,
      'xp': xp,
      'requested': xp,
      'day': '2026-10-16',
      'atMs': now - minutes * 60000,
    });
  }
  await user.collection('xpEvents').doc('e9').set({
    'type': 'part_passed',
    'xp': 40,
    'day': '2026-10-15',
    'atMs': now - 26 * 3600000,
    'reverted': true,
    'revertReason': 'Prueba',
  });
  await user.collection('simulatorResults').doc('r1').set({
    'title': 'Reto del día',
    'purpose': 'practice',
    'correct': 3,
    'total': 10,
    'percentage': 30.0,
    'submittedAtMs': now - 3600000,
  });
  await user.collection('learningProgress').doc('current').set({
    'partProgress': {
      'p1': {'completed': true},
      'p2': {'completed': true},
      'p3': {'completed': true},
    },
  });
  return db;
}

const _exam = '''
25. Halle el valor de x si 3x - 7 = 11
A) 4   B) 5   C) 6   D) 7   E) 8
26. En la figura, AB = BC. Halle el ángulo α.
A) 30°   B) 40°   C) 50°   D) 60°
27. ¿Cuántos términos tiene la sucesión 4, 9, 14, ..., 99?
A) 19 B) 20 C) 21 D) 22 E) 23

CLAVES
25. C   26. B   27. B
''';

void main() {
  setUpAll(loadShotFonts);

  testWidgets('preguntas a revisar', (t) async {
    await shot(t, name: 'f7_calidad', location: '/quality', db: await qualityDb());
  });

  testWidgets('ficha del alumno', (t) async {
    await shot(t, name: 'f7_ficha', location: '/students/gdGu', db: await studentDb());
  });

  testWidgets('importar: revisar', (t) async {
    await shot(
      t,
      name: 'f7_importar',
      location:
          '/import-exam?uni=704d2378-e7ee-48d6-8ae0-916490215724&exam=ee73f619-9826-486c-8e80-ac39780efbf1',
      db: await sampleDb(),
      size: const Size(1440, 1200),
      act: (t) async {
        await t.tap(find.text('Siguiente: pegar el examen →'));
        await t.pump(const Duration(milliseconds: 300));
        await t.enterText(find.byType(TextField).first, _exam);
        await t.tap(find.text('Leer el examen →'));
      },
    );
  });
}
