import 'entities/subtopic_entity.dart';

/// Salud del contenido (tableros 7, 8 y 16): qué le falta a cada parte y qué
/// le impide al alumno avanzar. Funciones puras: el repositorio solo carga.

enum HealthSeverity { blocking, quality }

/// Elementos de una parte, en el orden en que los ve el alumno.
enum PartElement {
  video('Video'),
  lesson('Lección'),
  examples('Ejemplos'),
  review('Repasar'),
  resources('Recursos'),
  quiz('Repaso relámpago'),
  exam('Examen de la parte');

  const PartElement(this.label);
  final String label;
}

enum ElementState { ready, partial, missing, optional }

class TemplateInfo {
  const TemplateInfo({
    required this.id,
    required this.title,
    required this.questionCount,
    required this.passPercent,
    required this.usable,
  });

  final String id;
  final String title;
  final int questionCount;
  final int? passPercent;

  /// Publicada, activa, dinámica y de examen de parte.
  final bool usable;
}

class HealthIssue {
  const HealthIssue({
    required this.severity,
    required this.title,
    required this.detail,
    required this.courseId,
    required this.topicId,
    required this.subtopicId,
    this.partId,
    this.missingQuestions = 0,
  });

  final HealthSeverity severity;
  final String title;
  final String detail;
  final String courseId;
  final String topicId;
  final String subtopicId;
  final String? partId;

  /// Para «Agregar N preguntas».
  final int missingQuestions;
}

class PartHealth {
  PartHealth({
    required this.courseId,
    required this.courseName,
    required this.topicId,
    required this.topicName,
    required this.subtopicId,
    required this.subtopicName,
    required this.part,
    required this.elements,
    required this.publishedQuestions,
    required this.template,
    required this.issues,
  });

  final String courseId;
  final String courseName;
  final String topicId;
  final String topicName;
  final String subtopicId;
  final String subtopicName;
  final SubtopicPartEntity part;
  final Map<PartElement, ElementState> elements;
  final int publishedQuestions;
  final TemplateInfo? template;
  final List<HealthIssue> issues;

  bool get blocking => issues.any((i) => i.severity == HealthSeverity.blocking);
  bool get ready => !blocking;

  /// «12/10» o «4/10» para la columna de examen.
  String get examLabel => template == null
      ? 'sin examen'
      : '$publishedQuestions/${template!.questionCount}';

  /// Qué falta para que la parte esté completa (para «Para publicar falta»).
  List<String> get missing => [for (final i in issues) i.title];
}

bool _has(String v) => v.trim().isNotEmpty;

/// Estado de cada elemento según los datos de la parte.
Map<PartElement, ElementState> partElements(
  SubtopicPartEntity p, {
  required TemplateInfo? template,
  required int publishedQuestions,
}) {
  final lessonPieces = [
    _has(p.content),
    _has(p.summary),
    p.keyPoints.isNotEmpty || p.objectives.isNotEmpty,
  ].where((x) => x).length;
  ElementState exam;
  if (template == null || !template.usable) {
    exam = ElementState.missing;
  } else if (publishedQuestions >= template.questionCount) {
    exam = ElementState.ready;
  } else {
    exam = ElementState.partial;
  }
  return {
    PartElement.video: _has(p.linkVideo)
        ? ElementState.ready
        : ElementState.missing,
    PartElement.lesson: lessonPieces >= 2
        ? ElementState.ready
        : lessonPieces == 1
        ? ElementState.partial
        : ElementState.missing,
    PartElement.examples: p.examples.length >= 2
        ? ElementState.ready
        : p.examples.isNotEmpty
        ? ElementState.partial
        : ElementState.missing,
    PartElement.review: p.flashcards.isNotEmpty
        ? ElementState.ready
        : ElementState.optional,
    PartElement.resources:
        _has(p.linkPdf) || p.externalLinks.isNotEmpty || p.images.isNotEmpty
        ? ElementState.ready
        : ElementState.optional,
    PartElement.quiz: p.quizQuestions.isNotEmpty
        ? ElementState.ready
        : ElementState.optional,
    PartElement.exam: exam,
  };
}

