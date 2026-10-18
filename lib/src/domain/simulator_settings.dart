/// One practice size offered in «Arma tu práctica».
class PracticeSize {
  const PracticeSize({
    required this.key,
    required this.label,
    required this.questions,
    required this.minutes,
    this.isDefault = false,
  });

  final String key;
  final String label;
  final int questions;
  final int minutes;
  final bool isDefault;

  static PracticeSize? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final key = (raw['key'] ?? '').toString().trim();
    final label = (raw['label'] ?? '').toString().trim();
    final questions = raw['questions'];
    final minutes = raw['minutes'];
    if (key.isEmpty || label.isEmpty || questions is! num || minutes is! num) {
      return null;
    }
    return PracticeSize(
      key: key,
      label: label,
      questions: questions.toInt(),
      minutes: minutes.toInt(),
      isDefault: raw['default'] == true,
    );
  }

  PracticeSize copyWith({
    String? label,
    int? questions,
    int? minutes,
    bool? isDefault,
  }) => PracticeSize(
    key: key,
    label: label ?? this.label,
    questions: questions ?? this.questions,
    minutes: minutes ?? this.minutes,
    isDefault: isDefault ?? this.isDefault,
  );

  Map<String, dynamic> toMap() => {
    'key': key,
    'label': label,
    'questions': questions,
    'minutes': minutes,
    if (isDefault) 'default': true,
  };
}

/// Simulator settings the app and Functions read from `{config}/simulator`.
/// Fields and defaults are in `docs/simulator_contract.md` §2.
class SimulatorSettings {
  const SimulatorSettings({
    this.practiceSizes = defaultSizes,
    this.practiceTimerDefault = true,
    this.practicePenalty = false,
    this.repeatWindowDays = 14,
    this.defaultSource = 'both',
    this.defaultDifficulty = 'mixed',
    this.showOtherUniversities = true,
    this.onlyCompleteExams = true,
    this.showExplanations = true,
    this.resultsLimit = 60,
    this.topicStatsLimit = 30,
  });

  static const defaults = SimulatorSettings();

  static const defaultSizes = [
    PracticeSize(key: 'short', label: 'Corto', questions: 10, minutes: 15),
    PracticeSize(
      key: 'normal',
      label: 'Normal',
      questions: 20,
      minutes: 30,
      isDefault: true,
    ),
    PracticeSize(key: 'long', label: 'Largo', questions: 40, minutes: 60),
  ];

  static const sources = {
    'both': 'Ambas',
    'real': 'Exámenes reales',
    'original': 'Preguntas IngresoYa',
  };
  static const difficulties = {
    'mixed': 'Mixta',
    'easy': 'Fácil',
    'medium': 'Media',
    'hard': 'Difícil',
  };

  /// Questions per practice: at least 10 (a session that counts) and at most
  /// what one attempt can hold.
  static const minQuestions = 10;
  static const maxQuestions = 100;
  static const maxMinutes = 300;
  static const maxRepeatWindowDays = 365;

  /// Resultados recientes que baja la app (historial, estadísticas, plan).
  static const minResultsLimit = 10;
  static const maxResultsLimit = 200;

  /// Temas con estadística que baja la app para «Hoy te toca».
  static const minTopicStatsLimit = 5;
  static const maxTopicStatsLimit = 200;

  final List<PracticeSize> practiceSizes;
  final bool practiceTimerDefault;
  final bool practicePenalty;
  final int repeatWindowDays;
  final String defaultSource;
  final String defaultDifficulty;
  final bool showOtherUniversities;
  final bool onlyCompleteExams;
  final bool showExplanations;
  final int resultsLimit;
  final int topicStatsLimit;

  factory SimulatorSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    final rawSizes = data['practiceSizes'];
    final sizes = rawSizes is List
        ? rawSizes.map(PracticeSize.fromMap).whereType<PracticeSize>().toList()
        : <PracticeSize>[];
    int number(String key, int fallback) {
      final value = data[key];
      return value is num ? value.toInt() : fallback;
    }

    String option(String key, Map<String, String> allowed, String fallback) {
      final value = data[key];
      return allowed.containsKey(value) ? value as String : fallback;
    }

