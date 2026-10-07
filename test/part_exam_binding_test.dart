import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';
import 'package:ingresoya_admin/src/data/repo/course_repo.dart';
import 'package:ingresoya_admin/src/data/repo/exam_template_repo.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

Map<String, dynamic> partTemplate(String id) => {
  'schemaVersion': 2,
  'id': id,
  'version': 1,
  'title': 'Examen de verificación de parte',
  'active': true,
  'purpose': 'part_completion',
  'mode': 'dynamic',
  'selectionPolicy': 'prefer_profile_university',
  'allowedFallbackSources': ['admission_exam'],
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

SubtopicPartEntity part({String id = 'part-1', String templateId = ''}) =>
    SubtopicPartEntity(
      id: id,
      name: 'Parte $id',
      idSubtopic: 'subtopic-1',
      idTopic: 'topic-1',
      content: 'Contenido',
      order: id.split('-').last,
      linkVideo: '',
      linkPdf: '',
      examTemplateId: templateId,
    );

Future<List<SubtopicPartEntity>> readParts(CourseRepo courses) async =>
    (await courses
            .watchSubtopics(courseId: 'course-1', topicId: 'topic-1')
            .first)
        .single
        .listPart;

void main() {
  late FakeFirebaseFirestore db;
  late ExamTemplateRepo templates;
  late CourseRepo courses;

  setUp(() async {
    db = FakeFirebaseFirestore();
    templates = ExamTemplateRepo(db);
    courses = CourseRepo(db);
    await courses.upsertSubtopic(
      courseId: 'course-1',
      topicId: 'topic-1',
      subtopicId: 'subtopic-1',
      name: 'Sucesiones',
      content: 'Contenido',
      order: 1,
      linkVideo: '',
    );
  });

  test(
    'selector offers only published, active, dynamic part templates',
    () async {
      await templates.save(ExamTemplate.fromJson(partTemplate('part-exam-v1')));
      await templates.save(
        ExamTemplate.fromJson({
          ...partTemplate('part-inactive'),
          'active': false,
        }),
      );
      await templates.save(
        ExamTemplate.fromJson({
          ...partTemplate('mastery-1'),
          'purpose': 'subtopic_mastery',
          'selectionPolicy': 'strict',
          'allowedFallbackSources': [],
        }),
      );
      await db.collection(AppEnv.examTemplatesCollection).doc('draft').set({
        ...partTemplate('draft'),
        'status': 'draft',
      });

      final choices = await templates.watchSelectablePartExamTemplates().first;
      expect(choices.map((choice) => choice.template.id), ['part-exam-v1']);
    },
  );

  test('binding is stored per part, editable and removable', () async {
    await templates.save(ExamTemplate.fromJson(partTemplate('part-exam-v1')));
    await courses.addPart(
      courseId: 'course-1',
      topicId: 'topic-1',
      subtopicId: 'subtopic-1',
      part: part(templateId: 'part-exam-v1'),
    );
    await courses.addPart(
      courseId: 'course-1',
      topicId: 'topic-1',
      subtopicId: 'subtopic-1',
      part: part(id: 'part-2'),
    );

    final bound = await readParts(courses);
    expect(bound.map((p) => p.examTemplateId), ['part-exam-v1', '']);

    await courses.updatePart(
      courseId: 'course-1',
      topicId: 'topic-1',
      subtopicId: 'subtopic-1',
      part: part(),
    );
    final unbound = await readParts(courses);
    expect(unbound.first.examTemplateId, isEmpty);
    expect(unbound.first.name, 'Parte part-1');
  });

  test('invalid templates are rejected without touching the parts', () async {
    await templates.save(
      ExamTemplate.fromJson({
        ...partTemplate('mastery-1'),
        'purpose': 'subtopic_mastery',
        'selectionPolicy': 'strict',
        'allowedFallbackSources': [],
      }),
    );
    for (final templateId in ['mastery-1', 'missing']) {
      await expectLater(
        courses.addPart(
          courseId: 'course-1',
          topicId: 'topic-1',
          subtopicId: 'subtopic-1',
          part: part(templateId: templateId),
        ),
        throwsStateError,
      );
    }
    expect(await readParts(courses), isEmpty);
  });

  test(
    'an inactive part stays inactive after edits, keeping unknown fields',
    () async {
      await courses.addPart(
        courseId: 'course-1',
        topicId: 'topic-1',
        subtopicId: 'subtopic-1',
        part: const SubtopicPartEntity(
          id: 'part-1',
          name: 'Parte 1',
          idSubtopic: 'subtopic-1',
          idTopic: 'topic-1',
          content: 'Contenido',
          order: '1',
          linkVideo: '',
          linkPdf: '',
          summary: 'Resumen',
          active: false,
        ),
      );
      final ref = db
          .collection(AppEnv.coursesCollection)
          .doc('course-1')
          .collection(AppEnv.topicsSubcollection)
          .doc('topic-1')
          .collection(AppEnv.subtopicsSubcollection)
          .doc('subtopic-1');
      // A field written by a script or a newer editor.
      final list = List<Map<String, dynamic>>.from(
        (await ref.get()).data()!['listPart'] as List,
      );
      list.first['reviewedBy'] = 'script';
      await ref.update({'listPart': list});

      final stored = (await readParts(courses)).single;
      expect(stored.active, isFalse);

      // Edit without touching the switch and clear the summary.
      await courses.updatePart(
        courseId: 'course-1',
        topicId: 'topic-1',
        subtopicId: 'subtopic-1',
        part: SubtopicPartEntity(
          id: stored.id,
          name: 'Parte 1 editada',
          idSubtopic: stored.idSubtopic,
          idTopic: stored.idTopic,
          content: stored.content,
          order: stored.order,
          linkVideo: '',
          linkPdf: '',
          active: stored.active,
        ),
      );
      final raw = ((await ref.get()).data()!['listPart'] as List).single as Map;
      expect(raw['active'], isFalse);
      expect(raw['name'], 'Parte 1 editada');
      expect(raw['reviewedBy'], 'script');
      expect(raw.containsKey('summary'), isFalse);
      expect((await readParts(courses)).single.active, isFalse);
    },
  );

  test('a part used by questions or templates cannot be deleted', () async {
    await courses.addPart(
      courseId: 'course-1',
      topicId: 'topic-1',
      subtopicId: 'subtopic-1',
      part: part(),
    );
    await db.collection(AppEnv.questionsCollection).doc('q-1').set({
      'status': 'published',
      'partIds': ['part-1'],
    });
    await expectLater(
      courses.deletePart(
        courseId: 'course-1',
        topicId: 'topic-1',
        subtopicId: 'subtopic-1',
        partId: 'part-1',
      ),
      throwsStateError,
    );
    expect(await readParts(courses), hasLength(1));

    await db.collection(AppEnv.questionsCollection).doc('q-1').update({
      'status': 'retired',
    });
    await db.collection(AppEnv.examTemplatesCollection).doc('t-1').set({
      'title': 'Simulacro',
      'active': true,
      'blocks': [
        {
          'count': 1,
          'filter': {'partId': 'part-1'},
        },
      ],
    });
    final blockers = await courses.deletionBlockers(
      courseId: 'course-1',
      topicId: 'topic-1',
      subtopicId: 'subtopic-1',
      partId: 'part-1',
    );
    expect(blockers.single, contains('Simulacro'));

    await db.collection(AppEnv.examTemplatesCollection).doc('t-1').delete();
    await courses.deletePart(
      courseId: 'course-1',
      topicId: 'topic-1',
      subtopicId: 'subtopic-1',
      partId: 'part-1',
    );
    expect(await readParts(courses), isEmpty);
  });

  test('part order is stored as a number and cannot repeat', () async {
    await courses.addPart(
      courseId: 'course-1',
      topicId: 'topic-1',
      subtopicId: 'subtopic-1',
      part: part(),
    );
    await expectLater(
      courses.addPart(
        courseId: 'course-1',
        topicId: 'topic-1',
        subtopicId: 'subtopic-1',
        part: SubtopicPartEntity(
          id: 'part-2',
          name: 'Repetida',
          idSubtopic: 'subtopic-1',
          idTopic: 'topic-1',
          content: 'Contenido',
          order: '1',
          linkVideo: '',
          linkPdf: '',
        ),
      ),
      throwsStateError,
    );
    final raw = await db
        .collection(AppEnv.coursesCollection)
        .doc('course-1')
        .collection(AppEnv.topicsSubcollection)
        .doc('topic-1')
        .collection(AppEnv.subtopicsSubcollection)
        .doc('subtopic-1')
        .get();
    expect(((raw.data()!['listPart'] as List).single as Map)['order'], 1);
  });
}
