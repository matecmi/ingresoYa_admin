class AppEnv {
  AppEnv._();

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
