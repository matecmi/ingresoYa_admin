import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/admission_exam.dart';
import '../../../../domain/entities/subtopic_entity.dart';
import '../../../../providers/question_catalog_providers.dart';

class QuestionCatalogFields extends ConsumerStatefulWidget {
  const QuestionCatalogFields({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.topicId,
    required this.topicName,
    required this.examId,
    required this.label,
    required this.onExamChanged,
    this.initialExam,
    this.allowLegacyOrigin = false,
    this.subtopicId,
    this.subtopicName,
    this.partIds,
    this.partNames,
  });
  final TextEditingController courseId,
      courseName,
      topicId,
      topicName,
      examId,
      label;
  final TextEditingController? subtopicId, subtopicName;
  final List<String>? partIds;
  final Map<String, String>? partNames;
  final AdmissionExam? initialExam;
  final bool allowLegacyOrigin;
  final ValueChanged<AdmissionExam?> onExamChanged;
  @override
  ConsumerState<QuestionCatalogFields> createState() =>
      _QuestionCatalogFieldsState();
}

class _QuestionCatalogFieldsState extends ConsumerState<QuestionCatalogFields> {
  late String universityId = widget.initialExam?.universityId ?? '';
  bool get _hasAcademicHierarchy =>
      widget.subtopicId != null &&
      widget.subtopicName != null &&
      widget.partIds != null &&
      widget.partNames != null;

  void _clearParts() {
    widget.partIds?.clear();
    widget.partNames?.clear();
  }

