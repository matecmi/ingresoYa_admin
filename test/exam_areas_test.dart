import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/university_repo.dart';
import 'package:ingresoya_admin/src/domain/university_profile.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/universities/university_profile_screen.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

// UNPRG 2026-II, Anexo 1, grupo E (parte de sus filas).
const _areaE = ExamArea(
  id: 'E',
  name: 'Ciencias e Ingenierías',
  source: 'Prospecto 2026-II, Anexo 1',
  rows: [
    ExamAreaRow(
      subject: 'Verbal',
      courseId: 'rv',
      questions: 20,
      points: 20,
      key: true,
    ),
    ExamAreaRow(
      subject: 'Álgebra',
      courseId: 'alg',
      questions: 6,
      points: 22.222,
    ),
    ExamAreaRow(subject: 'Psicología', questions: 2, points: 17.631),
  ],
);

Map<String, dynamic> _unprg() => {
  'name': 'Universidad Nacional Pedro Ruiz Gallo',
  'acronym': 'UNPRG',
  'professions': [
    {
      'id': 'civil',
      'idDoc': 'civil',
      'name': 'Ingeniería Civil',
      'acronym': 'IC',
      'active': true,
    },
    {
      'id': 'med',
      'idDoc': 'med',
      'name': 'Medicina Humana',
      'acronym': 'MH',
      'active': true,
    },
  ],
};

void main() {
  test('el área calcula su puntaje máximo y el peso de cada fila', () {
    expect(_areaE.totalQuestions, 28);
    expect(_areaE.maxScore, closeTo(400 + 133.332 + 35.262, .001));
    expect(
      _areaE.shareOf(_areaE.rows.first),
      closeTo(400 / _areaE.maxScore, 1e-9),
    );
    final copy = ExamArea.fromMap(_areaE.toMap())!;
    expect(copy.rows.first.key, isTrue);
    expect(copy.rows.last.courseId, '');
    expect(copy.validate(), isNull);
  });

  test('validar un área', () {
    expect(const ExamArea(id: '', name: 'X').validate(), contains('código'));
    expect(
      const ExamArea(id: 'A', name: 'Médicas').validate(),
      contains('entre 1 y 200 preguntas'),
    );
    expect(
      const ExamArea(
        id: 'A',
        name: 'Médicas',
        rows: [
          ExamAreaRow(subject: 'Biología', questions: 18, points: 25),
          ExamAreaRow(subject: 'biología', questions: 2, points: 25),
        ],
      ).validate(),
      contains('dos veces'),
    );
    expect(
      const ExamArea(
        id: 'A',
        name: 'Médicas',
        rows: [ExamAreaRow(subject: 'Biología', questions: 18, points: 0)],
      ).validate(),
      contains('puntos por respuesta'),
    );
  });

  test('guardar áreas; quitar una deja a sus carreras sin área', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('iya-universities-test').doc('unprg').set(_unprg());
    final repo = UniversityRepo(db);
    var data = await repo.watchStudentData('unprg').first;
    await repo.setExamAreas('unprg', data, [_areaE]);
    await repo.setCareerDetails(
      'unprg',
      'civil',
      const CareerDetails(examAreaId: 'E'),
    );
    data = await repo.watchStudentData('unprg').first;
    expect(data.areaOf('civil')?.name, 'Ciencias e Ingenierías');
    expect(data.areaOf('med'), isNull);
    expect(data.missing(), contains('área del examen de 1 carrera(s)'));
    await expectLater(
      repo.setExamAreas('unprg', data, [_areaE, _areaE]),
      throwsStateError,
    );

    await repo.setExamAreas('unprg', data, const []);
    data = await repo.watchStudentData('unprg').first;
    expect(data.examAreas, isEmpty);
    expect(data.detailsOf('civil').examAreaId, '');
  });

  testWidgets('la pestaña muestra las áreas con sus cursos clave', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    await db.collection('iya-universities-test').doc('unprg').set({
      ..._unprg(),
      'examAreas': [_areaE.toMap()],
      'careerDetails': {
        'civil': {'examAreaId': 'E'},
      },
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          firebaseFirestoreProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: UniversityProfileScreen(universityId: 'unprg'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áreas del examen'));
    await tester.pumpAndSettle();
    expect(find.text('E · Ciencias e Ingenierías'), findsOneWidget);
    expect(find.textContaining('clave: Verbal'), findsOneWidget);
    await tester.tap(find.text('Carreras'));
    await tester.pumpAndSettle();
    expect(find.textContaining('área E'), findsOneWidget);
  });
}
