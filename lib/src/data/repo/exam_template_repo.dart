import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/question_contract/question_contract.dart';
import '../../domain/exam_template_record.dart';
import '../../env/app_env.dart';

class ExamTemplateRepo {
  ExamTemplateRepo(this.db);

  final FirebaseFirestore db;
  static const _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _templates =>
      db.collection(AppEnv.examTemplatesCollection);

  Stream<List<ExamTemplateRecord>> watchTemplates() =>
      _templates.orderBy('updatedAt', descending: true).snapshots().map((snap) {
        final records = <ExamTemplateRecord>[];
        for (final document in snap.docs) {
          try {
            records.add(_record(document));
          } on FormatException {
            // Old/incomplete records remain in Firestore but are not offered as
            // selectable v2 templates until an editor repairs them.
          }
        }
        return records;
      });

  Future<ExamTemplateRecord?> read(String templateId) async {
    final snapshot = await _templates.doc(templateId).get();
    if (!snapshot.exists) return null;
    return _record(snapshot);
  }

  /// Every edit gets a fresh immutable version. Existing attempts keep their
  /// stored template snapshot/version and never consult this mutable root.
  Future<ExamTemplate> save(ExamTemplate requested) async {
    final root = _templates.doc(
      requested.id.isEmpty ? _uuid.v4() : requested.id,
    );
    return db.runTransaction((transaction) async {
      final existing = await transaction.get(root);
      final previousVersion = _integer(existing.data()?['version']) ?? 0;
      final nextVersion = previousVersion + 1;
      final template = ExamTemplate.fromJson({
        ...requested.toJson(),
        'id': root.id,
        'version': nextVersion,
      });
      await _validateReferences(transaction, template);
      final version = root
          .collection(AppEnv.templateVersionsSubcollection)
          .doc('$nextVersion');
      if ((await transaction.get(version)).exists) {
        throw StateError(
          'La versión de plantilla ya existe. Recarga e intenta nuevamente.',
        );
      }
      final fields = <String, dynamic>{
        ...template.toJson(),
        // `published` means structurally usable by Functions; `active` is the
        // switch that controls whether it can create new attempts.
        'status': 'published',
        'active': template.active,
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final rootFields = <String, dynamic>{
        ...fields,
        if (existing.exists && template.description.isEmpty)
          'description': FieldValue.delete(),
        if (existing.exists && template.priorityUniversityId.isEmpty)
          'priorityUniversityId': FieldValue.delete(),
      };
      transaction.set(version, {
        ...fields,
        'createdAt':
            existing.data()?['createdAt'] ?? FieldValue.serverTimestamp(),
        'versionedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(root, rootFields, SetOptions(merge: true));
      return template;
    });
  }

  Future<ExamTemplate> setActive(ExamTemplate template, bool active) {
    return save(
      ExamTemplate.fromJson({...template.toJson(), 'active': active}),
    );
  }

  ExamTemplateRecord _record(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) throw const FormatException('Missing template');
    return ExamTemplateRecord(
      template: ExamTemplate.fromJson({...data, 'id': snapshot.id}),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  Future<void> _validateReferences(
    Transaction transaction,
    ExamTemplate template,
  ) async {
    if (template.priorityUniversityId.isNotEmpty) {
      await _requireActive(
        transaction.get(
          db
              .collection(AppEnv.universitiesCollection)
              .doc(template.priorityUniversityId),
        ),
        'La universidad prioritaria',
      );
    }
    if (template.mode == 'fixed') {
      for (final question in template.fixedQuestions) {
        final root = db
            .collection(AppEnv.questionsCollection)
            .doc(question.questionId);
        final version = root
            .collection(AppEnv.questionVersionsSubcollection)
            .doc('${question.version}');
        final snapshots = await Future.wait([
          transaction.get(root),
          transaction.get(version),
        ]);
        if (!snapshots[0].exists ||
            !snapshots[1].exists ||
            snapshots[1].data()?['status'] != 'published') {
          throw StateError(
            'La pregunta fija ${question.questionId} v${question.version} no existe o no está publicada.',
          );
        }
      }
      return;
    }
    for (final block in template.blocks) {
      await _validateFilter(transaction, block.filter);
    }
  }

  Future<void> _validateFilter(
    Transaction transaction,
    ExamFilter filter,
  ) async {
    if (filter.sourceExamId.isNotEmpty && filter.universityId.isEmpty) {
      throw StateError(
        'Un examen de origen requiere una universidad en el mismo bloque.',
      );
    }
    if (filter.modalityId.isNotEmpty && filter.universityId.isEmpty) {
      throw StateError(
        'Una modalidad requiere una universidad en el mismo bloque.',
      );
    }
    if (filter.universityId.isNotEmpty) {
      final university = db
          .collection(AppEnv.universitiesCollection)
          .doc(filter.universityId);
      await _requireActive(
        transaction.get(university),
        'La universidad del bloque',
      );
      if (filter.modalityId.isNotEmpty) {
        await _requireActive(
          transaction.get(
            university
                .collection(AppEnv.modesSubcollection)
                .doc(filter.modalityId),
          ),
          'La modalidad del bloque',
        );
      }
      if (filter.sourceExamId.isNotEmpty) {
        await _requireActive(
          transaction.get(
            university.collection('admissionExams').doc(filter.sourceExamId),
          ),
          'El examen de origen del bloque',
        );
      }
    }
    if (filter.topicId.isNotEmpty && filter.courseId.isEmpty ||
        filter.subtopicId.isNotEmpty &&
            (filter.courseId.isEmpty || filter.topicId.isEmpty) ||
        filter.partId.isNotEmpty &&
            (filter.courseId.isEmpty ||
                filter.topicId.isEmpty ||
                filter.subtopicId.isEmpty)) {
      throw StateError(
        'La clasificación del bloque debe respetar curso, tema, subtema y parte.',
      );
    }
    if (filter.courseId.isEmpty) return;
    final course = db.collection(AppEnv.coursesCollection).doc(filter.courseId);
    await _requireActive(transaction.get(course), 'El curso del bloque');
    if (filter.topicId.isEmpty) return;
    final topic = course
        .collection(AppEnv.topicsSubcollection)
        .doc(filter.topicId);
    await _requireActive(transaction.get(topic), 'El tema del bloque');
    if (filter.subtopicId.isEmpty) return;
    final subtopic = topic
        .collection(AppEnv.subtopicsSubcollection)
        .doc(filter.subtopicId);
    final subtopicSnapshot = await transaction.get(subtopic);
    _requireActiveSnapshot(subtopicSnapshot, 'El subtema del bloque');
    if (filter.partId.isEmpty) return;
    final parts = subtopicSnapshot.data()?['listPart'];
    final part = _partById(parts, filter.partId);
    if (part == null || part['active'] == false) {
      throw StateError(
        'La parte del bloque no existe, está inactiva o no pertenece al subtema.',
      );
    }
  }

  Future<void> _requireActive(
    Future<DocumentSnapshot<Map<String, dynamic>>> future,
    String label,
  ) async => _requireActiveSnapshot(await future, label);

  void _requireActiveSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    String label,
  ) {
    if (!snapshot.exists || snapshot.data()?['active'] == false) {
      throw StateError('$label no existe o está inactivo.');
    }
  }

  Map<dynamic, dynamic>? _partById(dynamic value, String partId) {
    if (value is! List) return null;
    for (final item in value) {
      if (item is Map && item['id'] == partId) return item;
    }
    return null;
  }

  int? _integer(dynamic value) => value is num ? value.toInt() : null;

  DateTime? _date(dynamic value) => value is Timestamp ? value.toDate() : null;
}
