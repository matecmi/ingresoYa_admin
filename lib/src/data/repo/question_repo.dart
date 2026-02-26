import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

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
          id: doc.id,
          number: (d['number'] ?? 0) is int
              ? (d['number'] ?? 0) as int
              : int.tryParse((d['number'] ?? '0').toString()) ?? 0,
          label: (d['label'] ?? '').toString().trim().isEmpty
              ? null
              : (d['label'] ?? '').toString(),
          statementText: (d['statementText'] ?? '').toString(),
          active: (d['active'] ?? 'Y').toString(),
          topicId: (d['topicId'] ?? '').toString(),
          topicName: (d['topicName'] ?? '').toString(),
          courseId: (d['courseId'] ?? '').toString(),
          courseName: (d['courseName'] ?? '').toString(),
          examId: (d['examId'] ?? '').toString(),
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
          isCorrect: (d['isCorrect'] ?? 'N').toString(),
          questionId: questionId,
        );
      }).toList();
    });
  }

  Future<String> createQuestion({
    required int number,
    required String statementText,
    required String active,
    required String topicId,
    required String topicName,
    required String courseId,
    required String courseName,
    required String examId, // puede ser ""
    String? label, // opcional
  }) async {
    final id = const Uuid().v4();

    await _col.doc(id).set({
      'idDoc': id,
      'number': number,
      'label': (label ?? '').trim(),
      'statementText': statementText,
      'active': active,
      'topicId': topicId,
      'topicName': topicName,
      'courseId': courseId,
      'courseName': courseName,
      'examId': examId.trim(), // puede ser ""
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return id;
  }

  Future<void> updateQuestion(
    String id, {
    required Map<String, dynamic> patch,
  }) async {
    patch['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(id).update(patch);
  }

  Future<void> deleteQuestion(String id) async {
    final ref = _col.doc(id);
    final alts = await ref.collection(AppEnv.alternativesSubcollection).get();

    final batch = db.batch();
    for (final d in alts.docs) {
      batch.delete(d.reference);
    }
    batch.delete(ref);

    await batch.commit();
  }

  // -------- alternatives CRUD --------

  Future<void> upsertAlternative({
    required String questionId,
    String? alternativeId,
    required String value, // A,B,C...
    required String descriptionText,
    required String isCorrect, // "Y" | "N"
  }) async {
    final id = alternativeId ?? const Uuid().v4();
    await _col
        .doc(questionId)
        .collection(AppEnv.alternativesSubcollection)
        .doc(id)
        .set({
      'value': value.trim(),
      'descriptionText': descriptionText,
      'isCorrect': isCorrect,
      'updatedAt': FieldValue.serverTimestamp(),
      if (alternativeId == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

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
    final ref = _col.doc(questionId).collection(AppEnv.alternativesSubcollection);

    final snap = await ref.get();
    final batch = db.batch();

    for (final d in snap.docs) {
      batch.update(d.reference, {'isCorrect': d.id == alternativeId ? 'Y' : 'N'});
    }

    await batch.commit();
  }
}