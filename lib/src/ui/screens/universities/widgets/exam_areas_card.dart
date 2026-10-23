import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/course_entity.dart';
import '../../../../domain/university_profile.dart';
import '../../../../providers/providers.dart';
import '../../../../providers/question_catalog_providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/admin_ui.dart';
import 'university_profile_dialogs.dart';

/// «Áreas del examen» de la ficha (docs/exam_areas_contract.md): los grupos
/// académicos, cuántas preguntas trae cada asignatura, sus puntos y los
/// cursos clave. La app ordena la guía de cada alumno con esto.
class ExamAreasCard extends ConsumerWidget {
  const ExamAreasCard({super.key, required this.data});

  final UniversityStudentData data;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    List<ExamArea> areas,
  ) async {
    try {
      await ref
          .read(universityRepoProvider)
          .setExamAreas(data.universityId, data, areas);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message : 'No se pudo guardar.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(questionCoursesProvider).value ?? const [];
    final names = {for (final c in courses) c.idDoc: c.name};
    final areas = data.examAreas;
    return SectionCard(
      title: 'Áreas del examen · ${areas.length}',
      trailing: TextButton.icon(
        onPressed: () async {
          final area = await showExamAreaDialog(
            context,
            courses: courses,
            others: areas,
          );
          if (area == null || !context.mounted) return;
          await _save(context, ref, [...areas, area]);
        },
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Nueva área'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Los grupos académicos del prospecto: las carreras de un área '
            'rinden el mismo examen. Por asignatura, cuántas preguntas trae y '
            'cuántos puntos vale cada respuesta correcta. Los cursos clave '
            'salen primero en la guía del alumno. Asigna el área de cada '
            'carrera en la pestaña Carreras.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (areas.isEmpty)
            const EmptyState(
              icon: Icons.table_chart_outlined,
              title: 'Sin áreas',
              message:
                  'Sin áreas, la app muestra la guía igual para todas las '
                  'carreras.',
            )
          else
            for (final area in areas)
              _AreaTile(
                area: area,
                courseNames: names,
                careers: [
                  for (final c in data.careers)
                    if (data.detailsOf(c.id).examAreaId == area.id) c.name,
                ],
                onEdit: () async {
                  final edited = await showExamAreaDialog(
                    context,
                    courses: courses,
                    others: [
                      for (final a in areas)
                        if (a.id != area.id) a,
                    ],
                    initial: area,
                  );
                  if (edited == null || !context.mounted) return;
                  await _save(context, ref, [
                    for (final a in areas) a.id == area.id ? edited : a,
                  ]);
                },
                onDelete: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Quitar el área ${area.id}',
                    message:
                        'Sus carreras quedarán sin área y la app les mostrará '
                        'la guía sin ordenar.',
                  );
                  if (!ok || !context.mounted) return;
                  await _save(context, ref, [
                    for (final a in areas)
                      if (a.id != area.id) a,
                  ]);
                },
              ),
        ],
      ),
    );
  }
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({
    required this.area,
    required this.courseNames,
    required this.careers,
    required this.onEdit,
    required this.onDelete,
  });

  final ExamArea area;
  final Map<String, String> courseNames;
  final List<String> careers;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rows = [...area.rows]..sort((a, b) => b.weight.compareTo(a.weight));
    final keys = rows.where((r) => r.key).map((r) => r.subject).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(
          area.label,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          [
            '${area.totalQuestions} preguntas',
            'máx. ${fmtScore(area.maxScore)} puntos',
            careers.isEmpty ? 'sin carreras' : '${careers.length} carrera(s)',
            if (keys.isNotEmpty) 'clave: ${keys.join(', ')}',
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Quitar',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (careers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Carreras: ${careers.join(', ')}',
                style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
              ),
            ),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(3),
              2: FixedColumnWidth(80),
              3: FixedColumnWidth(80),
              4: FixedColumnWidth(70),
            },
            children: [
              TableRow(
                children: [
                  for (final h in [
                    'Asignatura',
                    'Curso de la guía',
                    'Preguntas',
                    'Puntos',
                    'Peso',
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        h,
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    _cell(r.key ? '★ ${r.subject}' : r.subject, bold: r.key),
                    _cell(
                      r.courseId.isEmpty
                          ? '—'
                          : courseNames[r.courseId] ?? r.courseId,
                    ),
                    _cell('${r.questions}'),
                    _cell(fmtScore(r.points)),
                    _cell('${(area.shareOf(r) * 100).toStringAsFixed(1)} %'),
                  ],
                ),
            ],
          ),
          if (area.source.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Fuente: ${area.source}',
                style: TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(String text, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
      ),
    ),
  );
}

Future<ExamArea?> showExamAreaDialog(
  BuildContext context, {
  required List<CourseEntity> courses,
  required List<ExamArea> others,
  ExamArea? initial,
}) => showDialog<ExamArea>(
  context: context,
  builder: (_) =>
      _AreaDialog(courses: courses, others: others, initial: initial),
);

