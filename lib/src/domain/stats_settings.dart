/// `{config}/stats`: cómo arma la app la pestaña Estadísticas
/// (docs/stats_contract.md). Mismos campos y límites que `StatsSettings` en
/// iya-app.
class StatsSettings {
  const StatsSettings({
    this.insightsEnabled = true,
    this.storiesEnabled = true,
    this.insightMinQuestions = 20,
    this.insightMinGapPoints = 10,
    this.blankWarnPercent = 25,
    this.fastPacePercent = 50,
    this.projectionMinDays = 7,
    this.focusCourses = 3,
    this.calendarWeeks = 12,
  });

  static const defaults = StatsSettings();

  static const minInsightQuestions = 5;
  static const maxInsightQuestions = 200;
  static const minGapPoints = 1;
  static const maxGapPoints = 50;
  static const minBlankPercent = 5;
  static const maxBlankPercent = 90;
  static const minFastPercent = 10;
  static const maxFastPercent = 90;
  static const minProjectionDays = 3;
  static const maxProjectionDays = 60;
  static const minFocusCourses = 1;
  static const maxFocusCourses = 5;
  static const minCalendarWeeks = 4;
  static const maxCalendarWeeks = 26;

  /// «El búho te dice»: hallazgos sobre cómo estudia el alumno.
  final bool insightsEnabled;

  /// Burbujas con las historias de la semana.
  final bool storiesEnabled;

  /// Preguntas que necesita cada grupo (franja, curso, mitad) antes de que el
  /// búho saque una conclusión.
  final int insightMinQuestions;

  /// Diferencia de acierto, en puntos, para hablar de «mejor hora» o de un
  /// curso que subió.
  final int insightMinGapPoints;

  /// Porcentaje de preguntas en blanco de un curso que dispara el aviso.
  final int blankWarnPercent;

  /// Si el alumno usa menos de este porcentaje del tiempo que da el examen
  /// por pregunta, el búho le dice que va muy rápido.
  final int fastPacePercent;

  /// Días de historia que necesita la proyección al día del examen.
  final int projectionMinDays;

  /// Cursos de «Lo que más te acerca a» la carrera del alumno.
  final int focusCourses;

  /// Semanas del calendario «Tus días de estudio».
  final int calendarWeeks;

  factory StatsSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    int number(String key, int fallback) {
      final value = data[key];
      return value is num ? value.toInt() : fallback;
    }

    return StatsSettings(
      insightsEnabled: data['insightsEnabled'] != false,
      storiesEnabled: data['storiesEnabled'] != false,
      insightMinQuestions: number(
        'insightMinQuestions',
        defaults.insightMinQuestions,
      ),
      insightMinGapPoints: number(
        'insightMinGapPoints',
        defaults.insightMinGapPoints,
      ),
      blankWarnPercent: number('blankWarnPercent', defaults.blankWarnPercent),
      fastPacePercent: number('fastPacePercent', defaults.fastPacePercent),
      projectionMinDays: number(
        'projectionMinDays',
        defaults.projectionMinDays,
      ),
      focusCourses: number('focusCourses', defaults.focusCourses),
      calendarWeeks: number('calendarWeeks', defaults.calendarWeeks),
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'insightsEnabled': insightsEnabled,
    'storiesEnabled': storiesEnabled,
    'insightMinQuestions': insightMinQuestions,
    'insightMinGapPoints': insightMinGapPoints,
    'blankWarnPercent': blankWarnPercent,
    'fastPacePercent': fastPacePercent,
    'projectionMinDays': projectionMinDays,
    'focusCourses': focusCourses,
    'calendarWeeks': calendarWeeks,
  };

  /// El primer problema, en español para el editor, o `null` si está bien.
  String? validate() {
    String? range(String label, int value, int min, int max) =>
        value < min || value > max ? '$label: entre $min y $max.' : null;
    return range(
          'Preguntas para un hallazgo',
          insightMinQuestions,
          minInsightQuestions,
          maxInsightQuestions,
        ) ??
        range(
          'Diferencia para un hallazgo',
          insightMinGapPoints,
          minGapPoints,
          maxGapPoints,
        ) ??
        range(
          'Aviso de preguntas en blanco',
          blankWarnPercent,
          minBlankPercent,
          maxBlankPercent,
        ) ??
        range(
          'Aviso de ritmo rápido',
          fastPacePercent,
          minFastPercent,
          maxFastPercent,
        ) ??
        range(
          'Días para proyectar',
          projectionMinDays,
          minProjectionDays,
          maxProjectionDays,
        ) ??
        range(
          'Cursos que más acercan',
          focusCourses,
          minFocusCourses,
          maxFocusCourses,
        ) ??
        range(
          'Semanas del calendario',
          calendarWeeks,
          minCalendarWeeks,
          maxCalendarWeeks,
        );
  }
}
