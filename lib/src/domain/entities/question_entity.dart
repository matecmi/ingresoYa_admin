import 'alternative_entity.dart';
import 'admission_exam.dart';
import '../editor_document.dart';

class QuestionEntity {
  final AdmissionExam? admissionExam;
  final String id;
  final int number;
  final String? label;
  final String statementText;
  final EditorDocument? editorContent;
  final String active; // "Y" | "N"

  final String topicId;
  final String topicName;

  final String subtopicId;
  final String subtopicName;
  final List<String> partIds;
  final Map<String, String> partNames;

  final String courseId;
  final String courseName;

  final String examId; // puede ser ""
  final String difficulty;
  final int? originalNumber;
  final String editorialStatus;
  final int version;
  final String sourceType;
  final String sourceLabel;
  final String universityId;
  final String modalityId;
  final int? year;
  final String period;
  final DateTime? updatedAt;
  final List<String> editorialWarnings;

  final List<AlternativeEntity> alternatives; // en lista lo dejamos vacío

  const QuestionEntity({
    required this.id,
    required this.number,
    required this.statementText,
    required this.active,
    required this.topicId,
    required this.topicName,
    required this.courseId,
    required this.courseName,
    required this.examId,
    required this.alternatives,
    this.difficulty = 'unknown',
    this.originalNumber,
    this.editorialStatus = 'draft',
    this.version = 1,
    this.sourceType = 'unknown',
    this.sourceLabel = '',
    this.universityId = '',
    this.modalityId = '',
    this.year,
    this.period = '',
    this.updatedAt,
    this.editorialWarnings = const [],
    this.subtopicId = '',
    this.subtopicName = '',
    this.partIds = const [],
    this.partNames = const {},
    this.label,
    this.editorContent,
    this.admissionExam,
  });

  bool get isActive => active == 'Y';
}
