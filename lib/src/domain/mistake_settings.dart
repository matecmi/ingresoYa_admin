/// «Mis errores» (banco de errores y misión diaria), campo `mistakes` de
/// `{config}/simulator` (`docs/mistakes_contract.md` §1). Límites iguales a
/// `functions/src/mistake_bank.ts` y a la app.
class MistakeSettings {
  const MistakeSettings({
    this.enabled = true,
    this.missionEnabled = true,
    this.missionSize = 5,
    this.missionXp = 15,
    this.exitHits = 1,
    this.bankMax = 300,
    this.practiceMax = 20,
    this.includeGuide = false,
    this.fixXp = 3,
    this.fixXpDailyCap = 30,
  });

  static const defaults = MistakeSettings();

  static const minMissionSize = 1;
  static const maxMissionSize = 20;
  static const maxMissionXp = 200;
  static const minExitHits = 1;
  static const maxExitHits = 3;
  static const minBankMax = 50;
  static const maxBankMax = 500;
  static const minPracticeMax = 5;
  static const maxPracticeMax = 50;
  static const maxFixXp = 50;
  static const maxFixXpDailyCap = 500;

  final bool enabled;
  final bool missionEnabled;

  /// Errores a corregir en el día para cumplir la misión.
  final int missionSize;
  final int missionXp;

  /// Aciertos seguidos para salir del banco.
  final int exitHits;

  /// Tope del banco por alumno; al llenarse salen las fallas más antiguas.
  final int bankMax;

  /// Lo más largo que se puede practicar de una vez.
  final int practiceMax;

  /// Reservado: sumar los exámenes de la guía (aún no se aplica). Se guarda
  /// tal cual para no perderlo.
  final bool includeGuide;
  final int fixXp;
  final int fixXpDailyCap;

  factory MistakeSettings.fromMap(Object? raw) {
    if (raw is! Map) return defaults;
    int number(String key, int fallback) {
      final value = raw[key];
      return value is num ? value.toInt() : fallback;
    }

    return MistakeSettings(
      enabled: raw['enabled'] != false,
      missionEnabled: raw['missionEnabled'] != false,
      missionSize: number('missionSize', defaults.missionSize),
      missionXp: number('missionXp', defaults.missionXp),
      exitHits: number('exitHits', defaults.exitHits),
      bankMax: number('bankMax', defaults.bankMax),
      practiceMax: number('practiceMax', defaults.practiceMax),
      includeGuide: raw['includeGuide'] == true,
      fixXp: number('fixXp', defaults.fixXp),
      fixXpDailyCap: number('fixXpDailyCap', defaults.fixXpDailyCap),
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'missionEnabled': missionEnabled,
    'missionSize': missionSize,
    'missionXp': missionXp,
    'exitHits': exitHits,
    'bankMax': bankMax,
    'practiceMax': practiceMax,
    'includeGuide': includeGuide,
    'fixXp': fixXp,
    'fixXpDailyCap': fixXpDailyCap,
  };

  /// El primer problema, en español para el editor, o null si está bien.
  String? validate() {
    if (missionSize < minMissionSize || missionSize > maxMissionSize) {
      return 'La misión debe pedir entre $minMissionSize y $maxMissionSize errores.';
    }
    if (missionXp < 0 || missionXp > maxMissionXp) {
      return 'El bono de la misión va de 0 a $maxMissionXp XP.';
    }
    if (exitHits < minExitHits || exitHits > maxExitHits) {
      return 'Los aciertos para salir van de $minExitHits a $maxExitHits.';
    }
    if (bankMax < minBankMax || bankMax > maxBankMax) {
      return 'El tope del banco va de $minBankMax a $maxBankMax preguntas.';
    }
    if (practiceMax < minPracticeMax || practiceMax > maxPracticeMax) {
      return 'La práctica más larga va de $minPracticeMax a $maxPracticeMax preguntas.';
    }
    if (fixXp < 0 || fixXp > maxFixXp) {
      return 'El XP por corregir va de 0 a $maxFixXp.';
    }
    if (fixXpDailyCap < 0 || fixXpDailyCap > maxFixXpDailyCap) {
      return 'El tope diario del XP por corregir va de 0 a $maxFixXpDailyCap.';
    }
    return null;
  }
}
