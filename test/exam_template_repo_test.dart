import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';
import 'package:ingresoya_admin/src/data/repo/exam_template_repo.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

void main() {
  test('uses the technical template ID as the Firestore document ID', () async {
    final db = FakeFirebaseFirestore();
    final repo = ExamTemplateRepo(db);

    await repo.save(
      ExamTemplate.fromJson({
        'schemaVersion': 2,
        'id': 'part-exam-v1',
        'version': 1,
        'title': 'Examen de verificación de parte',
        'active': true,
        'purpose': 'part_completion',
        'mode': 'dynamic',
        'selectionPolicy': 'strict',
        'allowedFallbackSources': [],
        'questionCount': 4,
        'passPercentExclusive': 80,
        'blocks': [
          {
            'count': 4,
            'filter': {'sourceType': 'admission_exam', 'difficulty': 'any'},
          },
        ],
        'fixedQuestions': [],
      }),
    );

    final saved = await db
        .collection(AppEnv.examTemplatesCollection)
        .doc('part-exam-v1')
        .get();

    expect(saved.exists, isTrue);
    expect(saved.data()?['id'], 'part-exam-v1');
    expect(saved.data()?['purpose'], 'part_completion');
  });
}
