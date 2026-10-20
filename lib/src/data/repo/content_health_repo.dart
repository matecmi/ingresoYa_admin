import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/content_health.dart';
import '../../domain/entities/subtopic_entity.dart';
import '../../env/app_env.dart';

/// Recalcula el reporte en el servidor y devuelve lo guardado.
typedef ContentHealthRefresher = Future<Map<String, dynamic>> Function();

/// Salud del contenido con pocas lecturas:
///
/// * El Inicio lee el reporte que guarda el servidor
///   (`{adminReports}/contentHealth`, una lectura). Si falta, está marcado
///   como desactualizado (`dirtyAtMs`, lo ponen los disparadores al cambiar
///   una pregunta, un curso, un tema, un subtema o una plantilla) o se pidió
///   «Revisar ahora», lo recalcula la Function `refreshContentHealth` con el
///   índice de preguntas por curso (~160 lecturas en el servidor).
/// * Las preguntas publicadas por parte salen del índice por curso
///   (`iya-question-index-{env}`, una lectura por curso) y no de leer todas
///   las preguntas.
///
/// Las reglas de qué falta siguen en `domain/content_health.dart`.
class ContentHealthRepo {
  ContentHealthRepo(
    this._db, {
    FirebaseFunctions? functions,
    ContentHealthRefresher? refresher,
  }) : _refresher = refresher ?? _callable(functions);

  final FirebaseFirestore _db;
  final ContentHealthRefresher? _refresher;

  /// Lo pide el propio admin tras guardar (los disparadores tardan un poco
  /// en marcar el reporte): la próxima carga recalcula.
  bool _stale = false;

  static ContentHealthRefresher? _callable(FirebaseFunctions? functions) {
    if (functions == null) return null;
    return () async {
      final res = await functions
          .httpsCallable(
            'refreshContentHealth',
            options: HttpsCallableOptions(timeout: const Duration(minutes: 2)),
          )
          .call<Map<String, dynamic>>({});
      return Map<String, dynamic>.from(res.data);
    };
  }

  static int _int(Object? v, [int fallback = 0]) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;

