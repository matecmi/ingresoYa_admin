import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/admission_exam_repo.dart';
import 'package:ingresoya_admin/src/data/repo/question_repo.dart';
import 'package:ingresoya_admin/src/domain/entities/admission_exam.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

AdmissionExam draft({
  String id = 'exam',
  String type = 'admission_exam',
  String period = 'I',
}) => AdmissionExam.fromJson({
  'id': id,
  'name': 'EXAMEN 2026 $period',
  'universityId': 'unprg',
  'universityName': 'Nombre antiguo',
  'universityAcronym': 'UNPRG',
  'modalityId': 'ordinary',
  'modalityName': 'Nombre antiguo',
  'year': 2026,
  'period': period,
  'examType': type,
});

Future<FakeFirebaseFirestore> database() async {
  final db = FakeFirebaseFirestore();
  final university = db.collection(AppEnv.universitiesCollection).doc('unprg');
  await university.set({
    'name': 'Universidad Nacional Pedro Ruiz Gallo',
    'acronym': 'UNPRG',
    'active': true,
  });
  await university.collection('modes').doc('ordinary').set({
    'name': 'Ordinario',
    'active': true,
  });
  return db;
}

Future<AdmissionExam> latest(
  AdmissionExamRepo repo, [
  String id = 'exam',
]) async =>
    AdmissionExam.fromJson((await repo.exams('unprg').doc(id).get()).data()!);

class InterruptedSyncRepo extends AdmissionExamRepo {
  InterruptedSyncRepo(super.db);
  @override
  Future<void> synchronizeQuestions(String universityId, String examId) async =>
      throw StateError('Simulated connection loss');
}

