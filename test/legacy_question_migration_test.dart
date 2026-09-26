import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';
import 'package:ingresoya_admin/src/data/repo/legacy_question_migration_repo.dart';
import 'package:ingresoya_admin/src/domain/legacy_question_migration.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

Future<void> seedVerifiedExam(FakeFirebaseFirestore db) => db
    .collection(AppEnv.universitiesCollection)
    .doc('uni-1')
    .collection('admissionExams')
    .doc('exam-1')
    .set({
      'id': 'exam-1',
      'name': 'Ordinario 2025-I',
      'universityId': 'uni-1',
      'universityName': 'Universidad Uno',
      'universityAcronym': 'U1',
      'modalityId': 'ordinary',
      'modalityName': 'Ordinario',
      'examType': 'admission_exam',
      'year': 2025,
      'period': 'I',
      'reference': 'Archivo institucional',
      'active': true,
      'revision': 3,
    });

void main() {
  test(
    'planner preserves legacy content and never derives an origin from label',
    () {
      final plan = LegacyQuestionMigrationPlan.build(
        questionId: 'legacy-1',
        root: {
          'statementText': '¿Cuánto vale x? [@]TEXT',
          'label': 'UNIVERSIDAD UNO 2025-I',
          'courseId': 'course-1',
          'topicId': 'topic-1',
          'subtopicId': 'subtopic-1',
          'partIds': ['part-1'],
          'number': 9,
        },
        alternatives: [
          {
            'id': 'old-b',
            'value': 'B',
            'descriptionText': 'Dos',
            'isCorrect': 'N',
          },
          {
            'id': 'old-a',
            'value': 'A',
            'descriptionText': 'Uno',
            'isCorrect': 'Y',
          },
        ],
        privateExplanation: {'descriptionText': 'Porque sí'},
      );

      expect(plan.disposition, LegacyMigrationDisposition.migrable);
      expect(plan.question!.status, 'draft');
      expect(plan.question!.sourceType, 'unknown');
      expect(plan.question!.sourceExam, isNull);
      expect(plan.question!.alternatives.map((a) => a.id), ['old-a', 'old-b']);
      expect(plan.question!.alternatives.map((a) => a.label), ['A', 'B']);
      expect(plan.answerKey!.correctAlternativeId, 'old-a');
      expect(plan.question!.content.blocks.single, isA<LegacyBlock>());
    },
  );

  test(
    'planner marks multiple correct choices and duplicate parts as manual',
    () {
      final ambiguous = LegacyQuestionMigrationPlan.build(
        questionId: 'legacy-2',
        root: {'statementText': 'Enunciado'},
        alternatives: [
          {'id': 'a', 'isCorrect': 'Y'},
          {'id': 'b', 'isCorrect': true},
        ],
        privateExplanation: null,
      );
      final duplicateParts = LegacyQuestionMigrationPlan.build(
        questionId: 'legacy-3',
        root: {
          'statementText': 'Enunciado',
          'partIds': ['part-1', 'part-1'],
        },
        alternatives: const [],
        privateExplanation: null,
      );

      expect(ambiguous.disposition, LegacyMigrationDisposition.manual);
      expect(duplicateParts.disposition, LegacyMigrationDisposition.manual);
    },
  );

  test(
    'dry run reports and a write run creates only an idempotent draft',
    () async {
      final db = FakeFirebaseFirestore();
      await seedVerifiedExam(db);
      final question = db
          .collection(AppEnv.questionsCollection)
          .doc('legacy-1');
      await question.set({
        'number': 12,
        'statementText': 'Enunciado legacy',
        'label': 'Etiqueta ambigua que no se usa para inferir origen',
        'universityId': 'uni-1',
        'examId': 'exam-1',
        'courseId': 'course-1',
        'topicId': 'topic-1',
        'subtopicId': 'subtopic-1',
        'partIds': ['part-1'],
      });
      await question
          .collection(AppEnv.alternativesSubcollection)
          .doc('answer-a')
          .set({
            'value': 'A',
            'descriptionText': 'Alternativa correcta',
            'isCorrect': 'Y',
          });
      await question
          .collection(AppEnv.alternativesSubcollection)
          .doc('answer-b')
          .set({
            'value': 'B',
            'descriptionText': 'Alternativa incorrecta',
            'isCorrect': 'N',
          });
      await db
          .collection(AppEnv.legacyQuestionEditorPrivateCollection)
          .doc('legacy-1')
          .set({'descriptionText': 'Explicación privada legacy'});

      final repo = LegacyQuestionMigrationRepo(db);
      final preview = await repo.runBatch(dryRun: true, batchSize: 1);
      expect(
        preview.processed.single.disposition,
        LegacyMigrationDisposition.migrable,
      );
      expect(
        (await question.get()).data()!.containsKey('schemaVersion'),
        isFalse,
      );
      expect(
        (await db
                .collection(AppEnv.questionMigrationRunsCollection)
                .doc(preview.runId)
                .collection('items')
                .doc('legacy-1')
                .get())
            .data()!['dryRun'],
        isTrue,
      );

      final written = await repo.runBatch(dryRun: false, batchSize: 1);
      expect(written.processed.single.applied, isTrue);
      final migrated = (await question.get()).data()!;
      expect(migrated['schemaVersion'], 2);
      expect(migrated['status'], 'draft');
      expect(migrated['version'], 1);
      expect(migrated['statementText'], 'Enunciado legacy');
      expect(migrated['sourceExamId'], 'exam-1');
      expect(migrated['year'], 2025);
      expect(migrated['migration']['legacyFieldsRetained'], isTrue);
      expect(
        (await question
                .collection(AppEnv.alternativesSubcollection)
                .doc('answer-a')
                .get())
            .exists,
        isTrue,
      );
      expect(
        (await db
                .collection(AppEnv.questionAnswerKeysCollection)
                .doc('legacy-1_1')
                .get())
            .data()!['correctAlternativeId'],
        'answer-a',
      );
      expect(
        (await question.collection(AppEnv.questionVersionsSubcollection).get())
            .docs,
        isEmpty,
      );

      // A separate retry observes the marker instead of creating a second key.
      // `fake_cloud_firestore` cannot evaluate a document-ID cursor, so the
      // persisted cursor itself is asserted from the run document here.
      final retry = await repo.runBatch(dryRun: false, batchSize: 1);
      expect(
        retry.processed.single.disposition,
        LegacyMigrationDisposition.alreadyMigrated,
      );
      expect(
        (await db
                .collection(AppEnv.questionMigrationRunsCollection)
                .doc(written.runId)
                .get())
            .data()!['cursorQuestionId'],
        'legacy-1',
      );
      expect(
        (await db.collection(AppEnv.questionAnswerKeysCollection).get()).docs,
        hasLength(1),
      );
    },
  );

  test(
    'manual cases are reported and do not mutate the legacy question',
    () async {
      final db = FakeFirebaseFirestore();
      final question = db
          .collection(AppEnv.questionsCollection)
          .doc('ambiguous');
      await question.set({'statementText': 'Enunciado'});
      for (final id in ['a', 'b']) {
        await question.collection(AppEnv.alternativesSubcollection).doc(id).set(
          {'isCorrect': 'Y'},
        );
      }

      final result = await LegacyQuestionMigrationRepo(
        db,
      ).runBatch(dryRun: false, batchSize: 1);
      expect(
        result.processed.single.disposition,
        LegacyMigrationDisposition.manual,
      );
      expect(
        (await question.get()).data()!.containsKey('schemaVersion'),
        isFalse,
      );
      expect(
        (await db.collection(AppEnv.questionAnswerKeysCollection).get()).docs,
        isEmpty,
      );
    },
  );
}
