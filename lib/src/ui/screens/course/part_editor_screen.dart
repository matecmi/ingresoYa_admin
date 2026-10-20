import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/content_health.dart';
import '../../../domain/entities/course_entity.dart';
import '../../../domain/entities/subtopic_entity.dart';
import '../../../domain/entities/topic_entity.dart';
import '../../../domain/staff.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import 'widgets/part_form_sheet.dart';

final _courseProvider = StreamProvider.autoDispose
    .family<CourseEntity?, String>(
      (ref, id) => ref
          .watch(courseRepoProvider)
          .watchCourses()
          .map((all) => all.where((c) => c.id == id).firstOrNull),
    );
final _topicsProvider = StreamProvider.autoDispose
    .family<List<TopicEntity>, String>(
      (ref, courseId) => ref.watch(courseRepoProvider).watchTopics(courseId),
    );
final _subtopicsProvider = StreamProvider.autoDispose
    .family<List<SubtopicEntity>, (String, String)>(
      (ref, ids) => ref
          .watch(courseRepoProvider)
          .watchSubtopics(courseId: ids.$1, topicId: ids.$2),
    );
final _templatesProvider =
    FutureProvider.autoDispose<Map<String, TemplateInfo>>(
      (ref) => ref.watch(contentHealthRepoProvider).templates(),
    );
final _countProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, partId) =>
      ref.watch(questionRepoProvider).publishedCountForPart(partId),
);

/// Una parte y sus elementos en una sola pantalla (tablero 17).
class PartEditorScreen extends ConsumerStatefulWidget {
  const PartEditorScreen({
    super.key,
    required this.courseId,
    required this.topicId,
    required this.subtopicId,
    required this.partId,
  });

  final String courseId;
  final String topicId;
  final String subtopicId;
  final String partId;

  @override
  ConsumerState<PartEditorScreen> createState() => _PartEditorScreenState();
}

class _PartEditorScreenState extends ConsumerState<PartEditorScreen> {
  PartElement _selected = PartElement.lesson;

