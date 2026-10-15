import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/admission_exam_repo.dart';
import 'package:ingresoya_admin/src/domain/entities/admission_exam.dart';
import 'package:ingresoya_admin/src/domain/entities/exam_simulator_rules.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

const _uni = 'unprg';
const _exam = 'ordinary-2026-I';

Future<FakeFirebaseFirestore> _seed({
  int published = 3,
  List<int?> numbers = const [1, 2, 3],
  int drafts = 1,
}) async {
  final db = FakeFirebaseFirestore();
  final uni = db.collection(AppEnv.universitiesCollection).doc(_uni);
  await uni.set({'name': 'UNPRG', 'acronym': 'UNPRG', 'active': true});
  await uni.collection('admissionExams').doc(_exam).set({
    'id': _exam,
    'name': 'EXAMEN DE ADMISIÓN ORDINARIO 2026 I',
    'universityId': _uni,
    'universityName': 'UNPRG',
    'universityAcronym': 'UNPRG',
    'modalityId': 'ordinary',
    'modalityName': 'Ordinario',
    'year': 2026,
    'period': 'I',
    'active': true,
    'revision': 4,
  });
  final questions = db.collection(AppEnv.questionsCollection);
  for (var i = 0; i < published; i++) {
    await questions.doc('q$i').set({
      'examId': _exam,
      'universityId': _uni,
      'status': 'published',
      if (i < numbers.length && numbers[i] != null)
        'originalNumber': numbers[i],
    });
  }
  for (var i = 0; i < drafts; i++) {
    await questions.doc('draft$i').set({
      'examId': _exam,
      'universityId': _uni,
      'status': 'draft',
      'originalNumber': 99,
    });
  }
  // Same exam id under another university does not count.
  await questions.doc('other').set({
    'examId': _exam,
    'universityId': 'unt',
    'status': 'published',
  });
  return db;
}

void main() {
  group('reglas del examen pasado', () {
    test('valida tiempo, puntaje y mínimos', () {
      const ok = ExamSimulatorRules(
        questionCount: 24,
        durationMinutes: 60,
        maxScore: 1000,
        correctPoints: 4,
        incorrectPoints: -1,
        cutoffs: {'sistemas': 702},
      );
      expect(ok.validate(), isNull);
      expect(ok.copyWith(questionCount: 0).validate(), isNotNull);
      expect(ok.copyWith(incorrectPoints: 1).validate(), isNotNull);
      expect(ok.copyWith(blankPoints: 5).validate(), isNotNull);
      expect(ok.copyWith(cutoffs: {'sistemas': 1200}).validate(), isNotNull);
    });

    test('lee valores guardados y conserva los de fábrica', () {
      final rules = ExamSimulatorRules.fromJson({
        'questionCount': 24,
        'correctPoints': 4,
        'incorrectPoints': -1.5,
        'questionOrder': 'shuffled',
        'available': true,
        'cutoffs': {'sistemas': 702.4, 'malo': 'x'},
      });
      expect(rules.durationMinutes, 60);
      expect(rules.incorrectPoints, -1.5);
      expect(rules.questionOrder, 'shuffled');
      expect(rules.cutoffs, {'sistemas': 702});
      expect(ExamSimulatorRules.fromJson(null).questionCount, 0);
    });

    test('las reglas no viajan a las preguntas del examen', () {
      final exam = AdmissionExam.fromJson({
        'id': _exam,
        'name': 'X',
        'universityId': _uni,
        'universityName': 'UNPRG',
        'universityAcronym': 'UNPRG',
        'modalityId': 'ordinary',
        'modalityName': 'Ordinario',
        'year': 2026,
        'period': 'I',
        'simulator': {'questionCount': 24, 'available': true},
      });
      expect(exam.simulator.questionCount, 24);
      expect(exam.toJson().containsKey('simulator'), isFalse);
      expect(
        exam.questionFields['admissionExam'],
        isNot(contains('simulator')),
      );
    });
  });

  group('completo', () {
    test('orden original exige número en todas, sin repetir', () {
      bool complete(int published, int numbered, bool unique, String order) =>
          ExamSimulatorRules.isComplete(
            questionCount: 3,
            publishedQuestions: published,
            numberedQuestions: numbered,
            numbersAreUnique: unique,
            questionOrder: order,
          );
      expect(complete(3, 3, true, 'original'), isTrue);
      expect(complete(3, 2, true, 'original'), isFalse);
      expect(complete(3, 3, false, 'original'), isFalse);
      expect(complete(3, 0, true, 'shuffled'), isTrue);
      expect(complete(2, 2, true, 'shuffled'), isFalse);
    });

    test('guardar cuenta solo las publicadas de esa universidad', () async {
      final db = await _seed();
      final saved = await AdmissionExamRepo(db).saveSimulatorRules(
        _uni,
        _exam,
        const ExamSimulatorRules(questionCount: 3, available: true),
      );
      expect(saved.publishedQuestions, 3);
      expect(saved.numberedQuestions, 3);
      expect(saved.complete, isTrue);
      final doc = await db
          .collection(AppEnv.universitiesCollection)
          .doc(_uni)
          .collection('admissionExams')
          .doc(_exam)
          .get();
      expect(doc.data()!['simulator']['available'], isTrue);
      // The catalog revision is untouched: no question sync is triggered.
      expect(doc.data()!['revision'], 4);
    });

    test('no se puede ofrecer un examen incompleto', () async {
      final db = await _seed(numbers: const [1, null, 3]);
      final repo = AdmissionExamRepo(db);
      await expectLater(
        repo.saveSimulatorRules(
          _uni,
          _exam,
          const ExamSimulatorRules(questionCount: 3, available: true),
        ),
        throwsA(isA<ExamCatalogException>()),
      );
      // Not offered, it saves and reports what is missing.
      final saved = await repo.saveSimulatorRules(
        _uni,
        _exam,
        const ExamSimulatorRules(questionCount: 3),
      );
      expect(saved.complete, isFalse);
      expect(saved.numberedQuestions, 2);
      // Mixed order does not need the numbers.
      final mixed = await repo.saveSimulatorRules(
        _uni,
        _exam,
        const ExamSimulatorRules(
          questionCount: 3,
          questionOrder: 'shuffled',
          available: true,
        ),
      );
      expect(mixed.complete, isTrue);
    });
  });
}
