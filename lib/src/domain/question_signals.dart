import 'quality_settings.dart';

/// Lo que respondieron los alumnos a una versión de una pregunta
/// (`iya-question-stats-{env}/{questionId}_{version}`).
class QuestionStat {
  const QuestionStat({
    required this.id,
    required this.questionId,
    required this.version,
    required this.answered,
    required this.blank,
    required this.correct,
    required this.byAlternative,
    required this.labels,
    required this.correctAlternativeId,
    this.reviewedAnswered,
    this.reviewedBy,
  });

  final String id;
  final String questionId;
  final int version;
  final int answered;
  final int blank;
  final int correct;
  final Map<String, int> byAlternative;
  final Map<String, String> labels;
  final String correctAlternativeId;

  /// «Está bien así»: con cuántas respuestas se revisó.
  final int? reviewedAnswered;
  final String? reviewedBy;

  int percentOf(String alternativeId) => answered == 0
      ? 0
      : ((byAlternative[alternativeId] ?? 0) * 100 / answered).round();

  int get correctPercent =>
      answered == 0 ? 0 : (correct * 100 / answered).round();

  /// Alternativas en orden de su letra.
  List<String> get alternativeIds {
    final ids = {...labels.keys, ...byAlternative.keys}.toList()
      ..sort((a, b) => (labels[a] ?? a).compareTo(labels[b] ?? b));
    return ids;
  }

  String label(String id) => labels[id] ?? '?';

  /// Se marcó como revisada y no cambió mucho desde entonces.
  bool get reviewedRecently =>
      reviewedAnswered != null && answered < reviewedAnswered! * 1.5;

  factory QuestionStat.fromMap(String id, Map<String, dynamic> d) {
    int n(Object? v) => v is num ? v.toInt() : 0;
    final review = d['review'] is Map ? d['review'] as Map : null;
    return QuestionStat(
      id: id,
      questionId: '${d['questionId'] ?? ''}',
      version: n(d['version']),
      answered: n(d['answered']),
      blank: n(d['blank']),
      correct: n(d['correct']),
      byAlternative: {
        for (final e in ((d['byAlternative'] as Map?) ?? const {}).entries)
          '${e.key}': n(e.value),
      },
      labels: {
        for (final e in ((d['labels'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
      correctAlternativeId: '${d['correctAlternativeId'] ?? ''}',
      reviewedAnswered: review == null ? null : n(review['answered']),
      reviewedBy: review == null ? null : '${review['by'] ?? ''}',
    );
  }
}

enum SignalKind {
  wrongKey('Una alternativa equivocada atrae a la mayoría'),
  hard('Casi todos fallan'),
  easy('Demasiado fáciles'),
  deadAlternative('Alternativas que nadie elige');

  const SignalKind(this.label);
  final String label;
}

class QuestionSignal {
  const QuestionSignal(this.kind, this.message);

  final SignalKind kind;
  final String message;
}

/// Señales de una pregunta según lo que respondieron (reglas puras).
List<QuestionSignal> signalsFor(QuestionStat s, QualitySettings q) {
  if (s.answered < q.minAnswers) return const [];
  final out = <QuestionSignal>[];
  final fail = 100 - s.correctPercent;
  if (fail >= q.failPercent) {
    String? top;
    var topPercent = 0;
    for (final id in s.alternativeIds) {
      if (id == s.correctAlternativeId) continue;
      final p = s.percentOf(id);
      if (p > topPercent) {
        topPercent = p;
        top = id;
      }
    }
    if (top != null && topPercent >= q.dominantWrongPercent) {
      out.add(
        QuestionSignal(
          SignalKind.wrongKey,
          'El $fail % la falla y el $topPercent % elige ${s.label(top)}. Es '
          'probable que la clave marcada (${s.label(s.correctAlternativeId)}) '
          'esté mal.',
        ),
      );
    } else {
      out.add(
        QuestionSignal(
          SignalKind.hard,
          'El $fail % la falla, pero las respuestas se reparten: parece '
          'difícil. Revisa si la explicación ayuda.',
        ),
      );
    }
  }
  if (s.correctPercent >= q.easyPercent) {
    out.add(
      QuestionSignal(
        SignalKind.easy,
        'El ${s.correctPercent} % acierta: es muy fácil para un examen de '
        'admisión.',
      ),
    );
  }
  if (s.answered >= q.deadAlternativeAnswers) {
    final dead = [
      for (final id in s.alternativeIds)
        if (id != s.correctAlternativeId && (s.byAlternative[id] ?? 0) == 0)
          s.label(id),
    ];
    if (dead.isNotEmpty) {
      out.add(
        QuestionSignal(
          SignalKind.deadAlternative,
          'Nadie elige ${dead.join(', ')}: esa alternativa no distrae.',
        ),
      );
    }
  }
  return out;
}
