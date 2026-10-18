/// `{config}/exam`: cómo la app guarda respuestas durante un examen
/// (docs/exam_config_contract.md). Mismos campos y límites que `ExamSettings`
/// en iya-app. La Fase 3C de costos suma aquí los límites de selección de
/// preguntas de las Functions.
class ExamSettings {
  const ExamSettings({this.saveEveryAnswers = 5, this.saveEverySeconds = 30});

  static const defaults = ExamSettings();

  static const minSaveEveryAnswers = 1;
  static const maxSaveEveryAnswers = 20;
  static const minSaveEverySeconds = 5;
  static const maxSaveEverySeconds = 300;

  /// Respuestas nuevas que acumula la app antes de guardarlas en el servidor.
  /// 1 = como antes (una llamada por respuesta).
  final int saveEveryAnswers;

  /// Segundos como máximo entre un cambio y su guardado, aunque no se llegue
  /// a [saveEveryAnswers]. Al pausar o salir siempre se guarda.
  final int saveEverySeconds;

  factory ExamSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    int number(String key, int fallback) {
      final value = data[key];
      return value is num ? value.toInt() : fallback;
    }

    return ExamSettings(
      saveEveryAnswers: number('saveEveryAnswers', defaults.saveEveryAnswers),
      saveEverySeconds: number('saveEverySeconds', defaults.saveEverySeconds),
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'saveEveryAnswers': saveEveryAnswers,
    'saveEverySeconds': saveEverySeconds,
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
    return null;
  }
}
