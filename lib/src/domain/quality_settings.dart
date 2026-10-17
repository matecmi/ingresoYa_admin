/// `{config}/quality`: cuándo una pregunta aparece en «Preguntas a revisar»
/// (docs/question_stats_contract.md). Solo lo usa el admin.
class QualitySettings {
  const QualitySettings({
    this.minAnswers = 20,
    this.failPercent = 90,
    this.dominantWrongPercent = 50,
    this.easyPercent = 95,
    this.deadAlternativeAnswers = 60,
  });

  static const defaults = QualitySettings();

  /// Respuestas mínimas para opinar sobre una pregunta.
  final int minAnswers;

  /// % de error desde el que «casi todos fallan».
  final int failPercent;

  /// % de las respuestas que debe llevarse una alternativa incorrecta para
  /// sospechar de la clave.
  final int dominantWrongPercent;

  /// % de acierto desde el que es «demasiado fácil».
  final int easyPercent;

  /// Respuestas mínimas para decir que nadie elige una alternativa.
  final int deadAlternativeAnswers;

  static int _bounded(Object? v, int fallback, int min, int max) =>
      v is num && v == v.roundToDouble() && v >= min && v <= max
      ? v.toInt()
      : fallback;

  factory QualitySettings.fromMap(Map<String, dynamic>? map) {
    final d = map ?? const <String, dynamic>{};
    const f = defaults;
    return QualitySettings(
      minAnswers: _bounded(d['minAnswers'], f.minAnswers, 5, 500),
      failPercent: _bounded(d['failPercent'], f.failPercent, 50, 100),
      dominantWrongPercent: _bounded(
        d['dominantWrongPercent'],
        f.dominantWrongPercent,
        20,
        100,
      ),
      easyPercent: _bounded(d['easyPercent'], f.easyPercent, 50, 100),
      deadAlternativeAnswers: _bounded(
        d['deadAlternativeAnswers'],
        f.deadAlternativeAnswers,
        10,
        1000,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'minAnswers': minAnswers,
    'failPercent': failPercent,
    'dominantWrongPercent': dominantWrongPercent,
    'easyPercent': easyPercent,
    'deadAlternativeAnswers': deadAlternativeAnswers,
  };

  String? validate() {
    if (minAnswers < 5 || minAnswers > 500) {
      return 'Respuestas mínimas: entre 5 y 500.';
    }
    if (failPercent < 50 || failPercent > 100) {
      return '«Casi todos fallan»: entre 50 y 100 %.';
    }
    if (dominantWrongPercent < 20 || dominantWrongPercent > 100) {
      return 'Alternativa que atrae: entre 20 y 100 %.';
    }
    if (easyPercent < 50 || easyPercent > 100) {
      return '«Demasiado fácil»: entre 50 y 100 %.';
    }
    if (deadAlternativeAnswers < 10 || deadAlternativeAnswers > 1000) {
      return 'Respuestas para «nadie la elige»: entre 10 y 1000.';
    }
    return null;
  }
}
