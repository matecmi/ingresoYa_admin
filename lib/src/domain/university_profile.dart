import 'package:cloud_firestore/cloud_firestore.dart';

import 'entities/university_entities.dart';

/// Lo que el alumno ve de una universidad en la app (sección Universidades,
/// docs/universities_contract.md). Va en el mismo documento de la
/// universidad: `faculties`, `careerDetails` y `profile`. Los datos deben
/// venir de fuentes oficiales: por eso cada ficha guarda su fuente y fecha.

DateTime? _date(Object? v) => switch (v) {
  Timestamp t => t.toDate(),
  DateTime d => d,
  _ => null,
};

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

double? _num(Object? v) => v is num
    ? v.toDouble()
    : double.tryParse('${v ?? ''}'.replaceAll(',', '.'));

String _str(Object? v) => '${v ?? ''}'.trim();

bool _isUrl(String v) {
  final uri = Uri.tryParse(v);
  return uri != null &&
      (uri.isScheme('https') || uri.isScheme('http')) &&
      uri.host.isNotEmpty;
}

class Faculty {
  const Faculty({
    required this.id,
    required this.name,
    required this.acronym,
    this.active = true,
  });

  final String id;

  /// «Facultad de Ingeniería Civil, de Sistemas y de Arquitectura».
  final String name;

  /// «FICSA».
  final String acronym;
  final bool active;

  static Faculty? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = _str(raw['id']);
    final name = _str(raw['name']);
    if (id.isEmpty || name.isEmpty) return null;
    return Faculty(
      id: id,
      name: name,
      acronym: _str(raw['acronym']),
      active: raw['active'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name.trim(),
    'acronym': acronym.trim().toUpperCase(),
    'active': active,
  };

  String get label => acronym.isEmpty ? name : '$acronym · $name';

  String? validate() {
    if (name.trim().length < 3) return 'Escribe el nombre de la facultad.';
    if (acronym.trim().length > 15) return 'La sigla es muy larga (máx. 15).';
    return null;
  }
}

/// Datos de una carrera en esta universidad (la carrera sale de
/// `professions[]` del documento).
class CareerDetails {
  const CareerDetails({
    this.facultyId = '',
    this.vacancies,
    this.minScore,
    this.maxScore,
    this.scorePeriod = '',
    this.durationYears,
    this.degree = '',
    this.officialUrl = '',
    this.description = '',
    this.examAreaId = '',
  });

  static const empty = CareerDetails();

  final String facultyId;

  /// Vacantes del último proceso (modalidad ordinaria).
  final int? vacancies;

  /// Puntaje mínimo y máximo de ingreso del último proceso.
  final double? minScore;
  final double? maxScore;

  /// De qué proceso son vacantes y puntajes: «2026-I».
  final String scorePeriod;
  final int? durationYears;

  /// Título que otorga: «Ingeniero Civil».
  final String degree;
  final String officialUrl;
  final String description;

  /// Área del examen que rinde (`examAreas[].id`, docs/exam_areas_contract.md).
  final String examAreaId;

  bool get isEmpty =>
      facultyId.isEmpty &&
      examAreaId.isEmpty &&
      vacancies == null &&
      minScore == null &&
      maxScore == null &&
      durationYears == null &&
      degree.isEmpty &&
      officialUrl.isEmpty &&
      description.isEmpty;

  factory CareerDetails.fromMap(Object? raw) {
    if (raw is! Map) return empty;
    return CareerDetails(
      facultyId: _str(raw['facultyId']),
      vacancies: _int(raw['vacancies']),
      minScore: _num(raw['minScore']),
      maxScore: _num(raw['maxScore']),
      scorePeriod: _str(raw['scorePeriod']),
      durationYears: _int(raw['durationYears']),
      degree: _str(raw['degree']),
      officialUrl: _str(raw['officialUrl']),
      description: _str(raw['description']),
      examAreaId: _str(raw['examAreaId']),
    );
  }

  Map<String, dynamic> toMap() => {
    'facultyId': facultyId,
    'examAreaId': examAreaId,
    'vacancies': vacancies,
    'minScore': minScore,
    'maxScore': maxScore,
    'scorePeriod': scorePeriod.trim(),
    'durationYears': durationYears,
    'degree': degree.trim(),
    'officialUrl': officialUrl.trim(),
    'description': description.trim(),
  };

