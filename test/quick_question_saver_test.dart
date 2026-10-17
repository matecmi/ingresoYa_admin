import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';
import 'package:ingresoya_admin/src/data/repo/publishable_question_repo.dart';
import 'package:ingresoya_admin/src/data/repo/question_repo.dart';
import 'package:ingresoya_admin/src/data/repo/quick_question_saver.dart';
import 'package:ingresoya_admin/src/domain/quick_question_parser.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

import 'publishable_question_repo_test.dart' show seedAcademicContext;

void main() {
  test('lo pegado en la carga rápida se guarda y se puede publicar', () async {
    final db = FakeFirebaseFirestore();
    await seedAcademicContext(db);
    final repo = QuestionRepo(db);
    final publicRepo = PublishableQuestionRepo(db);
    final parsed = parseQuickQuestion(
      r'Si $x = 3$, ¿cuánto vale $x^2$?'
      '\na) 6 b) 9 c) 12\nClave: b\n'
      'Solución: se multiplica 3 por 3.',
    );
    final alternatives = [
      for (var i = 0; i < parsed.alternatives.length; i++)
        QuestionAlternative.fromJson({
          'id': 'alt-$i',
          'label': alternativeLabel(i),
          'content': contentFromPlainText(
            parsed.alternatives[i],
            'a$i',
          ).toJson(),
        }),
    ];
    final id = await QuickQuestionSaver(repo, publicRepo).saveNew(
      target: const QuickQuestionTarget(
        courseId: 'course-demo',
        courseName: 'Curso demo',
        topicId: 'topic-demo',
        topicName: 'Tema demo',
        subtopicId: 'subtopic-demo',
        subtopicName: 'Subtema demo',
        partId: 'part-1',
        partName: 'Parte 1',
        difficulty: 'medium',
      ),
      statement: contentFromPlainText(parsed.statement, 'st'),
      alternatives: alternatives,
      correctAlternativeId: alternatives[parsed.correctIndex!].id,
      explanation: contentFromPlainText(parsed.explanation, 'ex'),
    );

    final validation = await publicRepo.validateDraft(id);
    expect(validation.issues.map((i) => i.message), isEmpty);
    await publicRepo.publishDraft(id);
    final root = await db.collection(AppEnv.questionsCollection).doc(id).get();
    expect(root.data()!['status'], 'published');
    expect(root.data()!['partIds'], ['part-1']);
    expect(await repo.publishedCountForPart('part-1'), 1);
    final key = await publicRepo.readAnswerKey(id, 1);
    expect(key!.correctAlternativeId, 'alt-1');
  });
}
