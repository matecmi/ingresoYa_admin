import 'dart:convert';

import 'package:flutter_math_fork/tex.dart';

import '../../shared/question_contract/question_contract.dart';

/// A concrete, editor-facing reason why a draft cannot be published.
class QuestionValidationIssue {
  const QuestionValidationIssue(this.code, this.message);

  final String code;
  final String message;
}

/// Result of validating the complete public question revision and its private
/// answer key. Catalog references are added by [PublishableQuestionRepo],
/// because they require Firestore reads.
class QuestionDraftValidation {
  const QuestionDraftValidation(this.issues);

  final List<QuestionValidationIssue> issues;

  bool get isPublishable => issues.isEmpty;
}

class QuestionPublicationException implements Exception {
  const QuestionPublicationException(this.validation);

  final QuestionDraftValidation validation;

  @override
  String toString() =>
      validation.issues.map((issue) => issue.message).join('\n');
}

/// Pure validation for every field that travels in the v2 question contract.
/// Keeping it independent of the UI makes the publishing transaction and the
/// draft error view apply the exact same content rules.
class QuestionPublicationValidator {
  QuestionPublicationValidator._();

  static QuestionDraftValidation validate({
    required QuestionDocument question,
    required QuestionAnswerKey? answerKey,
  }) {
    final issues = <QuestionValidationIssue>[];

    if (!_hasContent(question.content)) {
      issues.add(
        const QuestionValidationIssue(
          'statement.empty',
          'Falta el contenido del enunciado.',
        ),
      );
    }
    _validateContent(question.content, 'Enunciado', issues);

    if (question.courseId.isEmpty ||
        question.topicId.isEmpty ||
        question.subtopicId.isEmpty) {
      issues.add(
        const QuestionValidationIssue(
          'classification.incomplete',
          'Falta completar curso, tema y subtema.',
        ),
      );
    }
    if (question.partIds.isEmpty) {
      issues.add(
        const QuestionValidationIssue(
          'classification.parts.empty',
          'Selecciona al menos una parte evaluada.',
        ),
      );
    }
    if (question.partIds.toSet().length != question.partIds.length) {
      issues.add(
        const QuestionValidationIssue(
          'classification.parts.duplicate',
          'Las partes evaluadas no pueden repetirse.',
        ),
      );
    }
    if (question.difficulty == 'unknown') {
      issues.add(
        const QuestionValidationIssue(
          'difficulty.undefined',
          'Define la dificultad de la pregunta.',
        ),
      );
    }

    if (question.sourceType == 'unknown') {
      issues.add(
        const QuestionValidationIssue(
          'source.undefined',
          'Selecciona un tipo y un examen de origen.',
        ),
      );
    }
    if (const {
          'admission_exam',
          'official_practice',
          'other',
        }.contains(question.sourceType) &&
        question.sourceExam == null) {
      issues.add(
        const QuestionValidationIssue(
          'source.exam.missing',
          'El tipo de procedencia seleccionado requiere un examen de origen.',
        ),
      );
    }

    if (question.alternatives.length < 2) {
      issues.add(
        const QuestionValidationIssue(
          'alternatives.minimum',
          'Agrega al menos dos alternativas.',
        ),
      );
    }
    final contents = <String>{};
    for (var index = 0; index < question.alternatives.length; index++) {
      final alternative = question.alternatives[index];
      final label = alternative.label;
      if (!_hasContent(alternative.content)) {
        issues.add(
          QuestionValidationIssue(
            'alternative.$label.empty',
            'La alternativa $label no tiene contenido.',
          ),
        );
      }
      if (!contents.add(jsonEncode(alternative.content.toJson()))) {
        issues.add(
          QuestionValidationIssue(
            'alternative.$label.duplicate',
            'La alternativa $label repite el contenido de otra alternativa.',
          ),
        );
      }
      _validateContent(alternative.content, 'Alternativa $label', issues);
    }

    if (answerKey == null) {
      issues.add(
        const QuestionValidationIssue(
          'answer.missing',
          'Marca exactamente una alternativa correcta.',
        ),
      );
    } else {
      try {
        answerKey.validateAgainst(question);
      } on FormatException {
        issues.add(
          const QuestionValidationIssue(
            'answer.invalid',
            'La respuesta correcta no corresponde a esta versión o alternativa.',
          ),
        );
      }
      if (!_hasContent(answerKey.explanation)) {
        issues.add(
          const QuestionValidationIssue(
            'explanation.empty',
            'Agrega una explicación para la respuesta correcta.',
          ),
        );
      }
      _validateContent(answerKey.explanation, 'Explicación', issues);
    }

    return QuestionDraftValidation(List.unmodifiable(issues));
  }

  static bool hasContent(QuestionContent content) => _hasContent(content);

  static bool _hasContent(QuestionContent content) =>
      content.blocks.any((block) {
        return switch (block) {
          TextBlock block => block.text.trim().isNotEmpty,
          ParagraphBlock block => block.spans.any(
            (span) => span.value.trim().isNotEmpty,
          ),
          FormulaBlock block => block.latex.trim().isNotEmpty,
          ImageBlock _ => true,
          LegacyBlock block => block.raw.trim().isNotEmpty,
        };
      });

  static void _validateContent(
    QuestionContent content,
    String scope,
    List<QuestionValidationIssue> issues,
  ) {
    for (final block in content.blocks) {
      switch (block) {
        case FormulaBlock formula:
          _validateFormula(
            formula.latex,
            '$scope, bloque ${formula.id}',
            issues,
          );
        case ParagraphBlock paragraph:
          for (final span in paragraph.spans) {
            if (span.type == 'formula') {
              _validateFormula(
                span.value,
                '$scope, bloque ${paragraph.id}',
                issues,
              );
            }
          }
        case ImageBlock image:
          if (image.storagePath == null && image.url == null) {
            issues.add(
              QuestionValidationIssue(
                'image.${image.id}.unresolved',
                '$scope: la imagen ${image.id} no tiene una ruta o URL resuelta.',
              ),
            );
          }
        default:
          break;
      }
    }
  }

  static void _validateFormula(
    String latex,
    String scope,
    List<QuestionValidationIssue> issues,
  ) {
    if (latex.trim().isEmpty) {
      issues.add(
        QuestionValidationIssue(
          'formula.empty',
          '$scope contiene una fórmula vacía.',
        ),
      );
      return;
    }
    try {
      TexParser(latex, const TexParserSettings(strict: Strict.error)).parse();
    } catch (_) {
      issues.add(
        QuestionValidationIssue(
          'formula.invalid',
          '$scope contiene una fórmula LaTeX que no se puede interpretar.',
        ),
      );
    }
  }
}
