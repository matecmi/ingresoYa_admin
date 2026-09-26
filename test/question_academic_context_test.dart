import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/question_repo.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

Future<void> seedContext(FakeFirebaseFirestore db) async {
  final course = db.collection(AppEnv.coursesCollection).doc('math');
  await course.set({'name': 'Matemática', 'active': true});
  final topic = course.collection('topics').doc('algebra');
  await topic.set({'name': 'Álgebra', 'order': 1, 'active': true});
  await topic.collection('subtopics').doc('equations').set({
    'name': 'Ecuaciones',
    'order': 1,
    'active': true,
    'listPart': [
      {'id': 'linear', 'name': 'Ecuaciones lineales', 'active': true},
      {'id': 'quadratic', 'name': 'Ecuaciones cuadráticas', 'active': true},
    ],
  });
}

void main() {
  test('persists stable academic IDs with display-only name copies', () async {
    final db = FakeFirebaseFirestore();
    await seedContext(db);
    final id = await QuestionRepo(db).createQuestion(
      number: 1,
      statementText: 'Resuelve x',
      active: 'Y',
      courseId: 'math',
      courseName: 'Matemática',
      topicId: 'algebra',
      topicName: 'Álgebra',
      subtopicId: 'equations',
      subtopicName: 'Ecuaciones',
      partIds: const ['linear', 'quadratic'],
      partNames: const {
        'linear': 'Ecuaciones lineales',
        'quadratic': 'Ecuaciones cuadráticas',
      },
      examId: '',
    );
    final saved =
        (await db.collection(AppEnv.questionsCollection).doc(id).get()).data()!;
    expect(saved['subtopicId'], 'equations');
    expect(saved['partIds'], ['linear', 'quadratic']);
    expect(saved['partNames']['linear'], 'Ecuaciones lineales');
  });

  test('rejects duplicate, foreign and inactive parts', () async {
    final db = FakeFirebaseFirestore();
    await seedContext(db);
    final repo = QuestionRepo(db);
    Future<String> create(List<String> ids) => repo.createQuestion(
      number: 1,
      statementText: 'Resuelve x',
      active: 'Y',
      courseId: 'math',
      courseName: 'Matemática',
      topicId: 'algebra',
      topicName: 'Álgebra',
      subtopicId: 'equations',
      subtopicName: 'Ecuaciones',
      partIds: ids,
      examId: '',
    );

    await expectLater(create(['linear', 'linear']), throwsA(isA<StateError>()));
    await expectLater(create(['foreign']), throwsA(isA<StateError>()));
    await db
        .collection(AppEnv.coursesCollection)
        .doc('math')
        .collection('topics')
        .doc('algebra')
        .collection('subtopics')
        .doc('equations')
        .update({
          'listPart': [
            {'id': 'linear', 'name': 'Ecuaciones lineales', 'active': false},
          ],
        });
    await expectLater(create(['linear']), throwsA(isA<StateError>()));
  });
}