  static Map<String, dynamic> _map(Object? v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  static List<Map<String, dynamic>> _maps(Object? v) => v is List
      ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
      : const [];

  static bool _active(Object? v) {
    if (v == null) return true;
    if (v is bool) return v;
    final s = v.toString().trim().toLowerCase();
    return s != 'false' && s != 'n' && s != '0';
  }

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

  /// Marca el reporte para recalcularlo en la próxima carga.
  void markStale() => _stale = true;

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

  /// Preguntas publicadas por parte según el índice (`q[id].p`): una lectura
  /// por curso; con [courseId], solo la de ese curso.
  Future<Map<String, int>> publishedByPart({String? courseId}) async {
    final col = _db.collection(AppEnv.questionIndexCollection);
    final docs = courseId == null
        ? (await col.get()).docs.map((d) => d.data()).toList()
        : [(await col.doc(courseId).get()).data() ?? const {}];
    return countByPart(docs);
  }

  static Map<String, int> countByPart(Iterable<Map<String, dynamic>> docs) {
    final out = <String, int>{};
    for (final doc in docs) {
      for (final entry in _map(doc['q']).values) {
        final parts = _map(entry)['p'];
        if (parts is! List) continue;
        for (final id in parts.map((e) => '$e').toSet()) {
          out[id] = (out[id] ?? 0) + 1;
        }
      }
    }
    return out;
  }

  /// El reporte guardado; lo recalcula si falta, está desactualizado o se
  /// pide con [force] («Revisar ahora»).
  Future<ContentHealthReport> load({bool force = false}) async {
    final doc = await _db
        .collection(AppEnv.adminReportsCollection)
        .doc(AppEnv.contentHealthDocument)
        .get();
    var data = doc.data();
    final computed = _int(data?['computedAtMs']);
    final dirty = _int(data?['dirtyAtMs']) > computed;
    if (data == null || data['courses'] == null || dirty || force || _stale) {
      final refresher = _refresher;
      if (refresher == null) {
        if (data == null || data['courses'] == null) {
          throw StateError('Functions not available');
        }
      } else {
        data = await refresher();
        _stale = false;
      }
    }
    return reportFromFacts(data);
  }

  /// Parte armada con lo que guarda el servidor (`partFacts` en
  /// `functions/src/content_health.ts`): solo importa si cada elemento está.
  static SubtopicPartEntity partFromFacts(
    Map<String, dynamic> f, {
    required String subtopicId,
    required String topicId,
  }) {
    String has(String key) => f[key] == true ? 'x' : '';
    List<Map<String, dynamic>> some(bool present) =>
        present ? const [<String, dynamic>{}] : const [];
    return SubtopicPartEntity(
      id: '${f['id'] ?? ''}',
      name: '${f['name'] ?? ''}',
      idSubtopic: subtopicId,
      idTopic: topicId,
      content: has('content'),
      order: '${f['order'] ?? ''}',
      linkVideo: has('video'),
      linkPdf: has('res'),
      summary: has('summary'),
      objectives: const [],
      keyPoints: f['points'] == true ? const ['x'] : const [],
      examples: List.generate(_int(f['examples']), (_) => <String, dynamic>{}),
      exercises: const [],
      images: const [],
      externalLinks: const [],
      flashcards: some(f['flash'] == true),
      quizQuestions: some(f['quiz'] == true),
      formulas: const [],
      examTemplateId: '${f['tpl'] ?? ''}',
      active: true,
    );
  }

  /// Aplica las reglas del admin a los datos que guardó el servidor.
  static ContentHealthReport reportFromFacts(Map<String, dynamic> data) {
    final templates = {
      for (final e in _map(data['templates']).entries)
        e.key: TemplateInfo(
          id: e.key,
          title: '${_map(e.value)['title'] ?? e.key}',
          questionCount: _int(_map(e.value)['n']),
          passPercent: _map(e.value)['pass'] == null
              ? null
              : _int(_map(e.value)['pass']),
          usable: _map(e.value)['ok'] == true,
        ),
    };
    final counts = {
      for (final e in _map(data['published']).entries) e.key: _int(e.value),
    };
    final parts = <PartHealth>[];
    final extra = <HealthIssue>[];
    for (final course in _maps(data['courses'])) {
      final courseId = '${course['id'] ?? ''}';
      for (final topic in _maps(course['topics'])) {
        final topicId = '${topic['id'] ?? ''}';
        for (final sub in _maps(topic['subtopics'])) {
          final subId = '${sub['id'] ?? ''}';
          final subName = '${sub['name'] ?? ''}';
          final active = [
            for (final f in _maps(sub['parts']))
              partFromFacts(f, subtopicId: subId, topicId: topicId),
          ];
          for (final part in active) {
            parts.add(
              checkPart(
                courseId: courseId,
                courseName: '${course['name'] ?? ''}',
                topicId: topicId,
                topicName: '${topic['name'] ?? ''}',
                subtopicId: subId,
                subtopicName: subName,
                part: part,
                templates: templates,
                publishedByPart: counts,
              ),
            );
          }
          if (active.isNotEmpty && sub['mastery'] != true) {
            extra.add(
              HealthIssue(
                severity: HealthSeverity.quality,
                title: '«$subName» no tiene examen de dominio',
                detail:
                    'El alumno puede completar el subtema, pero no ganar la '
                    'medalla de dominio.',
                courseId: courseId,
                topicId: topicId,
                subtopicId: subId,
              ),
            );
          }
        }
      }
    }
    return ContentHealthReport(
      parts: parts,
      extraIssues: extra,
      checkedAt: DateTime.fromMillisecondsSinceEpoch(
        _int(data['computedAtMs']),
      ),
    );
  }
}
