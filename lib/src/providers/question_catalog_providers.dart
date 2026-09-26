import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/course_entity.dart';
import '../domain/entities/topic_entity.dart';
import '../domain/entities/subtopic_entity.dart';
import '../domain/entities/university_entities.dart';
import '../domain/entities/admission_exam.dart';
import 'providers.dart';

final questionCoursesProvider = StreamProvider.autoDispose<List<CourseEntity>>(
  (ref) => ref.watch(courseRepoProvider).watchCourses(),
);
final questionTopicsProvider = StreamProvider.autoDispose
    .family<List<TopicEntity>, String>(
      (ref, id) => ref.watch(courseRepoProvider).watchTopics(id),
    );
final questionSubtopicsProvider = StreamProvider.autoDispose
    .family<List<SubtopicEntity>, ({String courseId, String topicId})>(
      (ref, context) => ref
          .watch(courseRepoProvider)
          .watchSubtopics(courseId: context.courseId, topicId: context.topicId),
    );
final questionUniversitiesProvider =
    StreamProvider.autoDispose<List<UniversityEntity>>(
      (ref) => ref.watch(universityRepoProvider).watchUniversities(),
    );
final universityModesProvider = StreamProvider.autoDispose
    .family<List<ModeEntity>, String>(
      (ref, id) => ref.watch(universityRepoProvider).watchModes(id),
    );
final universityExamsProvider = StreamProvider.autoDispose
    .family<List<AdmissionExam>, String>(
      (ref, id) => ref.watch(admissionExamRepoProvider).watch(id),
    );
