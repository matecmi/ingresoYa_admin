import 'quick_question_parser.dart';

/// Una pregunta reconocida al pegar un examen completo (tablero 9).
class ImportedQuestion {
  const ImportedQuestion({
    required this.number,
    required this.raw,
    required this.parsed,
    required this.issues,
  });

  /// Número en el examen original («25.»).
  final int number;
  final String raw;
  final ParsedQuestion parsed;

  /// Qué revisar antes de publicarla.
  final List<String> issues;

  bool get ready => issues.isEmpty;

  ImportedQuestion withCorrect(int index) => ImportedQuestion(
    number: number,
    raw: raw,
    parsed: ParsedQuestion(
      statement: parsed.statement,
      alternatives: parsed.alternatives,
      correctIndex: index,
      explanation: parsed.explanation,
    ),
    issues: issues.where((i) => !i.startsWith('Falta la clave')).toList(),
  );
}

class ImportResult {
  const ImportResult({
    required this.questions,
    required this.keyFound,
    required this.expectedAlternatives,
  });

  final List<ImportedQuestion> questions;

  /// Se encontró una tabla de claves («1. C 2. B …»).
  final bool keyFound;

  /// Cuántas alternativas tiene la mayoría (para avisar si a una le faltan).
  final int expectedAlternatives;

  int get ready => questions.where((q) => q.ready).length;
  int get toReview => questions.length - ready;
}

final _questionStart = RegExp(
  r'^\s*(?:pregunta\s*)?(\d{1,3})\s*[.)\-–:]\s+',
  caseSensitive: false,
  multiLine: true,
);

final _keyHeading = RegExp(
  r'^\s*(?:clave(?:s)?(?: de respuestas)?|respuestas|solucionario|hoja de respuestas)\s*:?\s*$',
  caseSensitive: false,
  multiLine: true,
);

final _keyPair = RegExp(
  r'(\d{1,3})\s*[.)\-:–]?\s*\(?([A-Ea-e])\)?(?![a-zA-Z])',
);

final _figure = RegExp(
  r'\b(figura|gr[aá]fico|gr[aá]fica|imagen|dibujo|cuadro adjunto|diagrama)\b',
  caseSensitive: false,
);

/// Lee un examen pegado: preguntas numeradas, sus alternativas y, si existe,
/// la tabla de claves del final.
ImportResult parseExam(String text) {
  var body = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final keys = <int, int>{};

  final heading = _keyHeading.allMatches(body).lastOrNull;
  if (heading != null) {
    final tail = body.substring(heading.end);
    for (final m in _keyPair.allMatches(tail)) {
      keys[int.parse(m.group(1)!)] =
          m.group(2)!.toLowerCase().codeUnitAt(0) - 97;
    }
    body = body.substring(0, heading.start);
  }

  final starts = _questionStart.allMatches(body).toList();
  // Solo números que avanzan: «2)» dentro de un enunciado no corta la pregunta.
  final picked = <RegExpMatch>[];
  for (final m in starts) {
    final n = int.parse(m.group(1)!);
    if (picked.isEmpty || n == int.parse(picked.last.group(1)!) + 1) {
      picked.add(m);
    } else if (picked.length == 1 && n > int.parse(picked.last.group(1)!)) {
      picked
        ..clear()
        ..add(m);
    }
  }

  final questions = <ImportedQuestion>[];
  for (var i = 0; i < picked.length; i++) {
    final m = picked[i];
    final end = i + 1 < picked.length ? picked[i + 1].start : body.length;
    final raw = body.substring(m.end, end).trim();
    final number = int.parse(m.group(1)!);
    var parsed = parseQuickQuestion(raw);
    final key = keys[number];
    if (key != null && key < parsed.alternatives.length) {
      parsed = ParsedQuestion(
        statement: parsed.statement,
        alternatives: parsed.alternatives,
        correctIndex: key,
        explanation: parsed.explanation,
      );
    }
    questions.add(
      ImportedQuestion(number: number, raw: raw, parsed: parsed, issues: []),
    );
  }

  final counts = <int, int>{};
  for (final q in questions) {
    final n = q.parsed.alternatives.length;
    if (n >= 2) counts[n] = (counts[n] ?? 0) + 1;
  }
  final expected = counts.isEmpty
      ? 5
      : counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

  final withIssues = [
    for (final q in questions)
      ImportedQuestion(
        number: q.number,
        raw: q.raw,
        parsed: q.parsed,
        issues: [
          if (q.parsed.statement.isEmpty) 'No se reconoció el enunciado.',
          if (q.parsed.alternatives.length < expected)
            'Solo se detectaron ${q.parsed.alternatives.length} alternativas '
                '(${q.parsed.alternatives.length < expected ? 'falta la ${alternativeLabel(q.parsed.alternatives.length)}' : ''}).',
          if (q.parsed.alternatives.any((a) => a.isEmpty))
            'Hay una alternativa vacía.',
          if (_figure.hasMatch(q.parsed.statement))
            'Tiene una figura: súbela con el editor completo después de importar.',
          if (q.parsed.correctIndex == null) 'Falta la clave: márcala aquí.',
        ],
      ),
  ];
  return ImportResult(
    questions: withIssues,
    keyFound: keys.isNotEmpty,
    expectedAlternatives: expected,
  );
}
