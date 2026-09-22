import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/admission_exam_repo.dart';
import 'package:ingresoya_admin/src/data/repo/question_repo.dart';
import 'package:ingresoya_admin/src/domain/entities/admission_exam.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/question/widgets/question_catalog_fields.dart';
import 'package:ingresoya_admin/src/data/repo/university_repo.dart';
import 'package:ingresoya_admin/src/ui/screens/universities/widgets/admission_exams_tab.dart';

AdmissionExam exam(String uni, String acronym) => AdmissionExam.fromJson({
  'id': 'ordinary-2015-I',
  'name': 'EXAMEN DE ADMISIÓN ORDINARIO 2015 I',
  'universityId': uni,
  'universityName': 'Universidad $acronym',
  'universityAcronym': acronym,
  'modalityId': 'ordinary',
  'modalityName': 'Ordinario',
  'year': 2015,
  'period': 'I',
  'active': true,
});

Future<void> seed(FakeFirebaseFirestore db) async {
  for (final entry in {'unprg': 'UNPRG', 'unmsm': 'UNMSM'}.entries) {
    final doc = db.collection(AppEnv.universitiesCollection).doc(entry.key);
    await doc.set({
      'name': 'Universidad ${entry.value}',
      'acronym': entry.value,
      'active': true,
    });
    await doc.collection('modes').doc('ordinary').set({
      'name': 'Ordinario',
      'active': true,
    });
    await AdmissionExamRepo(db).save(exam(entry.key, entry.value));
  }
  for (final entry in {'math': 'Matemática', 'language': 'Lenguaje'}.entries) {
    final doc = db.collection(AppEnv.coursesCollection).doc(entry.key);
    await doc.set({'name': entry.value});
    final topic = doc.collection('topics').doc('${entry.key}-topic');
    await topic.set({
      'name': entry.key == 'math' ? 'Álgebra' : 'Ortografía',
      'order': 1,
    });
    await topic.collection('subtopics').doc('${entry.key}-subtopic').set({
      'name': entry.key == 'math' ? 'Ecuaciones' : 'Tildación',
      'order': 1,
      'listPart': [
        {
          'id': '${entry.key}-part-1',
          'name': entry.key == 'math'
              ? 'Ecuaciones lineales'
              : 'Tildes diacríticas',
        },
      ],
    });
  }
}

