import '../../shared/question_contract/question_contract.dart';

/// The one-time migration is intentionally conservative. It emits a valid v2
/// draft when legacy data can be represented without guessing, and otherwise
/// leaves the source untouched for an editor to resolve.
const legacyQuestionMigrationName = 'legacy-question-to-v2-draft-v1';

enum LegacyMigrationDisposition { migrable, manual, alreadyMigrated }

class LegacyQuestionMigrationPlan {
  const LegacyQuestionMigrationPlan({
    required this.disposition,
    required this.issues,
    this.question,
    this.answerKey,
  });

  final LegacyMigrationDisposition disposition;
  final List<String> issues;
  final QuestionDocument? question;
  final QuestionAnswerKey? answerKey;

  bool get isMigrable => disposition == LegacyMigrationDisposition.migrable;

  /// Converts only direct legacy values. The repository is responsible for
  /// resolving a [verifiedSourceExam] from the catalog; a free-text label is
  /// never enough to create an origin.
  factory LegacyQuestionMigrationPlan.build({
    required String questionId,
    required Map<String, dynamic> root,
    required List<Map<String, dynamic>> alternatives,
    required Map<String, dynamic>? privateExplanation,
    SourceExam? verifiedSourceExam,
  }) {
    final marker = root['migration'];
    if (marker is Map && marker['name'] == legacyQuestionMigrationName) {
      return const LegacyQuestionMigrationPlan(
        disposition: LegacyMigrationDisposition.alreadyMigrated,
        issues: ['La pregunta ya tiene el marcador de migración v2.'],
      );
    }
    if (root['schemaVersion'] == 2) {
      return const LegacyQuestionMigrationPlan(
        disposition: LegacyMigrationDisposition.alreadyMigrated,
        issues: ['La pregunta ya usa el contrato v2.'],
      );
    }

    final issues = <String>[];
    final partIds = _ids(root['partIds']);
    if (_hasDuplicateIds(root['partIds'])) {
      return const LegacyQuestionMigrationPlan(
        disposition: LegacyMigrationDisposition.manual,
        issues: ['partIds legacy contiene identificadores duplicados.'],
      );
    }

    final usedAlternativeIds = <String>{};
    final convertedAlternatives = <Map<String, dynamic>>[];
    final correctIds = <String>[];
    final orderedAlternatives = List<Map<String, dynamic>>.from(alternatives)
      ..sort(_alternativeOrder);
    for (var index = 0; index < orderedAlternatives.length; index++) {
      final alternative = orderedAlternatives[index];
      final id = (alternative['id'] ?? '').toString().trim();
      if (id.isEmpty || !usedAlternativeIds.add(id)) {
        return const LegacyQuestionMigrationPlan(
          disposition: LegacyMigrationDisposition.manual,
          issues: ['Una alternativa legacy no tiene un ID estable y único.'],
        );
      }
      final content = _contentFrom(
        alternative,
        (alternative['descriptionText'] ?? '').toString(),
        imageUrl: (alternative['descriptionUrlImage'] ?? '').toString(),
        imageIdPrefix: 'legacy-image-$id',
        issues: issues,
      );
      convertedAlternatives.add({
        'id': id,
        'label': _spreadsheetLabel(index),
        'content': content.toJson(),
      });
      if (_isCorrect(alternative['isCorrect'])) correctIds.add(id);
    }

    if (correctIds.length > 1) {
      return LegacyQuestionMigrationPlan(
        disposition: LegacyMigrationDisposition.manual,
        issues: [
          ...issues,
          'Hay ${correctIds.length} alternativas correctas; requiere revisión humana.',
        ],
      );
    }
    if (correctIds.isEmpty && convertedAlternatives.isNotEmpty) {
      issues.add('No se encontró una respuesta correcta verificable.');
    }
    if (convertedAlternatives.length < 2) {
      issues.add('El borrador tiene menos de dos alternativas.');
    }
    if (verifiedSourceExam == null && _hasLegacyOriginReference(root)) {
      issues.add('La procedencia legacy no está verificada en el catálogo.');
    }

    final statement = (root['statementText'] ?? '').toString();
    if (statement.trim().isEmpty && !_hasV2Content(root['content'])) {
      issues.add('El enunciado legacy está vacío.');
    }
    final question = QuestionDocument.fromJson({
      'schemaVersion': 2,
      'questionId': questionId,
      'version': 1,
      'status': 'draft',
      'sourceType': verifiedSourceExam?.examType ?? 'unknown',
      if (verifiedSourceExam != null) 'sourceExam': verifiedSourceExam.toJson(),
      if (_positiveInt(root['originalNumber'] ?? root['number']) != null)
        'originalNumber': _positiveInt(
          root['originalNumber'] ?? root['number'],
        ),
      'courseId': _id(root['courseId']),
      'topicId': _id(root['topicId']),
      'subtopicId': _id(root['subtopicId']),
      'partIds': partIds,
      'difficulty': _difficulty(root['difficulty']),
      'content': _contentFrom(root, statement).toJson(),
      'alternatives': convertedAlternatives,
    });

    QuestionAnswerKey? answerKey;
    if (correctIds.length == 1) {
      final explanation = _explanationContent(privateExplanation, root);
      if (!_hasMeaningfulContent(explanation)) {
        issues.add(
          'La explicación legacy está vacía; se conserva como clave pendiente.',
        );
      }
      answerKey = QuestionAnswerKey.fromJson({
        'schemaVersion': 2,
        'questionId': questionId,
        'version': 1,
        'correctAlternativeId': correctIds.single,
        'explanation': explanation.toJson(),
      });
    }
    return LegacyQuestionMigrationPlan(
      disposition: LegacyMigrationDisposition.migrable,
      issues: List.unmodifiable(issues),
      question: question,
      answerKey: answerKey,
    );
  }
}