  String? validate() {
    if (vacancies != null && (vacancies! < 0 || vacancies! > 5000)) {
      return 'Vacantes: entre 0 y 5000.';
    }
    for (final s in [minScore, maxScore]) {
      if (s != null && (s < 0 || s > 5000)) return 'Puntaje: entre 0 y 5000.';
    }
    if (minScore != null && maxScore != null && minScore! > maxScore!) {
      return 'El puntaje mínimo no puede ser mayor que el máximo.';
    }
    if ((minScore != null || maxScore != null || vacancies != null) &&
        scorePeriod.trim().isEmpty) {
      return 'Di de qué proceso son las vacantes y puntajes (p. ej. 2026-I).';
    }
    if (durationYears != null && (durationYears! < 1 || durationYears! > 10)) {
      return 'Duración: entre 1 y 10 años.';
    }
    if (officialUrl.trim().isNotEmpty && !_isUrl(officialUrl.trim())) {
      return 'El enlace de la carrera debe empezar con https://';
    }
    return null;
  }
}

/// Una asignatura del examen de un área (docs/exam_areas_contract.md).
class ExamAreaRow {
  const ExamAreaRow({
    required this.subject,
    this.courseId = '',
    required this.questions,
    required this.points,
    this.key = false,
  });

  /// «Álgebra», como la nombra el prospecto.
  final String subject;

  /// Curso de la guía que la cubre; vacío si la guía no lo tiene.
  final String courseId;
  final int questions;

  /// Puntos por respuesta correcta.
  final double points;

  /// Curso clave para esta área (lo marca el admin).
  final bool key;

  double get weight => questions * points;

  static ExamAreaRow? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final subject = _str(raw['subject']);
    if (subject.isEmpty) return null;
    return ExamAreaRow(
      subject: subject,
      courseId: _str(raw['courseId']),
      questions: _int(raw['questions']) ?? 0,
      points: _num(raw['points']) ?? 0,
      key: raw['key'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'subject': subject.trim(),
    'courseId': courseId,
    'questions': questions,
    'points': points,
    'key': key,
  };

  ExamAreaRow copyWith({
    String? subject,
    String? courseId,
    int? questions,
    double? points,
    bool? key,
  }) => ExamAreaRow(
    subject: subject ?? this.subject,
    courseId: courseId ?? this.courseId,
    questions: questions ?? this.questions,
    points: points ?? this.points,
    key: key ?? this.key,
  );
}

/// Grupo académico de la universidad: las carreras que rinden el mismo
/// examen y cuántas preguntas trae cada asignatura.
class ExamArea {
  const ExamArea({
    required this.id,
    required this.name,
    this.source = '',
    this.rows = const [],
  });

  /// «E», único en la universidad.
  final String id;

  /// «Ciencias e Ingenierías».
  final String name;

  /// «Prospecto 2026-II, Anexo 1».
  final String source;
  final List<ExamAreaRow> rows;

  int get totalQuestions => rows.fold(0, (total, r) => total + r.questions);

  /// Puntaje máximo del examen: Σ preguntas × puntos.
  double get maxScore => rows.fold(0.0, (total, r) => total + r.weight);

  /// Parte del puntaje que pesa la fila (0–1).
  double shareOf(ExamAreaRow row) => maxScore == 0 ? 0 : row.weight / maxScore;

  String get label => '$id · $name';

  static ExamArea? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = _str(raw['id']);
    final name = _str(raw['name']);
    if (id.isEmpty || name.isEmpty) return null;
    return ExamArea(
      id: id,
      name: name,
      source: _str(raw['source']),
      rows: [
        for (final r in (raw['rows'] as List? ?? const []))
          ?ExamAreaRow.fromMap(r),
      ],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id.trim().toUpperCase(),
    'name': name.trim(),
    'source': source.trim(),
    'rows': [for (final r in rows) r.toMap()],
  };

  String? validate() {
    if (id.trim().isEmpty || id.trim().length > 6) {
      return 'El código del área es obligatorio (máx. 6 caracteres).';
    }
    if (name.trim().length < 3) return 'Escribe el nombre del área.';
    final total = totalQuestions;
    if (total < 1 || total > 200) {
      return 'El área ${id.trim()} debe sumar entre 1 y 200 preguntas.';
    }
    final subjects = <String>{};
    for (final r in rows) {
      if (r.subject.trim().isEmpty) return 'Hay una asignatura sin nombre.';
      if (!subjects.add(r.subject.trim().toLowerCase())) {
        return '«${r.subject.trim()}» está dos veces en el área ${id.trim()}.';
      }
      if (r.questions < 0 || r.questions > 100) {
        return '«${r.subject.trim()}»: preguntas entre 0 y 100.';
      }
      if (r.points < .01 || r.points > 1000) {
        return '«${r.subject.trim()}»: puntos por respuesta entre 0,01 y 1000.';
      }
    }
    return null;
  }
}

enum LinkKind {
  website('website', 'Web oficial'),
  admission('admission', 'Admisión'),
  facebook('facebook', 'Facebook'),
  instagram('instagram', 'Instagram'),
  tiktok('tiktok', 'TikTok'),
  youtube('youtube', 'YouTube'),
  map('map', 'Mapa / ubicación'),
  other('other', 'Otro');

