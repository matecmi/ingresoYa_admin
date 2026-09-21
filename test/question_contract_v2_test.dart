import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
// The same conformance suite runs verbatim in both differently named packages.
// ignore: avoid_relative_lib_imports
import '../lib/shared/question_contract/question_contract.dart';

Json fixture() => objectField(
  jsonDecode(
    File('test/fixtures/question_contract_v2.json').readAsStringSync(),
  ),
);

void main() {
  test('other exam sources and references roundtrip in app and admin', () {
    final data = objectField(fixture()['sourceExam']);
    final source = SourceExam.fromJson({
      ...data,
      'examType': 'other',
      'reference': 'Documento original, página 5',
    });
    expect(
      SourceExam.fromJson(source.toJson()).reference,
      'Documento original, página 5',
    );
    expect(source.label, 'Pregunta del examen ordinario 2026-I | UNPRG');
    expect(ExamFilter.fromJson({'sourceType': 'other'}).sourceType, 'other');
    final named = SourceExam.fromJson({
      ...source.toJson(),
      'name': 'EXAMEN ORDINARIO 2026 I',
    });
    expect(
      SourceExam.fromJson(named.toJson()).label,
      'UNPRG - EXAMEN ORDINARIO 2026 I',
    );
  });
  test('official practice label and legacy IDs preserve their meaning', () {
    final data = objectField(fixture()['sourceExam']);
    expect(
      SourceExam.fromJson({...data, 'examType': 'official_practice'}).label,
      'Pregunta de práctica oficial ordinario 2026-I | UNPRG',
    );
    final old = objectField(fixture()['legacy']);
    old.remove('id');
    old['idDoc'] = 'firestore-old';
    expect(
      LegacyQuestionImport.fromJson(old).question.ref.questionId,
      'firestore-old',
    );
    expect(
      LegacyQuestionImport.fromJson(
        old,
        documentId: 'actual-doc',
      ).question.ref.questionId,
      'actual-doc',
    );
    final first = objectField((old['alternatives'] as List).first);
    old['alternatives'] = [
      first,
      {...first, 'id': 'old-b', 'value': 'B'},
    ];
    final imported = LegacyQuestionImport.fromJson(old);
    expect(imported.answerKey, isNull);
    expect(imported.restoreOriginal(), old);
    expect(
      imported.issues,
      contains('Expected exactly one correct alternative; found 2'),
    );
  });

  test('attempt questions require selectable alternatives', () {
    expect(
      () => AttemptQuestion.fromJson({
        'questionId': 'q',
        'version': 1,
        'alternativeOrder': [],
      }),
      throwsFormatException,
    );
  });

  test('shared fixture roundtrips all models without losing data', () {
    final data = fixture();
    final source = SourceExam.fromJson(objectField(data['sourceExam']));
    final question = QuestionDocument.fromJson(objectField(data['question']));
    final key = QuestionAnswerKey.fromJson(objectField(data['answerKey']));
    final template = ExamTemplate.fromJson(objectField(data['template']));
    final attempt = ExamAttempt.fromJson(objectField(data['attempt']));
    expect(source.toJson(), data['sourceExam']);
    expect(question.toJson(), data['question']);
    expect(key.toJson(), data['answerKey']);
    expect(template.toJson(), data['template']);
    expect(attempt.toJson(), data['attempt']);
    key.validateAgainst(question);
  });

  test(
    'preserves order, accents, paragraphs, inline math and image dimensions',
    () {
      final q = QuestionDocument.fromJson(objectField(fixture()['question']));
      expect(q.content.blocks.map((b) => b.id), [
        'text-1',
        'image-1',
        'formula-1',
        'paragraph-1',
      ]);
      expect(
        (q.content.blocks.first as TextBlock).text,
        'Observa la figura. ¿Cuánto vale x?\nJustifica tu elección.',
      );
      expect((q.content.blocks[2] as FormulaBlock).latex, r'A = \frac{8x}{2}');
      final image = q.content.blocks[1] as ImageBlock;
      expect(image.storagePath, 'questions/q-01/v1/figure.webp');
      expect([image.width, image.height], [1000, 700]);
      final paragraph = q.content.blocks[3] as ParagraphBlock;
      expect(paragraph.spans.map((s) => s.type), ['text', 'formula', 'text']);
      expect(paragraph.spans[1].value, 'x^2=25');
      expect(paragraph.spans.last.marks, ['bold']);
      expect(q.alternatives[1].content.blocks.single, isA<ImageBlock>());
    },
  );

  test('label is derived from verified origin and optional period', () {
    final data = objectField(fixture()['sourceExam']);
    expect(
      SourceExam.fromJson(data).label,
      'Pregunta del examen de admisión ordinario 2026-I | UNPRG',
    );
    expect(
      SourceExam.fromJson({...data, 'period': ''}).label,
      'Pregunta del examen de admisión ordinario 2026 | UNPRG',
    );
  });

  test('legacy payload is lossless and never invents university/year', () {
    final old = objectField(fixture()['legacy']);
    final imported = LegacyQuestionImport.fromJson(old);
    expect(imported.restoreOriginal(), old);
    expect(
      (imported.question.content.blocks.single as LegacyBlock).raw,
      old['statementText'],
    );
    expect(imported.question.status, 'draft');
    expect(imported.question.sourceExam, isNull);
    expect(imported.question.sourceType, 'unknown');
    expect(
      imported.question.alternatives.first.content.blocks.last,
      isA<ImageBlock>(),
    );
    imported.answerKey!.validateAgainst(imported.question);
    expect(imported.restoreOriginal()['sectionId'], 'section-old');
    expect(imported.restoreOriginal()['groupId'], 'group-old');
    final empty = LegacyQuestionImport.fromJson({...old, 'alternatives': null});
    expect(empty.answerKey, isNull);
    expect(
      empty.issues,
      contains('Expected exactly one correct alternative; found 0'),
    );
  });

  test('rejects unsupported versions, duplicate IDs and unknown blocks', () {
    final q = objectField(fixture()['question']);
    expect(
      () => QuestionDocument.fromJson({...q, 'schemaVersion': 3}),
      throwsFormatException,
    );
    expect(
      () => QuestionContent.fromJson([
        {'id': 'x', 'type': 'video'},
      ]),
      throwsFormatException,
    );
    expect(
      () => QuestionContent.fromJson([
        {'id': 'x', 'type': 'text', 'text': 'a'},
        {'id': 'x', 'type': 'text', 'text': 'b'},
      ]),
      throwsFormatException,
    );
    expect(
      () => QuestionDocument.fromJson({
        ...q,
        'alternatives': [q['alternatives'][0], q['alternatives'][0]],
      }),
      throwsFormatException,
    );
  });

  test(
    'rejects invalid images and separates public question from private key',
    () {
      expect(
        () => ImageBlock.fromJson({
          'id': 'x',
          'type': 'image',
          'url': 'javascript:alert(1)',
        }),
        throwsFormatException,
      );
      expect(
        () => ImageBlock.fromJson({
          'id': 'x',
          'type': 'image',
          'storagePath': '../secret',
        }),
        throwsFormatException,
      );
      final q = objectField(fixture()['question']);
      expect(
        () => QuestionDocument.fromJson({...q, 'correctAlternativeId': 'a'}),
        throwsFormatException,
      );
      final key = objectField(fixture()['answerKey']);
      expect(
        () => QuestionAnswerKey.fromJson({
          ...key,
          'version': 99,
        }).validateAgainst(QuestionDocument.fromJson(q)),
        throwsFormatException,
      );
      expect(
        () => QuestionAnswerKey.fromJson({
          ...key,
          'correctAlternativeId': 'missing',
        }).validateAgainst(QuestionDocument.fromJson(q)),
        throwsFormatException,
      );
    },
  );

  test('template enforces counts, fixed revisions and year ranges', () {
    final t = objectField(fixture()['template']);
    expect(ExamTemplate.fromJson(t).requiredCorrectAnswers, 9);
    expect(
      () => ExamTemplate.fromJson({...t, 'questionCount': 15}),
      throwsFormatException,
    );
    expect(
      () => ExamFilter.fromJson({'yearFrom': 2026, 'yearTo': 2025}),
      throwsFormatException,
    );
    final fixed = ExamTemplate.fromJson({
      ...t,
      'mode': 'fixed',
      'questionCount': 1,
      'blocks': [],
      'fixedQuestions': [
        {'questionId': 'q-01', 'version': 1},
      ],
    });
    expect(fixed.fixedQuestions.single.version, 1);
  });

  test('8/10 fails, 9/10 passes without rounding threshold errors', () {
    for (final correct in [8, 9]) {
      final r = ExamResult.fromJson({
        'schemaVersion': 2,
        'attemptId': 'a',
        'total': 10,
        'correct': correct,
        'passPercentExclusive': 80,
        'gradedAtMs': 1,
      });
      expect(r.passed, correct == 9);
      expect(r.percentage, correct * 10);
    }
  });

  test('attempt refuses foreign answers and mismatched results', () {
    final a = objectField(fixture()['attempt']);
    expect(
      () => ExamAttempt.fromJson({
        ...a,
        'answers': {'unknown': 'a'},
      }),
      throwsFormatException,
    );
    expect(
      () => ExamAttempt.fromJson({
        ...a,
        'answers': {'q-01': 'unknown'},
      }),
      throwsFormatException,
    );
    expect(
      () => ExamAttempt.fromJson({...a, 'status': 'graded'}),
      throwsFormatException,
    );
    final graded = ExamAttempt.fromJson({
      ...a,
      'status': 'graded',
      'result': {
        'schemaVersion': 2,
        'attemptId': a['id'],
        'total': 1,
        'correct': 1,
        'passPercentExclusive': 80,
        'gradedAtMs': 2,
      },
    });
    expect(ExamAttempt.fromJson(graded.toJson()).result!.passed, isTrue);
  });

  test('collections cannot be mutated after decoding', () {
    final q = QuestionDocument.fromJson(objectField(fixture()['question']));
    expect(() => q.partIds.add('another'), throwsUnsupportedError);
    expect(() => q.content.blocks.clear(), throwsUnsupportedError);
    expect(() => q.alternatives.clear(), throwsUnsupportedError);
  });
}
