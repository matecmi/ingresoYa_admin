class AlternativeEntity {
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
  });

  bool get correct => isCorrect == 'Y';
}