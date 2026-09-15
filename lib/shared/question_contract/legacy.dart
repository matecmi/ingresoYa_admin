import 'dart:convert';
import 'models.dart';

/// Non-destructive import. Original metadata stays available for later migration.
class LegacyQuestionImport {
  LegacyQuestionImport._(
    this.question,
    this.answerKey,
    this.originalJson,
    this.issues,
  );
  final QuestionDocument question;
  final QuestionAnswerKey? answerKey;
  final String originalJson;
  final List<String> issues;
  Json restoreOriginal() => objectField(jsonDecode(originalJson));

  factory LegacyQuestionImport.fromJson(Json json, {String? documentId}) {
    final id = documentId ?? (json['id'] ?? json['idDoc'])?.toString();
    if (id == null || id.trim().isEmpty) {
      throw const FormatException('Legacy question requires an ID');
    }
    final issues = <String>[
      'Legacy content requires editorial review',
      'Provenance has not been verified',
    ];
    final alternatives = <Json>[];
    final correctIds = <String>[];
    final oldAlternatives = json['alternatives'] ?? [];
    if (oldAlternatives is! List) {
      throw const FormatException('Invalid legacy alternatives');
    }
    for (var i = 0; i < oldAlternatives.length; i++) {
      final old = objectField(oldAlternatives[i]);
      final altId = (old['id'] ?? '$id-alt-${i + 1}').toString();
      final blocks = QuestionContent.legacy(
        (old['descriptionText'] ?? '').toString(),
      ).toJson();
      final url = (old['descriptionUrlImage'] ?? '').toString();
      if (url.isNotEmpty) {
        // Preserve unvalidated legacy links as raw content instead of dropping them.
        final uri = Uri.tryParse(url);
        if (uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty) {
          blocks.add({
            'id': 'legacy-image',
            'type': 'image',
            'url': url,
            'altText': '',
          });
        } else {
          blocks.add({'id': 'legacy-image', 'type': 'legacy', 'raw': url});
          issues.add('Alternative $altId has an invalid image URL');
        }
      }
      alternatives.add({
        'id': altId,
        'label': (old['value'] ?? '${i + 1}').toString(),
        'content': blocks,
      });
      if (old['isCorrect'] == 'Y') correctIds.add(altId);
    }
    final number = int.tryParse('${json['number']}');
    final question = QuestionDocument.fromJson({
      'schemaVersion': 2,
      'questionId': id,
      'version': 1,
      'status': 'draft',
      'sourceType': 'unknown',
      if (number != null && number > 0) 'originalNumber': number,
      'courseId': (json['courseId'] ?? '').toString(),
      'topicId': (json['topicId'] ?? '').toString(),
      'subtopicId': (json['subtopicId'] ?? '').toString(),
      'partIds': [],
      'difficulty': 'unknown',
      'content': QuestionContent.legacy(
        (json['statementText'] ?? '').toString(),
      ).toJson(),
      'alternatives': alternatives,
    });
    QuestionAnswerKey? answerKey;
    if (correctIds.length == 1) {
      answerKey = QuestionAnswerKey.fromJson({
        'schemaVersion': 2,
        ...question.ref.toJson(),
        'correctAlternativeId': correctIds.single,
        'explanation': QuestionContent.legacy(
          (json['explanation'] ?? '').toString(),
        ).toJson(),
      });
    } else {
      issues.add(
        'Expected exactly one correct alternative; found ${correctIds.length}',
      );
    }
    return LegacyQuestionImport._(
      question,
      answerKey,
      jsonEncode(json),
      List.unmodifiable(issues),
    );
  }
}
