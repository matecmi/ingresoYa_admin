import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ingresoya_admin/src/domain/entities/course_entity.dart';
import 'package:ingresoya_admin/src/domain/entities/topic_entity.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:uuid/uuid.dart';

class CourseRepo {
  CourseRepo(this.db);
  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection(AppEnv.coursesCollection);

  // ---------------- COURSES ----------------

  Stream<List<CourseEntity>> watchCourses() {
    return _col.orderBy('name').snapshots().map((snap) {
      return snap.docs.map((d) {
        final x = d.data();
        return CourseEntity(
          id: d.id,
          idDoc: (x['idDoc'] ?? d.id).toString(),
          name: (x['name'] ?? '').toString(),
          description: (x['description'] ?? '').toString(),
          topics: const [],
        );
      }).toList();
    });
  }

  Future<String> createCourse({
    required String name,
    required String description,
  }) async {
    final id = const Uuid().v4();
    await _col.doc(id).set({
      'idDoc': id,
      'name': name.trim(),
      'description': description.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  Future<void> updateCourse(String courseId, {required Map<String, dynamic> patch}) async {
    patch['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(courseId).update(patch);
  }

  Future<void> deleteCourse(String courseId) async {
    final courseRef = _col.doc(courseId);

    // borra topics + subtopics
    final topics = await courseRef.collection(AppEnv.topicsSubcollection).get();

    final batch = db.batch();
    for (final t in topics.docs) {
      final sub = await t.reference.collection(AppEnv.subtopicsSubcollection).get();
      for (final s in sub.docs) {
        batch.delete(s.reference);
      }
      batch.delete(t.reference);
    }
    batch.delete(courseRef);
    await batch.commit();
  }

  // ---------------- TOPICS ----------------

  Stream<List<TopicEntity>> watchTopics(String courseId) {
    final ref = _col.doc(courseId).collection(AppEnv.topicsSubcollection);
    return ref.orderBy('order').snapshots().map((snap) {
      return snap.docs.map((d) {
        final x = d.data();
        return TopicEntity(
          id: d.id,
          name: (x['name'] ?? '').toString(),
          description: (x['description'] ?? '').toString(),
                  order: (x['order'] ?? 0) is int
            ? x['order']
            : int.tryParse(x['order'].toString()) ?? 0,
          summary: (x['summary'] ?? '').toString(),
          subtopics: const [],
        );
      }).toList();
    });
  }

  Future<void> upsertTopic({
    required String courseId,
    String? topicId,
    required String name,
    required String description,
    required int order,
    required String summary,
  }) async {
    final ref = _col.doc(courseId).collection(AppEnv.topicsSubcollection);
    final id = topicId ?? const Uuid().v4();

    await ref.doc(id).set({
      'name': name.trim(),
      'description': description.trim(),
      'order': order,
      'summary': summary.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (topicId == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteTopic({
    required String courseId,
    required String topicId,
  }) async {
    final topicRef = _col.doc(courseId).collection(AppEnv.topicsSubcollection).doc(topicId);

    final subs = await topicRef.collection(AppEnv.subtopicsSubcollection).get();
    final batch = db.batch();
    for (final s in subs.docs) {
      batch.delete(s.reference);
    }
    batch.delete(topicRef);
    await batch.commit();
  }

  // ---------------- SUBTOPICS ----------------

  Stream<List<SubtopicEntity>> watchSubtopics({
    required String courseId,
    required String topicId,
  }) {
    final ref = _col
        .doc(courseId)
        .collection(AppEnv.topicsSubcollection)
        .doc(topicId)
        .collection(AppEnv.subtopicsSubcollection);

    return ref.orderBy('order').snapshots().map((snap) {
      return snap.docs.map((d) {
        final x = d.data();
        return SubtopicEntity(
          id: d.id,
          idTopic: topicId,
          name: (x['name'] ?? '').toString(),
          content: (x['content'] ?? '').toString(),
                  order: (x['order'] ?? 0) is int
            ? x['order']
            : int.tryParse(x['order'].toString()) ?? 0,
          linkVideo: (x['linkVideo'] ?? '').toString(),
        );
      }).toList();
    });
  }

  Future<void> upsertSubtopic({
    required String courseId,
    required String topicId,
    String? subtopicId,
    required String name,
    required String content,
    required int order,
    required String linkVideo,
  }) async {
    final ref = _col
        .doc(courseId)
        .collection(AppEnv.topicsSubcollection)
        .doc(topicId)
        .collection(AppEnv.subtopicsSubcollection);

    final id = subtopicId ?? const Uuid().v4();

    await ref.doc(id).set({
      'name': name.trim(),
      'content': content.trim(),
      'order': order,
      'linkVideo': linkVideo.trim(),
      'idTopic': topicId, // opcional para consulta
      'updatedAt': FieldValue.serverTimestamp(),
      if (subtopicId == null) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteSubtopic({
    required String courseId,
    required String topicId,
    required String subtopicId,
  }) async {
    await _col
        .doc(courseId)
        .collection(AppEnv.topicsSubcollection)
        .doc(topicId)
        .collection(AppEnv.subtopicsSubcollection)
        .doc(subtopicId)
        .delete();
  }

  // ---------------- JSON IMPORT (Courses) ----------------
  bool _toBool(dynamic v, {bool fallback = true}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    if (s == 'true' || s == '1' || s == 'y' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'n' || s == 'no') return false;
    return fallback;
  }

  List<Map<String, dynamic>> parseJsonListOrThrow(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw Exception('El JSON debe ser una LISTA []');
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// ✅ Import masivo de cursos: [{idDoc?, name, description}]
  Future<void> bulkUpsertCoursesFromJsonList(List<Map<String, dynamic>> list) async {
    const chunkSize = 400;
    for (var i = 0; i < list.length; i += chunkSize) {
      final chunk = list.sublist(i, (i + chunkSize > list.length) ? list.length : i + chunkSize);
      final batch = db.batch();

      for (final item in chunk) {
        final idDocRaw = (item['idDoc'] ?? item['id'] ?? '').toString().trim();
        final docId = idDocRaw.isNotEmpty ? idDocRaw : const Uuid().v4();

        final name = (item['name'] ?? '').toString().trim();
        if (name.isEmpty) throw Exception('Falta "name" en un item (idDoc=$docId)');

        final patch = <String, dynamic>{
          'idDoc': docId,
          'name': name,
          'description': (item['description'] ?? '').toString().trim(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };

        batch.set(_col.doc(docId), patch, SetOptions(merge: true));
      }

      await batch.commit();
    }
  }
}
