/// Training plan settings, field `plan` of `{config}/simulator`
/// (`docs/simulator_contract.md` §4). The student's own choices (exam month,
/// sessions per week, mock-exam day, reminder) live in their profile.
class PlanSettings {
  const PlanSettings({
    this.sessionOptions = const [3, 5, 7],
    this.recommendedSessions = 5,
    this.dailyQuestions = 10,
    this.dailyMinutes = 15,
    this.weakSharePercent = 60,
    this.weakThresholdPercent = 50,
    this.minAnswersToJudge = 5,
    this.diagnosticPerCourse = 4,
    this.diagnosticMinutes = 30,
    this.showWhy = true,
    this.defaultMockDay = 6,
    this.defaultReminderTime = '19:00',
    this.minQuestionsPerSession = 10,
    this.streakGraceDays = 1,
    this.freeExamsCount = true,
    this.maxPartsPerDay = 3,
  });

  static const defaults = PlanSettings();

  static const weekDays = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
    7: 'Domingo',
  };

  /// Sessions per week the student can choose.
  final List<int> sessionOptions;
  final int recommendedSessions;

  /// «Hoy te toca»: size of the daily session.
  final int dailyQuestions;
  final int dailyMinutes;

  /// Share of the daily session taken from the student's weak topics.
  final int weakSharePercent;

  /// A topic is weak when its accuracy is below this, once it has at least
  /// [minAnswersToJudge] answers.
  final int weakThresholdPercent;
  final int minAnswersToJudge;

  /// First session without history: questions per course and duration.
  final int diagnosticPerCourse;
  final int diagnosticMinutes;
  final bool showWhy;

  /// 1 = Monday … 7 = Sunday.
  final int defaultMockDay;

  /// `HH:mm`, 24 h.
  final String defaultReminderTime;

  /// An exam counts as a session of the week from this many questions.
  final int minQuestionsPerSession;

  /// Days without practice before the streak is lost.
  final int streakGraceDays;

  /// Free exams (not proposed by the plan) also count as sessions.
  final bool freeExamsCount;

  /// «Tu plan de hoy»: never asks for more guide parts per study day.
  final int maxPartsPerDay;

  factory PlanSettings.fromMap(Object? raw) {
    if (raw is! Map) return defaults;
    int number(String key, int fallback) {
      final value = raw[key];
      return value is num ? value.toInt() : fallback;
    }

    final options = raw['sessionOptions'];
    final time = raw['defaultReminderTime'];
    return PlanSettings(
      sessionOptions: options is List && options.every((v) => v is num)
          ? [for (final v in options) (v as num).toInt()]
          : defaults.sessionOptions,
      recommendedSessions: number(
        'recommendedSessions',
        defaults.recommendedSessions,
      ),
      dailyQuestions: number('dailyQuestions', defaults.dailyQuestions),
      dailyMinutes: number('dailyMinutes', defaults.dailyMinutes),
      weakSharePercent: number('weakSharePercent', defaults.weakSharePercent),
      weakThresholdPercent: number(
        'weakThresholdPercent',
        defaults.weakThresholdPercent,
      ),
      minAnswersToJudge: number(
        'minAnswersToJudge',
        defaults.minAnswersToJudge,
      ),
      diagnosticPerCourse: number(
        'diagnosticPerCourse',
        defaults.diagnosticPerCourse,
      ),
      diagnosticMinutes: number(
        'diagnosticMinutes',
        defaults.diagnosticMinutes,
      ),
      showWhy: raw['showWhy'] != false,
      defaultMockDay: number('defaultMockDay', defaults.defaultMockDay),
      defaultReminderTime: time is String && _time.hasMatch(time)
          ? time
          : defaults.defaultReminderTime,
      minQuestionsPerSession: number(
        'minQuestionsPerSession',
        defaults.minQuestionsPerSession,
      ),
      streakGraceDays: number('streakGraceDays', defaults.streakGraceDays),
      freeExamsCount: raw['freeExamsCount'] != false,
      maxPartsPerDay: number('maxPartsPerDay', defaults.maxPartsPerDay),
    );
  }

  static final _time = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  Map<String, dynamic> toMap() => {
    'sessionOptions': sessionOptions,
    'recommendedSessions': recommendedSessions,
    'dailyQuestions': dailyQuestions,
    'dailyMinutes': dailyMinutes,
    'weakSharePercent': weakSharePercent,
    'weakThresholdPercent': weakThresholdPercent,
    'minAnswersToJudge': minAnswersToJudge,
    'diagnosticPerCourse': diagnosticPerCourse,
    'diagnosticMinutes': diagnosticMinutes,
    'showWhy': showWhy,
    'defaultMockDay': defaultMockDay,
    'defaultReminderTime': defaultReminderTime,
    'minQuestionsPerSession': minQuestionsPerSession,
    'streakGraceDays': streakGraceDays,
    'freeExamsCount': freeExamsCount,
    'maxPartsPerDay': maxPartsPerDay,
  };

  /// The first problem, in Spanish for the editor, or null when valid.
  String? validate() {
    if (sessionOptions.isEmpty ||
        sessionOptions.length > 7 ||
        sessionOptions.any((v) => v < 1 || v > 7) ||
        sessionOptions.toSet().length != sessionOptions.length) {
      return 'Las sesiones por semana deben ser de 1 a 7, sin repetir.';
    }
    if (!sessionOptions.contains(recommendedSessions)) {
      return 'Las sesiones recomendadas deben ser una de las opciones.';
    }
    if (dailyQuestions < 5 || dailyQuestions > 40) {
      return 'La sesión del día debe tener entre 5 y 40 preguntas.';
    }
    if (dailyMinutes < 5 || dailyMinutes > 120) {
      return 'La sesión del día debe durar entre 5 y 120 minutos.';
    }
    if (weakSharePercent < 0 || weakSharePercent > 100) {
      return 'La parte de temas débiles va de 0 a 100 %.';
    }
    if (weakThresholdPercent < 1 || weakThresholdPercent > 99) {
      return 'El umbral de tema débil va de 1 a 99 %.';
    }
    if (minAnswersToJudge < 1 || minAnswersToJudge > 50) {
      return 'Las respuestas mínimas por tema van de 1 a 50.';
    }
    if (diagnosticPerCourse < 1 || diagnosticPerCourse > 10) {
      return 'El diagnóstico usa de 1 a 10 preguntas por curso.';
    }
    if (diagnosticMinutes < 5 || diagnosticMinutes > 180) {
      return 'El diagnóstico debe durar entre 5 y 180 minutos.';
    }
    if (!weekDays.containsKey(defaultMockDay)) {
      return 'Elige el día del simulacro semanal.';
    }
    if (!_time.hasMatch(defaultReminderTime)) {
      return 'La hora del recordatorio debe ser HH:mm (24 h).';
    }
    if (minQuestionsPerSession < 1 || minQuestionsPerSession > 100) {
      return 'El mínimo para contar una sesión va de 1 a 100 preguntas.';
    }
    if (streakGraceDays < 0 || streakGraceDays > 7) {
      return 'Los días antes de perder la racha van de 0 a 7.';
    }
    if (maxPartsPerDay < 1 || maxPartsPerDay > 10) {
      return 'Las partes de la guía por día van de 1 a 10.';
    }
    return null;
  }
}
