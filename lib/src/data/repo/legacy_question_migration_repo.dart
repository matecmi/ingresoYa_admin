import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/question_contract/question_contract.dart';
import '../../domain/entities/admission_exam.dart';
import '../../domain/legacy_question_migration.dart';
import '../../domain/question_bank_filter.dart';
import '../../env/app_env.dart';

/// Admin-only, resumable migration for legacy question documents.
///
/// A dry run writes a report but never changes a question, answer key, legacy
/// alternative or private explanation. A real run only produces v2 `draft`
/// roots; it never invokes the publication path.
class LegacyQuestionMigrationRepo {
  LegacyQuestionMigrationRepo(this.db);

  final FirebaseFirestore db;

  static const defaultBatchSize = 20;
  static const maxBatchSize = 50;

  CollectionReference<Map<String, dynamic>> get _questions =>
      db.collection(AppEnv.questionsCollection);
  CollectionReference<Map<String, dynamic>> get _answerKeys =>
      db.collection(AppEnv.questionAnswerKeysCollection);
  CollectionReference<Map<String, dynamic>> get _runs =>
      db.collection(AppEnv.questionMigrationRunsCollection);
  CollectionReference<Map<String, dynamic>> get _legacyExplanations =>
      db.collection(AppEnv.legacyQuestionEditorPrivateCollection);

