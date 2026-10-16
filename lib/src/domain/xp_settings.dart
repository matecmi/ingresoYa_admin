/// `{config}/xp`: rank ladder, XP per event and limits (docs/xp_contract.md).
/// Same defaults and fallbacks as `functions/src/xp.ts`.
library;

/// Badge images bundled in the student app (`assets/ranks/{key}.png`).
const rankImages = [
  'bronze_1', 'bronze_6', 'bronze_12', //
  'silver_1', 'silver_6', 'silver_12',
  'platinum_1', 'platinum_6', 'platinum_12',
  'sapphire_1', 'sapphire_6', 'sapphire_12',
  'amethyst_1', 'amethyst_6', 'amethyst_12',
  'master_1', 'master_6', 'master_12',
];

class RankStep {
  const RankStep({
    required this.name,
    required this.minXp,
    required this.image,
  });

  final String name;
  final int minXp;
  final String image;

  Map<String, dynamic> toMap() => {
    'name': name,
    'minXp': minXp,
    'image': image,
  };
}

/// Event keys of `amounts`, with their admin label and factory XP.
const xpAmountFields = <(String, String, int)>[
  ('sectionReviewed', 'Sección de la guía revisada', 2),
  ('partPassed', 'Parte aprobada', 40),
  ('subtopicCompleted', 'Subtema completado (plata)', 80),
  ('subtopicMastered', 'Subtema dominado (oro)', 150),
  ('simulatorSession', 'Sesión del Simulador', 10),
  ('correctAnswer', 'Respuesta correcta nueva', 1),
  ('diagnostic', 'Diagnóstico inicial', 30),
  ('pastExamCompleted', 'Examen pasado completo', 50),
  ('improvementPer10', 'Mejora de mejor puntaje (por cada 10 pts)', 1),
  ('improvementMax', 'Mejora de mejor puntaje (máximo)', 50),
  ('weeklyGoal', 'Meta semanal cumplida', 50),
  ('streakDay', 'Día de racha', 5),
];

const _names = ['Bronce', 'Plata', 'Platino', 'Zafiro', 'Amatista', 'Maestro'];
const _minXp = [
  0,
  150,
  350,
  600,
  900,
  1250,
  1650,
  2100,
  2600,
  3200,
  3900,
  4700,
  5600,
  6600,
  7700,
  9000,
  10500,
  12000,
];

class XpSettings {
  const XpSettings({
    required this.ranks,
    this.starsEnabled = true,
    this.xpPerStar = 2000,
    required this.amounts,
    this.dailyCap = 300,
    this.minQuestionsPerSession = 10,
    this.repeatWindowDays = 14,
    this.minSecondsPerQuestion = 5,
    this.pastExamEveryDays = 7,
  });

  final List<RankStep> ranks;
  final bool starsEnabled;
  final int xpPerStar;
  final Map<String, int> amounts;
  final int dailyCap;
  final int minQuestionsPerSession;
  final int repeatWindowDays;
  final int minSecondsPerQuestion;
  final int pastExamEveryDays;

  static final XpSettings defaults = XpSettings(
    ranks: [
      for (var i = 0; i < rankImages.length; i++)
        RankStep(
          name: '${_names[i ~/ 3]} ${['I', 'II', 'III'][i % 3]}',
          minXp: _minXp[i],
          image: rankImages[i],
        ),
    ],
    amounts: {for (final (key, _, value) in xpAmountFields) key: value},
  );

  static int _bounded(Object? value, int fallback, int min, int max) =>
      value is num &&
          value == value.roundToDouble() &&
          value >= min &&
          value <= max
      ? value.toInt()
      : fallback;

  static List<RankStep> _ranks(Object? value) {
    if (value is! List || value.isEmpty || value.length > 40) {
      return defaults.ranks;
    }
    final ranks = <RankStep>[];
    for (final item in value) {
      if (item is! Map) return defaults.ranks;
      final name = item['name'], minXp = item['minXp'], image = item['image'];
      if (name is! String ||
          name.trim().isEmpty ||
          minXp is! num ||
          minXp != minXp.roundToDouble() ||
          image is! String ||
          !rankImages.contains(image)) {
        return defaults.ranks;
      }
      ranks.add(
        RankStep(name: name.trim(), minXp: minXp.toInt(), image: image),
      );
    }
    return validateRanks(ranks) == null ? ranks : defaults.ranks;
  }

