import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/admission_exam.dart';
import '../../env/app_env.dart';

class ExamCatalogException implements Exception {
  const ExamCatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExamSyncPending extends ExamCatalogException {
  const ExamSyncPending(this.exam)
    : super(
        'El examen se guardó, pero falta actualizar algunas preguntas vinculadas. Reintenta la actualización.',
      );
  final AdmissionExam exam;
}

class AdmissionExamRepo {
  AdmissionExamRepo(this.db);
  final FirebaseFirestore db;
  CollectionReference<Map<String, dynamic>> exams(String universityId) => db
      .collection(AppEnv.universitiesCollection)
      .doc(universityId)
      .collection('admissionExams');

  Stream<List<AdmissionExam>> watch(String universityId) => exams(universityId)
      .orderBy('year', descending: true)
      .snapshots()
      .map((snapshot) {
        final result = snapshot.docs
            .map((doc) => AdmissionExam.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
        result.sort((a, b) {
          final year = b.year.compareTo(a.year);
          return year != 0 ? year : a.name.compareTo(b.name);
        });
        return result;
      });

  Future<void> save(AdmissionExam exam) async {
    final uni = db
        .collection(AppEnv.universitiesCollection)
        .doc(exam.universityId);
    final target = exams(exam.universityId).doc(exam.id);
    final reservation = uni
        .collection('admissionExamKeys')
        .doc(exam.convocatoriaKey);
    // Check pre-reservation records as well. Re-read candidates inside the transaction.
    final legacyCandidates = await exams(
      exam.universityId,
    ).where('year', isEqualTo: exam.year).get();
    final saved = await db.runTransaction<AdmissionExam>((transaction) async {
      final university = await transaction.get(uni);
      final mode = await transaction.get(
        uni.collection(AppEnv.modesSubcollection).doc(exam.modalityId),
      );
      final current = await transaction.get(target);
      final reserved = await transaction.get(reservation);
      if (!university.exists || !mode.exists) {
        throw const ExamCatalogException(
          'La universidad o modalidad ya no existe.',
        );
      }
      final old = current.exists
          ? AdmissionExam.fromJson(current.data()!)
          : null;
      if ((old?.revision ?? 0) != exam.revision) {
        throw const ExamCatalogException(
          'Otro administrador modificó el examen. Cierra y vuelve a abrirlo para cargar sus datos actuales.',
        );
      }
      if (reserved.exists && reserved.data()!['examId'] != exam.id) {
        throw const ExamCatalogException(
          'Ya existe un examen para esta modalidad, tipo, año y período. Edita el existente.',
        );
      }
      for (final candidate in legacyCandidates.docs) {
        if (candidate.id == exam.id) continue;
        final fresh = await transaction.get(candidate.reference);
        if (fresh.exists &&
            AdmissionExam.fromJson({
                  ...fresh.data()!,
                  'id': fresh.id,
                }).convocatoriaKey ==
                exam.convocatoriaKey) {
          throw const ExamCatalogException(
            'Ya existe un examen para esta modalidad, tipo, año y período. Edita el existente.',
          );
        }
      }
      if ((university.data()!['active'] == false ||
              mode.data()!['active'] == false) &&
          (old == null || old.modalityId != exam.modalityId)) {
        throw const ExamCatalogException(
          'Selecciona una universidad y una modalidad activas.',
        );
      }
      final updated = AdmissionExam.fromJson({
        ...exam.toJson(),
        'universityName': university.data()!['name'],
        'universityAcronym': university.data()!['acronym'],
        'modalityName': mode.data()!['name'],
        'revision': (old?.revision ?? 0) + 1,
        'syncPending': true,
      });
      final previousKey =
          old != null && old.convocatoriaKey != exam.convocatoriaKey
          ? uni.collection('admissionExamKeys').doc(old.convocatoriaKey)
          : null;
      final previousReservation = previousKey == null
          ? null
          : await transaction.get(previousKey);
      if (previousReservation?.data()?['examId'] == exam.id) {
        transaction.delete(previousKey!);
      }
      transaction.set(reservation, {'examId': exam.id});
      final data = <String, dynamic>{
        ...updated.toJson(),
        'syncPending': true,
        if (!current.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (current.exists) {
        transaction.update(target, data);
      } else {
        transaction.set(target, data);
      }
      return updated;
    });
    try {
      await synchronizeQuestions(saved.universityId, saved.id);
    } catch (_) {
      throw ExamSyncPending(saved);
    }
  }

  /// Safe to restart after interruption. Each page reads the latest catalog version
  /// and verifies question ownership before writing, so concurrent edits survive.
  Future<void> synchronizeQuestions(String universityId, String examId) async {
    final target = exams(universityId).doc(examId);
    final initial = await target.get();
    if (!initial.exists) {
      throw const ExamCatalogException('El examen ya no existe.');
    }
    final revision = (initial.data()!['revision'] as num?)?.toInt() ?? 0;
    QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
    while (true) {
      Query<Map<String, dynamic>> query = db
          .collection(AppEnv.questionsCollection)
          .where('examId', isEqualTo: examId)
          .orderBy(FieldPath.documentId);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final page = await query.limit(100).get();
      if (page.docs.isEmpty) break;
      await db.runTransaction((transaction) async {
        final catalog = await transaction.get(target);
        if (!catalog.exists) {
          throw const ExamCatalogException('El examen ya no existe.');
        }
        final currentExam = AdmissionExam.fromJson(catalog.data()!);
        final questions = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final doc in page.docs) {
          questions.add(await transaction.get(doc.reference));
        }
        for (final question in questions) {
          final data = question.data();
          // Do not infer a legacy question's university just from an examId.
          if (data == null ||
              data['examId'] != examId ||
              data['universityId'] != universityId) {
            continue;
          }
          if (data['sourceExamRevision'] == currentExam.revision) continue;
          transaction.update(question.reference, {
            ...currentExam.questionFields,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      cursor = page.docs.last;
      if (page.docs.length < 100) break;
    }
    await db.runTransaction((transaction) async {
      final latest = await transaction.get(target);
      if (!latest.exists || latest.data()!['revision'] != revision) {
        throw const ExamCatalogException(
          'El examen cambió durante la actualización. Vuelve a sincronizar.',
        );
      }
      transaction.update(target, {
        'syncPending': false,
        'syncedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
