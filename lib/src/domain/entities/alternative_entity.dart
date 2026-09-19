import '../editor_document.dart';

class AlternativeEntity {
  final EditorDocument? editorContent;
  final String id;
  final String value; // A, B, C...
  final String descriptionText;
  final String isCorrect; // "Y" | "N"
  final String questionId;

  const AlternativeEntity({
    required this.id,
    required this.value,
    required this.descriptionText,
    required this.isCorrect,
    required this.questionId,
    this.editorContent,
  });

  bool get correct => isCorrect == 'Y';
}
