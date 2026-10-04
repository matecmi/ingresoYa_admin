import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';
import 'package:ingresoya_admin/src/data/repo/course_repo.dart';
import 'package:ingresoya_admin/src/data/repo/exam_template_repo.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

Map<String, dynamic> masteryTemplate(String id) => {
  'schemaVersion': 2,
  'id': id,
  'version': 1,
  'title': 'Dominio del subtema',
  'active': true,
  'purpose': 'subtopic_mastery',
  'mode': 'dynamic',
  'selectionPolicy': 'strict',
  'allowedFallbackSources': [],
  'questionCount': 4,
  'passPercentExclusive': 80,
  'blocks': [
    {
      'count': 4,
      'filter': {'sourceType': 'admission_exam', 'difficulty': 'any'},
    },
  ],
  'fixedQuestions': [],
};

Future<void> saveSubtopic(CourseRepo repo, {String? templateId}) =>
    repo.upsertSubtopic(
      courseId: 'course-1',
      topicId: 'topic-1',
      subtopicId: 'subtopic-1',
      name: 'Ecuaciones',
      content: 'Contenido',
      order: 1,
      linkVideo: '',
      masteryTemplateId: templateId,
    );

void main() {
  test(
    'selector offers only published, active, dynamic mastery templates',
    () async {
      final db = FakeFirebaseFirestore();
      final templates = ExamTemplateRepo(db);
      await templates.save(ExamTemplate.fromJson(masteryTemplate('mastery-1')));
      await templates.save(
        ExamTemplate.fromJson({
          ...masteryTemplate('mastery-inactive'),
          'active': false,
        }),
      );
      await templates.save(
        ExamTemplate.fromJson({
          ...masteryTemplate('part-1'),
          'purpose': 'part_completion',
        }),
      );
      await db.collection(AppEnv.examTemplatesCollection).doc('draft').set({
        ...masteryTemplate('draft'),
        'status': 'draft',
      });

      final choices = await templates.watchSelectableMasteryTemplates().first;
      expect(choices.map((choice) => choice.template.id), ['mastery-1']);
    },
  );

  test(
    'binding is published, readable, and removable without losing content',
    () async {
      final db = FakeFirebaseFirestore();
      final templates = ExamTemplateRepo(db);
      final courses = CourseRepo(db);
      await templates.save(ExamTemplate.fromJson(masteryTemplate('mastery-1')));
      await saveSubtopic(courses, templateId: 'mastery-1');

      final bound = await courses
          .watchSubtopics(courseId: 'course-1', topicId: 'topic-1')
          .first;
      expect(bound.single.masteryTemplateId, 'mastery-1');
      expect(bound.single.name, 'Ecuaciones');

      await saveSubtopic(courses, templateId: '');
      final unbound = await courses
          .watchSubtopics(courseId: 'course-1', topicId: 'topic-1')
          .first;
      expect(unbound.single.masteryTemplateId, isEmpty);
      expect(unbound.single.name, 'Ecuaciones');
    },
  );

  test(
    'legacy subtopic remains valid and invalid binding is rejected',
    () async {
      final db = FakeFirebaseFirestore();
      final courses = CourseRepo(db);
      await saveSubtopic(courses);
      final legacy = await courses
          .watchSubtopics(courseId: 'course-1', topicId: 'topic-1')
          .first;
      expect(legacy.single.masteryTemplateId, isEmpty);

      await db.collection(AppEnv.examTemplatesCollection).doc('draft').set({
        ...masteryTemplate('draft'),
        'status': 'draft',
      });
      await expectLater(
        saveSubtopic(courses, templateId: 'draft'),
        throwsStateError,
      );
      await expectLater(
        saveSubtopic(courses, templateId: 'missing'),
        throwsStateError,
      );
      final after = await courses
          .watchSubtopics(courseId: 'course-1', topicId: 'topic-1')
          .first;
      expect(after.single.masteryTemplateId, isEmpty);
    },
  );
}
