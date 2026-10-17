import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/content_health.dart';
import '../../domain/entities/subtopic_entity.dart';
import '../../env/app_env.dart';

/// Carga lo necesario para la salud del contenido: cursos activos con sus
/// temas, subtemas y partes, las plantillas y las preguntas publicadas.
///
/// Lee todas las preguntas publicadas una vez (≈1.000 lecturas en TEST); se
/// usa bajo demanda («Revisar ahora») y se guarda en memoria.
class ContentHealthRepo {
  ContentHealthRepo(this._db);

  final FirebaseFirestore _db;

  static bool _active(Object? v) {
    if (v == null) return true;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    return s != 'false' && s != 'n' && s != '0';
  }

  static int _int(Object? v, [int fallback = 0]) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;

  static List<Map<String, dynamic>> _maps(Object? v) => v is List
      ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : const [];

  static List<String> _strings(Object? v) =>
      v is List ? v.map((e) => '$e').toList() : const [];

  /// Parte del `listPart` del subtema (mismos campos que `CourseRepo`).
  static SubtopicPartEntity partFromMap(Map<String, dynamic> p) =>
      SubtopicPartEntity(
        id: '${p['id'] ?? ''}',
        name: '${p['name'] ?? ''}',
        idSubtopic: '${p['idSubtopic'] ?? ''}',
        idTopic: '${p['idTopic'] ?? ''}',
        content: '${p['content'] ?? ''}',
        order: '${p['order'] ?? ''}',
        linkVideo: '${p['linkVideo'] ?? ''}',
        linkPdf: '${p['linkPdf'] ?? ''}',
        summary: '${p['summary'] ?? ''}',
        objectives: _strings(p['objectives']),
        keyPoints: _strings(p['keyPoints']),
        examples: _maps(p['examples']),
        exercises: _maps(p['exercises']),
        images: _maps(p['images']),
        externalLinks: _maps(p['externalLinks']),
        flashcards: _maps(p['flashcards']),
        quizQuestions: _maps(p['quizQuestions']),
        formulas: _maps(p['formulas']),
        examTemplateId: '${p['examTemplateId'] ?? ''}',
        active: _active(p['active']),
      );

  Future<Map<String, TemplateInfo>> templates() async {
    final snap = await _db.collection(AppEnv.examTemplatesCollection).get();
    return {
      for (final d in snap.docs)
        d.id: TemplateInfo(
          id: d.id,
          title: '${d.data()['title'] ?? d.id}',
          questionCount: _int(d.data()['questionCount']),
          passPercent: d.data()['passPercentExclusive'] == null
              ? null
              : _int(d.data()['passPercentExclusive']),
          usable:
              d.data()['status'] == 'published' &&
              d.data()['active'] != false &&
              d.data()['purpose'] == 'part_completion' &&
              d.data()['mode'] == 'dynamic',
        ),
    };
  }

  Future<Map<String, int>> publishedByPart() async {
    final snap = await _db
        .collection(AppEnv.questionsCollection)
        .where('status', isEqualTo: 'published')
        .get();
    final out = <String, int>{};
    for (final d in snap.docs) {
      if (d.data()['active'] == 'N') continue;
      for (final id in _strings(d.data()['partIds'])) {
        out[id] = (out[id] ?? 0) + 1;
      }
    }
    return out;
  }

  Future<ContentHealthReport> load({String? onlyCourseId}) async {
    final results = await Future.wait([templates(), publishedByPart()]);
    final templateMap = results[0] as Map<String, TemplateInfo>;
    final counts = results[1] as Map<String, int>;
    final courses = await _db.collection(AppEnv.coursesCollection).get();
    final parts = <PartHealth>[];
    final extra = <HealthIssue>[];
    for (final course in courses.docs) {
      if (onlyCourseId != null && course.id != onlyCourseId) continue;
      if (!_active(course.data()['active'])) continue;
      final courseName = '${course.data()['name'] ?? ''}';
      final topics = await course.reference
          .collection(AppEnv.topicsSubcollection)
          .get();
      // La app muestra todos los temas y subtemas (solo oculta partes y
      // cursos inactivos), así que aquí también se revisan todos.
      for (final topic in topics.docs) {
        final subtopics = await topic.reference
            .collection(AppEnv.subtopicsSubcollection)
            .get();
        for (final sub in subtopics.docs) {
          final data = sub.data();
          final subName = '${data['name'] ?? ''}';
          final active = [
            for (final raw in _maps(data['listPart']))
              if (_active(raw['active'])) partFromMap(raw),
          ];
          for (final part in active) {
            parts.add(
              checkPart(
                courseId: course.id,
                courseName: courseName,
                topicId: topic.id,
                topicName: '${topic.data()['name'] ?? ''}',
                subtopicId: sub.id,
                subtopicName: subName,
                part: part,
                templates: templateMap,
                publishedByPart: counts,
              ),
            );
          }
          if (active.isNotEmpty &&
              '${data['masteryTemplateId'] ?? ''}'.trim().isEmpty) {
            extra.add(
              HealthIssue(
                severity: HealthSeverity.quality,
                title: '«$subName» no tiene examen de dominio',
                detail:
                    'El alumno puede completar el subtema, pero no ganar la '
                    'medalla de dominio.',
                courseId: course.id,
                topicId: topic.id,
                subtopicId: sub.id,
              ),
            );
          }
        }
      }
    }
    return ContentHealthReport(
      parts: parts,
      extraIssues: extra,
      checkedAt: DateTime.now(),
    );
  }
}