  Future<void> _openFullEditor(SubtopicPartEntity part) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      builder: (_) => PartFormSheet(
        courseId: widget.courseId,
        topicId: widget.topicId,
        subtopicId: widget.subtopicId,
        part: part,
      ),
    );
    ref.invalidate(_countProvider(widget.partId));
    refreshContentHealth(ref);
  }

  Future<void> _setActive(bool active) async {
    try {
      await ref.read(courseStructureRepoProvider).patchPart(
        widget.courseId,
        widget.topicId,
        widget.subtopicId,
        widget.partId,
        {'active': active},
      );
      refreshContentHealth(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active
                ? 'Parte publicada: los alumnos ya la ven.'
                : 'Parte oculta: los alumnos dejan de verla.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar. Vuelve a intentarlo.'),
        ),
      );
    }
  }

  Future<void> _changeTemplate(
    SubtopicPartEntity part,
    Map<String, TemplateInfo> templates,
  ) async {
    final usable = templates.values.where((t) => t.usable).toList();
    final id = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Examen de esta parte'),
        children: [
          for (final t in usable)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, t.id),
              child: Text(
                '${t.title} · ${t.questionCount} preguntas'
                '${t.passPercent == null ? '' : ' · aprueba con más de ${t.passPercent} %'}',
              ),
            ),
        ],
      ),
    );
    if (id == null) return;
    try {
      await ref
          .read(courseRepoProvider)
          .updatePart(
            courseId: widget.courseId,
            topicId: widget.topicId,
            subtopicId: widget.subtopicId,
            part: SubtopicPartEntity(
              id: part.id,
              name: part.name,
              idSubtopic: part.idSubtopic,
              idTopic: part.idTopic,
              content: part.content,
              order: part.order,
              linkVideo: part.linkVideo,
              linkPdf: part.linkPdf,
              summary: part.summary,
              objectives: part.objectives,
              keyPoints: part.keyPoints,
              estimatedMinutes: part.estimatedMinutes,
              difficulty: part.difficulty,
              formulas: part.formulas,
              examples: part.examples,
              exercises: part.exercises,
              images: part.images,
              externalLinks: part.externalLinks,
              flashcards: part.flashcards,
              quizQuestions: part.quizQuestions,
              examTemplateId: id,
              active: part.active,
            ),
          );
      refreshContentHealth(ref);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message : 'No se pudo guardar.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(effectiveSessionProvider);
    final canEdit = session.can(StaffSection.courses, StaffAction.edit);
    final canPublish = session.can(StaffSection.courses, StaffAction.publish);
    final course = ref.watch(_courseProvider(widget.courseId)).value;
    final topic = ref
        .watch(_topicsProvider(widget.courseId))
        .value
        ?.where((t) => t.id == widget.topicId)
        .firstOrNull;
    final subs = ref.watch(
      _subtopicsProvider((widget.courseId, widget.topicId)),
    );
    final subtopic = subs.value
        ?.where((s) => s.id == widget.subtopicId)
        .firstOrNull;
    final part = subtopic?.listPart
        .where((p) => p.id == widget.partId)
        .firstOrNull;
    final templates = ref.watch(_templatesProvider).value ?? const {};
    final published = ref.watch(_countProvider(widget.partId)).value ?? 0;

    if (subs.isLoading && part == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (part == null || subtopic == null) {
      return const Center(
        child: EmptyState(
          title: 'No encontramos esta parte',
          message: 'Puede que la hayan eliminado o movido.',
        ),
      );
    }
    final health = checkPart(
      courseId: widget.courseId,
      courseName: course?.name ?? '',
      topicId: widget.topicId,
      topicName: topic?.name ?? '',
      subtopicId: widget.subtopicId,
      subtopicName: subtopic.name,
      part: part,
      templates: templates,
      publishedByPart: {part.id: published},
    );
    final blockingIssues = health.issues
        .where((i) => i.severity == HealthSeverity.blocking)
        .toList();
    final quickRoute =
        '/questions/quick?course=${widget.courseId}&topic=${widget.topicId}'
        '&subtopic=${widget.subtopicId}&part=${widget.partId}';

    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/courses/${widget.courseId}'),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(course?.name ?? 'Curso'),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${topic?.name ?? ''} · ${subtopic.name}',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              Text(
                part.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          StatusPill(
            part.active
                ? (health.ready ? 'Publicada' : 'Publicada con problemas')
                : 'Oculta a los alumnos',
            tone: part.active
                ? (health.ready ? Tone.success : Tone.error)
                : Tone.neutral,
          ),
          if (canEdit)
            OutlinedButton.icon(
              onPressed: () => _openFullEditor(part),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar contenido'),
            ),
          if (canPublish && !part.active)
            FilledButton(
              onPressed: blockingIssues.isEmpty ? () => _setActive(true) : null,
              child: Text(
                blockingIssues.isEmpty
                    ? 'Publicar'
                    : 'Publicar · falta${blockingIssues.length == 1 ? '' : 'n'} ${blockingIssues.length} cosa${blockingIssues.length == 1 ? '' : 's'}',
              ),
            ),
          if (canPublish && part.active)
            TextButton(
              onPressed: () => _setActive(false),
              child: const Text('Ocultar a los alumnos'),
            ),
        ],
      ),
    );

    final nav = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'LO QUE VE EL ALUMNO, EN ORDEN',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppTheme.muted,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 8),
        for (final (i, e) in PartElement.values.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ElementTile(
              index: i + 1,
              element: e,
              state: health.elements[e]!,
              hint: _hint(e, part, health),
              selected: _selected == e,
              onTap: () => setState(() => _selected = e),
            ),
          ),
      ],
    );

    final center = _ElementDetail(
      element: _selected,
      part: part,
      health: health,
      canEdit: canEdit,
      onEdit: () => _openFullEditor(part),
      onQuick: () => context.go(quickRoute),
      onTemplate: canEdit ? () => _changeTemplate(part, templates) : null,
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (health.issues.isEmpty)
          const InfoNote(
            'Está completa: tiene su examen con preguntas suficientes y el '
            'contenido principal.',
            tone: Tone.success,
            icon: Icons.check_circle_outline_rounded,
          )
        else
          SectionCard(
            title: blockingIssues.isEmpty
                ? 'Para mejorarla'
                : 'Para publicar falta',
            titleColor: blockingIssues.isEmpty ? AppTheme.warn : AppTheme.error,
            color: blockingIssues.isEmpty
                ? AppTheme.warnSoft
                : AppTheme.errorSoft,
            borderColor: blockingIssues.isEmpty
                ? AppTheme.warnLine
                : AppTheme.errorLine,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final i in health.issues)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.title
                              .replaceFirst(RegExp(r'^«[^»]*»\s*'), '')
                              .replaceFirst(
                                RegExp(r'^El examen de «[^»]*»'),
                                'El examen',
                              ),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(i.detail, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                if (health.issues.any((i) => i.missingQuestions > 0) && canEdit)
                  FilledButton(
                    onPressed: () => context.go(quickRoute),
                    child: Text(
                      'Cargar ${health.issues.firstWhere((i) => i.missingQuestions > 0).missingQuestions} preguntas aquí',
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Examen de esta parte',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kv('Plantilla', health.template?.title ?? 'ninguna'),
              _kv(
                'Preguntas por intento',
                '${health.template?.questionCount ?? '—'}',
              ),
              _kv(
                'Aprueba con',
                health.template?.passPercent == null
                    ? '—'
                    : 'más de ${health.template!.passPercent} %',
              ),
              _kv('Publicadas en el banco', '$published'),
              if (canEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _changeTemplate(part, templates),
                    child: const Text('Cambiar la plantilla de esta parte'),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const InfoNote(
          'Mientras esté oculta, los alumnos no la ven: la guía salta a la '
          'siguiente parte publicada.',
        ),
      ],
    );

    return Column(
      children: [
        header,
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 1000) {
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    nav,
                    const SizedBox(height: 12),
                    center,
                    const SizedBox(height: 12),
                    side,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 280,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 18, 8, 24),
                      children: [nav],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 18, 8, 24),
                      children: [center],
                    ),
                  ),
                  SizedBox(
                    width: 340,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 18, 24, 24),
                      children: [side],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(fontSize: 13))),
        Text(
          v,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  static String _hint(
    PartElement e,
    SubtopicPartEntity p,
    PartHealth h,
  ) => switch (e) {
    PartElement.video => p.linkVideo.trim().isEmpty ? 'sin video' : 'con video',
    PartElement.lesson =>
      '${p.keyPoints.length} puntos clave${p.summary.isEmpty ? ' · sin resumen' : ''}',
    PartElement.examples => '${p.examples.length} ejemplo(s)',
    PartElement.review =>
      p.flashcards.isEmpty ? 'opcional' : '${p.flashcards.length} tarjeta(s)',
    PartElement.resources =>
      p.linkPdf.isEmpty && p.externalLinks.isEmpty
          ? 'opcional'
          : 'con recursos',
    PartElement.quiz =>
      p.quizQuestions.isEmpty
          ? 'opcional'
          : '${p.quizQuestions.length} pregunta(s)',
    PartElement.exam =>
      h.template == null
          ? 'sin examen'
          : '${h.publishedQuestions} de ${h.template!.questionCount} preguntas',
  };
}

