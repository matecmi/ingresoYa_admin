import 'quick_question_parser.dart';

/// Dónde va una pregunta en la guía (curso → tema → subtema → parte).
class ClassTarget {
  const ClassTarget({
    required this.courseId,
    required this.courseName,
    required this.topicId,
    required this.topicName,
    required this.subtopicId,
    required this.subtopicName,
    required this.partId,
    required this.partName,
  });

  final String courseId;
  final String courseName;
  final String topicId;
  final String topicName;
  final String subtopicId;
  final String subtopicName;
  final String partId;
  final String partName;

  String get key => '$subtopicId|$partId';

  String get label => [
    courseName,
    subtopicName,
    partName,
  ].where((s) => s.isNotEmpty).join(' · ');
}

/// Sugiere curso, tema, subtema y parte comparando las palabras de la
/// pregunta con las de las preguntas que ya están clasificadas.
class SubtopicClassifier {
  SubtopicClassifier(List<(ClassTarget, String)> examples) {
    for (final (target, text) in examples) {
      final tokens = similarityTokens(text);
      if (tokens.isEmpty) continue;
      _targets[target.key] = target;
      final counts = _counts.putIfAbsent(target.key, () => {});
      for (final t in tokens) {
        counts[t] = (counts[t] ?? 0) + 1;
        _df[t] = (_df[t] ?? 0) + 1;
      }
      _docs++;
    }
  }

  final _targets = <String, ClassTarget>{};
  final _counts = <String, Map<String, int>>{};
  final _df = <String, int>{};
  var _docs = 0;

  bool get isEmpty => _targets.isEmpty;

  /// La mejor coincidencia o `null` si nada se parece.
  ClassTarget? suggest(String text) {
    final tokens = similarityTokens(text);
    if (tokens.isEmpty || _targets.isEmpty) return null;
    String? best;
    var bestScore = 0.0;
    for (final entry in _counts.entries) {
      var score = 0.0;
      final total = entry.value.values.fold(0, (a, b) => a + b);
      for (final t in tokens) {
        final c = entry.value[t];
        if (c == null) continue;
        // Las palabras raras pesan más que las comunes («halle», «valor»).
        final idf = 1 / (1 + (_df[t] ?? 0) / (_docs == 0 ? 1 : _docs));
        score += idf * c / total;
      }
      if (score > bestScore) {
        bestScore = score;
        best = entry.key;
      }
    }
    return best == null ? null : _targets[best];
  }
}
