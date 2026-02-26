import 'alternative_entity.dart';

class QuestionEntity {
  final String id;
  final int number;
  final String? label;
  final String statementText;
  final String active; // "Y" | "N"

  final String topicId;
  final String topicName;

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
    this.label,
  });

  bool get isActive => active == 'Y';
}