  factory XpSettings.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    final rawAmounts = data['amounts'] is Map
        ? data['amounts'] as Map
        : const {};
    final d = defaults;
    return XpSettings(
      ranks: _ranks(data['ranks']),
      starsEnabled: data['starsEnabled'] is bool
          ? data['starsEnabled'] as bool
          : d.starsEnabled,
      xpPerStar: _bounded(data['xpPerStar'], d.xpPerStar, 100, 100000),
      amounts: {
        for (final (key, _, value) in xpAmountFields)
          key: _bounded(rawAmounts[key], value, 0, 1000),
      },
      dailyCap: _bounded(data['dailyCap'], d.dailyCap, 0, 100000),
      minQuestionsPerSession: _bounded(
        data['minQuestionsPerSession'],
        d.minQuestionsPerSession,
        1,
        300,
      ),
      repeatWindowDays: _bounded(
        data['repeatWindowDays'],
        d.repeatWindowDays,
        0,
        365,
      ),
      minSecondsPerQuestion: _bounded(
        data['minSecondsPerQuestion'],
        d.minSecondsPerQuestion,
        0,
        600,
      ),
      pastExamEveryDays: _bounded(
        data['pastExamEveryDays'],
        d.pastExamEveryDays,
        0,
        365,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'ranks': [for (final rank in ranks) rank.toMap()],
    'starsEnabled': starsEnabled,
    'xpPerStar': xpPerStar,
    'amounts': amounts,
    'dailyCap': dailyCap,
    'minQuestionsPerSession': minQuestionsPerSession,
    'repeatWindowDays': repeatWindowDays,
    'minSecondsPerQuestion': minSecondsPerQuestion,
    'pastExamEveryDays': pastExamEveryDays,
  };

  static String? validateRanks(List<RankStep> ranks) {
    if (ranks.isEmpty) return 'Agrega al menos un rango.';
    if (ranks.first.minXp != 0) return 'El primer rango debe empezar en 0 XP.';
    for (var i = 0; i < ranks.length; i++) {
      if (ranks[i].name.trim().isEmpty) {
        return 'El rango ${i + 1} no tiene nombre.';
      }
      if (!rankImages.contains(ranks[i].image)) {
        return 'El rango ${ranks[i].name} usa una imagen que la app no trae.';
      }
      if (i > 0 && ranks[i].minXp <= ranks[i - 1].minXp) {
        return 'Los umbrales deben ir en orden creciente (revisa ${ranks[i].name}).';
      }
    }
    return null;
  }

  String? validate() {
    final ranksProblem = validateRanks(ranks);
    if (ranksProblem != null) return ranksProblem;
    if (xpPerStar < 100 || xpPerStar > 100000) {
      return 'XP por estrella: entre 100 y 100 000.';
    }
    for (final (key, label, _) in xpAmountFields) {
      final value = amounts[key] ?? -1;
      if (value < 0 || value > 1000) return '$label: entre 0 y 1000 XP.';
    }
    if (dailyCap < 0 || dailyCap > 100000) {
      return 'Tope diario: entre 0 y 100 000.';
    }
    if (minQuestionsPerSession < 1 || minQuestionsPerSession > 300) {
      return 'Mínimo de preguntas por sesión: entre 1 y 300.';
    }
    if (repeatWindowDays < 0 || repeatWindowDays > 365) {
      return 'Días para no repetir: entre 0 y 365.';
    }
    if (minSecondsPerQuestion < 0 || minSecondsPerQuestion > 600) {
      return 'Segundos mínimos por pregunta: entre 0 y 600.';
    }
    if (pastExamEveryDays < 0 || pastExamEveryDays > 365) {
      return 'Examen pasado cada: entre 0 y 365 días.';
    }
    return null;
  }

  /// Index of the highest rank reached with [total] XP.
  int rankStepFor(int total) {
    var step = 0;
    for (var i = 0; i < ranks.length; i++) {
      if (total >= ranks[i].minXp) step = i;
    }
    return step;
  }
}

/// Labels of the XP event types for the admin ledger.
const xpEventLabels = {
  'section_reviewed': 'Sección revisada',
  'part_passed': 'Parte aprobada',
  'subtopic_completed': 'Subtema completado',
  'subtopic_mastered': 'Subtema dominado',
  'simulator_session': 'Sesión del Simulador',
  'correct_answers': 'Respuestas correctas',
  'diagnostic': 'Diagnóstico inicial',
  'past_exam_completed': 'Examen pasado completo',
  'past_exam_improvement': 'Mejora de puntaje',
  'weekly_goal': 'Meta semanal',
  'streak_day': 'Día de racha',
};
