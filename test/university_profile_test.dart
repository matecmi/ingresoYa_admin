import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/universities/university_profile_screen.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/university_repo.dart';
import 'package:ingresoya_admin/src/domain/university_profile.dart';

const _ficsa = Faculty(
  id: 'f1',
  name: 'Facultad de Ingeniería Civil, de Sistemas y de Arquitectura',
  acronym: 'ficsa',
);

void main() {
  test('facultad: sigla en mayúsculas y validación', () {
    expect(_ficsa.toMap()['acronym'], 'FICSA');
    expect(Faculty.fromMap(_ficsa.toMap())!.label, startsWith('FICSA · '));
    expect(const Faculty(id: 'x', name: 'Fa', acronym: '').validate(), isNotNull);
  });

  test('carrera: puntajes con su proceso, rangos y enlace', () {
    expect(const CareerDetails(minScore: 702.5).validate(), contains('proceso'));
    expect(
      const CareerDetails(minScore: 800, maxScore: 700, scorePeriod: '2026-I').validate(),
      contains('mínimo'),
    );
    expect(
      const CareerDetails(officialUrl: 'unprg.edu.pe').validate(),
      contains('https'),
    );
    const ok = CareerDetails(
      facultyId: 'f1',
      vacancies: 40,
      minScore: 702.5,
      maxScore: 905,
      scorePeriod: '2026-I',
      durationYears: 5,
      degree: 'Ingeniero Civil',
    );
    expect(ok.validate(), isNull);
    final back = CareerDetails.fromMap(ok.toMap());
    expect(back.minScore, 702.5);
    expect(back.vacancies, 40);
    expect(back.scorePeriod, '2026-I');
  });

  test('ficha visible pide la fuente; los enlaces deben ser https', () {
    expect(const UniversityProfile(visible: true).validate(), contains('fuente'));
    expect(
      const UniversityProfile(
        links: [OfficialLink(kind: LinkKind.website, url: 'www.x.pe')],
      ).validate(),
      contains('https'),
    );
    expect(
      const UniversityProfile(visible: true, source: 'Prospecto 2026-I').validate(),
      isNull,
    );
  });

  test('guardar facultades y detalles; quitar una facultad desvincula carreras', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('iya-universities-test').doc('unprg').set({
      'name': 'Universidad Nacional Pedro Ruiz Gallo',
      'acronym': 'UNPRG',
      'professions': [
        {'id': 'civil', 'idDoc': 'civil', 'name': 'Ingeniería Civil', 'acronym': 'IC', 'active': true},
        {'id': 'sis', 'idDoc': 'sis', 'name': 'Ingeniería de Sistemas', 'acronym': 'IS', 'active': true},
      ],
    });
    final repo = UniversityRepo(db);
    await repo.setFaculties('unprg', [_ficsa]);
    await expectLater(
      repo.setFaculties('unprg', [_ficsa, const Faculty(id: 'f2', name: 'Otra facultad', acronym: 'FICSA')]),
      throwsStateError,
    );
    await repo.setCareerDetails(
      'unprg',
      'civil',
      const CareerDetails(facultyId: 'f1', minScore: 702.5, scorePeriod: '2026-I'),
    );
    await repo.saveProfile(
      'unprg',
      const UniversityProfile(summary: 'Universidad pública de Lambayeque.', source: 'Web oficial'),
    );
    var data = await repo.watchStudentData('unprg').first;
    expect(data.faculties.single.acronym, 'FICSA');
    expect(data.detailsOf('civil').facultyId, 'f1');
    expect(data.careers.map((c) => c.id), ['civil', 'sis']);
    expect(data.missing(), contains('facultad de 1 carrera(s)'));
    expect(data.missing(), contains('web oficial'));

    await repo.deleteFaculty('unprg', data, 'f1');
    data = await repo.watchStudentData('unprg').first;
    expect(data.faculties, isEmpty);
    expect(data.detailsOf('civil').facultyId, '');
    expect(data.detailsOf('civil').minScore, 702.5);
  });

  testWidgets('la ficha muestra lo que falta y las facultades', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = FakeFirebaseFirestore();
    await db.collection('iya-universities-test').doc('unprg').set({
      'name': 'Universidad Nacional Pedro Ruiz Gallo',
      'acronym': 'UNPRG',
      'faculties': [_ficsa.toMap()],
      'professions': [
        {'id': 'civil', 'idDoc': 'civil', 'name': 'Ingeniería Civil', 'acronym': 'IC', 'active': true},
      ],
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [firestoreProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: UniversityProfileScreen(universityId: 'unprg'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ficha para el alumno · UNPRG'), findsOneWidget);
    expect(find.textContaining('Falta: resumen'), findsOneWidget);
    await tester.tap(find.text('Facultades'));
    await tester.pumpAndSettle();
    expect(find.text('FICSA'), findsOneWidget);
    expect(find.text('0 carrera(s)'), findsOneWidget);
    await tester.tap(find.text('Carreras'));
    await tester.pumpAndSettle();
    expect(find.text('Ingeniería Civil'), findsOneWidget);
    expect(find.text('Incompleta'), findsOneWidget);
  });
}
