import 'content.dart';
export 'content.dart';

void requireV2(Json json) {
  if (json['schemaVersion'] != 2) {
    throw const FormatException('Expected schemaVersion 2');
  }
}

class SourceExam {
  SourceExam.fromJson(Json json)
    : id = idField(json, 'id'),
      universityId = idField(json, 'universityId'),
      universityName = idField(json, 'universityName'),
      universityAcronym = idField(json, 'universityAcronym'),
      examType = enumField(json, 'examType', [
        'admission_exam',
        'official_practice',
      ]),
      modalityId = idField(json, 'modalityId'),
      modalityName = idField(json, 'modalityName'),
      year = intField(json, 'year', min: 1),
      period = stringField(json, 'period', fallback: ''),
      reference = stringField(json, 'reference', fallback: '') {
    requireV2(json);
  }
  final String id, universityId, universityName, universityAcronym;
  final String examType, modalityId, modalityName, period, reference;
  final int year;
  String get label {
    final kind = examType == 'admission_exam'
        ? 'examen de admisión'
        : 'práctica oficial';
    final date = '$year${period.isEmpty ? '' : '-$period'}';
    final prefix = examType == 'admission_exam'
        ? 'Pregunta del'
        : 'Pregunta de';
    return '$prefix $kind $modalityName $date | $universityAcronym';
  }

  Json toJson() => {
    'schemaVersion': 2,
    'id': id,
    'universityId': universityId,
    'universityName': universityName,
    'universityAcronym': universityAcronym,
    'examType': examType,
    'modalityId': modalityId,
    'modalityName': modalityName,
    'year': year,
    'period': period,
    'reference': reference,
  };
}

class QuestionVersionRef {
  QuestionVersionRef.fromJson(Json json)
    : questionId = idField(json, 'questionId'),
      version = intField(json, 'version', min: 1);
  final String questionId;
  final int version;
  String get key => '$questionId@$version';
  Json toJson() => {'questionId': questionId, 'version': version};
}

class QuestionAlternative {
  QuestionAlternative.fromJson(Json json)
    : id = idField(json, 'id'),
      label = idField(json, 'label'),
      content = QuestionContent.fromJson(json['content']) {
    if (json.containsKey('isCorrect')) {
      throw const FormatException(
        'Correctness belongs in the private answer key',
      );
    }
  }
  final String id, label;
  final QuestionContent content;
  Json toJson() => {'id': id, 'label': label, 'content': content.toJson()};
}

