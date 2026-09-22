import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/editor_document.dart';
import '../../domain/entities/admission_exam.dart';
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

  // ✅ Lista de preguntas (SIN alternatives, para performance)
  Stream<List<QuestionEntity>> watchQuestions() {
    return _col.orderBy('number').snapshots().map((snap) {
      return snap.docs.map((doc) {
        final d = doc.data();

        return QuestionEntity(
          admissionExam: d['admissionExam'] == null
              ? null
              : AdmissionExam.fromJson(
                  Map<String, dynamic>.from(d['admissionExam']),
                ),
          id: doc.id,
          number: (d['number'] ?? 0) is int
              ? (d['number'] ?? 0) as int
              : int.tryParse((d['number'] ?? '0').toString()) ?? 0,
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
          examId: (d['examId'] ?? '').toString(),
          difficulty: (d['difficulty'] ?? 'unknown').toString(),
          originalNumber: (d['originalNumber'] as num?)?.toInt(),
          editorialStatus: (d['status'] ?? 'draft').toString(),
          version: (d['version'] as num?)?.toInt() ?? 1,
          alternatives: const [], // 👈 no cargar en list
        );
      }).toList();
    });
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
    required String courseId,
    required String courseName,
    required String examId, // puede ser ""
    String? label, // opcional
  }) async {
    final id = const Uuid().v4();

    await _writeQuestion(_col.doc(id), {
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
    }, create: true);

    return id;
  }

  Future<void> updateQuestion(
    String id, {
    required Map<String, dynamic> patch,
  }) async {
    await _writeQuestion(_col.doc(id), {
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    }, create: false);
  }

  Future<void> _writeQuestion(
    DocumentReference<Map<String, dynamic>> target,
    Map<String, dynamic> fields, {
    required bool create,
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
    if (fields.containsKey('subtopicId') || fields.containsKey('partIds')) {
      final combined = <String, dynamic>{...?previousData, ...data};
      await AcademicContextValidator.validate(
        db,
        transaction,
        courseId: (combined['courseId'] ?? '').toString().trim(),
        topicId: (combined['topicId'] ?? '').toString().trim(),
        subtopicId: (combined['subtopicId'] ?? '').toString().trim(),
        partIds: _stringList(combined['partIds']),
        requireComplete: true,
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
}
