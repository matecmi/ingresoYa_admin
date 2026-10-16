/// `{config}/rankings` (docs/rankings_contract.md §2): usernames, weekly
/// league and daily challenge. Off by default until there are enough
/// students. Same parsing as Functions and the app.
class RankingsSettings {
  const RankingsSettings({
    this.enabled = false,
    this.startWeek = '',
    this.bannedWords = const [],
    this.stageNames = defaultStageNames,
    this.groupSize = 30,
    this.promotePercent = 15,
    this.demotePercent = 15,
    this.minGroupForDemotion = 5,
    this.preferSameUniversity = false,
    this.showWeekPositions = true,
    this.weekMinCareerPlayers = 5,
    this.challengeEnabled = true,
    this.questionCount = 10,
    this.minutes = 15,
    this.bonusXp = 20,
    this.ownPastExamQuestions = 6,
    this.noRepeatDays = 30,
    this.challengeMinCareerPlayers = 5,
  });

  static const defaultStageNames = [
    'Aspirante',
    'Postulante',
    'Finalista',
    'Ingresante',
  ];

  static const defaults = RankingsSettings();

  final bool enabled;
  final String startWeek;
  final List<String> bannedWords;
  final List<String> stageNames;
  final int groupSize;
  final int promotePercent;
  final int demotePercent;
  final int minGroupForDemotion;
  final bool preferSameUniversity;
  final bool showWeekPositions;
  final int weekMinCareerPlayers;
  final bool challengeEnabled;
  final int questionCount;
  final int minutes;
  final int bonusXp;
  final int ownPastExamQuestions;
  final int noRepeatDays;
  final int challengeMinCareerPlayers;

  static int _bounded(Object? value, int fallback, int min, int max) =>
      value is num &&
          value == value.roundToDouble() &&
          value >= min &&
          value <= max
      ? value.toInt()
      : fallback;

  factory RankingsSettings.fromMap(Map<String, dynamic>? map) {
    final data = map ?? const <String, dynamic>{};
    final league = data['league'] is Map ? data['league'] as Map : const {};
    final challenge = data['challenge'] is Map
        ? data['challenge'] as Map
        : const {};
    const d = defaults;
    bool flag(Object? v, bool fallback) => v is bool ? v : fallback;
    final names = league['stageNames'] is List
        ? [
            for (final name in league['stageNames'] as List)
              if (name is String && name.trim().isNotEmpty) name.trim(),
          ]
        : const <String>[];
    final start = data['startWeek'];
    final words = data['bannedWords'];
    final questions = _bounded(
      challenge['questionCount'],
      d.questionCount,
      3,
      30,
    );
    return RankingsSettings(
      enabled: flag(data['enabled'], false),
      startWeek:
          start is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(start)
          ? start
          : '',
      bannedWords: words is List
          ? [
              for (final word in words)
                if (word is String && word.trim().length >= 2)
                  word.trim().toLowerCase(),
            ]
          : const [],
      stageNames: names.length >= 2 && names.length <= 8
          ? names
          : defaultStageNames,
      groupSize: _bounded(league['groupSize'], d.groupSize, 5, 100),
      promotePercent: _bounded(
        league['promotePercent'],
        d.promotePercent,
        0,
        50,
      ),
      demotePercent: _bounded(league['demotePercent'], d.demotePercent, 0, 50),
      minGroupForDemotion: _bounded(
        league['minGroupForDemotion'],
        d.minGroupForDemotion,
        1,
        100,
      ),
      preferSameUniversity: flag(league['preferSameUniversity'], false),
      showWeekPositions: flag(league['showWeekPositions'], true),
      weekMinCareerPlayers: _bounded(
        league['minCareerPlayers'],
        d.weekMinCareerPlayers,
        1,
        1000,
      ),
      challengeEnabled: flag(challenge['enabled'], true),
      questionCount: questions,
      minutes: _bounded(challenge['minutes'], d.minutes, 3, 120),
      bonusXp: _bounded(challenge['bonusXp'], d.bonusXp, 0, 1000),
      ownPastExamQuestions: _bounded(
        challenge['ownPastExamQuestions'],
        d.ownPastExamQuestions,
        0,
        30,
      ).clamp(0, questions),
      noRepeatDays: _bounded(challenge['noRepeatDays'], d.noRepeatDays, 0, 365),
      challengeMinCareerPlayers: _bounded(
        challenge['minCareerPlayers'],
        d.challengeMinCareerPlayers,
        1,
        1000,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    if (startWeek.isNotEmpty) 'startWeek': startWeek,
    'bannedWords': bannedWords,
    'league': {
      'stageNames': stageNames,
      'groupSize': groupSize,
      'promotePercent': promotePercent,
      'demotePercent': demotePercent,
      'minGroupForDemotion': minGroupForDemotion,
      'preferSameUniversity': preferSameUniversity,
      'showWeekPositions': showWeekPositions,
      'minCareerPlayers': weekMinCareerPlayers,
    },
    'challenge': {
      'enabled': challengeEnabled,
      'questionCount': questionCount,
      'minutes': minutes,
      'bonusXp': bonusXp,
      'ownPastExamQuestions': ownPastExamQuestions,
      'noRepeatDays': noRepeatDays,
      'minCareerPlayers': challengeMinCareerPlayers,
    },
  };

  RankingsSettings copyWith({bool? enabled, String? startWeek}) =>
      RankingsSettings.fromMap({
        ...toMap(),
        'enabled': enabled ?? this.enabled,
        'startWeek': startWeek ?? this.startWeek,
      });

  String? validate() {
    if (stageNames.length < 2 || stageNames.length > 8) {
      return 'Las etapas deben ser de 2 a 8.';
    }
    if (stageNames.any((name) => name.trim().isEmpty)) {
      return 'Cada etapa necesita un nombre.';
    }
    if (groupSize < 5 || groupSize > 100) {
      return 'Alumnos por grupo: entre 5 y 100.';
    }
    if (promotePercent > 50 || demotePercent > 50) {
      return 'Los que suben o bajan: como máximo 50 %.';
    }
    if (minGroupForDemotion < 1 || minGroupForDemotion > 100) {
      return 'Tamaño mínimo para bajar: entre 1 y 100.';
    }
    if (questionCount < 3 || questionCount > 30) {
      return 'Preguntas del reto: entre 3 y 30.';
    }
    if (ownPastExamQuestions > questionCount) {
      return 'Las preguntas de exámenes pasados propios no pueden ser más que las del reto.';
    }
    if (minutes < 3 || minutes > 120) {
      return 'Minutos del reto: entre 3 y 120.';
    }
    if (bonusXp > 1000) return 'Bono del reto: hasta 1000 XP.';
    if (noRepeatDays > 365) return 'No repetir preguntas: hasta 365 días.';
    return null;
  }
}

/// Monday (`YYYY-MM-DD`) of the Peru week after [now]: the league starts on
/// a full week when the admin turns rankings on.
String nextPeruMonday(DateTime now) {
  final lima = now.toUtc().subtract(const Duration(hours: 5));
  final today = DateTime.utc(lima.year, lima.month, lima.day);
  final next = today.add(Duration(days: 8 - today.weekday));
  return next.toIso8601String().substring(0, 10);
}

/// Monday (`YYYY-MM-DD`) of the current Peru week.
String currentPeruMonday(DateTime now) {
  final lima = now.toUtc().subtract(const Duration(hours: 5));
  final today = DateTime.utc(lima.year, lima.month, lima.day);
  return today
      .subtract(Duration(days: today.weekday - 1))
      .toIso8601String()
      .substring(0, 10);
}
