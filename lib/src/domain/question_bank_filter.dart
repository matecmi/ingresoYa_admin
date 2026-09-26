/// Server-side filters for the editorial question bank. Empty values mean
/// “all”; the repository translates only populated values into Firestore
/// constraints, never into local list filtering.
class QuestionBankFilter {
  const QuestionBankFilter({
    this.status = '',
    this.universityId = '',
    this.sourceExamId = '',
    this.sourceType = '',
    this.modalityId = '',
    this.yearFrom,
    this.yearTo,
    this.courseId = '',
    this.topicId = '',
    this.subtopicId = '',
    this.partId = '',
    this.difficulty = '',
    this.text = '',
  });

  final String status;
  final String universityId;
  final String sourceExamId;
  final String sourceType;
  final String modalityId;
  final int? yearFrom;
  final int? yearTo;
  final String courseId;
  final String topicId;
  final String subtopicId;
  final String partId;
  final String difficulty;
  final String text;

  bool get hasText => QuestionBankSearch.normalise(text).isNotEmpty;
  bool get hasYearRange => yearFrom != null || yearTo != null;

  QuestionBankFilter copyWith({
    String? status,
    String? universityId,
    String? sourceExamId,
    String? sourceType,
    String? modalityId,
    int? yearFrom,
    int? yearTo,
    String? courseId,
    String? topicId,
    String? subtopicId,
    String? partId,
    String? difficulty,
    String? text,
  }) => QuestionBankFilter(
    status: status ?? this.status,
    universityId: universityId ?? this.universityId,
    sourceExamId: sourceExamId ?? this.sourceExamId,
    sourceType: sourceType ?? this.sourceType,
    modalityId: modalityId ?? this.modalityId,
    yearFrom: yearFrom ?? this.yearFrom,
    yearTo: yearTo ?? this.yearTo,
    courseId: courseId ?? this.courseId,
    topicId: topicId ?? this.topicId,
    subtopicId: subtopicId ?? this.subtopicId,
    partId: partId ?? this.partId,
    difficulty: difficulty ?? this.difficulty,
    text: text ?? this.text,
  );
}

/// Compact terms written to `searchTokens`. Prefixes let the bank search a
/// statement or stable identifier without downloading documents first.
class QuestionBankSearch {
  QuestionBankSearch._();

  static String normalise(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');

  static String? queryToken(String value) {
    final terms = _terms(value);
    return terms.isEmpty ? null : terms.first;
  }

  static List<String> tokens(Iterable<String> values) {
    final result = <String>{};
    for (final value in values) {
      for (final term in _terms(value)) {
        result.add(term);
        for (var length = 3; length < term.length; length++) {
          result.add(term.substring(0, length));
        }
      }
    }
    final ordered = result.toList()..sort();
    return ordered.take(120).toList(growable: false);
  }

  /// Firestore permits one `array-contains` clause per query. This crossed
  /// index keeps “part + text” server-side instead of filtering a page in
  /// memory after querying only one of those dimensions.
  static List<String> partTokens(
    Iterable<String> partIds,
    Iterable<String> searchTokens,
  ) {
    final result = <String>{
      for (final partId in partIds.where((id) => id.trim().isNotEmpty))
        for (final token in searchTokens) '${partId.trim()}|$token',
    };
    final ordered = result.toList()..sort();
    return ordered.take(240).toList(growable: false);
  }

  static List<String> _terms(String value) => normalise(value)
      .split(RegExp(r'[^a-z0-9-]+'))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);
}
