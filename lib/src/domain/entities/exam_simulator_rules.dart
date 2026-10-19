/// How a past exam is offered in the app's Simulator. Stored in the exam
/// document as `simulator`, apart from the catalog fields, so editing it never
/// changes the exam revision nor rewrites the questions linked to it.
///
/// Score: raw = correct·[correctPoints] + incorrect·[incorrectPoints] +
/// blank·[blankPoints]; shown = max(0, raw) scaled so that answering every
/// question right gives [maxScore]. See docs/simulator_contract.md.
class ExamSimulatorRules {
  const ExamSimulatorRules({
    this.questionCount = 0,
    this.durationMinutes = 60,
    this.maxScore = 1000,
    this.correctPoints = 1,
    this.incorrectPoints = 0,
    this.blankPoints = 0,
    this.questionOrder = 'original',
    this.available = false,
    this.cutoffs = const {},
    this.publishedQuestions = 0,
    this.numberedQuestions = 0,
    this.complete = false,
  });

  factory ExamSimulatorRules.fromJson(Object? raw) {
    if (raw is! Map) return const ExamSimulatorRules();
    num numberOf(String key, num fallback) {
      final value = raw[key];
      return value is num ? value : fallback;
    }

    final cutoffs = <String, int>{};
    final rawCutoffs = raw['cutoffs'];
    if (rawCutoffs is Map) {
      for (final entry in rawCutoffs.entries) {
        final value = entry.value;
        if (value is num) cutoffs[entry.key.toString()] = value.round();
      }
    }
    return ExamSimulatorRules(
      questionCount: numberOf('questionCount', 0).toInt(),
      durationMinutes: numberOf('durationMinutes', 60).toInt(),
      maxScore: numberOf('maxScore', 1000).toInt(),
      correctPoints: numberOf('correctPoints', 1).toDouble(),
      incorrectPoints: numberOf('incorrectPoints', 0).toDouble(),
      blankPoints: numberOf('blankPoints', 0).toDouble(),
      questionOrder: raw['questionOrder'] == 'shuffled'
          ? 'shuffled'
          : 'original',
      available: raw['available'] == true,
      cutoffs: cutoffs,
      publishedQuestions: numberOf('publishedQuestions', 0).toInt(),
      numberedQuestions: numberOf('numberedQuestions', 0).toInt(),
      complete: raw['complete'] == true,
    );
  }

  /// Questions the real exam had.
  final int questionCount;
  final int durationMinutes;
  final int maxScore;
  final double correctPoints;

  /// Zero or negative: points lost per wrong answer.
  final double incorrectPoints;
  final double blankPoints;

  /// `original` follows each question's `originalNumber`; `shuffled` mixes them.
  final String questionOrder;

  /// Offered in the app. Only allowed while [complete].
  final bool available;

  /// Minimum admission score per career (profession id), on [maxScore].
  final Map<String, int> cutoffs;

  /// Computed by the admin when saving: published questions of this exam and
  /// how many carry their number in the original exam.
  final int publishedQuestions;
  final int numberedQuestions;
  final bool complete;

  /// Every question published and, for the original order, numbered.
  static bool isComplete({
    required int questionCount,
    required int publishedQuestions,
    required int numberedQuestions,
    required bool numbersAreUnique,
    required String questionOrder,
  }) =>
      questionCount > 0 &&
      publishedQuestions == questionCount &&
      (questionOrder == 'shuffled' ||
          (numberedQuestions == questionCount && numbersAreUnique));

  /// Spanish message for the first invalid value, or null when valid.
  String? validate() {
    if (questionCount < 1 || questionCount > 100) {
      return 'Las preguntas del examen original deben estar entre 1 y 100.';
    }
    if (durationMinutes < 1 || durationMinutes > 600) {
      return 'La duración debe estar entre 1 y 600 minutos.';
    }
    if (maxScore < 1 || maxScore > 100000) {
      return 'El puntaje máximo debe ser mayor que 0.';
    }
    if (correctPoints <= 0) return 'Cada correcta debe sumar más de 0 puntos.';
    if (incorrectPoints > 0) {
      return 'Una incorrecta no puede sumar: usa 0 o un valor negativo.';
    }
    if (blankPoints < incorrectPoints || blankPoints > correctPoints) {
      return 'En blanco debe estar entre lo de una incorrecta y una correcta.';
    }
    for (final score in cutoffs.values) {
      if (score < 0 || score > maxScore) {
        return 'Cada mínimo de ingreso debe estar entre 0 y $maxScore.';
      }
    }
    return null;
  }

  ExamSimulatorRules copyWith({
    int? questionCount,
    int? durationMinutes,
    int? maxScore,
    double? correctPoints,
    double? incorrectPoints,
    double? blankPoints,
    String? questionOrder,
    bool? available,
    Map<String, int>? cutoffs,
    int? publishedQuestions,
    int? numberedQuestions,
    bool? complete,
  }) => ExamSimulatorRules(
    questionCount: questionCount ?? this.questionCount,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    maxScore: maxScore ?? this.maxScore,
    correctPoints: correctPoints ?? this.correctPoints,
    incorrectPoints: incorrectPoints ?? this.incorrectPoints,
    blankPoints: blankPoints ?? this.blankPoints,
    questionOrder: questionOrder ?? this.questionOrder,
    available: available ?? this.available,
    cutoffs: cutoffs ?? this.cutoffs,
    publishedQuestions: publishedQuestions ?? this.publishedQuestions,
    numberedQuestions: numberedQuestions ?? this.numberedQuestions,
    complete: complete ?? this.complete,
  );

  Map<String, dynamic> toJson() => {
    'questionCount': questionCount,
    'durationMinutes': durationMinutes,
    'maxScore': maxScore,
    'correctPoints': correctPoints,
    'incorrectPoints': incorrectPoints,
    'blankPoints': blankPoints,
    'questionOrder': questionOrder,
    'available': available,
    'cutoffs': cutoffs,
    'publishedQuestions': publishedQuestions,
    'numberedQuestions': numberedQuestions,
    'complete': complete,
  };
}
