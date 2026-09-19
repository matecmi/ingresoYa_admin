import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/admission_exam.dart';
import '../../env/app_env.dart';

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
    await db.runTransaction((transaction) async {
      final university = await transaction.get(uni);
      final mode = await transaction.get(
        uni.collection(AppEnv.modesSubcollection).doc(exam.modalityId),
      );
      final current = await transaction.get(
        exams(exam.universityId).doc(exam.id),
      );
      if (!university.exists || !mode.exists) {
        throw StateError('La universidad o modalidad ya no existe.');
      }
      transaction.set(exams(exam.universityId).doc(exam.id), {
        ...exam.toJson(),
        'universityName': university.data()!['name'],
        'universityAcronym': university.data()!['acronym'],
        'modalityName': mode.data()!['name'],
        if (!current.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