  const LinkKind(this.key, this.label);

  final String key;
  final String label;

  static LinkKind fromKey(Object? key) =>
      values.firstWhere((k) => k.key == key, orElse: () => LinkKind.other);
}

class OfficialLink {
  const OfficialLink({required this.kind, required this.url, this.label = ''});

  final LinkKind kind;
  final String url;

  /// Texto opcional («Prospecto 2026-I»); si no, el nombre del tipo.
  final String label;

  String get title => label.trim().isEmpty ? kind.label : label.trim();

  static OfficialLink? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final url = _str(raw['url']);
    if (url.isEmpty) return null;
    return OfficialLink(
      kind: LinkKind.fromKey(raw['kind']),
      url: url,
      label: _str(raw['label']),
    );
  }

  Map<String, dynamic> toMap() => {
    'kind': kind.key,
    'url': url.trim(),
    'label': label.trim(),
  };
}

class AdmissionDate {
  const AdmissionDate({required this.label, required this.at});

  /// «Inscripciones», «Examen ordinario», «Resultados».
  final String label;
  final DateTime at;

  static AdmissionDate? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final at = _date(raw['at']);
    final label = _str(raw['label']);
    if (at == null || label.isEmpty) return null;
    return AdmissionDate(label: label, at: at);
  }

  Map<String, dynamic> toMap() => {
    'label': label.trim(),
    'at': Timestamp.fromDate(at),
  };
}

enum UniversityType {
  unknown('', 'Sin indicar'),
  public('public', 'Pública'),
  private('private', 'Privada');

  const UniversityType(this.key, this.label);

  final String key;
  final String label;

  static UniversityType fromKey(Object? key) => values.firstWhere(
    (t) => t.key == key,
    orElse: () => UniversityType.unknown,
  );
}

/// `profile` del documento de la universidad.
class UniversityProfile {
  const UniversityProfile({
    this.summary = '',
    this.type = UniversityType.unknown,
    this.foundedYear,
    this.links = const [],
    this.admissionInfo = '',
    this.admissionDates = const [],
    this.source = '',
    this.sourceCheckedAt,
    this.visible = false,
  });

  static const empty = UniversityProfile();

  /// Dos o tres líneas de presentación.
  final String summary;
  final UniversityType type;
  final int? foundedYear;
  final List<OfficialLink> links;

  /// Cómo es su admisión (modalidades, requisitos), en pocas líneas.
  final String admissionInfo;
  final List<AdmissionDate> admissionDates;

  /// De dónde salen los datos: «Prospecto de admisión 2026-I (web oficial)».
  final String source;

  /// Cuándo se revisaron por última vez.
  final DateTime? sourceCheckedAt;

  /// La ficha se muestra en la app (si no, solo el nombre en el directorio).
  final bool visible;

