/// `{config}/exam`: cómo la app guarda respuestas durante un examen
/// (docs/exam_config_contract.md). Mismos campos y límites que `ExamSettings`
/// en iya-app. La Fase 3C de costos suma aquí los límites de selección de
/// preguntas de las Functions.
class ExamSettings {
  const ExamSettings({
    this.saveEveryAnswers = 5,
    this.saveEverySeconds = 30,
    this.candidateStartsPerBlock = 2,
    this.maxCandidatesPerStart = 40,
    this.recentQuestionLimit = 60,
    this.simulatorSeenLimit = 100,
  });

  static const defaults = ExamSettings();

  static const minSaveEveryAnswers = 1;
  static const maxSaveEveryAnswers = 20;
  static const minSaveEverySeconds = 5;
  static const maxSaveEverySeconds = 300;
  static const minCandidateStarts = 1;
  static const maxCandidateStarts = 8;
  static const candidatesPerStartMin = 20;
  static const candidatesPerStartMax = 80;
  static const minRecentQuestions = 1;
  static const maxRecentQuestions = 200;
  static const minSimulatorSeen = 20;
  static const maxSimulatorSeen = 500;

  /// Respuestas nuevas que acumula la app antes de guardarlas en el servidor.
  /// 1 = como antes (una llamada por respuesta).
  final int saveEveryAnswers;

  /// Segundos como máximo entre un cambio y su guardado, aunque no se llegue
  /// a [saveEveryAnswers]. Al pausar o salir siempre se guarda.
  final int saveEverySeconds;

  /// Selección de preguntas en las Functions (Fase 3C): escaneos aleatorios
  /// por bloque al armar un examen de la guía. Más = más variedad y más
  /// lecturas.
  final int candidateStartsPerBlock;

  /// Candidatas que trae cada escaneo (también tope de los pools del
  /// Simulador).
  final int maxCandidatesPerStart;

  /// Preguntas recientes del alumno que se revisan para no repetir en la guía.
  final int recentQuestionLimit;

  /// Preguntas vistas que revisa el Simulador en su ventana de repetición.
  final int simulatorSeenLimit;

  factory ExamSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    int number(String key, int fallback) {
      final value = data[key];
      return value is num ? value.toInt() : fallback;
    }

    return ExamSettings(
      saveEveryAnswers: number('saveEveryAnswers', defaults.saveEveryAnswers),
      saveEverySeconds: number('saveEverySeconds', defaults.saveEverySeconds),
      candidateStartsPerBlock: number(
        'candidateStartsPerBlock',
        defaults.candidateStartsPerBlock,
      ),
      maxCandidatesPerStart: number(
        'maxCandidatesPerStart',
        defaults.maxCandidatesPerStart,
      ),
      recentQuestionLimit: number(
        'recentQuestionLimit',
        defaults.recentQuestionLimit,
      ),
      simulatorSeenLimit: number(
        'simulatorSeenLimit',
        defaults.simulatorSeenLimit,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'saveEveryAnswers': saveEveryAnswers,
    'saveEverySeconds': saveEverySeconds,
    'candidateStartsPerBlock': candidateStartsPerBlock,
    'maxCandidatesPerStart': maxCandidatesPerStart,
    'recentQuestionLimit': recentQuestionLimit,
    'simulatorSeenLimit': simulatorSeenLimit,
  };

  /// El primer problema, en español para el editor, o `null` si está bien.
  String? validate() {
    if (saveEveryAnswers < minSaveEveryAnswers ||
        saveEveryAnswers > maxSaveEveryAnswers) {
      return 'Respuestas por guardado: entre $minSaveEveryAnswers y '
          '$maxSaveEveryAnswers.';
    }
    if (saveEverySeconds < minSaveEverySeconds ||
        saveEverySeconds > maxSaveEverySeconds) {
      return 'Segundos entre guardados: entre $minSaveEverySeconds y '
          '$maxSaveEverySeconds.';
    }
    if (candidateStartsPerBlock < minCandidateStarts ||
        candidateStartsPerBlock > maxCandidateStarts) {
      return 'Escaneos por bloque: entre $minCandidateStarts y '
          '$maxCandidateStarts.';
    }
    if (maxCandidatesPerStart < candidatesPerStartMin ||
        maxCandidatesPerStart > candidatesPerStartMax) {
      return 'Candidatas por escaneo: entre $candidatesPerStartMin y '
          '$candidatesPerStartMax.';
    }
    if (recentQuestionLimit < minRecentQuestions ||
        recentQuestionLimit > maxRecentQuestions) {
      return 'Preguntas recientes revisadas: entre $minRecentQuestions y '
          '$maxRecentQuestions.';
    }
    if (simulatorSeenLimit < minSimulatorSeen ||
        simulatorSeenLimit > maxSimulatorSeen) {
      return 'Preguntas vistas del Simulador: entre $minSimulatorSeen y '
          '$maxSimulatorSeen.';
    }
    return null;
  }
}
