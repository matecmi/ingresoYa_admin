import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/data/repo/course_repo.dart';
import 'package:ingresoya_admin/src/data/repo/profession_repo.dart';
import 'package:ingresoya_admin/src/data/repo/question_repo.dart';
import 'package:ingresoya_admin/src/data/repo/university_repo.dart';


final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final professionRepoProvider = Provider<ProfessionRepo>((ref) {
  return ProfessionRepo(ref.watch(firestoreProvider));
});

final universityRepoProvider = Provider<UniversityRepo>((ref) {
  return UniversityRepo(ref.watch(firestoreProvider));
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final courseRepoProvider = Provider<CourseRepo>((ref) {
  return CourseRepo(ref.read(firebaseFirestoreProvider));
});

final questionRepoProvider = Provider<QuestionRepo>((ref) {
  return QuestionRepo(FirebaseFirestore.instance);
});