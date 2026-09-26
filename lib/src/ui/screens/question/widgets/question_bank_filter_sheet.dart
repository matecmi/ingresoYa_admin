import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/domain/question_bank_filter.dart';
import 'package:ingresoya_admin/src/providers/question_catalog_providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

class QuestionBankFilterSheet extends ConsumerStatefulWidget {
  const QuestionBankFilterSheet({super.key, required this.initial});

  final QuestionBankFilter initial;

  @override
  ConsumerState<QuestionBankFilterSheet> createState() =>
      _QuestionBankFilterSheetState();
}

class _QuestionBankFilterSheetState
    extends ConsumerState<QuestionBankFilterSheet> {
  late String status = widget.initial.status;
  late String universityId = widget.initial.universityId;
  late String sourceExamId = widget.initial.sourceExamId;
  late String sourceType = widget.initial.sourceType;
  late String modalityId = widget.initial.modalityId;
  late String courseId = widget.initial.courseId;
  late String topicId = widget.initial.topicId;
  late String subtopicId = widget.initial.subtopicId;
  late String partId = widget.initial.partId;
  late String difficulty = widget.initial.difficulty;
  late final TextEditingController yearFrom = TextEditingController(
    text: widget.initial.yearFrom?.toString() ?? '',
  );
  late final TextEditingController yearTo = TextEditingController(
    text: widget.initial.yearTo?.toString() ?? '',
  );
  String? yearError;

  @override
  void dispose() {
    yearFrom.dispose();
    yearTo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(questionCoursesProvider);
    final universities = ref.watch(questionUniversitiesProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .88,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filtros del banco',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            _dropdown('Estado', status, const {
              '': 'Todos',
              'draft': 'Borrador',
              'published': 'Publicada',
              'retired': 'Retirada',
            }, (value) => setState(() => status = value)),
            universities.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('No se cargaron universidades.'),
              data: (items) => _dropdown(
                'Universidad',
                universityId,
                {
                  for (final item in items)
                    item.id: '${item.acronym} — ${item.name}',
                },
                (value) => setState(() {
                  universityId = value;
                  sourceExamId = '';
                  modalityId = '';
                }),
              ),
            ),
            if (universityId.isNotEmpty)
              ref
                  .watch(universityExamsProvider(universityId))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('No se cargaron exámenes.'),
                    data: (items) => _dropdown(
                      'Examen de origen',
                      sourceExamId,
                      {for (final item in items) item.id: item.name},
                      (value) => setState(() => sourceExamId = value),
                    ),
                  ),
            if (universityId.isNotEmpty)
              ref
                  .watch(universityModesProvider(universityId))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('No se cargaron modalidades.'),
                    data: (items) => _dropdown(
                      'Modalidad',
                      modalityId,
                      {for (final item in items) item.id: item.name},
                      (value) => setState(() => modalityId = value),
                    ),
                  ),
            _dropdown(
              'Tipo de origen',
              sourceType,
              const {
                '': 'Todos',
                'admission_exam': 'Examen de admisión',
                'official_practice': 'Práctica oficial',
                'other': 'Otro',
                'original': 'Original IngresoYa',
                'adapted': 'Adaptada',
              },
              (value) => setState(() => sourceType = value),
            ),
            _yearRange(),
            const Divider(height: 28),
            courses.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('No se cargaron cursos.'),
              data: (items) => _dropdown(
                'Curso',
                courseId,
                {for (final item in items) item.id: item.name},
                (value) => setState(() {
                  courseId = value;
                  topicId = '';
                  subtopicId = '';
                  partId = '';
                }),
              ),
            ),
            if (courseId.isNotEmpty)
              ref
                  .watch(questionTopicsProvider(courseId))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('No se cargaron temas.'),
                    data: (items) => _dropdown(
                      'Tema',
                      topicId,
                      {for (final item in items) item.id: item.name},
                      (value) => setState(() {
                        topicId = value;
                        subtopicId = '';
                        partId = '';
                      }),
                    ),
                  ),
            if (courseId.isNotEmpty && topicId.isNotEmpty)
              ref
                  .watch(
                    questionSubtopicsProvider((
                      courseId: courseId,
                      topicId: topicId,
                    )),
                  )
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('No se cargaron subtemas.'),
                    data: _subtopicFilters,
                  ),
            _dropdown('Dificultad', difficulty, const {
              '': 'Todas',
              'easy': 'Fácil',
              'medium': 'Media',
              'hard': 'Difícil',
              'unknown': 'Pendiente',
            }, (value) => setState(() => difficulty = value)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _clear,
              child: const Text('Limpiar filtros'),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _apply,
              icon: const Icon(Icons.filter_alt_rounded),
              label: const Text('Aplicar filtros'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subtopicFilters(List<SubtopicEntity> items) {
    final selected = items.where((item) => item.id == subtopicId);
    final current = selected.isEmpty ? null : selected.first;
    return Column(
      children: [
        _dropdown(
          'Subtema',
          subtopicId,
          {for (final item in items) item.id: item.name},
          (value) => setState(() {
            subtopicId = value;
            partId = '';
          }),
        ),
        if (current != null)
          _dropdown('Parte', partId, {
            for (final part in current.listPart) part.id: part.name,
          }, (value) => setState(() => partId = value)),
      ],
    );
  }

  Widget _yearRange() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(child: _yearField(yearFrom, 'Año desde')),
        const SizedBox(width: 10),
        Expanded(child: _yearField(yearTo, 'Año hasta')),
      ],
    ),
  );

  Widget _yearField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          errorText: yearError,
          border: const OutlineInputBorder(),
        ),
      );

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    final values = <String, String>{
      if (!options.containsKey('')) '': 'Todos',
      ...options,
    };
    if (value.isNotEmpty && !values.containsKey(value)) {
      values[value] = '$value (no disponible)';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final option in values.entries)
            DropdownMenuItem(value: option.key, child: Text(option.value)),
        ],
        onChanged: (next) => onChanged(next ?? ''),
      ),
    );
  }

  void _clear() {
    setState(() {
      status = '';
      universityId = '';
      sourceExamId = '';
      sourceType = '';
      modalityId = '';
      courseId = '';
      topicId = '';
      subtopicId = '';
      partId = '';
      difficulty = '';
      yearFrom.clear();
      yearTo.clear();
      yearError = null;
    });
  }

  void _apply() {
    final from = yearFrom.text.trim().isEmpty
        ? null
        : int.tryParse(yearFrom.text.trim());
    final to = yearTo.text.trim().isEmpty
        ? null
        : int.tryParse(yearTo.text.trim());
    if ((yearFrom.text.trim().isNotEmpty && from == null) ||
        (yearTo.text.trim().isNotEmpty && to == null) ||
        (from != null && to != null && from > to)) {
      setState(() => yearError = 'Rango inválido');
      return;
    }
    Navigator.pop(
      context,
      QuestionBankFilter(
        status: status,
        universityId: universityId,
        sourceExamId: sourceExamId,
        sourceType: sourceType,
        modalityId: modalityId,
        yearFrom: from,
        yearTo: to,
        courseId: courseId,
        topicId: topicId,
        subtopicId: subtopicId,
        partId: partId,
        difficulty: difficulty,
        text: widget.initial.text,
      ),
    );
  }
}
