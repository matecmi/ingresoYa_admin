import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import 'package:ingresoya_admin/src/domain/entities/university_entities.dart';
import 'package:ingresoya_admin/src/domain/entities/profession_entity.dart';
import 'package:ingresoya_admin/src/domain/university_profile.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

class UniversityRepo {
  UniversityRepo(this.db);

  final FirebaseFirestore db;

  CollectionReference<Map<String, dynamic>> get _col =>
      db.collection(AppEnv.universitiesCollection);

  final _uuid = const Uuid();

  /// ============================================================
  /// WATCH UNIVERSITIES
  /// ============================================================

  Stream<List<UniversityEntity>> watchUniversities() {
    return _col.orderBy('name').snapshots().map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();

        return UniversityEntity(
          id: doc.id,

          idDoc: (data['idDoc'] ?? doc.id).toString(),

          name: (data['name'] ?? '').toString(),

          acronym: (data['acronym'] ?? '').toString(),

          active: (data['active'] ?? true) == true,

          slogan: (data['slogan'] ?? '').toString(),

          address: (data['address'] ?? '').toString(),

          urlImage: (data['urlImage'] ?? '').toString(),

          location: (data['location'] ?? '').toString(),

          ubigeo: (data['ubigeo'] ?? '').toString(),

          department: (data['department'] ?? '').toString(),

          province: (data['province'] ?? '').toString(),

          district: (data['district'] ?? '').toString(),

          links: _toStringList(data['links']),

          modes: _toModes(data['modes'], doc.id),

          professions: _toProfessions(data['professions']),

          simulatorVisible: data['simulatorVisible'] != false,
          nextExam: UniversityNextExam.fromMap(data['nextExam']),
        );
      }).toList();
    });
  }

  /// ============================================================
  /// CREATE UNIVERSITY
  /// ============================================================

  Future<String> createUniversity({
    required String name,

    required String acronym,

    required bool active,

    required String slogan,

    required String address,

    required String urlImage,

    required String location,

    required String ubigeo,

    required String department,

    required String province,

    required String district,

    required List<String> links,
  }) async {
    final id = _uuid.v4();

    await _col.doc(id).set({
      'id': id,

      'idDoc': id,

      'name': name.trim(),

      'acronym': acronym.trim(),

      'active': active,

      'slogan': slogan.trim(),

      'address': address.trim(),

      'urlImage': urlImage.trim(),

      'location': location.trim(),

      'ubigeo': ubigeo.trim(),

      'department': department.trim(),

      'province': province.trim(),

      'district': district.trim(),

      'links': links,

      /// ARRAY
      'modes': [],

      /// ARRAY
      'professions': [],

      'createdAt': FieldValue.serverTimestamp(),

      'updatedAt': FieldValue.serverTimestamp(),
    });

    return id;
  }

  /// ============================================================
  /// UPDATE UNIVERSITY
  /// ============================================================

  Future<void> updateUniversity(
    String id, {

    required Map<String, dynamic> patch,
  }) async {
    patch['updatedAt'] = FieldValue.serverTimestamp();

    await _col.doc(id).update(patch);
  }

  /// Fecha del próximo examen de admisión (null la quita).
  Future<void> setNextExam(String id, {String? name, DateTime? at}) =>
      _col.doc(id).update({
        'nextExam': at == null
            ? FieldValue.delete()
            : {'name': (name ?? '').trim(), 'at': Timestamp.fromDate(at)},
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Ficha para el alumno (docs/universities_contract.md).
  Stream<UniversityStudentData> watchStudentData(String id) => _col
      .doc(id)
      .snapshots()
      .map((s) => UniversityStudentData.fromDoc(s.id, s.data()));

  Future<void> saveProfile(String id, UniversityProfile profile) async {
    final problem = profile.validate();
    if (problem != null) throw StateError(problem);
    await _col.doc(id).update({
      'profile': profile.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setFaculties(String id, List<Faculty> faculties) async {
    for (final f in faculties) {
      final problem = f.validate();
      if (problem != null) throw StateError(problem);
    }
    final acronyms = faculties
        .map((f) => f.acronym.trim().toUpperCase())
        .where((a) => a.isNotEmpty)
        .toList();
    if (acronyms.toSet().length != acronyms.length) {
      throw StateError('Hay dos facultades con la misma sigla.');
    }
    await _col.doc(id).update({
      'faculties': [for (final f in faculties) f.toMap()],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Quita una facultad y la desvincula de sus carreras.
  Future<void> deleteFaculty(
    String id,
    UniversityStudentData data,
    String facultyId,
  ) async {
    await _col.doc(id).update({
      'faculties': [
        for (final f in data.faculties)
          if (f.id != facultyId) f.toMap(),
      ],
      for (final e in data.careerDetails.entries)
        if (e.value.facultyId == facultyId)
          'careerDetails.${e.key}.facultyId': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setCareerDetails(
    String id,
    String careerId,
    CareerDetails details,
  ) async {
    final problem = details.validate();
    if (problem != null) throw StateError(problem);
    await _col.doc(id).update({
      'careerDetails.$careerId': details.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Áreas del examen (docs/exam_areas_contract.md). Una carrera cuya área
  /// ya no existe queda sin área.
  Future<void> setExamAreas(
    String id,
    UniversityStudentData data,
    List<ExamArea> areas,
  ) async {
    for (final a in areas) {
      final problem = a.validate();
      if (problem != null) throw StateError(problem);
    }
    final ids = areas.map((a) => a.id.trim().toUpperCase()).toList();
    if (ids.toSet().length != ids.length) {
      throw StateError('Hay dos áreas con el mismo código.');
    }
    await _col.doc(id).update({
      'examAreas': [for (final a in areas) a.toMap()],
      for (final e in data.careerDetails.entries)
        if (e.value.examAreaId.isNotEmpty && !ids.contains(e.value.examAreaId))
          'careerDetails.${e.key}.examAreaId': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String newFacultyId() => _uuid.v4();

  /// ============================================================
  /// DELETE UNIVERSITY
  /// ============================================================

  Future<void> deleteUniversity(String id) async {
    await _col.doc(id).delete();
  }

  /// ============================================================
  /// SAVE PROFESSIONS ARRAY
  /// ============================================================

  Future<void> setUniversityProfessions({
    required String universityId,

    required List<ProfessionEntity> professions,
  }) async {
    await _col.doc(universityId).update({
      'professions': professions
          .map(
            (e) => {
              'id': e.id,

              'idDoc': e.idDoc,

              'name': e.name,

              'acronym': e.acronym,

              'active': e.active,
            },
          )
          .toList(),

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ============================================================
  /// SAVE MODES ARRAY
  /// ============================================================

  Future<void> setUniversityModes({
    required String universityId,

    required List<ModeEntity> modes,
  }) async {
    await _col.doc(universityId).update({
      'modes': modes
          .map(
            (e) => {
              'id': e.id,

              'name': e.name,

              'acronym': e.acronym,

              'active': e.active,
            },
          )
          .toList(),

      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// ============================================================
  /// JSON IMPORT
  /// ============================================================

  Future<void> bulkUpsertUniversitiesFromJsonList(
    List<Map<String, dynamic>> list,
  ) async {
    const chunk = 400;

    for (var i = 0; i < list.length; i += chunk) {
      final batch = db.batch();

      final part = list.sublist(
        i,

        i + chunk > list.length ? list.length : i + chunk,
      );

      for (final item in part) {
        final idDoc = (item['idDoc'] ?? item['id'] ?? _uuid.v4()).toString();

        batch.set(_col.doc(idDoc), {
          'id': idDoc,

          'idDoc': idDoc,

          'name': item['name'],

          'acronym': item['acronym'],

          'active': _toBool(item['active']),

          'links': _toStringList(item['links']),

          'updatedAt': FieldValue.serverTimestamp(),

          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
    }
  }

  /// ============================================================
  /// HELPERS
  /// ============================================================

  List<ProfessionEntity> _toProfessions(dynamic v) {
    if (v is! List) return [];

    return v.map((e) {
      final m = Map<String, dynamic>.from(e);

      return ProfessionEntity(
        id: m['id'],

        idDoc: m['idDoc'],

        name: m['name'],

        acronym: m['acronym'],

        active: m['active'] == true,
      );
    }).toList();
  }

  List<ModeEntity> _toModes(dynamic v, String universityId) {
    if (v is! List) return [];

    return v.map((e) {
      final m = Map<String, dynamic>.from(e);

      return ModeEntity(
        id: m['id'],

        name: m['name'],

        acronym: m['acronym'],

        active: m['active'] == true,

        universityId: universityId,
      );
    }).toList();
  }

  bool _toBool(dynamic v, {bool fallback = true}) {
    if (v == null) return fallback;

    if (v is bool) return v;

    final s = v.toString();

    return s == 'true' || s == '1';
  }

  List<String> _toStringList(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }

    return [];
  }

  /// ✅ Lee professions[] del doc y lo convierte a List<ProfessionEntity>
  Future<List<ProfessionEntity>> _getUniversityProfessions(
    String universityId,
  ) async {
    final snap = await _col.doc(universityId).get();
    final data = snap.data() ?? <String, dynamic>{};
    return _toProfessions(data['professions']);
  }

  /// ✅ Agrega o reemplaza una profesión dentro de la universidad (array)
  /// Usa el mismo modelo (id, idDoc, name, acronym, active)
  Future<void> addProfessionToUniversity({
    required String universityId,
    required ProfessionEntity profession,
  }) async {
    final list = await _getUniversityProfessions(universityId);

    final idx = list.indexWhere((p) => p.id == profession.id);
    if (idx >= 0) {
      list[idx] = profession; // replace
    } else {
      list.add(profession); // add
    }

    await setUniversityProfessions(
      universityId: universityId,
      professions: list,
    );
  }

  /// ✅ Quita profesión de la universidad (array)
  Future<void> removeProfessionFromUniversity({
    required String universityId,
    required String professionId,
  }) async {
    final list = await _getUniversityProfessions(universityId);

    list.removeWhere((p) => p.id == professionId);

    await setUniversityProfessions(
      universityId: universityId,
      professions: list,
    );
  }

  /// ✅ Actualiza solo nombre/sigla/active dentro del array para esa universidad
  /// (sin tocar el catálogo global)
  Future<void> updateUniversityProfession({
    required String universityId,
    required String professionId,
    String? name,
    String? acronym,
    bool? active,
  }) async {
    final list = await _getUniversityProfessions(universityId);

    final idx = list.indexWhere((p) => p.id == professionId);
    if (idx < 0) return;

    final current = list[idx];
    final updated = ProfessionEntity(
      id: current.id,
      idDoc: current.idDoc,
      name: (name ?? current.name).trim(),
      acronym: (acronym ?? current.acronym).trim(),
      active: active ?? current.active,
    );

    list[idx] = updated;

    await setUniversityProfessions(
      universityId: universityId,
      professions: list,
    );
  }

  Stream<List<ProfessionEntity>> watchUniversityProfessions(
    String universityId,
  ) {
    return _col.doc(universityId).snapshots().map((doc) {
      final data = doc.data() ?? <String, dynamic>{};
      return _toProfessions(data['professions']);
    });
  }

  Stream<List<ModeEntity>> watchModes(String universityId) {
    final ref = _col.doc(universityId).collection(AppEnv.modesSubcollection);
    return ref.orderBy('name').snapshots().map((snap) {
      return snap.docs.map((d) {
        final x = d.data();
        return ModeEntity(
          id: d.id,
          name: (x['name'] ?? '').toString(),
          acronym: (x['acronym'] ?? '').toString(),
          active: (x['active'] ?? true) == true,
          universityId: universityId,
        );
      }).toList();
    });
  }

  Future<String> upsertMode({
    required String universityId,
    String? modeId,
    required String name,
    required String acronym,
    required bool active,
  }) async {
    if (universityId.trim().isEmpty || name.trim().isEmpty) {
      throw ArgumentError(
        'Universidad y nombre de modalidad son obligatorios.',
      );
    }
    final id = modeId ?? _uuid.v4();
    final university = _col.doc(universityId);
    final target = university.collection(AppEnv.modesSubcollection).doc(id);
    await db.runTransaction((transaction) async {
      final parent = await transaction.get(university);
      final current = await transaction.get(target);
      if (!parent.exists) throw StateError('La universidad ya no existe.');
      final data = <String, dynamic>{
        'id': id,
        'universityId': universityId,
        'name': name.trim(),
        'acronym': acronym.trim(),
        'active': active,
        if (!current.exists) 'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (current.exists) {
        transaction.update(target, data);
      } else {
        transaction.set(target, data);
      }
    });
    return id;
  }

  Future<void> deleteMode({
    required String universityId,
    required String modeId,
  }) async {
    await _col
        .doc(universityId)
        .collection(AppEnv.modesSubcollection)
        .doc(modeId)
        .delete();
  }
}