/// Canonical question revision. No correct answer or solution in this payload.
class QuestionDocument {
  QuestionDocument.fromJson(Json json)
    : ref = QuestionVersionRef.fromJson(json),
      status = enumField(json, 'status', ['draft', 'published', 'retired']),
      sourceType = enumField(json, 'sourceType', [
        'admission_exam',
        'official_practice',
        'original',
        'adapted',
        'unknown',
      ]),
      sourceExam = json['sourceExam'] == null
          ? null
          : SourceExam.fromJson(objectField(json['sourceExam'])),
      originalNumber = json['originalNumber'] == null
          ? null
          : intField(json, 'originalNumber', min: 1),
      courseId = stringField(json, 'courseId', fallback: ''),
      topicId = stringField(json, 'topicId', fallback: ''),
      subtopicId = stringField(json, 'subtopicId', fallback: ''),
      partIds = idsField(json['partIds'] ?? []),
      difficulty = enumField(json, 'difficulty', [
        'unknown',
        'easy',
        'medium',
        'hard',
      ]),
      content = QuestionContent.fromJson(json['content']),
      alternatives = listField(
        json['alternatives'],
        (v) => QuestionAlternative.fromJson(objectField(v)),
      ) {
    requireV2(json);
    uniqueIds(alternatives.map((a) => a.id));
    uniqueIds(alternatives.map((a) => a.label));
    if (json.containsKey('correctAlternativeId') ||
        json.containsKey('explanation')) {
      throw const FormatException('Private answer fields in question payload');
    }
    if (['admission_exam', 'official_practice'].contains(sourceType) &&
        (sourceExam == null || sourceExam!.examType != sourceType)) {
      throw const FormatException('Source exam does not match provenance');
    }
    if (sourceType == 'original' && sourceExam != null) {
      throw const FormatException(
        'Original questions cannot claim an exam origin',
      );
    }
  }
  final QuestionVersionRef ref;
  final String status, sourceType, courseId, topicId, subtopicId, difficulty;
  final SourceExam? sourceExam;
  final int? originalNumber;
  final List<String> partIds;
  final QuestionContent content;
  final List<QuestionAlternative> alternatives;
  String get sourceLabel => switch (sourceType) {
    'original' => 'Pregunta de práctica IngresoYa',
    'adapted' =>
      'Pregunta adaptada${sourceExam == null ? '' : ' | ${sourceExam!.universityAcronym}'}',
    'unknown' => 'Procedencia pendiente de verificar',
    _ => sourceExam!.label,
  };
  Json toJson() => {
    'schemaVersion': 2,
    ...ref.toJson(),
    'status': status,
    'sourceType': sourceType,
    if (sourceExam != null) 'sourceExam': sourceExam!.toJson(),
    if (originalNumber != null) 'originalNumber': originalNumber,
    'courseId': courseId,
    'topicId': topicId,
    'subtopicId': subtopicId,
    'partIds': partIds,
    'difficulty': difficulty,
    'content': content.toJson(),
    'alternatives': alternatives.map((a) => a.toJson()).toList(),
  };
}

/// Stored in a separate private collection. Never sent before submission.
class QuestionAnswerKey {
  QuestionAnswerKey.fromJson(Json json)
    : ref = QuestionVersionRef.fromJson(json),
      correctAlternativeId = idField(json, 'correctAlternativeId'),
      explanation = QuestionContent.fromJson(json['explanation']) {
    requireV2(json);
  }
  final QuestionVersionRef ref;
  final String correctAlternativeId;
  final QuestionContent explanation;
  void validateAgainst(QuestionDocument question) {
    if (ref.key != question.ref.key ||
        !question.alternatives.any((a) => a.id == correctAlternativeId)) {
      throw const FormatException(
        'Answer key does not match question revision',
      );
    }
  }

  Json toJson() => {
    'schemaVersion': 2,
    ...ref.toJson(),
    'correctAlternativeId': correctAlternativeId,
    'explanation': explanation.toJson(),
  };
}

class ExamFilter {
  ExamFilter.fromJson(Json json)
    : universityId = stringField(json, 'universityId', fallback: ''),
      sourceExamId = stringField(json, 'sourceExamId', fallback: ''),
      modalityId = stringField(json, 'modalityId', fallback: ''),
      courseId = stringField(json, 'courseId', fallback: ''),
      topicId = stringField(json, 'topicId', fallback: ''),
      subtopicId = stringField(json, 'subtopicId', fallback: ''),
      partId = stringField(json, 'partId', fallback: ''),
      sourceType = enumField(
        {...json, 'sourceType': json['sourceType'] ?? 'any'},
        'sourceType',
        ['any', 'admission_exam', 'official_practice', 'original', 'adapted'],
      ),
      difficulty = enumField(
        {...json, 'difficulty': json['difficulty'] ?? 'any'},
        'difficulty',
        ['any', 'easy', 'medium', 'hard'],
      ),
      yearFrom = json['yearFrom'] == null
          ? null
          : intField(json, 'yearFrom', min: 1),
      yearTo = json['yearTo'] == null
          ? null
          : intField(json, 'yearTo', min: 1) {
    if (yearFrom != null && yearTo != null && yearFrom! > yearTo!) {
      throw const FormatException('Inverted year range');
    }
  }
  final String universityId,
      sourceExamId,
      modalityId,
      courseId,
      topicId,
      subtopicId,
      partId,
      sourceType,
      difficulty;
  final int? yearFrom, yearTo;
  Json toJson() => {
    'universityId': universityId,
    'sourceExamId': sourceExamId,
    'modalityId': modalityId,
    'courseId': courseId,
    'topicId': topicId,
    'subtopicId': subtopicId,
    'partId': partId,
    'sourceType': sourceType,
    'difficulty': difficulty,
    if (yearFrom != null) 'yearFrom': yearFrom,
    if (yearTo != null) 'yearTo': yearTo,
  };
}