/// Revisa una parte activa.
PartHealth checkPart({
  required String courseId,
  required String courseName,
  required String topicId,
  required String topicName,
  required String subtopicId,
  required String subtopicName,
  required SubtopicPartEntity part,
  required Map<String, TemplateInfo> templates,
  required Map<String, int> publishedByPart,
}) {
  final templateId = part.examTemplateId.trim();
  final template = templateId.isEmpty ? null : templates[templateId];
  final published = publishedByPart[part.id] ?? 0;
  final elements = partElements(
    part,
    template: template,
    publishedQuestions: published,
  );
  final where = '«$subtopicName · ${part.name}»';
  HealthIssue issue(
    HealthSeverity s,
    String title,
    String detail, {
    int missing = 0,
  }) => HealthIssue(
    severity: s,
    title: title,
    detail: detail,
    courseId: courseId,
    topicId: topicId,
    subtopicId: subtopicId,
    partId: part.id,
    missingQuestions: missing,
  );

  final issues = <HealthIssue>[];
  if (templateId.isEmpty) {
    issues.add(
      issue(
        HealthSeverity.blocking,
        '$where no tiene examen',
        'La parte nunca se completa: el alumno no puede aprobarla y el '
            'subtema queda trabado.',
      ),
    );
  } else if (template == null || !template.usable) {
    issues.add(
      issue(
        HealthSeverity.blocking,
        '$where usa una plantilla que no existe o no está publicada',
        'Al abrir el examen de esa parte el alumno ve un error.',
      ),
    );
  } else if (published < template.questionCount) {
    final missing = template.questionCount - published;
    issues.add(
      issue(
        HealthSeverity.blocking,
        'El examen de $where pide ${template.questionCount} preguntas y el '
            'banco tiene $published',
        'Quien llegue al examen de esa parte verá un error y no podrá '
            'aprobarla. Faltan $missing.',
        missing: missing,
      ),
    );
  }
  final quality = <String>[
    if (elements[PartElement.video] == ElementState.missing) 'video',
    if (elements[PartElement.lesson] == ElementState.missing) 'lección',
    if (elements[PartElement.examples] == ElementState.missing) 'ejemplos',
  ];
  if (quality.isNotEmpty) {
    issues.add(
      issue(
        HealthSeverity.quality,
        '$where sin ${quality.join(', ')}',
        'Funciona, pero el alumno tiene menos con qué estudiar antes del '
            'examen.',
      ),
    );
  }
  return PartHealth(
    courseId: courseId,
    courseName: courseName,
    topicId: topicId,
    topicName: topicName,
    subtopicId: subtopicId,
    subtopicName: subtopicName,
    part: part,
    elements: elements,
    publishedQuestions: published,
    template: template,
    issues: issues,
  );
}

class ContentHealthReport {
  const ContentHealthReport({
    required this.parts,
    required this.extraIssues,
    required this.checkedAt,
  });

  final List<PartHealth> parts;

  /// Problemas fuera de las partes (p. ej. subtema sin examen de dominio).
  final List<HealthIssue> extraIssues;
  final DateTime checkedAt;

  static final empty = ContentHealthReport(
    parts: const [],
    extraIssues: const [],
    checkedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  List<HealthIssue> get issues => [
    for (final p in parts) ...p.issues,
    ...extraIssues,
  ];

  List<HealthIssue> get blocking =>
      issues.where((i) => i.severity == HealthSeverity.blocking).toList();

  List<HealthIssue> get quality =>
      issues.where((i) => i.severity == HealthSeverity.quality).toList();

  int get readyParts => parts.where((p) => p.ready).length;

  List<PartHealth> partsOfCourse(String courseId) =>
      parts.where((p) => p.courseId == courseId).toList();

  PartHealth? part(String partId) =>
      parts.where((p) => p.part.id == partId).firstOrNull;

  /// Problemas por curso (para el contador del menú y la lista de cursos).
  Map<String, int> blockingByCourse() {
    final out = <String, int>{};
    for (final i in blocking) {
      out[i.courseId] = (out[i.courseId] ?? 0) + 1;
    }
    return out;
  }
}