class _AreaDialog extends StatefulWidget {
  const _AreaDialog({
    required this.courses,
    required this.others,
    this.initial,
  });

  final List<CourseEntity> courses;
  final List<ExamArea> others;
  final ExamArea? initial;

  @override
  State<_AreaDialog> createState() => _AreaDialogState();
}

class _RowDraft {
  _RowDraft(ExamAreaRow row)
    : subject = TextEditingController(text: row.subject),
      questions = TextEditingController(text: '${row.questions}'),
      points = TextEditingController(text: fmtScore(row.points)),
      courseId = row.courseId,
      key = row.key;

  final TextEditingController subject;
  final TextEditingController questions;
  final TextEditingController points;
  String courseId;
  bool key;

  ExamAreaRow get row => ExamAreaRow(
    subject: subject.text.trim(),
    courseId: courseId,
    questions: int.tryParse(questions.text.trim()) ?? -1,
    points: double.tryParse(points.text.trim().replaceAll(',', '.')) ?? 0,
    key: key,
  );

  void dispose() {
    subject.dispose();
    questions.dispose();
    points.dispose();
  }
}

class _AreaDialogState extends State<_AreaDialog> {
  late final _id = TextEditingController(text: widget.initial?.id ?? '');
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _source = TextEditingController(
    text: widget.initial?.source ?? '',
  );
  late final List<_RowDraft> _rows = [
    for (final r in widget.initial?.rows ?? const <ExamAreaRow>[]) _RowDraft(r),
  ];
  String? _error;

  @override
  void dispose() {
    for (final c in [_id, _name, _source]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  ExamArea get _area => ExamArea(
    id: _id.text.trim().toUpperCase(),
    name: _name.text,
    source: _source.text,
    rows: [for (final r in _rows) r.row],
  );

  void _copyFrom(ExamArea other) => setState(() {
    for (final r in _rows) {
      r.dispose();
    }
    _rows
      ..clear()
      ..addAll(other.rows.map(_RowDraft.new));
    if (_source.text.trim().isEmpty) _source.text = other.source;
  });

  @override
  Widget build(BuildContext context) {
    final area = _area;
    final courses = [...widget.courses.where((c) => c.active)]
      ..sort((a, b) => a.name.compareTo(b.name));
    final number = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? 'Nueva área del examen'
            : 'Área ${widget.initial!.id}',
      ),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _id,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Código',
                        hintText: 'E',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 320,
                    child: TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del área o grupo',
                        hintText: 'Ciencias e Ingenierías',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: TextField(
                      controller: _source,
                      decoration: const InputDecoration(
                        labelText: 'Fuente',
                        hintText: 'Prospecto 2026-II, Anexo 1',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${area.totalQuestions} preguntas · máx. '
                      '${fmtScore(area.maxScore)} puntos. ★ = curso clave '
                      '(sale primero en la guía).',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
                    ),
                  ),
                  if (widget.others.isNotEmpty)
                    PopupMenuButton<ExamArea>(
                      tooltip: 'Copiar las asignaturas de otra área',
                      onSelected: _copyFrom,
                      itemBuilder: (_) => [
                        for (final o in widget.others)
                          PopupMenuItem(
                            value: o,
                            child: Text('Copiar de ${o.label}'),
                          ),
                      ],
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text('Copiar de otra área'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              for (final (i, r) in _rows.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Tooltip(
                        message: 'Curso clave',
                        child: Checkbox(
                          value: r.key,
                          onChanged: (v) => setState(() => r.key = v ?? false),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: r.subject,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Asignatura',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              courses.any((c) => c.idDoc == r.courseId)
                              ? r.courseId
                              : '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Curso de la guía',
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Sin curso en la guía'),
                            ),
                            for (final c in courses)
                              DropdownMenuItem(
                                value: c.idDoc,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) =>
                              setState(() => r.courseId = v ?? ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: r.questions,
                          inputFormatters: number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Preguntas',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: r.points,
                          inputFormatters: number,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Puntos c/u',
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Text(
                          '${(area.shareOf(area.rows[i]) * 100).toStringAsFixed(1)} %',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Quitar asignatura',
                        onPressed: () =>
                            setState(() => _rows.removeAt(i).dispose()),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(
                    () => _rows.add(
                      _RowDraft(
                        const ExamAreaRow(subject: '', questions: 0, points: 1),
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Agregar asignatura'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                InfoNote(_error!, tone: Tone.error),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final a = _area;
            final problem =
                a.validate() ??
                (widget.others.any((o) => o.id == a.id)
                    ? 'Ya hay un área con el código ${a.id}.'
                    : null);
            if (problem != null) return setState(() => _error = problem);
            Navigator.pop(context, a);
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
