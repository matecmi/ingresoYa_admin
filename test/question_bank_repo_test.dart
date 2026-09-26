import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/question_repo.dart';
import 'package:ingresoya_admin/src/domain/question_bank_filter.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

Future<void> seedQuestion(
  FakeFirebaseFirestore db,
  int index, {
  String status = 'published',
  String courseId = 'math',
  String topicId = 'algebra',
  String subtopicId = 'ecuaciones',
  List<String> partIds = const ['part-1'],
  String universityId = 'unprg',
  String sourceExamId = 'exam-1',
  String sourceType = 'admission_exam',
  String modalityId = 'ordinary',
  int year = 2026,
  String difficulty = 'medium',
}) async {
  final id = 'question-$index';
  final text = 'Ecuacion cuadratica $index';
  final searchTokens = QuestionBankSearch.tokens([
    id,
    text,
    'Matemática Álgebra',
  ]);
  await db.collection(AppEnv.questionsCollection).doc(id).set({
    'questionId': id,
    'number': index,
    'status': status,
    'version': 2,
    'statementText': text,
    'content': [
      {'id': 'text-$index', 'type': 'text', 'text': text},
    ],
    'sourceType': sourceType,
    'sourceExamId': sourceExamId,
    'sourceLabel': 'UNPRG - Ordinario',
    'universityId': universityId,
    'modalityId': modalityId,
    'year': year,
    'period': 'I',
    'courseId': courseId,
    'courseName': 'Matemática',
    'topicId': topicId,
    'topicName': 'Álgebra',
    'subtopicId': subtopicId,
    'subtopicName': 'Ecuaciones',
    'partIds': partIds,
    'partNames': {'part-1': 'Cuadráticas'},
    'difficulty': difficulty,
    'searchTokens': searchTokens,
    'partSearchTokens': QuestionBankSearch.partTokens(partIds, searchTokens),
    'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1, 0, 0, index)),
  });
}

void main() {
  test(
    'reads a bounded page and continues with its Firestore cursor',
    () async {
      final db = FakeFirebaseFirestore();
      for (var index = 0; index < 27; index++) {
        await seedQuestion(db, index);
      }
      final repo = QuestionRepo(db);

      final first = await repo.fetchQuestionPage(
        const QuestionBankFilter(status: 'published'),
      );
      expect(first.items, hasLength(QuestionRepo.questionBankPageSize));
      expect(first.hasMore, isTrue);
      expect(first.items.first.number, 26);

      final second = await repo.fetchQuestionPage(
        const QuestionBankFilter(status: 'published'),
        after: first.nextCursor,
      );
      expect(second.items.map((item) => item.number), [1, 0]);
      expect(second.hasMore, isFalse);
    },
  );

  test(
    'translates source, academic, part, year and text filters to the page',
    () async {
      final db = FakeFirebaseFirestore();
      await seedQuestion(db, 1);
      await seedQuestion(
        db,
        2,
        universityId: 'unmsm',
        sourceExamId: 'exam-2',
        partIds: const ['part-2'],
        year: 2024,
        difficulty: 'hard',
      );
      final repo = QuestionRepo(db);

      final filtered = await repo.fetchQuestionPage(
        const QuestionBankFilter(
          universityId: 'unprg',
          sourceExamId: 'exam-1',
          courseId: 'math',
          topicId: 'algebra',
          subtopicId: 'ecuaciones',
          partId: 'part-1',
          difficulty: 'medium',
          yearFrom: 2025,
          yearTo: 2026,
          text: 'cuad',
        ),
      );

      expect(filtered.items.map((item) => item.id), ['question-1']);
      expect(filtered.items.single.sourceLabel, 'UNPRG - Ordinario');
      expect(filtered.items.single.editorialWarnings, isEmpty);
    },
  );
}