class ExamTemplateBlock {
  ExamTemplateBlock.fromJson(Json json)
    : count = intField(json, 'count', min: 1),
      filter = ExamFilter.fromJson(objectField(json['filter']));
  final int count;
  final ExamFilter filter;
  Json toJson() => {'count': count, 'filter': filter.toJson()};
}

class ExamTemplate {
  ExamTemplate.fromJson(Json json)
    : id = idField(json, 'id'),
      version = intField(json, 'version', min: 1),
      title = idField(json, 'title'),
      purpose = enumField(json, 'purpose', [
        'practice',
        'part_completion',
        'simulation',
      ]),
      mode = enumField(json, 'mode', ['dynamic', 'fixed']),
      selectionPolicy = enumField(json, 'selectionPolicy', [
        'strict',
        'prefer_profile_university',
      ]),
      allowedFallbackSources = listField(
        json['allowedFallbackSources'] ?? [],
        (v) => enumField(
          {'source': v},
          'source',
          ['admission_exam', 'official_practice', 'original', 'adapted'],
        ),
      ),
      questionCount = intField(json, 'questionCount', min: 1),
      durationSeconds = json['durationSeconds'] == null
          ? null
          : intField(json, 'durationSeconds', min: 1),
      passPercentExclusive = intField(
        json,
        'passPercentExclusive',
        fallback: 80,
      ),
      blocks = listField(
        json['blocks'] ?? [],
        (v) => ExamTemplateBlock.fromJson(objectField(v)),
      ),
      fixedQuestions = listField(
        json['fixedQuestions'] ?? [],
        (v) => QuestionVersionRef.fromJson(objectField(v)),
      ) {
    requireV2(json);
    if (passPercentExclusive >= 100) {
      throw const FormatException('Impossible passing threshold');
    }
    if (mode == 'dynamic' &&
        (fixedQuestions.isNotEmpty ||
            blocks.fold<int>(0, (n, b) => n + b.count) != questionCount)) {
      throw const FormatException('Dynamic blocks must match questionCount');
    }
    if (mode == 'fixed' &&
        (blocks.isNotEmpty || fixedQuestions.length != questionCount)) {
      throw const FormatException('Fixed questions must match questionCount');
    }
    uniqueIds(fixedQuestions.map((q) => q.questionId));
    if (selectionPolicy == 'strict' && allowedFallbackSources.isNotEmpty) {
      throw const FormatException(
        'Strict templates cannot have fallback sources',
      );
    }
  }
  final String id, title, purpose, mode, selectionPolicy;
  final int version, questionCount, passPercentExclusive;
  final int? durationSeconds;
  final List<String> allowedFallbackSources;
  final List<ExamTemplateBlock> blocks;
  final List<QuestionVersionRef> fixedQuestions;
  int get requiredCorrectAnswers =>
      questionCount * passPercentExclusive ~/ 100 + 1;
  Json toJson() => {
    'schemaVersion': 2,
    'id': id,
    'version': version,
    'title': title,
    'purpose': purpose,
    'mode': mode,
    'selectionPolicy': selectionPolicy,
    'questionCount': questionCount,
    'allowedFallbackSources': allowedFallbackSources,
    'passPercentExclusive': passPercentExclusive,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    'blocks': blocks.map((b) => b.toJson()).toList(),
    'fixedQuestions': fixedQuestions.map((q) => q.toJson()).toList(),
  };
}

