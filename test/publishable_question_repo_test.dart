import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/publishable_question_repo.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';

Map<String, dynamic> fixture() => Map<String, dynamic>.from(
  jsonDecode(File('test/fixtures/question_contract_v2.json').readAsStringSync())
      as Map,
);

QuestionDocument question({String status = 'draft', int version = 1}) =>
    QuestionDocument.fromJson({
      ...Map<String, dynamic>.from(fixture()['question'] as Map),
      'status': status,
      'version': version,
    });

QuestionAnswerKey key({int version = 1}) => QuestionAnswerKey.fromJson({
  ...Map<String, dynamic>.from(fixture()['answerKey'] as Map),
  'version': version,
});

Future<void> seedAcademicContext(
  FakeFirebaseFirestore db, {
  bool partActive = true,
}) async {
  final course = db.collection(AppEnv.coursesCollection).doc('course-demo');
  await course.set({'name': 'Curso demo', 'active': true});
  final topic = course.collection('topics').doc('topic-demo');
  await topic.set({'name': 'Tema demo', 'active': true, 'order': 1});
  await topic.collection('subtopics').doc('subtopic-demo').set({
    'name': 'Subtema demo',
    'active': true,
    'order': 1,
    'listPart': [
      {'id': 'part-1', 'name': 'Parte 1', 'active': partActive},
      {'id': 'part-2', 'name': 'Parte 2', 'active': true},
    ],
  });
}

void main() {
  test(
    'publishes a public projection without correctness and freezes it',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = PublishableQuestionRepo(db);
      await seedAcademicContext(db);
      final draft = question();
      await repo.saveDraft(draft, answerKey: key());
      await repo.publishDraft(draft.ref.questionId);

      final root = await db
          .collection(AppEnv.questionsCollection)
          .doc(draft.ref.questionId)
          .get();
      final publicData = root.data()!;
      expect(publicData['status'], 'published');
      expect(publicData['alternatives'], hasLength(2));
      expect(publicData.containsKey('correctAlternativeId'), false);
      expect(publicData.containsKey('explanation'), false);
      expect(
        (publicData['alternatives'] as List).every(
          (alternative) => !(alternative as Map).containsKey('isCorrect'),
        ),
        isTrue,
      );
      expect(publicData['sourceExamId'], 'exam-demo');

      final frozen = await db
          .collection(AppEnv.questionsCollection)
          .doc(draft.ref.questionId)
          .collection(AppEnv.questionVersionsSubcollection)
          .doc('1')
          .get();
      expect(frozen.data()!['status'], 'published');
      expect(
        (await db
                .collection(AppEnv.questionAnswerKeysCollection)
                .doc('${draft.ref.questionId}_1')
                .get())
            .data()!['correctAlternativeId'],
        'alt-a',
      );
    },
  );

  test(
    'editing a publication forks the next draft without mutating v1',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = PublishableQuestionRepo(db);
      await seedAcademicContext(db);
      await repo.saveDraft(question(), answerKey: key());
      await repo.publishDraft('q-01');
      final before =
          (await db
                  .collection(AppEnv.questionsCollection)
                  .doc('q-01')
                  .collection(AppEnv.questionVersionsSubcollection)
                  .doc('1')
                  .get())
              .data()!;

      final next = await repo.forkPublishedForEdit('q-01');
      expect(next.version, 2);
      final root =
          (await db.collection(AppEnv.questionsCollection).doc('q-01').get())
              .data()!;
      expect([root['status'], root['version']], ['draft', 2]);

      await repo.saveDraft(question(version: 2), answerKey: key(version: 2));
      final frozen =
          (await db
                  .collection(AppEnv.questionsCollection)
                  .doc('q-01')
                  .collection(AppEnv.questionVersionsSubcollection)
                  .doc('1')
                  .get())
              .data()!;
      expect(frozen['content'], before['content']);
      expect(frozen['status'], 'published');
    },
  );

  test(
    'a draft cannot save a key for an alternative it does not contain',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = PublishableQuestionRepo(db);
      await expectLater(
        repo.saveDraft(
          question(),
          answerKey: QuestionAnswerKey.fromJson({
            ...key().toJson(),
            'correctAlternativeId': 'missing',
          }),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'publication rejects a removed or inactive academic reference',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = PublishableQuestionRepo(db);
      await seedAcademicContext(db, partActive: false);
      await repo.saveDraft(question(), answerKey: key());

      await expectLater(repo.publishDraft('q-01'), throwsA(isA<StateError>()));
    },
  );
}
