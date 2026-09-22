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