  factory UniversityProfile.fromMap(Object? raw) {
    if (raw is! Map) return empty;
    return UniversityProfile(
      summary: _str(raw['summary']),
      type: UniversityType.fromKey(raw['type']),
      foundedYear: _int(raw['foundedYear']),
      links: [
        for (final l in (raw['links'] as List? ?? const []))
          ?OfficialLink.fromMap(l),
      ],
      admissionInfo: _str(raw['admissionInfo']),
      admissionDates: [
        for (final d in (raw['admissionDates'] as List? ?? const []))
          ?AdmissionDate.fromMap(d),
      ]..sort((a, b) => a.at.compareTo(b.at)),
      source: _str(raw['source']),
      sourceCheckedAt: _date(raw['sourceCheckedAt']),
      visible: raw['visible'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'summary': summary.trim(),
    'type': type.key,
    'foundedYear': foundedYear,
    'links': [for (final l in links) l.toMap()],
    'admissionInfo': admissionInfo.trim(),
    'admissionDates': [for (final d in admissionDates) d.toMap()],
    'source': source.trim(),
    'sourceCheckedAt': sourceCheckedAt == null
        ? null
        : Timestamp.fromDate(sourceCheckedAt!),
    'visible': visible,
  };

  String? validate() {
    if (summary.trim().length > 600) {
      return 'El resumen es muy largo (máx. 600 caracteres).';
    }
    final year = DateTime.now().year;
    if (foundedYear != null && (foundedYear! < 1551 || foundedYear! > year)) {
      return 'Año de fundación: entre 1551 y $year.';
    }
    for (final l in links) {
      if (!_isUrl(l.url)) {
        return 'El enlace «${l.title}» debe empezar con https://';
      }
    }
    if (visible && source.trim().isEmpty) {
      return 'Para mostrar la ficha a los alumnos, indica la fuente de los datos.';
    }
    return null;
  }

  UniversityProfile copyWith({
    String? summary,
    UniversityType? type,
    int? Function()? foundedYear,
    List<OfficialLink>? links,
    String? admissionInfo,
    List<AdmissionDate>? admissionDates,
    String? source,
    DateTime? Function()? sourceCheckedAt,
    bool? visible,
  }) => UniversityProfile(
    summary: summary ?? this.summary,
    type: type ?? this.type,
    foundedYear: foundedYear != null ? foundedYear() : this.foundedYear,
    links: links ?? this.links,
    admissionInfo: admissionInfo ?? this.admissionInfo,
    admissionDates: admissionDates ?? this.admissionDates,
    source: source ?? this.source,
    sourceCheckedAt: sourceCheckedAt != null
        ? sourceCheckedAt()
        : this.sourceCheckedAt,
    visible: visible ?? this.visible,
  );
}

/// Carrera de la universidad (de `professions[]`).
class UniversityCareer {
  const UniversityCareer({
    required this.id,
    required this.name,
    required this.acronym,
    required this.active,
  });

  final String id;
  final String name;
  final String acronym;
  final bool active;
}

/// Todo lo de la ficha, leído del documento de la universidad.
class UniversityStudentData {
  const UniversityStudentData({
    required this.universityId,
    required this.name,
    required this.acronym,
    required this.profile,
    required this.faculties,
    required this.careers,
    required this.careerDetails,
    this.nextExam,
    this.examAreas = const [],
  });

  final String universityId;
  final String name;
  final String acronym;
  final UniversityProfile profile;
  final List<Faculty> faculties;
  final List<UniversityCareer> careers;
  final Map<String, CareerDetails> careerDetails;
  final UniversityNextExam? nextExam;
  final List<ExamArea> examAreas;

  factory UniversityStudentData.fromDoc(String id, Map<String, dynamic>? d) {
    final data = d ?? const <String, dynamic>{};
    final details = data['careerDetails'];
    return UniversityStudentData(
      universityId: id,
      name: _str(data['name']),
      acronym: _str(data['acronym']),
      profile: UniversityProfile.fromMap(data['profile']),
      faculties: [
        for (final f in (data['faculties'] as List? ?? const []))
          ?Faculty.fromMap(f),
      ],
      careers: [
        for (final p in (data['professions'] as List? ?? const []))
          if (p is Map && _str(p['id']).isNotEmpty)
            UniversityCareer(
              id: _str(p['id']),
              name: _str(p['name']),
              acronym: _str(p['acronym']),
              active: p['active'] != false,
            ),
      ]..sort((a, b) => a.name.compareTo(b.name)),
      careerDetails: details is Map
          ? {
              for (final e in details.entries)
                '${e.key}': CareerDetails.fromMap(e.value),
            }
          : const {},
      nextExam: UniversityNextExam.fromMap(data['nextExam']),
      examAreas: [
        for (final a in (data['examAreas'] as List? ?? const []))
          ?ExamArea.fromMap(a),
      ],
    );
  }

  CareerDetails detailsOf(String careerId) =>
      careerDetails[careerId] ?? CareerDetails.empty;

  ExamArea? areaOf(String careerId) {
    final id = detailsOf(careerId).examAreaId;
    if (id.isEmpty) return null;
    for (final a in examAreas) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Qué falta para que la ficha esté completa (para el admin).
  List<String> missing() => [
    if (profile.summary.isEmpty) 'resumen',
    if (!profile.links.any((l) => l.kind == LinkKind.website)) 'web oficial',
    if (faculties.isEmpty) 'facultades',
    if (careers.any((c) => detailsOf(c.id).facultyId.isEmpty))
      'facultad de ${careers.where((c) => detailsOf(c.id).facultyId.isEmpty).length} carrera(s)',
    if (careers.any((c) => detailsOf(c.id).minScore == null))
      'puntaje de ${careers.where((c) => detailsOf(c.id).minScore == null).length} carrera(s)',
    if (profile.source.isEmpty) 'fuente de los datos',
    if (examAreas.isNotEmpty && careers.any((c) => areaOf(c.id) == null))
      'área del examen de ${careers.where((c) => areaOf(c.id) == null).length} carrera(s)',
  ];
}