class AttemptQuestion {
  AttemptQuestion.fromJson(Json json)
    : ref = QuestionVersionRef.fromJson(json),
      alternativeOrder = idsField(json['alternativeOrder']) {
    if (alternativeOrder.length < 2) {
      throw const FormatException(
        'An attempt question needs at least two alternatives',
      );
    }
  }
  final QuestionVersionRef ref;
  final List<String> alternativeOrder;
  Json toJson() => {...ref.toJson(), 'alternativeOrder': alternativeOrder};
}

class ExamResult {
  ExamResult.fromJson(Json json)
    : attemptId = idField(json, 'attemptId'),
      total = intField(json, 'total', min: 1),
      correct = intField(json, 'correct'),
      passPercentExclusive = intField(json, 'passPercentExclusive'),
      gradedAtMs = intField(json, 'gradedAtMs', min: 1) {
    requireV2(json);
    if (correct > total || passPercentExclusive >= 100) {
      throw const FormatException('Invalid result');
    }
  }
  final String attemptId;
  final int total, correct, passPercentExclusive, gradedAtMs;
  double get percentage => correct * 100 / total;
  bool get passed => correct * 100 > total * passPercentExclusive;
  Json toJson() => {
    'schemaVersion': 2,
    'attemptId': attemptId,
    'total': total,
    'correct': correct,
    'passPercentExclusive': passPercentExclusive,
    'gradedAtMs': gradedAtMs,
  };
}

class ExamAttempt {
  ExamAttempt.fromJson(Json json)
    : id = idField(json, 'id'),
      userId = idField(json, 'userId'),
      requestId = idField(json, 'requestId'),
      templateId = idField(json, 'templateId'),
      templateVersion = intField(json, 'templateVersion', min: 1),
      partId = stringField(json, 'partId', fallback: ''),
      status = enumField(json, 'status', [
        'in_progress',
        'submitted',
        'graded',
        'abandoned',
      ]),
      createdAtMs = intField(json, 'createdAtMs', min: 1),
      questions = listField(
        json['questions'],
        (v) => AttemptQuestion.fromJson(objectField(v)),
      ),
      answers = Map<String, String>.unmodifiable(
        objectField(json['answers'] ?? {}).map((k, v) {
          if (v is! String) {
            throw const FormatException('Answer must be an alternative ID');
          }
          return MapEntry(k, v);
        }),
      ),
      result = json['result'] == null
          ? null
          : ExamResult.fromJson(objectField(json['result'])) {
    requireV2(json);
    if (questions.isEmpty) throw const FormatException('Empty attempt');
    uniqueIds(questions.map((q) => q.ref.questionId));
    for (final entry in answers.entries) {
      if (!questions.any(
        (q) =>
            q.ref.questionId == entry.key &&
            q.alternativeOrder.contains(entry.value),
      )) {
        throw const FormatException('Answer outside attempt');
      }
    }
    if ((status == 'graded') != (result != null) ||
        (result != null &&
            (result!.attemptId != id || result!.total != questions.length))) {
      throw const FormatException('Result does not match attempt');
    }
  }
  final String id, userId, requestId, templateId, partId, status;
  final int templateVersion, createdAtMs;
  final List<AttemptQuestion> questions;
  final Map<String, String> answers;
  final ExamResult? result;
  Json toJson() => {
    'schemaVersion': 2,
    'id': id,
    'userId': userId,
    'requestId': requestId,
    'templateId': templateId,
    'templateVersion': templateVersion,
    'partId': partId,
    'status': status,
    'createdAtMs': createdAtMs,
    'questions': questions.map((q) => q.toJson()).toList(),
    'answers': answers,
    if (result != null) 'result': result!.toJson(),
  };
}
