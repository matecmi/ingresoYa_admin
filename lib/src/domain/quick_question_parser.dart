import '../../shared/question_contract/question_contract.dart';

/// Pregunta reconocida en un texto pegado (carga rápida, tablero 15).
class ParsedQuestion {
  const ParsedQuestion({
    required this.statement,
    required this.alternatives,
    this.correctIndex,
    this.explanation = '',
  });

  final String statement;
  final List<String> alternatives;

  /// Índice de la alternativa correcta si el texto traía «Clave: B».
  final int? correctIndex;
  final String explanation;

  static const empty = ParsedQuestion(statement: '', alternatives: []);

  bool get isEmpty => statement.isEmpty && alternatives.isEmpty;
}

/// Letra de una alternativa por posición (A, B, C…).
String alternativeLabel(int index) => String.fromCharCode(65 + index);

final _keyLine = RegExp(
  r'^\s*(?:clave|rpta|respuesta|resp|correcta)\s*[:.\-=]?\s*\(?([a-e])\)?\s*\.?\s*$',
  caseSensitive: false,
  multiLine: true,
);

final _explanationStart = RegExp(
  r'^\s*(?:soluci[oó]n|explicaci[oó]n|resoluci[oó]n)\s*[:.\-]?\s*',
  caseSensitive: false,
  multiLine: true,
);

final _marker = RegExp(r'(^|[\s])\(?([A-Ea-e])\s?[\)\.]\s*', multiLine: true);

class _Mark {
  _Mark(this.start, this.end, this.letter, this.lineStart);
  final int start;
  final int end;
  final int letter;
  final bool lineStart;
}

/// Separa enunciado, alternativas (a) b) c)…, A. B. …, (a) (b)…), la clave
/// («Clave: B», «Rpta: c») y la explicación («Solución: …»).
ParsedQuestion parseQuickQuestion(String raw) {
  var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
  if (text.isEmpty) return ParsedQuestion.empty;

  int? correct;
  final key = _keyLine.allMatches(text).lastOrNull;
  if (key != null) {
    correct = key.group(1)!.toLowerCase().codeUnitAt(0) - 97;
    text = (text.substring(0, key.start) + text.substring(key.end)).trim();
  }

  var explanation = '';
  final exp = _explanationStart.firstMatch(text);
  if (exp != null) {
    explanation = text.substring(exp.end).trim();
    text = text.substring(0, exp.start).trim();
  }

  final marks = <_Mark>[];
  for (final m in _marker.allMatches(text)) {
    final prefix = m.group(1) ?? '';
    final start = m.start + prefix.length;
    final lineStart = start == 0 || text[start - 1] == '\n';
    marks.add(
      _Mark(
        start,
        m.end,
        m.group(2)!.toLowerCase().codeUnitAt(0) - 97,
        lineStart,
      ),
    );
  }

  List<_Mark> chainFrom(int i, bool onlyLineStart) {
    final chain = [marks[i]];
    for (var j = i + 1; j < marks.length; j++) {
      final m = marks[j];
      if (onlyLineStart && !m.lineStart) continue;
      if (m.letter == chain.last.letter + 1) chain.add(m);
    }
    return chain;
  }

  List<_Mark> best = const [];
  for (final onlyLineStart in [true, false]) {
    for (var i = 0; i < marks.length; i++) {
      if (marks[i].letter != 0) continue;
      if (onlyLineStart && !marks[i].lineStart) continue;
      final chain = chainFrom(i, onlyLineStart);
      if (chain.length >= best.length) best = chain;
    }
    if (best.length >= 2) break;
  }

  if (best.length < 2) {
    return ParsedQuestion(
      statement: text,
      alternatives: const [],
      correctIndex: correct,
      explanation: explanation,
    );
  }

  final statement = text.substring(0, best.first.start).trim();
  final alternatives = <String>[
    for (var i = 0; i < best.length; i++)
      text
          .substring(
            best[i].end,
            i + 1 < best.length ? best[i + 1].start : text.length,
          )
          .trim(),
  ];
  return ParsedQuestion(
    statement: statement,
    alternatives: alternatives,
    correctIndex: correct != null && correct < alternatives.length
        ? correct
        : null,
    explanation: explanation,
  );
}

/// Contenido v2 desde texto: una línea por bloque; `$…$` es una fórmula.
QuestionContent contentFromPlainText(String text, String idPrefix) {
  final blocks = <Map<String, Object>>[];
  final lines = text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final id = '$idPrefix-$i';
    if (!line.contains(r'$')) {
      blocks.add({'id': id, 'type': 'text', 'text': line});
      continue;
    }
    final spans = <Map<String, Object>>[];
    final parts = line.split(r'$');
    for (var p = 0; p < parts.length; p++) {
      final value = parts[p];
      if (value.isEmpty) continue;
      // Partes impares estaban entre `$`; si el `$` quedó sin cerrar, texto.
      final formula = p.isOdd && p < parts.length - 1;
      spans.add(
        formula
            ? {'type': 'formula', 'latex': value.trim()}
            : {'type': 'text', 'text': value},
      );
    }
    blocks.add({'id': id, 'type': 'paragraph', 'spans': spans});
  }
  return QuestionContent.fromJson(blocks);
}

/// Palabras para comparar enunciados (sin tildes, minúsculas, ≥ 2 letras).
Set<String> similarityTokens(String text) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  final lower = text.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return RegExp(
    r'[a-z0-9]{2,}',
  ).allMatches(buffer.toString()).map((m) => m.group(0)!).toSet();
}

/// Parecido entre 0 y 1 (Jaccard de palabras).
double statementSimilarity(Set<String> a, Set<String> b) {
  if (a.length < 4 || b.length < 4) return 0;
  final inter = a.intersection(b).length;
  return inter / (a.length + b.length - inter);
}
