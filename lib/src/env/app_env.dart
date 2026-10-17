enum AdminEnvironment { test, staging, production }

class AppEnv {
  AppEnv._();

  /// Entorno al que apuntan las colecciones de abajo. Cambiarlo junto con los
  /// sufijos (`-test`, `-staging`, sin sufijo en producción). El admin lo
  /// muestra en la franja superior para no confundir entornos.
  static const environment = AdminEnvironment.test;

  /// ✅ Cambiar aquí cuando pases a producción
  static const universitiesCollection = 'iya-universities-test';
  static const professionsCollection = 'iya-professions-test';
  static const coursesCollection = 'iya-courses-test';
  static const String questionsCollection = 'iya-questions-test';
  // Publicable exam-bank collections. Keep the environment suffix in the
  // collection name: production removes `-test`, staging uses `-staging`.
  static const String questionAnswerKeysCollection =
      'iya-question-answer-keys-test';
  static const String examTemplatesCollection = 'iya-exam-templates-test';
  static const String examAttemptsCollection = 'iya-exam-attempts-test';
  static const String usersCollection = 'iya-profile-test';
  // Settings the student app reads at startup (signed-in read, admin write).
  static const String configCollection = 'iya-config-test';
  static const String syncSettingsDocument = 'sync';
  static const String studyReviewRulesDocument = 'study';
  static const String simulatorSettingsDocument = 'simulator';
  static const String xpSettingsDocument = 'xp';

  /// Public cards with the week XP (written by Functions; the admin moderates).
  static const String leaderboardCollection = 'iya-leaderboard-test';

  /// Alias reservations (server-only; the admin frees one when moderating).
  static const String aliasesCollection = 'iya-aliases-test';

  /// Weekly league seats and daily challenges (docs/rankings_contract.md).
  static const String leagueMembersCollection = 'iya-league-members-test';
  static const String dailyChallengesCollection = 'iya-daily-challenges-test';
  static const String challengeEntriesCollection = 'iya-challenge-entries-test';
  static const String rankingsSettingsDocument = 'rankings';

  /// Perfiles y permisos del admin (docs/admin_staff_contract.md). Solo las
  /// Functions escriben aquí.
  static const String staffCollection = 'iya-admin-staff-test';
  static const String staffRolesCollection = 'iya-admin-roles-test';
  static const String staffInvitesCollection = 'iya-admin-invites-test';

  /// Región de las Functions (callables del admin).
  static const String functionsRegion = 'southamerica-east1';
  // Migration runs are admin-only audit records. Like every other collection,
  // their suffix changes with the configured test/staging/production build.
  static const String questionMigrationRunsCollection =
      'iya-question-migration-runs-test';
  static const String legacyQuestionEditorPrivateCollection =
      '$questionsCollection-editor-private';

  static const String questionVersionsSubcollection = 'versions';
  static const String templateVersionsSubcollection = 'versions';
  static const String examRequestKeysSubcollection = 'examRequestKeys';
  static const String recentQuestionsSubcollection = 'recentQuestions';

  // subcollections
  static const String alternativesSubcollection = 'alternatives';

  /// subcollections
  static const modesSubcollection = 'modes';
  static const professionsSubcollection = 'professions';
  static const topicsSubcollection = 'topics';
  static const subtopicsSubcollection = 'subtopics';
}