  /// Creates a new migration report or resumes [runId] from its persisted
  /// document-ID cursor. A run cannot switch between dry-run and write mode.
  Future<LegacyMigrationBatch> runBatch({
    bool dryRun = true,
    String? runId,
    int batchSize = defaultBatchSize,
  }) async {
    final size = batchSize.clamp(1, maxBatchSize);
    final run = await _openRun(dryRun: dryRun, runId: runId);
    final data = run.data()!;
    final cursor = (data['cursorQuestionId'] ?? '').toString();
    Query<Map<String, dynamic>> query = _questions
        .orderBy(FieldPath.documentId)
        .limit(size);
    if (cursor.isNotEmpty) query = query.startAfter([cursor]);
    final page = await query.get();

    final reports = <LegacyMigrationItemReport>[];
    for (final snapshot in page.docs) {
      final report = await _inspect(snapshot);
      var applied = false;
      if (!dryRun && report.plan.isMigrable) {
        applied = await _apply(report.plan, snapshot.reference, run.id);
      }
      reports.add(
        LegacyMigrationItemReport(
          questionId: snapshot.id,
          disposition: report.plan.disposition,
          issues: report.plan.issues,
          wouldCreateAnswerKey: report.plan.answerKey != null,
          applied: applied,
        ),
      );
      await _saveReport(
        run,
        snapshot,
        report,
        dryRun: dryRun,
        applied: applied,
      );
    }

    final nextCursor = page.docs.isEmpty ? cursor : page.docs.last.id;
    final finished = page.docs.length < size;
    await run.reference.set({
      'name': legacyQuestionMigrationName,
      'dryRun': dryRun,
      'batchSize': size,
      'cursorQuestionId': nextCursor,
      'finished': finished,
      'lastBatchAt': FieldValue.serverTimestamp(),
      if (finished) 'finishedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return LegacyMigrationBatch(
      runId: run.id,
      dryRun: dryRun,
      processed: reports,
      hasMore: !finished,
      nextCursorQuestionId: nextCursor,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _openRun({
    required bool dryRun,
    String? runId,
  }) async {
    if (runId != null && runId.trim().isNotEmpty) {
      final existing = await _runs.doc(runId.trim()).get();
      if (!existing.exists) throw StateError('No existe el proceso $runId.');
      if (existing.data()?['name'] != legacyQuestionMigrationName) {
        throw StateError('El proceso no corresponde a esta migración.');
      }
      if (existing.data()?['dryRun'] != dryRun) {
        throw StateError(
          'Un proceso no puede cambiar entre dry-run y escritura.',
        );
      }
      return existing;
    }
    final reference = _runs.doc();
    await reference.set({
      'name': legacyQuestionMigrationName,
      'dryRun': dryRun,
      'cursorQuestionId': '',
      'finished': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return reference.get();
  }

  Future<_LegacyInspection> _inspect(
    DocumentSnapshot<Map<String, dynamic>> root,
  ) async {
    final alternatives = await root.reference
        .collection(AppEnv.alternativesSubcollection)
        .get();
    final privateExplanation = await _legacyExplanations.doc(root.id).get();
    final source = await _verifiedSource(root.data()!);
    final values = alternatives.docs
        .map(
          (document) => <String, dynamic>{
            ...document.data(),
            'id': document.id,
          },
        )
        .toList(growable: false);
    return _LegacyInspection(
      LegacyQuestionMigrationPlan.build(
        questionId: root.id,
        root: root.data()!,
        alternatives: values,
        privateExplanation: privateExplanation.exists
            ? privateExplanation.data()
            : null,
        verifiedSourceExam: source,
      ),
      values,
      privateExplanation.exists ? privateExplanation.data() : null,
    );
  }

  /// Catalog IDs must be supplied by the legacy record and point to the exact
  /// canonical document. Names, labels, years and modalities are never parsed
  /// or inferred from legacy text.
  Future<SourceExam?> _verifiedSource(Map<String, dynamic> root) async {
    final embedded = root['admissionExam'];
    final raw = embedded is Map
        ? Map<String, dynamic>.from(embedded)
        : const <String, dynamic>{};
    final universityId = (raw['universityId'] ?? root['universityId'] ?? '')
        .toString()
        .trim();
    final examId = (raw['id'] ?? root['examId'] ?? '').toString().trim();
    if (universityId.isEmpty || examId.isEmpty) return null;
    final catalog = await db
        .collection(AppEnv.universitiesCollection)
        .doc(universityId)
        .collection('admissionExams')
        .doc(examId)
        .get();
    if (!catalog.exists) return null;
    try {
      final exam = AdmissionExam.fromJson(catalog.data()!);
      if (exam.id != examId || exam.universityId != universityId) return null;
      return exam.source;
    } on FormatException {
      return null;
    }
  }

  Future<bool> _apply(
    LegacyQuestionMigrationPlan plan,
    DocumentReference<Map<String, dynamic>> root,
    String runId,
  ) async {
    final question = plan.question!;
    final key = plan.answerKey;
    return db.runTransaction((transaction) async {
      final current = await transaction.get(root);
      if (!current.exists) return false;
      final marker = current.data()?['migration'];
      if (current.data()?['schemaVersion'] == 2 ||
          (marker is Map && marker['name'] == legacyQuestionMigrationName)) {
        return false;
      }
      final keyReference = _answerKeys.doc('${question.ref.questionId}_1');
      final currentKey = await transaction.get(keyReference);
      final fields = _publicFields(question, current.data()!, runId);
      transaction.set(root, fields, SetOptions(merge: true));
      // Do not overwrite an independently-created private key. The preserved
      // legacy data and run report make that conflict visible to the editor.
      if (key != null && !currentKey.exists) {
        transaction.set(keyReference, {
          ...key.toJson(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'migration': {'name': legacyQuestionMigrationName, 'runId': runId},
        });
      }
      return true;
    });
  }

  Map<String, dynamic> _publicFields(
    QuestionDocument question,
    Map<String, dynamic> original,
    String runId,
  ) {
    final source = question.sourceExam;
    final tokens = QuestionBankSearch.tokens([
      question.ref.questionId,
      (original['number'] ?? '').toString(),
      (original['statementText'] ?? '').toString(),
      question.sourceLabel,
      source?.id ?? '',
    ]);
    return {
      ...question.toJson(),
      // Set it explicitly as well as retaining the legacy field through merge:
      // some older Firestore emulators used for editorial imports did not
      // preserve omitted fields in a transaction merge consistently.
      if (original.containsKey('statementText'))
        'statementText': original['statementText'],
      'questionId': question.ref.questionId,
      'sourceExamId': source?.id ?? '',
      'universityId': source?.universityId ?? '',
      'modalityId': source?.modalityId ?? '',
      'year': source?.year,
      'period': source?.period ?? '',
      'sourceLabel': question.sourceLabel,
      'searchTokens': tokens,
      'partSearchTokens': QuestionBankSearch.partTokens(
        question.partIds,
        tokens,
      ),
      'updatedAt': FieldValue.serverTimestamp(),
      if (original['createdAt'] == null)
        'createdAt': FieldValue.serverTimestamp(),
      'migration': {
        'name': legacyQuestionMigrationName,
        'runId': runId,
        'state': 'migrated_draft',
        'legacyFieldsRetained': true,
        'legacyAlternativesRetainedAt':
            '${AppEnv.questionsCollection}/${question.ref.questionId}/${AppEnv.alternativesSubcollection}',
        'legacyExplanationRetainedAt':
            '${AppEnv.legacyQuestionEditorPrivateCollection}/${question.ref.questionId}',
        'originalStatementText': original['statementText'] ?? '',
        'originalNumber': original['originalNumber'] ?? original['number'],
        'originalExamId': original['examId'] ?? '',
        'migratedAt': FieldValue.serverTimestamp(),
      },
    };
  }

  Future<void> _saveReport(
    DocumentSnapshot<Map<String, dynamic>> run,
    DocumentSnapshot<Map<String, dynamic>> root,
    _LegacyInspection inspection, {
    required bool dryRun,
    required bool applied,
  }) async {
    final reference = run.reference.collection('items').doc(root.id);
    final existing = await reference.get();
    if (inspection.plan.disposition ==
            LegacyMigrationDisposition.alreadyMigrated &&
        existing.exists) {
      return;
    }
    await reference.set({
      'questionId': root.id,
      'disposition': inspection.plan.disposition.name,
      'issues': inspection.plan.issues,
      'dryRun': dryRun,
      'wouldCreateAnswerKey': inspection.plan.answerKey != null,
      'applied': applied,
      'affectedPaths': [
        '${AppEnv.questionsCollection}/${root.id}',
        '${AppEnv.questionsCollection}/${root.id}/${AppEnv.alternativesSubcollection}',
        '${AppEnv.legacyQuestionEditorPrivateCollection}/${root.id}',
      ],
      // This is a compact logical backup. The original root and every legacy
      // subcollection document are also retained in place, never deleted.
      'originalFields': {
        'statementText': root.data()?['statementText'] ?? '',
        'number': root.data()?['number'],
        'originalNumber': root.data()?['originalNumber'],
        'examId': root.data()?['examId'] ?? '',
        'universityId': root.data()?['universityId'] ?? '',
        'label': root.data()?['label'] ?? '',
        'alternativeIds': inspection.alternatives
            .map((alternative) => alternative['id'])
            .toList(growable: false),
        'hasPrivateExplanation': inspection.privateExplanation != null,
      },
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class LegacyMigrationBatch {
  const LegacyMigrationBatch({
    required this.runId,
    required this.dryRun,
    required this.processed,
    required this.hasMore,
    required this.nextCursorQuestionId,
  });

  final String runId;
  final bool dryRun, hasMore;
  final String nextCursorQuestionId;
  final List<LegacyMigrationItemReport> processed;
}

class LegacyMigrationItemReport {
  const LegacyMigrationItemReport({
    required this.questionId,
    required this.disposition,
    required this.issues,
    required this.wouldCreateAnswerKey,
    required this.applied,
  });

  final String questionId;
  final LegacyMigrationDisposition disposition;
  final List<String> issues;
  final bool wouldCreateAnswerKey, applied;
}

class _LegacyInspection {
  const _LegacyInspection(
    this.plan,
    this.alternatives,
    this.privateExplanation,
  );

  final LegacyQuestionMigrationPlan plan;
  final List<Map<String, dynamic>> alternatives;
  final Map<String, dynamic>? privateExplanation;
}