  void _clearSubtopicAndParts() {
    widget.subtopicId?.clear();
    widget.subtopicName?.clear();
    _clearParts();
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(questionCoursesProvider);
    final universities = ref.watch(questionUniversitiesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        courses.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, stack) =>
              _error('cursos', () => ref.invalidate(questionCoursesProvider)),
          data: (items) => _select(
            'Curso',
            widget.courseId.text,
            {
              for (final item in items.where((item) => item.active))
                item.id: item.name,
            },
            widget.courseName.text,
            (id) => setState(() {
              final course = items.firstWhere((e) => e.id == id);
              widget.courseId.text = course.id;
              widget.courseName.text = course.name;
              widget.topicId.clear();
              widget.topicName.clear();
              _clearSubtopicAndParts();
            }),
          ),
        ),
        if (widget.courseId.text.isEmpty)
          const Text('Selecciona un curso para ver sus temas.')
        else
          ref
              .watch(questionTopicsProvider(widget.courseId.text))
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, stack) => _error(
                  'temas',
                  () => ref.invalidate(
                    questionTopicsProvider(widget.courseId.text),
                  ),
                ),
                data: (items) => _select(
                  'Tema',
                  widget.topicId.text,
                  {
                    for (final item in items.where((item) => item.active))
                      item.id: item.name,
                  },
                  widget.topicName.text,
                  (id) => setState(() {
                    final topic = items.firstWhere((e) => e.id == id);
                    widget.topicId.text = topic.id;
                    widget.topicName.text = topic.name;
                    _clearSubtopicAndParts();
                  }),
                ),
              ),
        if (_hasAcademicHierarchy) ...[
          if (widget.topicId.text.isEmpty)
            const Text('Selecciona un tema para ver sus subtemas y partes.')
          else
            ref
                .watch(
                  questionSubtopicsProvider((
                    courseId: widget.courseId.text,
                    topicId: widget.topicId.text,
                  )),
                )
                .when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, stack) => _error(
                    'subtemas',
                    () => ref.invalidate(
                      questionSubtopicsProvider((
                        courseId: widget.courseId.text,
                        topicId: widget.topicId.text,
                      )),
                    ),
                  ),
                  data: (items) => _subtopicAndParts(items),
                ),
        ],
        const SizedBox(height: 12),
        universities.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, stack) => _error(
            'universidades',
            () => ref.invalidate(questionUniversitiesProvider),
          ),
          data: (items) => _select(
            'Universidad',
            universityId,
            {
              for (final u in items.where(
                (u) => u.active || u.id == universityId,
              ))
                u.id: '${u.acronym} — ${u.name}',
            },
            widget.initialExam?.universityName ?? '',
            (id) => setState(() {
              universityId = id;
              widget.examId.clear();
              widget.label.clear();
              widget.onExamChanged(null);
            }),
            required: !widget.allowLegacyOrigin || universityId.isNotEmpty,
          ),
        ),
        if (universityId.isEmpty)
          const Text(
            'Selecciona una universidad para ver sus exámenes de admisión.',
          )
        else
          ref
              .watch(universityExamsProvider(universityId))
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (_, stack) => _error(
                  'exámenes',
                  () => ref.invalidate(universityExamsProvider(universityId)),
                ),
                data: (items) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _select(
                      'Examen de origen',
                      widget.examId.text,
                      {
                        for (final e in items.where(
                          (e) => e.active || e.id == widget.examId.text,
                        ))
                          e.id: e.name,
                      },
                      widget.initialExam?.name ?? '',
                      (id) => setState(() {
                        var exam = items.firstWhere((e) => e.id == id);
                        final current = universities.asData?.value
                            .where((u) => u.id == universityId)
                            .firstOrNull;
                        if (current != null) {
                          exam = AdmissionExam.fromJson({
                            ...exam.toJson(),
                            'universityName': current.name,
                            'universityAcronym': current.acronym,
                          });
                        }
                        widget.examId.text = exam.id;
                        widget.label.text = exam.label;
                        widget.onExamChanged(exam);
                      }),
                    ),
                    if (items.where((e) => e.active).isEmpty)
                      const Text(
                        'Registra un examen en Universidades → Exámenes de origen.',
                      ),
                  ],
                ),
              ),
        if (widget.allowLegacyOrigin && universityId.isEmpty)
          const Text(
            'Pregunta antigua sin origen vinculado: se conservarán su examen y etiqueta hasta que selecciones un origen.',
          ),
        const SizedBox(height: 12),
        TextFormField(
          controller: widget.label,
          readOnly: true,
          maxLines: null,
          decoration: const InputDecoration(
            labelText: 'Etiqueta automática',
            helperText: 'Sigla de universidad - Nombre del examen',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _error(String name, VoidCallback retry) => Row(
    children: [
      Expanded(child: Text('No se pudieron cargar los $name.')),
      TextButton(onPressed: retry, child: const Text('Reintentar')),
    ],
  );

  Widget _subtopicAndParts(List<SubtopicEntity> items) {
    final subtopicId = widget.subtopicId!;
    final subtopicName = widget.subtopicName!;
    final selected = items.where((item) => item.id == subtopicId.text);
    final current = selected.isEmpty || !selected.first.active
        ? null
        : selected.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _select(
          'Subtema',
          subtopicId.text,
          {
            for (final item in items.where((item) => item.active))
              item.id: item.name,
          },
          subtopicName.text,
          (id) => setState(() {
            final subtopic = items.firstWhere((item) => item.id == id);
            subtopicId.text = subtopic.id;
            subtopicName.text = subtopic.name;
            _clearParts();
          }),
        ),
        if (subtopicId.text.isNotEmpty)
          _partSelector(current?.listPart ?? const []),
      ],
    );
  }

  Widget _partSelector(List<SubtopicPartEntity> parts) {
    final selected = widget.partIds!;
    final names = widget.partNames!;
    final active = {
      for (final part in parts.where((part) => part.active)) part.id: part,
    };
    final legacy = selected.where((id) => !active.containsKey(id));
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Partes evaluadas'),
          const SizedBox(height: 6),
          if (active.isEmpty && legacy.isEmpty)
            const Text('Este subtema no tiene partes activas registradas.'),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final part in active.values)
                FilterChip(
                  label: Text(part.name),
                  selected: selected.contains(part.id),
                  onSelected: (enabled) => setState(() {
                    if (enabled) {
                      if (!selected.contains(part.id)) selected.add(part.id);
                      names[part.id] = part.name;
                    } else {
                      selected.remove(part.id);
                      names.remove(part.id);
                    }
                  }),
                ),
              for (final id in legacy)
                FilterChip(
                  label: Text(
                    '${names[id] ?? id} (registro guardado no disponible)',
                  ),
                  selected: true,
                  onSelected: null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _select(
    String name,
    String value,
    Map<String, String> values,
    String savedName,
    ValueChanged<String> change, {
    bool required = true,
  }) {
    final available = {...values};
    if (value.isNotEmpty && !available.containsKey(value)) {
      available[value] = '$savedName (registro guardado no disponible)';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$name-$value-${available.keys.join(',')}'),
        initialValue: value.isEmpty ? null : value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: name,
          border: const OutlineInputBorder(),
        ),
        items: available.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                enabled: values.containsKey(e.key),
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: available.isEmpty
            ? null
            : (id) {
                if (id != null) change(id);
              },
        validator: (_) => required && value.isEmpty ? 'Selecciona $name' : null,
      ),
    );
  }
}