    return SimulatorSettings(
      practiceSizes: sizes.isEmpty ? defaultSizes : sizes,
      practiceTimerDefault: data['practiceTimerDefault'] != false,
      practicePenalty: data['practicePenalty'] == true,
      repeatWindowDays: number('repeatWindowDays', defaults.repeatWindowDays),
      defaultSource: option('defaultSource', sources, defaults.defaultSource),
      defaultDifficulty: option(
        'defaultDifficulty',
        difficulties,
        defaults.defaultDifficulty,
      ),
      showOtherUniversities: data['showOtherUniversities'] != false,
      onlyCompleteExams: data['onlyCompleteExams'] != false,
      showExplanations: data['showExplanations'] != false,
      resultsLimit: number('resultsLimit', defaults.resultsLimit),
      topicStatsLimit: number('topicStatsLimit', defaults.topicStatsLimit),
    );
  }

  SimulatorSettings copyWith({
    List<PracticeSize>? practiceSizes,
    bool? practiceTimerDefault,
    bool? practicePenalty,
    int? repeatWindowDays,
    String? defaultSource,
    String? defaultDifficulty,
    bool? showOtherUniversities,
    bool? onlyCompleteExams,
    bool? showExplanations,
    int? resultsLimit,
    int? topicStatsLimit,
  }) => SimulatorSettings(
    practiceSizes: practiceSizes ?? this.practiceSizes,
    practiceTimerDefault: practiceTimerDefault ?? this.practiceTimerDefault,
    practicePenalty: practicePenalty ?? this.practicePenalty,
    repeatWindowDays: repeatWindowDays ?? this.repeatWindowDays,
    defaultSource: defaultSource ?? this.defaultSource,
    defaultDifficulty: defaultDifficulty ?? this.defaultDifficulty,
    showOtherUniversities: showOtherUniversities ?? this.showOtherUniversities,
    onlyCompleteExams: onlyCompleteExams ?? this.onlyCompleteExams,
    showExplanations: showExplanations ?? this.showExplanations,
    resultsLimit: resultsLimit ?? this.resultsLimit,
    topicStatsLimit: topicStatsLimit ?? this.topicStatsLimit,
  );

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'practiceSizes': practiceSizes.map((size) => size.toMap()).toList(),
    'practiceTimerDefault': practiceTimerDefault,
    'practicePenalty': practicePenalty,
    'repeatWindowDays': repeatWindowDays,
    'defaultSource': defaultSource,
    'defaultDifficulty': defaultDifficulty,
    'showOtherUniversities': showOtherUniversities,
    'onlyCompleteExams': onlyCompleteExams,
    'showExplanations': showExplanations,
    'resultsLimit': resultsLimit,
    'topicStatsLimit': topicStatsLimit,
  };

  /// The first problem found, in Spanish for the editor, or null when valid.
  String? validate() {
    if (practiceSizes.isEmpty || practiceSizes.length > 5) {
      return 'Define entre 1 y 5 tamaños de práctica.';
    }
    final keys = <String>{};
    for (final size in practiceSizes) {
      if (!keys.add(size.key)) return 'Hay dos tamaños con la misma clave.';
      if (size.label.trim().isEmpty) return 'Cada tamaño necesita un nombre.';
      if (size.questions < minQuestions || size.questions > maxQuestions) {
        return '«${size.label}» debe tener entre $minQuestions y '
            '$maxQuestions preguntas.';
      }
      if (size.minutes < 1 || size.minutes > maxMinutes) {
        return '«${size.label}» debe durar entre 1 y $maxMinutes minutos.';
      }
    }
    if (practiceSizes.where((size) => size.isDefault).length != 1) {
      return 'Marca exactamente un tamaño por defecto.';
    }
    if (repeatWindowDays < 0 || repeatWindowDays > maxRepeatWindowDays) {
      return 'Los días sin repetir deben estar entre 0 y $maxRepeatWindowDays.';
    }
    if (resultsLimit < minResultsLimit || resultsLimit > maxResultsLimit) {
      return 'Resultados que baja la app: entre $minResultsLimit y '
          '$maxResultsLimit.';
    }
    if (topicStatsLimit < minTopicStatsLimit ||
        topicStatsLimit > maxTopicStatsLimit) {
      return 'Temas con estadística: entre $minTopicStatsLimit y '
          '$maxTopicStatsLimit.';
    }
    return null;
  }
}

class SimulatorSettingsRecord {
  const SimulatorSettingsRecord({
    required this.settings,
    required this.exists,
    this.updatedAt,
    this.updatedBy = '',
  });

  final SimulatorSettings settings;

  /// False until the first save: app and Functions use the defaults.
  final bool exists;
  final DateTime? updatedAt;
  final String updatedBy;
}
