import '../../../shared/question_contract/question_contract.dart';
import '../../domain/editor_document.dart';
import '../../domain/entities/admission_exam.dart';
import 'publishable_question_repo.dart';
import 'question_repo.dart';

/// Datos fijos de la carga rápida (se quedan entre una pregunta y otra).
class QuickQuestionTarget {
  const QuickQuestionTarget({
    required this.courseId,
    required this.courseName,
    required this.topicId,
    required this.topicName,
    required this.subtopicId,
    required this.subtopicName,
    required this.partId,
    required this.partName,
    required this.difficulty,
  });

  final String courseId;
  final String courseName;
  final String topicId;
  final String topicName;
  final String subtopicId;
  final String subtopicName;
  final String partId;
  final String partName;

  /// `unknown`, `easy`, `medium` o `hard` (contrato v2).
  final String difficulty;

  /// Publicar exige curso, tema, subtema y al menos una parte.
  bool get complete =>
      courseId.isNotEmpty &&
      topicId.isNotEmpty &&
      subtopicId.isNotEmpty &&
      partId.isNotEmpty;
}

/// Guarda una pregunta nueva como borrador v2 con su clave, por el mismo
/// camino que el formulario completo (raíz, borrador, clave, espejo de
/// alternativas y explicación privada).
class QuickQuestionSaver {
  QuickQuestionSaver(this._repo, this._publicRepo);

  final QuestionRepo _repo;
  final PublishableQuestionRepo _publicRepo;

  Future<String> saveNew({
    required QuickQuestionTarget target,
    required QuestionContent statement,
    required List<QuestionAlternative> alternatives,
    required String? correctAlternativeId,
    required QuestionContent explanation,
    AdmissionExam? exam,
    int? originalNumber,
  }) async {
    final content = EditorDocument(statement);
    final questionId = await _repo.createQuestion(
      editorContent: content,
      admissionExam: exam,
      originalNumber: originalNumber,
      number: DateTime.now().microsecondsSinceEpoch,
      statementText: content.legacy,
      active: 'Y',
      topicId: target.topicId,
      topicName: target.topicName,
      subtopicId: target.subtopicId,
      subtopicName: target.subtopicName,
      partIds: [if (target.partId.isNotEmpty) target.partId],
      partNames: {if (target.partId.isNotEmpty) target.partId: target.partName},
      difficulty: target.difficulty,
      requireCompleteAcademic: false,
      courseId: target.courseId,
      courseName: target.courseName,
      examId: exam?.id ?? '',
      label: exam?.label,
    );
    final draft = QuestionDocument.fromJson({
      'schemaVersion': 2,
      'questionId': questionId,
      'version': 1,
      'status': 'draft',
      'sourceType': exam?.examType ?? 'original',
      if (exam != null) 'sourceExam': exam.source.toJson(),
      'originalNumber': ?originalNumber,
      'courseId': target.courseId,
      'topicId': target.topicId,
      'subtopicId': target.subtopicId,
      'partIds': [if (target.partId.isNotEmpty) target.partId],
      'difficulty': target.difficulty,
      'content': statement.toJson(),
      'alternatives': alternatives.map((a) => a.toJson()).toList(),
    });
    final answerKey = correctAlternativeId == null
        ? null
        : QuestionAnswerKey.fromJson({
            'schemaVersion': 2,
            'questionId': questionId,
            'version': 1,
            'correctAlternativeId': correctAlternativeId,
            'explanation': explanation.toJson(),
          });
    await _publicRepo.saveDraft(draft, answerKey: answerKey);
    await _repo.mirrorV2Alternatives(
      questionId: questionId,
      alternatives: alternatives,
      correctAlternativeId: correctAlternativeId,
    );
    final explanationDoc = EditorDocument(explanation);
    if (explanationDoc.hasContent) {
      await _repo.saveExplanation(questionId, explanationDoc);
    }
    return questionId;
  }
}
