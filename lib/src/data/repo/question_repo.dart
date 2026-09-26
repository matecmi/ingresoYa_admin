import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/editor_document.dart';
import '../../domain/entities/admission_exam.dart';
import '../../domain/question_bank_filter.dart';
import 'academic_context_validator.dart';
import '../../../shared/question_contract/question_contract.dart';

import 'package:ingresoya_admin/src/domain/entities/question_entity.dart';
import 'package:ingresoya_admin/src/domain/entities/alternative_entity.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

class QuestionRepo {
  QuestionRepo(this.db);
  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection(AppEnv.questionsCollection);

  static const questionBankPageSize = 25;

  // ✅ Lista de preguntas (SIN alternatives, para performance)
  Stream<List<QuestionEntity>> watchQuestions() {
    return _col.orderBy('number').snapshots().map((snap) {
      return snap.docs.map(_toQuestion).toList();
    });
  }

  /// Reads one bounded server-side page. The result cursor is the final
  /// document returned by this query, never an offset or locally filtered row.
  Future<QuestionBankPage> fetchQuestionPage(
    QuestionBankFilter filter, {
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    Query<Map<String, dynamic>> query = _col;
    if (filter.status.isNotEmpty) {
      query = query.where('status', isEqualTo: filter.status);
    }
    if (filter.universityId.isNotEmpty) {
      query = query.where('universityId', isEqualTo: filter.universityId);
    }
    if (filter.sourceExamId.isNotEmpty) {
      query = query.where('sourceExamId', isEqualTo: filter.sourceExamId);
    }
    if (filter.sourceType.isNotEmpty) {
      query = query.where('sourceType', isEqualTo: filter.sourceType);
    }
    if (filter.modalityId.isNotEmpty) {
      query = query.where('modalityId', isEqualTo: filter.modalityId);
    }
    if (filter.courseId.isNotEmpty) {
      query = query.where('courseId', isEqualTo: filter.courseId);
    }
    if (filter.topicId.isNotEmpty) {
      query = query.where('topicId', isEqualTo: filter.topicId);
    }
    if (filter.subtopicId.isNotEmpty) {
      query = query.where('subtopicId', isEqualTo: filter.subtopicId);
    }
    if (filter.difficulty.isNotEmpty) {
      query = query.where('difficulty', isEqualTo: filter.difficulty);
    }
    final token = QuestionBankSearch.queryToken(filter.text);
    if (filter.partId.isNotEmpty && token != null) {
      query = query.where(
        'partSearchTokens',
        arrayContains: '${filter.partId}|$token',
      );
    } else if (filter.partId.isNotEmpty) {
      query = query.where('partIds', arrayContains: filter.partId);
    } else if (token != null) {
      query = query.where('searchTokens', arrayContains: token);
    }
    if (filter.yearFrom != null) {
      query = query.where('year', isGreaterThanOrEqualTo: filter.yearFrom);
    }
    if (filter.yearTo != null) {
      query = query.where('year', isLessThanOrEqualTo: filter.yearTo);
    }
    if (filter.hasYearRange) {
      query = query.orderBy('year').orderBy('updatedAt', descending: true);
    } else {
      query = query.orderBy('updatedAt', descending: true);
    }
    query = query.orderBy(FieldPath.documentId, descending: true);
    if (after != null) query = query.startAfterDocument(after);

    final snapshot = await query.limit(questionBankPageSize + 1).get();
    final hasMore = snapshot.docs.length > questionBankPageSize;
    final docs = snapshot.docs.take(questionBankPageSize).toList();
    return QuestionBankPage(
      items: docs.map(_toQuestion).toList(growable: false),
      nextCursor: docs.isEmpty ? null : docs.last,
      hasMore: hasMore,
    );
  }

  // ✅ Watch alternativas por pregunta
  Stream<List<AlternativeEntity>> watchAlternatives(String questionId) {
    final ref = _col
        .doc(questionId)
        .collection(AppEnv.alternativesSubcollection)
        .orderBy('value');
    return ref.snapshots().map((snap) {
      return snap.docs.map((doc) {
        final d = doc.data();
        return AlternativeEntity(
          id: doc.id,
          value: (d['value'] ?? '').toString(),
          descriptionText: (d['descriptionText'] ?? '').toString(),
          editorContent: EditorDocument.read(
            d,
            (d['descriptionText'] ?? '').toString(),
          ),
          isCorrect: (d['isCorrect'] ?? 'N').toString(),
          questionId: questionId,
        );
      }).toList();
    });
  }

  Future<String> createQuestion({
    EditorDocument? editorContent,
    AdmissionExam? admissionExam,
    required int number,
    required String statementText,
    required String active,
    required String topicId,
    required String topicName,
    String? subtopicId,
    String? subtopicName,
    List<String>? partIds,
    Map<String, String>? partNames,
    String difficulty = 'unknown',
    int? originalNumber,
    bool requireCompleteAcademic = true,
    required String courseId,
    required String courseName,
    required String examId, // puede ser ""
    String? label, // opcional
  }) async {
    final id = const Uuid().v4();

    await _writeQuestion(
      _col.doc(id),
      {
        'idDoc': id,
        'number': number,
        'label': (label ?? '').trim(),
        'statementText': statementText,
        if (editorContent != null) ...editorContent.toFields(),
        'active': active,
        'topicId': topicId,
        'topicName': topicName,
        if (subtopicId != null) 'subtopicId': subtopicId.trim(),
        if (subtopicName != null) 'subtopicName': subtopicName.trim(),
        if (partIds != null) 'partIds': List<String>.from(partIds),
        if (partNames != null) 'partNames': Map<String, String>.from(partNames),
        'difficulty': difficulty,
        if (originalNumber != null) 'originalNumber': originalNumber,
        'courseId': courseId,
        'courseName': courseName,
        'examId': examId.trim(), // puede ser ""
        if (admissionExam != null) ...admissionExam.questionFields,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      create: true,
      requireCompleteAcademic: requireCompleteAcademic,
    );

    return id;
  }

  Future<void> updateQuestion(
    String id, {
    required Map<String, dynamic> patch,
    bool requireCompleteAcademic = true,
  }) async {
    await _writeQuestion(
      _col.doc(id),
      {...patch, 'updatedAt': FieldValue.serverTimestamp()},
      create: false,
      requireCompleteAcademic: requireCompleteAcademic,
    );
  }

  Future<void> _writeQuestion(
    DocumentReference<Map<String, dynamic>> target,
    Map<String, dynamic> fields, {
    required bool create,
    required bool requireCompleteAcademic,
  }) => db.runTransaction((transaction) async {
    final previous = create ? null : await transaction.get(target);
    if (!create && previous?.exists != true) {
      throw StateError('La pregunta ya no existe.');
    }
    final previousData = previous?.data();
    final origin = fields['admissionExam'] ?? previousData?['admissionExam'];
    final data = <String, dynamic>{...fields};
    if (origin is Map) {
      final selected = AdmissionExam.fromJson(
        Map<String, dynamic>.from(origin),
      );
      final snapshot = await transaction.get(
        db
            .collection(AppEnv.universitiesCollection)
            .doc(selected.universityId)
            .collection('admissionExams')
            .doc(selected.id),
      );
      if (!snapshot.exists) {
        throw StateError('El examen seleccionado ya no existe.');
      }
      final latest = AdmissionExam.fromJson(snapshot.data()!);
      final sameOrigin =
          previousData?['examId'] == latest.id &&
          previousData?['universityId'] == latest.universityId;
      if (!latest.active && !sameOrigin) {
        throw StateError('El examen seleccionado está inactivo.');
      }
      data.addAll(latest.questionFields);
    }
    final indexedData = <String, dynamic>{...?previousData, ...data};
    final searchTokens = _searchTokens(indexedData, target.id);
    data['searchTokens'] = searchTokens;
    data['partSearchTokens'] = QuestionBankSearch.partTokens(
      _stringList(indexedData['partIds']),
      searchTokens,
    );
    if (fields.containsKey('subtopicId') || fields.containsKey('partIds')) {
      final combined = <String, dynamic>{...?previousData, ...data};
      await AcademicContextValidator.validate(
        db,
        transaction,
        courseId: (combined['courseId'] ?? '').toString().trim(),
        topicId: (combined['topicId'] ?? '').toString().trim(),
        subtopicId: (combined['subtopicId'] ?? '').toString().trim(),
        partIds: _stringList(combined['partIds']),
        requireComplete: requireCompleteAcademic,
      );
    }
    if (create) {
      transaction.set(target, data);
    } else {
      transaction.update(target, data);
    }
  });

  Future<void> deleteQuestion(String id) async {
    final ref = _col.doc(id);
    final alts = await ref.collection(AppEnv.alternativesSubcollection).get();

    final batch = db.batch();
    for (final d in alts.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_explanation(id));
    batch.delete(ref);

    await batch.commit();
  }

  // -------- alternatives CRUD --------

  Future<String> upsertAlternative({
    EditorDocument? editorContent,
    required String questionId,
    String? alternativeId,
    required String value, // A,B,C...
    required String descriptionText,
    required String isCorrect, // "Y" | "N"
  }) async {
    final id = alternativeId ?? const Uuid().v4();
    final target = _col
        .doc(questionId)
        .collection(AppEnv.alternativesSubcollection)
        .doc(id);
    final batch = db.batch();
    if (isCorrect == 'Y') {
      final others = await target.parent.get();
      for (final doc in others.docs) {
        if (doc.id != id) batch.update(doc.reference, {'isCorrect': 'N'});
      }
    }
    batch.set(target, {
      'value': value.trim(),
      'descriptionText': descriptionText,
      if (editorContent != null) ...editorContent.toFields(),
      'isCorrect': isCorrect,
      'updatedAt': FieldValue.serverTimestamp(),
      if (alternativeId == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await batch.commit();
    return id;
  }

  // Editorial explanations must never be placed under the public catalog tree.
  DocumentReference<Map<String, dynamic>> _explanation(String questionId) => db
      .collection('${AppEnv.questionsCollection}-editor-private')
      .doc(questionId);

  Future<EditorDocument> readExplanation(String questionId) async =>
      EditorDocument.read(
        (await _explanation(questionId).get()).data() ?? {},
        '',
      );

  Future<void> saveExplanation(String questionId, EditorDocument document) =>
      _explanation(questionId).set({
        ...document.toFields(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteAlternative({
    required String questionId,
    required String alternativeId,
  }) async {
    await _col
        .doc(questionId)
        .collection(AppEnv.alternativesSubcollection)
        .doc(alternativeId)
        .delete();
  }

  // ✅ marca SOLO una alternativa como correcta
  Future<void> setCorrectAlternative({
    required String questionId,
    required String alternativeId,
  }) async {
    final ref = _col
        .doc(questionId)
        .collection(AppEnv.alternativesSubcollection);

    final snap = await ref.get();
    final batch = db.batch();

    for (final d in snap.docs) {
      batch.update(d.reference, {
        'isCorrect': d.id == alternativeId ? 'Y' : 'N',
      });
    }

    await batch.commit();
  }

  /// Compatibility projection for the pre-v2 details screen. It only upserts
  /// edited alternatives and deliberately never deletes old subcollection
  /// documents; editorial migration is progressive and reversible.
  Future<void> mirrorV2Alternatives({
    required String questionId,
    required List<QuestionAlternative> alternatives,
    String? correctAlternativeId,
  }) async {
    final batch = db.batch();
    final collection = _col
        .doc(questionId)
        .collection(AppEnv.alternativesSubcollection);
    for (final alternative in alternatives) {
      final document = EditorDocument(alternative.content);
      batch.set(collection.doc(alternative.id), {
        'value': alternative.label,
        'descriptionText': document.legacy,
        ...document.toFields(),
        'isCorrect': alternative.id == correctAlternativeId ? 'Y' : 'N',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) return const {};
    return Map<String, String>.unmodifiable(
      value.map((key, item) => MapEntry(key.toString(), item.toString())),
    );
  }

  QuestionEntity _toQuestion(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    AdmissionExam? admissionExam;
    if (d['admissionExam'] is Map) {
      try {
        admissionExam = AdmissionExam.fromJson(
          Map<String, dynamic>.from(d['admissionExam'] as Map),
        );
      } on FormatException {
        // Old catalog copies remain visible as a warning instead of breaking
        // an entire page of the bank.
      }
    }
    final status = (d['status'] ?? 'draft').toString();
    return QuestionEntity(
      admissionExam: admissionExam,
      id: doc.id,
      number:
          (d['number'] as num?)?.toInt() ??
          int.tryParse((d['number'] ?? '0').toString()) ??
          0,
      label: (d['label'] ?? '').toString().trim().isEmpty
          ? null
          : (d['label'] ?? '').toString(),
      statementText: (d['statementText'] ?? '').toString(),
      editorContent: EditorDocument.read(
        d,
        (d['statementText'] ?? '').toString(),
      ),
      active: (d['active'] ?? 'Y').toString(),
      topicId: (d['topicId'] ?? '').toString(),
      topicName: (d['topicName'] ?? '').toString(),
      subtopicId: (d['subtopicId'] ?? '').toString(),
      subtopicName: (d['subtopicName'] ?? '').toString(),
      partIds: _stringList(d['partIds']),
      partNames: _stringMap(d['partNames']),
      courseId: (d['courseId'] ?? '').toString(),
      courseName: (d['courseName'] ?? '').toString(),
      examId: (d['examId'] ?? d['sourceExamId'] ?? '').toString(),
      difficulty: (d['difficulty'] ?? 'unknown').toString(),
      originalNumber: (d['originalNumber'] as num?)?.toInt(),
      editorialStatus: status,
      version: (d['version'] as num?)?.toInt() ?? 1,
      sourceType: (d['sourceType'] ?? 'unknown').toString(),
      sourceLabel: (d['sourceLabel'] ?? d['label'] ?? '').toString(),
      universityId: (d['universityId'] ?? '').toString(),
      modalityId: (d['modalityId'] ?? '').toString(),
      year: (d['year'] as num?)?.toInt(),
      period: (d['period'] ?? '').toString(),
      updatedAt: _date(d['updatedAt']),
      editorialWarnings: _warnings(d, status),
      alternatives: const [],
    );
  }

  static List<String> _searchTokens(Map<String, dynamic> data, String id) =>
      QuestionBankSearch.tokens([
        id,
        (data['number'] ?? '').toString(),
        (data['originalNumber'] ?? '').toString(),
        (data['statementText'] ?? '').toString(),
        (data['label'] ?? '').toString(),
        (data['courseName'] ?? '').toString(),
        (data['topicName'] ?? '').toString(),
        (data['subtopicName'] ?? '').toString(),
        (data['examId'] ?? '').toString(),
        (data['examName'] ?? '').toString(),
      ]);

  static DateTime? _date(dynamic value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    DateTime date => date,
    _ => null,
  };

  static List<String> _warnings(Map<String, dynamic> data, String status) {
    final warnings = <String>[];
    if (!data.containsKey('status')) warnings.add('Registro legacy pendiente');
    if (status == 'draft') warnings.add('Borrador sin publicar');
    if (status == 'retired') warnings.add('Retirada de nuevos exámenes');
    if ((data['difficulty'] ?? 'unknown') == 'unknown') {
      warnings.add('Dificultad pendiente');
    }
    if ((data['courseId'] ?? '').toString().isEmpty ||
        (data['topicId'] ?? '').toString().isEmpty ||
        (data['subtopicId'] ?? '').toString().isEmpty ||
        _stringList(data['partIds']).isEmpty) {
      warnings.add('Clasificación incompleta');
    }
    if ((data['sourceType'] ?? 'unknown') == 'unknown') {
      warnings.add('Procedencia pendiente');
    }
    if (data['alternatives'] is List &&
        (data['alternatives'] as List).length < 2) {
      warnings.add('Alternativas incompletas');
    }
    return List.unmodifiable(warnings);
  }
}

class QuestionBankPage {
  const QuestionBankPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<QuestionEntity> items;
  final DocumentSnapshot<Map<String, dynamic>>? nextCursor;
  final bool hasMore;
}
