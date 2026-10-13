/// When a part's sections count as reviewed in the student app, stored in
/// `{config}/study`. Same fields and limits as `StudyReviewRules` in iya-app
/// (`features/study_guide/domain/study_review_rules.dart`).
class StudyReviewRules {
  const StudyReviewRules({
    this.strict = true,
    this.videoMinPercent = 60,
    this.sectionMinSeconds = 5,
  });

  static const defaults = StudyReviewRules();

  static const minVideoPercent = 1;
  static const maxVideoPercent = 100;
  static const maxSectionSeconds = 300;

  /// Off: opening a section, or playing a video, is enough.
  final bool strict;

  /// Share of the video, in real playback, that counts it as watched.
  final int videoMinPercent;

  /// How long a section must stay open to count.
  final int sectionMinSeconds;

  factory StudyReviewRules.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    int number(String key, int fallback) {
      final value = data[key];
      return value is num ? value.toInt() : fallback;
    }

    return StudyReviewRules(
      strict: data['strict'] != false,
      videoMinPercent: number('videoMinPercent', defaults.videoMinPercent),
      sectionMinSeconds: number(
        'sectionMinSeconds',
        defaults.sectionMinSeconds,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'strict': strict,
    'videoMinPercent': videoMinPercent,
    'sectionMinSeconds': sectionMinSeconds,
  };

  /// The first problem found, in Spanish for the editor, or null when valid.
  String? validate() {
    if (videoMinPercent < minVideoPercent ||
        videoMinPercent > maxVideoPercent) {
      return 'El porcentaje del video debe estar entre $minVideoPercent y '
          '$maxVideoPercent.';
    }
    if (sectionMinSeconds < 0 || sectionMinSeconds > maxSectionSeconds) {
      return 'El tiempo mínimo por sección debe estar entre 0 y '
          '$maxSectionSeconds segundos.';
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is StudyReviewRules &&
      other.strict == strict &&
      other.videoMinPercent == videoMinPercent &&
      other.sectionMinSeconds == sectionMinSeconds;

  @override
  int get hashCode => Object.hash(strict, videoMinPercent, sectionMinSeconds);
}

/// Saved rules plus who changed them and when.
class StudyReviewRulesRecord {
  const StudyReviewRulesRecord({
    required this.rules,
    required this.exists,
    this.updatedAt,
    this.updatedBy = '',
  });

  final StudyReviewRules rules;

  /// False until the first save: the app is using its built-in defaults.
  final bool exists;
  final DateTime? updatedAt;
  final String updatedBy;
}