String _id(dynamic value) => value?.toString().trim() ?? '';

List<String> _ids(dynamic value) {
  if (value is! List) return const [];
  return value.map(_id).where((id) => id.isNotEmpty).toList(growable: false);
}

bool _hasDuplicateIds(dynamic value) {
  final ids = _ids(value);
  return ids.length != ids.toSet().length;
}

int? _positiveInt(dynamic value) {
  final number = value is num ? value.toInt() : int.tryParse('$value');
  return number != null && number > 0 ? number : null;
}

String _difficulty(dynamic value) {
  const valid = {'easy', 'medium', 'hard', 'unknown'};
  final normalized = _id(value).toLowerCase();
  return valid.contains(normalized) ? normalized : 'unknown';
}

bool _isCorrect(dynamic value) {
  if (value is bool) return value;
  return {'y', 'yes', 'true', '1'}.contains(_id(value).toLowerCase());
}

bool _hasLegacyOriginReference(Map<String, dynamic> root) =>
    _id(root['examId']).isNotEmpty ||
    _id(root['universityId']).isNotEmpty ||
    root['admissionExam'] is Map;

bool _hasV2Content(dynamic value) {
  if (value is! List) return false;
  try {
    QuestionContent.fromJson(value);
    return true;
  } on FormatException {
    return false;
  }
}

QuestionContent _contentFrom(
  Map<String, dynamic> data,
  String legacy, {
  String imageUrl = '',
  String imageIdPrefix = 'legacy-image',
  List<String>? issues,
}) {
  final current = data['content'];
  if (_hasV2Content(current)) return QuestionContent.fromJson(current);
  final blocks = legacy.trim().isEmpty
      ? <Map<String, dynamic>>[]
      : QuestionContent.legacy(legacy).toJson();
  if (imageUrl.trim().isNotEmpty) {
    final uri = Uri.tryParse(imageUrl);
    final id = _nextBlockId(blocks, imageIdPrefix);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      blocks.add({
        'id': id,
        'type': 'image',
        'url': imageUrl,
        'altText': '',
        'caption': '',
      });
    } else {
      blocks.add({'id': id, 'type': 'legacy', 'raw': imageUrl});
      issues?.add('La imagen legacy "$imageUrl" necesita revisión.');
    }
  }
  return QuestionContent.fromJson(blocks);
}

String _nextBlockId(List<Map<String, dynamic>> blocks, String prefix) {
  final ids = blocks.map((block) => block['id']).toSet();
  var id = prefix;
  var suffix = 2;
  while (ids.contains(id)) {
    id = '$prefix-$suffix';
    suffix++;
  }
  return id;
}

QuestionContent _explanationContent(
  Map<String, dynamic>? privateExplanation,
  Map<String, dynamic> root,
) {
  if (privateExplanation != null) {
    return _contentFrom(
      privateExplanation,
      (privateExplanation['descriptionText'] ??
              privateExplanation['explanation'] ??
              '')
          .toString(),
    );
  }
  return _contentFrom(root, (root['explanation'] ?? '').toString());
}

bool _hasMeaningfulContent(QuestionContent content) => content.blocks.any(
  (block) => switch (block) {
    TextBlock value => value.text.trim().isNotEmpty,
    ParagraphBlock value => value.spans.any(
      (span) => span.value.trim().isNotEmpty,
    ),
    FormulaBlock value => value.latex.trim().isNotEmpty,
    ImageBlock _ => true,
    LegacyBlock value => value.raw.trim().isNotEmpty,
  },
);

int _alternativeOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
  final left = _id(a['value']);
  final right = _id(b['value']);
  final label = left.compareTo(right);
  return label != 0 ? label : _id(a['id']).compareTo(_id(b['id']));
}

String _spreadsheetLabel(int index) {
  var value = index + 1;
  var result = '';
  while (value > 0) {
    value--;
    result = String.fromCharCode(65 + value % 26) + result;
    value ~/= 26;
  }
  return result;
}
