import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/question_contract/question_contract.dart';
import '../../domain/question_bank_filter.dart';
import '../../domain/question_publication_validation.dart';
import '../../env/app_env.dart';
import 'academic_context_validator.dart';

/// Editorial persistence for the v2 public bank.
///
/// The root document is the current selectable revision only while its status
/// is `published`. Each publication is copied once to `versions`, so attempts
/// can always use the immutable revision they were created with.
class PublishableQuestionRepo {
  PublishableQuestionRepo(this.db);

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _questions =>
      db.collection(AppEnv.questionsCollection);
  CollectionReference<Map<String, dynamic>> get _answerKeys =>
      db.collection(AppEnv.questionAnswerKeysCollection);

  DocumentReference<Map<String, dynamic>> _question(String questionId) =>
      _questions.doc(questionId);
  DocumentReference<Map<String, dynamic>> _answerKey(
    String questionId,
    int version,
  ) => _answerKeys.doc('${questionId}_$version');
  DocumentReference<Map<String, dynamic>> _version(
    String questionId,
    int version,
  ) => _question(
    questionId,
  ).collection(AppEnv.questionVersionsSubcollection).doc('$version');

  /// Saves a v2 draft. A published root must be forked first so no published
  /// revision is overwritten by an editorial save.
  Future<void> saveDraft(
    QuestionDocument question, {
    QuestionAnswerKey? answerKey,
  }) async {
    _requireDraft(question);
    answerKey?.validateAgainst(question);
    final root = _question(question.ref.questionId);
    final key = _answerKey(question.ref.questionId, question.ref.version);
    await db.runTransaction((transaction) async {
      final existing = await transaction.get(root);
      final data = existing.data();
      if (data?['status'] == 'published') {
        throw StateError('Primero crea un borrador de la pregunta publicada.');
      }
      if (data?['status'] == 'retired') {
        throw StateError(
          'Una pregunta retirada no se puede reabrir desde el formulario.',
        );
      }
      if (data?['version'] != null &&
          _versionOf(data!) != question.ref.version) {
        throw StateError('La versión del borrador ya cambió. Recárgalo.');
      }
      final savedKey = await transaction.get(key);
      final fields = {
        ..._questionFields(question, randomKey: _randomKey(data)),
        if (data?['searchTokens'] == null)
          'searchTokens': _searchTokens(question),
        if (data?['partSearchTokens'] == null)
          'partSearchTokens': QuestionBankSearch.partTokens(
            question.partIds,
            _searchTokens(question),
          ),
        if (question.originalNumber == null && data?['originalNumber'] != null)
          'originalNumber': FieldValue.delete(),
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (existing.exists) {
        transaction.update(root, fields);
      } else {
        transaction.set(root, fields);
      }
      if (answerKey != null) {
        transaction.set(key, {
          ...answerKey.toJson(),
          'createdAt':
              savedKey.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (savedKey.exists) {
        transaction.delete(key);
      }
    });
  }

  /// Available only to the authenticated admin editor. Mobile clients have no
  /// read rule for this collection.
  Future<QuestionAnswerKey?> readAnswerKey(
    String questionId,
    int version,
  ) async {
    final snapshot = await _answerKey(questionId, version).get();
    return snapshot.exists
        ? QuestionAnswerKey.fromJson(snapshot.data()!)
        : null;
  }

  Future<QuestionDocument?> readQuestionDocument(String questionId) async {
    final snapshot = await _question(questionId).get();
    if (!snapshot.exists) return null;
    try {
      return QuestionDocument.fromJson(snapshot.data()!);
    } on FormatException {
      return null;
    }
  }

  /// Performs the same content checks used for publication and reports every
  /// missing field that can be observed from the current draft. It is a
  /// preflight only; [publishDraft] repeats the critical checks transactionally.
  Future<QuestionDraftValidation> validateDraft(String questionId) async {
    final root = await _question(questionId).get();
    if (!root.exists) {
      return const QuestionDraftValidation([
        QuestionValidationIssue(
          'question.missing',
          'La pregunta ya no existe.',
        ),
      ]);
    }
    late QuestionDocument question;
    try {
      question = QuestionDocument.fromJson(root.data()!);
    } on FormatException {
      return const QuestionDraftValidation([
        QuestionValidationIssue(
          'contract.invalid',
          'El borrador no cumple el contrato de pregunta v2.',
        ),
      ]);
    }
    final issues = <QuestionValidationIssue>[];
    QuestionAnswerKey? answerKey;
    final key = await _answerKey(questionId, question.ref.version).get();
    if (key.exists) {
      try {
        answerKey = QuestionAnswerKey.fromJson(key.data()!);
      } on FormatException {
        issues.add(
          const QuestionValidationIssue(
            'answer.contract.invalid',
            'La clave privada no cumple el contrato v2.',
          ),
        );
      }
    }
    issues.addAll(
      QuestionPublicationValidator.validate(
        question: question,
        answerKey: answerKey,
      ).issues,
    );
    issues.addAll(await _referenceIssues(question));
    return QuestionDraftValidation(List.unmodifiable(issues));
  }

  /// Publishes the current draft and atomically freezes the matching snapshot.
  /// A snapshot can never be replaced, even by a later edit of the root.
  Future<void> publishDraft(String questionId) async {
    final root = _question(questionId);
    await db.runTransaction((transaction) async {
      final current = await transaction.get(root);
      if (!current.exists) throw StateError('La pregunta no existe.');
      late QuestionDocument question;
      try {
        question = QuestionDocument.fromJson(current.data()!);
      } on FormatException {
        throw const QuestionPublicationException(
          QuestionDraftValidation([
            QuestionValidationIssue(
              'contract.invalid',
              'El borrador no cumple el contrato de pregunta v2.',
            ),
          ]),
        );
      }
      _requireDraft(question);
      final keyRef = _answerKey(questionId, question.ref.version);
      final keySnapshot = await transaction.get(keyRef);
      QuestionAnswerKey? answerKey;
      if (keySnapshot.exists) {
        try {
          answerKey = QuestionAnswerKey.fromJson(keySnapshot.data()!);
        } on FormatException {
          throw const QuestionPublicationException(
            QuestionDraftValidation([
              QuestionValidationIssue(
                'answer.contract.invalid',
                'La clave privada no cumple el contrato v2.',
              ),
            ]),
          );
        }
      }
      final validation = QuestionPublicationValidator.validate(
        question: question,
        answerKey: answerKey,
      );
      if (!validation.isPublishable) {
        throw QuestionPublicationException(validation);
      }
      try {
        await _validateActiveSource(transaction, question);
        await AcademicContextValidator.validate(
          db,
          transaction,
          courseId: question.courseId,
          topicId: question.topicId,
          subtopicId: question.subtopicId,
          partIds: question.partIds,
          requireComplete: true,
        );
      } on StateError catch (error) {
        throw QuestionPublicationException(
          QuestionDraftValidation([
            QuestionValidationIssue(
              'references.invalid',
              error.message.toString(),
            ),
          ]),
        );
      }
      final version = _version(questionId, question.ref.version);
      if ((await transaction.get(version)).exists) {
        throw StateError('Esta versión ya fue publicada y es inmutable.');
      }
      final published = QuestionDocument.fromJson({
        ...question.toJson(),
        'status': 'published',
      });
      final fields = _questionFields(
        published,
        randomKey: _randomKey(current.data()),
      );
      transaction.set(version, {
        ...fields,
        'createdAt':
            current.data()!['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'publishedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(root, {
        ...fields,
        'updatedAt': FieldValue.serverTimestamp(),
        'publishedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Copies a published revision into the next editable draft. The old snapshot
  /// and its answer key remain untouched for existing attempts.
  Future<QuestionVersionRef> forkPublishedForEdit(String questionId) async {
    final root = _question(questionId);
    return db.runTransaction((transaction) async {
      final current = await transaction.get(root);
      if (!current.exists) throw StateError('La pregunta no existe.');
      final published = QuestionDocument.fromJson(current.data()!);
      if (published.status != 'published') {
        throw StateError(
          'Solo una pregunta publicada puede crear una revisión.',
        );
      }
      final previousKey = await transaction.get(
        _answerKey(questionId, published.ref.version),
      );
      if (!previousKey.exists) {
        throw StateError('Falta la clave privada de la versión publicada.');
      }
      final nextRef = QuestionVersionRef.fromJson({
        'questionId': questionId,
        'version': published.ref.version + 1,
      });
      final draft = QuestionDocument.fromJson({
        ...published.toJson(),
        ...nextRef.toJson(),
        'status': 'draft',
      });
      final nextKey = QuestionAnswerKey.fromJson({
        ...previousKey.data()!,
        ...nextRef.toJson(),
      });
      nextKey.validateAgainst(draft);
      transaction.set(root, {
        ..._questionFields(draft, randomKey: _randomKey(current.data())),
        'publishedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(_answerKey(questionId, nextRef.version), {
        ...nextKey.toJson(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return nextRef;
    });
  }

  /// A retired question is no longer selectable but keeps every frozen version.
  Future<void> retirePublished(String questionId) async {
    final root = _question(questionId);
    await db.runTransaction((transaction) async {
      final current = await transaction.get(root);
      if (!current.exists || current.data()?['status'] != 'published') {
        throw StateError('Solo se puede retirar una pregunta publicada.');
      }
      transaction.update(root, {
        'status': 'retired',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Map<String, dynamic> _questionFields(
    QuestionDocument question, {
    required double randomKey,
  }) {
    final source = question.sourceExam;
    return {
      ...question.toJson(),
      'questionId': question.ref.questionId,
      'sourceExamId': source?.id ?? '',
      'universityId': source?.universityId ?? '',
      'modalityId': source?.modalityId ?? '',
      'year': source?.year,
      'period': source?.period ?? '',
      'sourceLabel': question.sourceLabel,
      'randomKey': randomKey,
    };
  }

  double _randomKey(Map<String, dynamic>? data) {
    final value = data?['randomKey'];
    if (value is num && value >= 0 && value < 1) return value.toDouble();
    return Random.secure().nextDouble();
  }

  List<String> _searchTokens(QuestionDocument question) =>
      QuestionBankSearch.tokens([
        question.ref.questionId,
        question.sourceLabel,
        question.sourceExam?.id ?? '',
        for (final block in question.content.blocks)
          switch (block) {
            TextBlock block => block.text,
            ParagraphBlock block =>
              block.spans.map((span) => span.value).join(' '),
            FormulaBlock block => block.latex,
            ImageBlock block => '${block.altText} ${block.caption}',
            LegacyBlock block => block.raw,
          },
      ]);

  int _versionOf(Map<String, dynamic> data) =>
      (data['version'] as num?)?.toInt() ?? 0;

  void _requireDraft(QuestionDocument question) {
    if (question.status != 'draft') {
      throw ArgumentError.value(question.status, 'status', 'Expected draft');
    }
  }

  Future<void> _validateActiveSource(
    Transaction transaction,
    QuestionDocument question,
  ) async {
    if (![
      'admission_exam',
      'official_practice',
      'other',
    ].contains(question.sourceType)) {
      return;
    }
    final source = question.sourceExam;
    if (source == null) {
      throw StateError('Selecciona un examen de origen antes de publicar.');
    }
    final catalog = await transaction.get(
      db
          .collection(AppEnv.universitiesCollection)
          .doc(source.universityId)
          .collection('admissionExams')
          .doc(source.id),
    );
    if (!catalog.exists || catalog.data()?['active'] == false) {
      throw StateError('El examen de origen ya no existe o está inactivo.');
    }
  }

  Future<List<QuestionValidationIssue>> _referenceIssues(
    QuestionDocument question,
  ) async {
    final issues = <QuestionValidationIssue>[];
    final source = question.sourceExam;
    if (source != null &&
        const {
          'admission_exam',
          'official_practice',
          'other',
        }.contains(question.sourceType)) {
      final exam = await db
          .collection(AppEnv.universitiesCollection)
          .doc(source.universityId)
          .collection('admissionExams')
          .doc(source.id)
          .get();
      if (!exam.exists) {
        issues.add(
          const QuestionValidationIssue(
            'source.exam.missing',
            'El examen de origen ya no existe.',
          ),
        );
      } else if (!_isActive(exam.data())) {
        issues.add(
          const QuestionValidationIssue(
            'source.exam.inactive',
            'El examen de origen está inactivo.',
          ),
        );
      }
    }

    if (question.courseId.isEmpty) return issues;
    final course = await db
        .collection(AppEnv.coursesCollection)
        .doc(question.courseId)
        .get();
    if (!course.exists || !_isActive(course.data())) {
      issues.add(
        const QuestionValidationIssue(
          'course.invalid',
          'El curso seleccionado ya no existe o está inactivo.',
        ),
      );
      return issues;
    }
    if (question.topicId.isEmpty) return issues;
    final topic = await course.reference
        .collection(AppEnv.topicsSubcollection)
        .doc(question.topicId)
        .get();
    if (!topic.exists || !_isActive(topic.data())) {
      issues.add(
        const QuestionValidationIssue(
          'topic.invalid',
          'El tema seleccionado ya no existe, está inactivo o no pertenece al curso.',
        ),
      );
      return issues;
    }
    if (question.subtopicId.isEmpty) return issues;
    final subtopic = await topic.reference
        .collection(AppEnv.subtopicsSubcollection)
        .doc(question.subtopicId)
        .get();
    final subtopicData = subtopic.data();
    if (!subtopic.exists || !_isActive(subtopicData)) {
      issues.add(
        const QuestionValidationIssue(
          'subtopic.invalid',
          'El subtema seleccionado ya no existe, está inactivo o no pertenece al tema.',
        ),
      );
      return issues;
    }
    final parts = <String, Map<String, dynamic>>{
      for (final raw in (subtopicData?['listPart'] as List? ?? const []))
        if (raw is Map && raw['id']?.toString().trim().isNotEmpty == true)
          raw['id'].toString(): Map<String, dynamic>.from(raw),
    };
    for (final partId in question.partIds) {
      if (!parts.containsKey(partId) || !_isActive(parts[partId])) {
        issues.add(
          QuestionValidationIssue(
            'part.$partId.invalid',
            'La parte seleccionada "$partId" no existe, está inactiva o no pertenece al subtema.',
          ),
        );
      }
    }
    return issues;
  }

  bool _isActive(Map<String, dynamic>? data) {
    if (data == null) return false;
    final value = data['active'];
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized != 'false' && normalized != 'n' && normalized != '0';
  }
}
