import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/question_contract/question_contract.dart';
import '../../env/app_env.dart';

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
    required QuestionAnswerKey answerKey,
  }) async {
    _requireDraft(question);
    answerKey.validateAgainst(question);
    final root = _question(question.ref.questionId);
    final key = _answerKey(question.ref.questionId, question.ref.version);
    await db.runTransaction((transaction) async {
      final existing = await transaction.get(root);
      final data = existing.data();
      if (data?['status'] == 'published') {
        throw StateError('Primero crea un borrador de la pregunta publicada.');
      }
      if (data != null && _versionOf(data) != question.ref.version) {
        throw StateError('La versión del borrador ya cambió. Recárgalo.');
      }
      final savedKey = await transaction.get(key);
      transaction.set(root, {
        ..._questionFields(question, randomKey: _randomKey(data)),
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(key, {
        ...answerKey.toJson(),
        'createdAt':
            savedKey.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Publishes the current draft and atomically freezes the matching snapshot.
  /// A snapshot can never be replaced, even by a later edit of the root.
  Future<void> publishDraft(String questionId) async {
    final root = _question(questionId);
    await db.runTransaction((transaction) async {
      final current = await transaction.get(root);
      if (!current.exists) throw StateError('La pregunta no existe.');
      final question = QuestionDocument.fromJson(current.data()!);
      _requireDraft(question);
      _requirePublishable(question);
      final keyRef = _answerKey(questionId, question.ref.version);
      final keySnapshot = await transaction.get(keyRef);
      if (!keySnapshot.exists) {
        throw StateError('Falta la clave de respuesta privada.');
      }
      final answerKey = QuestionAnswerKey.fromJson(keySnapshot.data()!);
      answerKey.validateAgainst(question);
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

  int _versionOf(Map<String, dynamic> data) =>
      (data['version'] as num?)?.toInt() ?? 0;

  void _requireDraft(QuestionDocument question) {
    if (question.status != 'draft') {
      throw ArgumentError.value(question.status, 'status', 'Expected draft');
    }
  }

  void _requirePublishable(QuestionDocument question) {
    if (!_hasContent(question.content)) {
      throw StateError('El enunciado no puede estar vacío al publicar.');
    }
    if (question.alternatives.length < 2 ||
        question.alternatives.any(
          (alternative) => !_hasContent(alternative.content),
        )) {
      throw StateError('Publica al menos dos alternativas con contenido.');
    }
    if (question.courseId.isEmpty || question.topicId.isEmpty) {
      throw StateError('Selecciona curso y tema antes de publicar.');
    }
  }

  bool _hasContent(QuestionContent content) => content.blocks.any((block) {
    return switch (block) {
      TextBlock block => block.text.trim().isNotEmpty,
      ParagraphBlock block => block.spans.any(
        (span) => span.value.trim().isNotEmpty,
      ),
      FormulaBlock block => block.latex.trim().isNotEmpty,
      ImageBlock _ => true,
      LegacyBlock block => block.raw.trim().isNotEmpty,
    };
  });
}