class _ElementTile extends StatelessWidget {
  const _ElementTile({
    required this.index,
    required this.element,
    required this.state,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final PartElement element;
  final ElementState state;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      ElementState.ready => (Icons.check_circle_rounded, AppTheme.success),
      ElementState.partial => (Icons.contrast_rounded, AppTheme.warn),
      ElementState.missing => (Icons.cancel_rounded, AppTheme.error),
      ElementState.optional => (
        Icons.remove_circle_outline_rounded,
        AppTheme.faint,
      ),
    };
    return Material(
      color: selected ? AppTheme.brandTint : AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.brand : AppTheme.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$index · ${element.label}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      hint,
                      style: TextStyle(
                        fontSize: 12,
                        color: state == ElementState.missing
                            ? AppTheme.error
                            : AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ElementDetail extends StatelessWidget {
  const _ElementDetail({
    required this.element,
    required this.part,
    required this.health,
    required this.canEdit,
    required this.onEdit,
    required this.onQuick,
    required this.onTemplate,
  });

  final PartElement element;
  final SubtopicPartEntity part;
  final PartHealth health;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onQuick;
  final VoidCallback? onTemplate;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    void line(String label, String value, {bool missing = false}) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.trim().isEmpty ? 'Falta' : value,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: value.trim().isEmpty || missing
                      ? AppTheme.error
                      : AppTheme.body,
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (element) {
      case PartElement.video:
        line('Enlace del video', part.linkVideo);
      case PartElement.lesson:
        line('Contenido', part.content);
        line('Resumen', part.summary);
        line('Objetivos', part.objectives.map((o) => '• $o').join('\n'));
        line('Puntos clave', part.keyPoints.map((o) => '• $o').join('\n'));
      case PartElement.examples:
        line(
          'Ejemplos resueltos (${part.examples.length})',
          part.examples
              .map(
                (e) =>
                    '• ${e['title'] ?? e['problem'] ?? e['statement'] ?? 'Ejemplo'}',
              )
              .join('\n'),
          missing: part.examples.length < 2,
        );
      case PartElement.review:
        line(
          'Tarjetas para repasar (${part.flashcards.length})',
          part.flashcards
              .map((e) => '• ${e['front'] ?? e['question'] ?? ''}')
              .join('\n'),
        );
      case PartElement.resources:
        line('PDF', part.linkPdf);
        line(
          'Enlaces (${part.externalLinks.length})',
          part.externalLinks
              .map((e) => '• ${e['title'] ?? e['url'] ?? ''}')
              .join('\n'),
        );
      case PartElement.quiz:
        line(
          'Preguntas del repaso relámpago (${part.quizQuestions.length}) · opcional',
          part.quizQuestions.map((e) => '• ${e['question'] ?? ''}').join('\n'),
        );
      case PartElement.exam:
        line('Plantilla', health.template?.title ?? '');
        line(
          'Preguntas publicadas para esta parte',
          health.template == null
              ? '${health.publishedQuestions}'
              : '${health.publishedQuestions} de ${health.template!.questionCount} que pide el examen',
          missing: health.elements[PartElement.exam] != ElementState.ready,
        );
    }

    return SectionCard(
      title: element.label,
      trailing: canEdit
          ? (element == PartElement.exam
                ? Wrap(
                    spacing: 6,
                    children: [
                      if (onTemplate != null)
                        TextButton(
                          onPressed: onTemplate,
                          child: const Text('Cambiar plantilla'),
                        ),
                      FilledButton(
                        onPressed: onQuick,
                        child: const Text('Cargar preguntas'),
                      ),
                    ],
                  )
                : OutlinedButton(
                    onPressed: onEdit,
                    child: const Text('Editar'),
                  ))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
