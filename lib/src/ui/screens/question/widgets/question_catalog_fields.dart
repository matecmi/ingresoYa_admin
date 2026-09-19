import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../domain/entities/admission_exam.dart';
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
  });
  final TextEditingController courseId,
      courseName,
      topicId,
      topicName,
      examId,
      label;
  final AdmissionExam? initialExam;
  final bool allowLegacyOrigin;
  final ValueChanged<AdmissionExam?> onExamChanged;
  @override
  ConsumerState<QuestionCatalogFields> createState() =>
      _QuestionCatalogFieldsState();
}

class _QuestionCatalogFieldsState extends ConsumerState<QuestionCatalogFields> {
  late String universityId = widget.initialExam?.universityId ?? '';
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
            {for (final item in items) item.id: item.name},
            widget.courseName.text,
            (id) => setState(() {
              final course = items.firstWhere((e) => e.id == id);
              widget.courseId.text = course.id;
              widget.courseName.text = course.name;
              widget.topicId.clear();
              widget.topicName.clear();
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
                  {for (final item in items) item.id: item.name},
                  widget.topicName.text,
                  (id) => setState(() {
                    final topic = items.firstWhere((e) => e.id == id);
                    widget.topicId.text = topic.id;
                    widget.topicName.text = topic.name;
                  }),
                ),
              ),
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