void main() {
  testWidgets(
    'Register an admission exam with suggested name, year and period',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      await seed(db);
      final university = (await UniversityRepo(
        db,
      ).watchUniversities().first).firstWhere((u) => u.id == 'unprg');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [firestoreProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AdmissionExamDialog(university: university),
                  ),
                  child: const Text('Registrar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Modalidad'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ordinario').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Año'), '2020');
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Período'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('II').last);
      await tester.pumpAndSettle();
      expect(
        find.text('UNPRG - EXAMEN DE ADMISIÓN ORDINARIO 2020 II'),
        findsOneWidget,
      );
      await tester.tap(find.text('Guardar examen'));
      await tester.pumpAndSettle();
      final records = await AdmissionExamRepo(db).watch('unprg').first;
      expect(records, hasLength(2));
      expect(records.first.name, 'EXAMEN DE ADMISIÓN ORDINARIO 2020 II');
      expect(records.first.period, 'II');
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'Admission exam scope, edit, archival and question origin roundtrip',
    () async {
      final db = FakeFirebaseFirestore();
      await seed(db);
      final exams = AdmissionExamRepo(db);
      final saved = (await exams.watch('unprg').first).single;
      expect(saved.label, 'UNPRG - EXAMEN DE ADMISIÓN ORDINARIO 2015 I');
      expect((await exams.watch('unmsm').first).single.universityId, 'unmsm');
      final questions = QuestionRepo(db);
      final id = await questions.createQuestion(
        number: 1,
        statementText: 'Calcula x',
        active: 'Y',
        courseId: 'math',
        courseName: 'Matemática',
        topicId: 'math-topic',
        topicName: 'Álgebra',
        examId: saved.id,
        admissionExam: saved,
      );
      final reopened = (await questions.watchQuestions().first).single;
      expect(reopened.admissionExam!.toJson(), saved.toJson());
      expect(reopened.label, saved.label);
      final doc =
          (await db.collection(AppEnv.questionsCollection).doc(id).get())
              .data()!;
      expect(doc['universityId'], 'unprg');
      expect(doc['year'], 2015);
      expect(doc['period'], 'I');
      expect(doc['sourceExam']['modalityId'], 'ordinary');
      await exams.save(
        AdmissionExam.fromJson({
          ...saved.toJson(),
          'active': false,
          'name': 'Nombre actualizado',
        }),
      );
      expect((await exams.watch('unprg').first).single.active, false);
      expect(
        (await questions.watchQuestions().first).single.label,
        'UNPRG - Nombre actualizado',
      );
    },
  );

  test(
    'Repository rejects another university modality and model rejects invalid period',
    () async {
      final db = FakeFirebaseFirestore();
      await seed(db);
      final original = exam('unprg', 'UNPRG');
      expect(
        () => AdmissionExam.fromJson({...original.toJson(), 'period': 'IV'}),
        throwsFormatException,
      );
      await expectLater(
        AdmissionExamRepo(db).save(
          AdmissionExam.fromJson({
            ...original.toJson(),
            'modalityId': 'missing-mode',
          }),
        ),
        throwsA(isA<ExamCatalogException>()),
      );
    },
  );

  testWidgets(
    'Dependent dropdowns clear old topics and exams; label uses chosen university',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = FakeFirebaseFirestore();
      await seed(db);
      final courseId = TextEditingController(),
          courseName = TextEditingController();
      final topicId = TextEditingController(),
          topicName = TextEditingController();
      final subtopicId = TextEditingController(),
          subtopicName = TextEditingController();
      final partIds = <String>[];
      final partNames = <String, String>{};
      final examId = TextEditingController(), label = TextEditingController();
      addTearDown(() {
        for (final c in [
          courseId,
          courseName,
          topicId,
          topicName,
          subtopicId,
          subtopicName,
          examId,
          label,
        ]) {
          c.dispose();
        }
      });
      AdmissionExam? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firestoreProvider.overrideWithValue(db),
            firebaseFirestoreProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Form(
                  child: QuestionCatalogFields(
                    courseId: courseId,
                    courseName: courseName,
                    topicId: topicId,
                    topicName: topicName,
                    subtopicId: subtopicId,
                    subtopicName: subtopicName,
                    partIds: partIds,
                    partNames: partNames,
                    examId: examId,
                    label: label,
                    onExamChanged: (e) => selected = e,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> choose(String field, String value) async {
        final dropdown = find.widgetWithText(
          DropdownButtonFormField<String>,
          field,
        );
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
      }

      await choose('Curso', 'Matemática');
      await choose('Tema', 'Álgebra');
      expect(topicId.text, 'math-topic');
      await choose('Subtema', 'Ecuaciones');
      await tester.tap(find.text('Ecuaciones lineales'));
      await tester.pumpAndSettle();
      expect(subtopicId.text, 'math-subtopic');
      expect(partIds, ['math-part-1']);
      await choose('Curso', 'Lenguaje');
      expect(topicId.text, isEmpty);
      expect(subtopicId.text, isEmpty);
      expect(partIds, isEmpty);
      await choose('Tema', 'Ortografía');
      await choose('Subtema', 'Tildación');
      await choose('Universidad', 'UNPRG — Universidad UNPRG');
      await choose('Examen de origen', 'EXAMEN DE ADMISIÓN ORDINARIO 2015 I');
      expect(label.text, 'UNPRG - EXAMEN DE ADMISIÓN ORDINARIO 2015 I');
      await choose('Universidad', 'UNMSM — Universidad UNMSM');
      expect(examId.text, isEmpty);
      expect(label.text, isEmpty);
      expect(selected, isNull);
      await choose('Examen de origen', 'EXAMEN DE ADMISIÓN ORDINARIO 2015 I');
      expect(selected!.universityId, 'unmsm');
      expect(label.text, 'UNMSM - EXAMEN DE ADMISIÓN ORDINARIO 2015 I');
      expect(tester.takeException(), isNull);
    },
  );
}
