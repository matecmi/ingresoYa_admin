import '../../../shared/question_contract/question_contract.dart';

/// Editorial projection of the current immutable [ExamTemplate] revision.
class ExamTemplateRecord {
  const ExamTemplateRecord({
    required this.template,
    required this.updatedAt,
    this.createdAt,
    this.published = false,
  });

  final ExamTemplate template;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool published;

  bool get active => template.active;
  bool get selectableForMastery =>
      active &&
      published &&
      template.purpose == 'subtopic_mastery' &&
      template.mode == 'dynamic';
}
