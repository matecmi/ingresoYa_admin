/// Revisión de una pregunta en borrador (docs/admin_staff_contract.md):
/// quien no puede publicar la envía; quien puede, la publica o la devuelve.
class QuestionReview {
  const QuestionReview({
    required this.status,
    required this.requestedBy,
    this.requestedByEmail = '',
    this.requestedAt,
    this.note = '',
    this.reviewedByEmail = '',
  });

  /// `pending` (esperando) o `returned` (devuelta con comentario).
  final String status;
  final String requestedBy;
  final String requestedByEmail;
  final DateTime? requestedAt;
  final String note;
  final String reviewedByEmail;

  bool get pending => status == 'pending';
  bool get returned => status == 'returned';

  static QuestionReview? fromJson(Object? json, {DateTime? requestedAt}) {
    if (json is! Map) return null;
    final status = json['status'];
    if (status != 'pending' && status != 'returned') return null;
    return QuestionReview(
      status: status as String,
      requestedBy: (json['requestedBy'] ?? '').toString(),
      requestedByEmail: (json['requestedByEmail'] ?? '').toString(),
      requestedAt: requestedAt,
      note: (json['note'] ?? '').toString(),
      reviewedByEmail: (json['reviewedByEmail'] ?? '').toString(),
    );
  }
}
