import '../../../shared/question_contract/question_contract.dart';

/// Editorial projection of the current immutable [ExamTemplate] revision.
class ExamTemplateRecord {
  const ExamTemplateRecord({
    required this.template,
    required this.updatedAt,
    this.createdAt,
  });

  final ExamTemplate template;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get active => template.active;
}
