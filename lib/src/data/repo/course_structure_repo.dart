import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/syllabus_parser.dart';
import '../../env/app_env.dart';

/// Cambios de estructura del curso (tablero 16): agregar en línea, ocultar,
/// reordenar, pegar un temario, copiar otro curso y la plantilla de parte.
///
/// Escribe sobre las mismas colecciones que `CourseRepo`; las partes viven en
/// `listPart` del subtema y se reescriben en una transacción.
class CourseStructureRepo {
  CourseStructureRepo(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _course(String courseId) =>
      _db.collection(AppEnv.coursesCollection).doc(courseId);

  DocumentReference<Map<String, dynamic>> _topic(String c, String t) =>
      _course(c).collection(AppEnv.topicsSubcollection).doc(t);

  DocumentReference<Map<String, dynamic>> _subtopic(
    String c,
    String t,
    String s,
  ) => _topic(c, t).collection(AppEnv.subtopicsSubcollection).doc(s);

  static int _order(Object? v) =>
      v is num ? v.toInt() : int.tryParse('${v ?? ''}'.trim()) ?? 0;

  /// Plantilla que reciben las partes nuevas del curso (`partDefaults`).
  Future<String> partTemplateOf(String courseId) async {
    final snap = await _course(courseId).get();
    final defaults = snap.data()?['partDefaults'];
    return defaults is Map ? '${defaults['examTemplateId'] ?? ''}' : '';
  }

  Future<void> setPartTemplate(String courseId, String templateId) =>
      _course(courseId).set({
        'partDefaults': {'examTemplateId': templateId},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<String> addTopic(String courseId, String name) async {
    final existing = await _course(
      courseId,
    ).collection(AppEnv.topicsSubcollection).get();
    final next = existing.docs.fold<int>(
      0,
      (m, d) => _order(d.data()['order']) > m ? _order(d.data()['order']) : m,
    );
    final id = const Uuid().v4();
    await _topic(courseId, id).set({
      'name': name.trim(),
      'description': '',
      'summary': '',
      'order': next + 1,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  Future<String> addSubtopic(
    String courseId,
    String topicId,
    String name,
  ) async {
    final existing = await _topic(
      courseId,
      topicId,
    ).collection(AppEnv.subtopicsSubcollection).get();
    final next = existing.docs.fold<int>(
      0,
      (m, d) => _order(d.data()['order']) > m ? _order(d.data()['order']) : m,
    );
    final id = const Uuid().v4();
    await _subtopic(courseId, topicId, id).set({
      'name': name.trim(),
      'content': '',
      'linkVideo': '',
      'order': next + 1,
      'idTopic': topicId,
      'active': true,
      'listPart': <Object>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return id;
  }

  /// Agrega partes al final del subtema con la plantilla del curso.
  Future<List<String>> addParts(
    String courseId,
    String topicId,
    String subtopicId,
    List<String> names,
  ) async {
    final template = await partTemplateOf(courseId);
    final ref = _subtopic(courseId, topicId, subtopicId);
    final ids = <String>[];
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final list = List<Map<String, dynamic>>.from(
        (snap.data()?['listPart'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      var next = list.fold<int>(
        0,
        (m, p) => _order(p['order']) > m ? _order(p['order']) : m,
      );
      for (final name
          in names.map((n) => n.trim()).where((n) => n.isNotEmpty)) {
        final id = const Uuid().v4();
        ids.add(id);
        next++;
        list.add({
          'id': id,
          'name': name,
          'idSubtopic': subtopicId,
          'idTopic': topicId,
          'content': '',
          'order': next,
          'linkVideo': '',
          'linkPdf': '',
          'active': true,
          if (template.isNotEmpty) 'examTemplateId': template,
        });
      }
      tx.update(ref, {
        'listPart': list,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return ids;
  }

  /// Cambia campos simples de una parte (nombre, activa, orden).
  Future<void> patchPart(
    String courseId,
    String topicId,
    String subtopicId,
    String partId,
    Map<String, Object?> patch,
  ) {
    final ref = _subtopic(courseId, topicId, subtopicId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final list = List<Map<String, dynamic>>.from(
        (snap.data()?['listPart'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      final i = list.indexWhere((p) => p['id'] == partId);
      if (i < 0) throw StateError('La parte ya no existe.');
      list[i] = {...list[i], ...patch};
      tx.update(ref, {
        'listPart': list,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Copia una parte (mismo contenido, nombre «(copia)», al final).
  Future<void> duplicatePart(
    String courseId,
    String topicId,
    String subtopicId,
    String partId,
  ) {
    final ref = _subtopic(courseId, topicId, subtopicId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final list = List<Map<String, dynamic>>.from(
        (snap.data()?['listPart'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      final source = list.where((p) => p['id'] == partId).firstOrNull;
      if (source == null) throw StateError('La parte ya no existe.');
      final next = list.fold<int>(
        0,
        (m, p) => _order(p['order']) > m ? _order(p['order']) : m,
      );
      list.add({
        ...source,
        'id': const Uuid().v4(),
        'name': '${source['name']} (copia)',
        'order': next + 1,
      });
      tx.update(ref, {'listPart': list});
    });
  }

  /// Sube o baja una parte intercambiando su orden con la vecina.
  Future<void> movePart(
    String courseId,
    String topicId,
    String subtopicId,
    String partId,
    int delta,
  ) {
    final ref = _subtopic(courseId, topicId, subtopicId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final list = List<Map<String, dynamic>>.from(
        (snap.data()?['listPart'] as List? ?? const []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      )..sort((a, b) => _order(a['order']).compareTo(_order(b['order'])));
      final i = list.indexWhere((p) => p['id'] == partId);
      final j = i + delta;
      if (i < 0 || j < 0 || j >= list.length) return;
      // Órdenes consecutivos y luego el intercambio, así nunca chocan.
      for (var k = 0; k < list.length; k++) {
        list[k]['order'] = k + 1;
      }
      list[i]['order'] = j + 1;
      list[j]['order'] = i + 1;
      tx.update(ref, {'listPart': list});
    });
  }

  Future<void> patchTopic(
    String courseId,
    String topicId,
    Map<String, Object?> patch,
  ) => _topic(courseId, topicId).set({
    ...patch,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  Future<void> patchSubtopic(
    String courseId,
    String topicId,
    String subtopicId,
    Map<String, Object?> patch,
  ) => _subtopic(courseId, topicId, subtopicId).set({
    ...patch,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  /// Intercambia el orden de dos temas o subtemas vecinos.
  Future<void> swapOrder(
    DocumentReference<Map<String, dynamic>> a,
    DocumentReference<Map<String, dynamic>> b,
  ) => _db.runTransaction((tx) async {
    final sa = await tx.get(a);
    final sb = await tx.get(b);
    final oa = _order(sa.data()?['order']);
    final ob = _order(sb.data()?['order']);
    tx.update(a, {'order': oa == ob ? ob + 1 : ob});
    tx.update(b, {'order': oa});
  });

  DocumentReference<Map<String, dynamic>> topicRef(String c, String t) =>
      _topic(c, t);

  DocumentReference<Map<String, dynamic>> subtopicRef(
    String c,
    String t,
    String s,
  ) => _subtopic(c, t, s);

  /// Crea temas, subtemas y partes de un temario pegado (sin contenido).
  Future<SyllabusCounts> createFromSyllabus(
    String courseId,
    List<SyllabusNode> topics,
  ) async {
    final template = await partTemplateOf(courseId);
    final existing = await _course(
      courseId,
    ).collection(AppEnv.topicsSubcollection).get();
    var topicOrder = existing.docs.fold<int>(
      0,
      (m, d) => _order(d.data()['order']) > m ? _order(d.data()['order']) : m,
    );
    final batch = _db.batch();
    var nTopics = 0, nSubs = 0, nParts = 0;
    for (final t in topics) {
      final topicId = const Uuid().v4();
      nTopics++;
      batch.set(_topic(courseId, topicId), {
        'name': t.name,
        'description': '',
        'summary': '',
        'order': ++topicOrder,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      var subOrder = 0;
      for (final s in t.children) {
        final subId = const Uuid().v4();
        nSubs++;
        var partOrder = 0;
        batch.set(_subtopic(courseId, topicId, subId), {
          'name': s.name,
          'content': '',
          'linkVideo': '',
          'order': ++subOrder,
          'idTopic': topicId,
          'active': true,
          'listPart': [
            for (final p in s.children)
              {
                'id': const Uuid().v4(),
                'name': p.name,
                'idSubtopic': subId,
                'idTopic': topicId,
                'content': '',
                'order': ++partOrder,
                'linkVideo': '',
                'linkPdf': '',
                'active': true,
                if (template.isNotEmpty) 'examTemplateId': template,
              },
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        nParts += s.children.length;
      }
    }
    await batch.commit();
    return SyllabusCounts(nTopics, nSubs, nParts);
  }

  /// Lee la estructura (nombres) de un curso para copiarla.
  Future<List<SyllabusNode>> structureOf(String courseId) async {
    final topics = await _course(
      courseId,
    ).collection(AppEnv.topicsSubcollection).orderBy('order').get();
    final out = <SyllabusNode>[];
    for (final t in topics.docs) {
      final subs = await t.reference
          .collection(AppEnv.subtopicsSubcollection)
          .orderBy('order')
          .get();
      out.add(
        SyllabusNode('${t.data()['name'] ?? ''}', [
          for (final s in subs.docs)
            SyllabusNode('${s.data()['name'] ?? ''}', [
              for (final p
                  in ((s.data()['listPart'] as List? ?? const [])
                      .whereType<Map>()
                      .toList()
                    ..sort(
                      (a, b) =>
                          _order(a['order']).compareTo(_order(b['order'])),
                    )))
                SyllabusNode('${p['name'] ?? ''}', const []),
            ]),
        ]),
      );
    }
    return out;
  }
}