void main() {
  test(
    'Same convocatoria rejects duplicates, including renamed and inactive records',
    () async {
      final db = await database();
      final repo = AdmissionExamRepo(db);
      await repo.save(draft());
      var current = await latest(repo);
      expect(current.universityName, 'Universidad Nacional Pedro Ruiz Gallo');
      expect(current.modalityName, 'Ordinario');
      await repo.save(
        AdmissionExam.fromJson({...current.toJson(), 'active': false}),
      );
      await expectLater(
        repo.save(
          AdmissionExam.fromJson({
            ...draft(id: 'duplicate').toJson(),
            'name': 'OTRO NOMBRE',
          }),
        ),
        throwsA(
          isA<ExamCatalogException>().having(
            (e) => e.message,
            'message',
            contains('Ya existe'),
          ),
        ),
      );
      await repo.save(draft(id: 'period-2', period: 'II'));
      await repo.save(draft(id: 'official', type: 'official_practice'));
      await repo.save(draft(id: 'other', type: 'other'));
      expect((await repo.watch('unprg').first), hasLength(4));
    },
  );

  test('Legacy exam without reservation prevents a second copy', () async {
    final repo = AdmissionExamRepo(await database());
    final old = draft(id: 'legacy').toJson()..remove('examType');
    await repo.exams('unprg').doc('legacy').set(old);
    await expectLater(repo.save(draft()), throwsA(isA<ExamCatalogException>()));
    expect((await repo.watch('unprg').first), hasLength(1));
  });

  test(
    'Changing convocatoria releases old reservation; stale edits are rejected',
    () async {
      final repo = AdmissionExamRepo(await database());
      await repo.save(draft());
      final original = await latest(repo);
      await repo.save(
        AdmissionExam.fromJson({
          ...original.toJson(),
          'period': 'II',
          'name': 'EXAMEN II',
        }),
      );
      await repo.save(draft(id: 'replacement'));
      await expectLater(
        repo.save(
          AdmissionExam.fromJson({...original.toJson(), 'name': 'Obsoleto'}),
        ),
        throwsA(
          isA<ExamCatalogException>().having(
            (e) => e.message,
            'message',
            contains('Otro administrador'),
          ),
        ),
      );
      expect((await latest(repo)).name, 'EXAMEN II');
    },
  );

  test(
    'Correction propagates across 3 pages without changing content or foreign questions',
    () async {
      final db = await database();
      final repo = AdmissionExamRepo(db);
      await repo.save(draft());
      final original = await latest(repo);
      final questions = db.collection(AppEnv.questionsCollection);
      final batch = db.batch();
      for (var i = 0; i < 205; i++) {
        batch.set(questions.doc('q-${i.toString().padLeft(3, '0')}'), {
          ...original.questionFields,
          'statementText': 'Conservar $i',
          'courseId': 'math',
        });
      }
      batch.set(questions.doc('foreign'), {
        ...original.questionFields,
        'universityId': 'other-university',
        'label': 'NO CAMBIAR',
      });
      batch.set(questions.doc('legacy'), {
        'examId': original.id,
        'label': 'SIN ORIGEN VERIFICADO',
      });
      await batch.commit();
      final createdAt = (await repo.exams('unprg').doc('exam').get())
          .data()!['createdAt'];
      await repo.save(
        AdmissionExam.fromJson({
          ...original.toJson(),
          'name': 'Nombre corregido',
          'year': 2025,
          'examType': 'official_practice',
          'reference': 'https://universidad.example/examen.pdf',
        }),
      );
      final synced = await questions.get();
      for (final doc in synced.docs.where((d) => d.id.startsWith('q-'))) {
        expect(doc.data()['label'], 'UNPRG - Nombre corregido', reason: doc.id);
        expect(doc.data()['year'], 2025);
        expect(doc.data()['sourceType'], 'official_practice');
        expect(
          doc.data()['sourceExam']['reference'],
          'https://universidad.example/examen.pdf',
        );
        expect(doc.data()['sourceExamRevision'], 2);
        expect(doc.data()['statementText'], startsWith('Conservar'));
        expect(doc.data()['courseId'], 'math');
      }
      expect(
        (await questions.doc('foreign').get()).data()!['label'],
        'NO CAMBIAR',
      );
      expect(
        (await questions.doc('legacy').get()).data()!['label'],
        'SIN ORIGEN VERIFICADO',
      );
      expect((await latest(repo)).syncPending, false);
      expect(
        (await repo.exams('unprg').doc('exam').get()).data()!['createdAt'],
        createdAt,
      );
      final timestamp = (await questions.doc('q-000').get())
          .data()!['updatedAt'];
      await repo.synchronizeQuestions('unprg', 'exam');
      expect(
        (await questions.doc('q-000').get()).data()!['updatedAt'],
        timestamp,
      );
    },
  );

  test(
    'Interrupted synchronization stays visible and a new session can resume it',
    () async {
      final db = await database();
      final repo = AdmissionExamRepo(db);
      await repo.save(draft());
      final original = await latest(repo);
      await db
          .collection(AppEnv.questionsCollection)
          .doc('q')
          .set(original.questionFields);
      await expectLater(
        InterruptedSyncRepo(db).save(
          AdmissionExam.fromJson({...original.toJson(), 'name': 'Corregido'}),
        ),
        throwsA(isA<ExamSyncPending>()),
      );
      expect((await latest(repo)).syncPending, true);
      await AdmissionExamRepo(db).synchronizeQuestions('unprg', 'exam');
      expect((await latest(repo)).syncPending, false);
      expect(
        (await db.collection(AppEnv.questionsCollection).doc('q').get())
            .data()!['label'],
        'UNPRG - Corregido',
      );
    },
  );

  test(
    'Question create and edit re-read latest origin instead of persisting stale forms',
    () async {
      final db = await database();
      final exams = AdmissionExamRepo(db);
      await exams.save(draft());
      final stale = await latest(exams);
      await exams.save(
        AdmissionExam.fromJson({...stale.toJson(), 'name': 'Actualizado'}),
      );
      final repo = QuestionRepo(db);
      final id = await repo.createQuestion(
        number: 1,
        statementText: 'Pregunta',
        active: 'Y',
        courseId: 'math',
        courseName: 'Matemática',
        topicId: 'algebra',
        topicName: 'Álgebra',
        examId: stale.id,
        admissionExam: stale,
      );
      await repo.updateQuestion(
        id,
        patch: {...stale.questionFields, 'statementText': 'Editado'},
      );
      var current = (await repo.watchQuestions().first).single;
      expect(current.label, 'UNPRG - Actualizado');
      expect(current.statementText, 'Editado');
      final fresh = await latest(exams);
      await exams.save(
        AdmissionExam.fromJson({...fresh.toJson(), 'active': false}),
      );
      await expectLater(
        repo.createQuestion(
          number: 2,
          statementText: 'Otra',
          active: 'Y',
          courseId: 'math',
          courseName: 'Matemática',
          topicId: 'algebra',
          topicName: 'Álgebra',
          examId: stale.id,
          admissionExam: stale,
        ),
        throwsStateError,
      );
      await repo.updateQuestion(
        id,
        patch: {'statementText': 'Puede editar contenido'},
      );
      current = (await repo.watchQuestions().first).single;
      expect(current.statementText, 'Puede editar contenido');
    },
  );
}
