import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repo/content_health_repo.dart';
import '../../../domain/content_health.dart';
import '../../../domain/entities/course_entity.dart';
import '../../../domain/entities/subtopic_entity.dart';
import '../../../domain/entities/topic_entity.dart';
import '../../../domain/staff.dart';
import '../../../domain/syllabus_parser.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import 'widgets/course_details_sheet.dart';

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
final _countsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>(
      (ref, courseId) => ref
          .watch(contentHealthRepoProvider)
          .publishedByPart(courseId: courseId),
    );
final _partTemplateProvider = FutureProvider.autoDispose.family<String, String>(
  (ref, courseId) =>
      ref.watch(courseStructureRepoProvider).partTemplateOf(courseId),
);

int _order(String v) => int.tryParse(v.trim()) ?? 0;

/// Estructura del curso (tablero 16): temas, subtemas y partes con el estado
/// de cada elemento; se agrega en línea y se reordena desde aquí.
class CourseStructureScreen extends ConsumerStatefulWidget {
  const CourseStructureScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<CourseStructureScreen> createState() =>
      _CourseStructureScreenState();
}

class _CourseStructureScreenState extends ConsumerState<CourseStructureScreen> {
  bool _onlyProblems = false;
  final _collapsed = <String>{};

  String get _courseId => widget.courseId;

  Future<void> _run(Future<void> Function() action, [String? done]) async {
    try {
      await action();
      ref.invalidate(_countsProvider(_courseId));
      refreshContentHealth(ref);
      if (done != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError
          ? e.message
          : 'No se pudo guardar. Vuelve a intentarlo.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(effectiveSessionProvider);
    final canEdit = session.can(StaffSection.courses, StaffAction.edit);
    final course = ref.watch(_courseProvider(_courseId)).value;
    final topics = [...?ref.watch(_topicsProvider(_courseId)).value]
      ..sort((a, b) => a.order.compareTo(b.order));
    final templates = ref.watch(_templatesProvider).value ?? const {};
    final counts = ref.watch(_countsProvider(_courseId)).value ?? const {};
    final defaultTemplate =
        ref.watch(_partTemplateProvider(_courseId)).value ?? '';

    // Salud de las partes ya cargadas (para el resumen de arriba).
    final health = <PartHealth>[];
    final subsByTopic = <String, List<SubtopicEntity>>{};
    for (final t in topics) {
      final subs = [...?ref.watch(_subtopicsProvider((_courseId, t.id))).value]
        ..sort((a, b) => _order(a.order).compareTo(_order(b.order)));
      subsByTopic[t.id] = subs;
      for (final s in subs) {
        for (final p in s.listPart.where((p) => p.active)) {
          health.add(
            checkPart(
              courseId: _courseId,
              courseName: course?.name ?? '',
              topicId: t.id,
              topicName: t.name,
              subtopicId: s.id,
              subtopicName: s.name,
              part: p,
              templates: templates,
              publishedByPart: counts,
            ),
          );
        }
      }
    }
    final ready = health.where((h) => h.ready).length;
    final problems = health.length - ready;
    final healthById = {for (final h in health) h.part.id: h};

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
      children: [
        AdminPageHeader(
          crumbs: const ['Contenido', 'Cursos'],
          title: course?.name ?? 'Curso',
          subtitle:
              'Escribe como en una lista: Enter crea otro al mismo nivel. '
              'Cada parte muestra si tiene video, lección, ejemplos y su examen.',
          actions: [
            OutlinedButton(
              onPressed: () => setState(() => _onlyProblems = !_onlyProblems),
              child: Text(_onlyProblems ? 'Ver todo' : 'Solo con problemas'),
            ),
            if (canEdit)
              OutlinedButton.icon(
                onPressed: () => _pasteSyllabus(),
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Pegar un temario'),
              ),
            if (canEdit)
              OutlinedButton.icon(
                onPressed: () => _copyFromCourse(),
                icon: const Icon(Icons.copy_all_rounded, size: 18),
                label: const Text('Copiar estructura de otro curso'),
              ),
            if (course != null)
              TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  useSafeArea: true,
                  builder: (_) => CourseDetailsSheet(course: course),
                ),
                child: const Text('Vista anterior'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            SizedBox(
              width: 220,
              child: LinearProgressIndicator(
                value: health.isEmpty ? 0 : ready / health.length,
                minHeight: 8,
                color: AppTheme.success,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$ready de ${health.length} partes listas'
              '${problems > 0 ? ' · $problems con problemas' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _PartTemplateBar(
          templateId: defaultTemplate,
          templates: templates,
          canEdit: canEdit,
          onChange: (id) => _run(() async {
            await ref
                .read(courseStructureRepoProvider)
                .setPartTemplate(_courseId, id);
            ref.invalidate(_partTemplateProvider(_courseId));
          }, 'Las partes nuevas de este curso usarán esa plantilla.'),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: AppTheme.cardDeco(),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HeaderRow(),
              for (var ti = 0; ti < topics.length; ti++)
                ..._topicRows(
                  topics[ti],
                  subsByTopic[topics[ti].id] ?? const [],
                  healthById,
                  canEdit,
                  previous: ti > 0 ? topics[ti - 1] : null,
                  next: ti + 1 < topics.length ? topics[ti + 1] : null,
                ),
              if (canEdit)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: _InlineAdd(
                    label: '+ Tema',
                    hint: 'Nombre del tema y Enter',
                    onSubmit: (name) => _run(
                      () => ref
                          .read(courseStructureRepoProvider)
                          .addTopic(_courseId, name),
                    ),
                  ),
                ),
              const Divider(height: 18),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 16,
                  children: [
                    _Legend(color: AppTheme.success, text: 'listo'),
                    _Legend(color: AppTheme.warn, text: 'a medias'),
                    _Legend(color: AppTheme.lineStrong, text: 'falta'),
                    Text(
                      'Examen: preguntas publicadas / las que pide',
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _topicRows(
    TopicEntity t,
    List<SubtopicEntity> subs,
    Map<String, PartHealth> health,
    bool canEdit, {
    TopicEntity? previous,
    TopicEntity? next,
  }) {
    final structure = ref.read(courseStructureRepoProvider);
    final parts = [
      for (final s in subs)
        for (final p in s.listPart.where((p) => p.active)) health[p.id],
    ].whereType<PartHealth>().toList();
    final ready = parts.where((p) => p.ready).length;
    final open = !_collapsed.contains(t.id);
    final hasProblems = parts.any((p) => !p.ready);
    if (_onlyProblems && !hasProblems) return const [];
    return [
      _NodeRow(
        indent: 0,
        bold: true,
        open: open,
        onToggle: () => setState(
          () => open ? _collapsed.add(t.id) : _collapsed.remove(t.id),
        ),
        name: t.name,
        kind: 'TEMA',
        inactive: !t.active,
        status: parts.isEmpty
            ? null
            : StatusPill(
                '$ready de ${parts.length}',
                tone: ready == parts.length ? Tone.success : Tone.warn,
              ),
        menu: !canEdit
            ? null
            : [
                _MenuAction(
                  'Renombrar',
                  () => _rename(
                    t.name,
                    (n) => structure.patchTopic(_courseId, t.id, {'name': n}),
                  ),
                ),
                if (previous != null)
                  _MenuAction(
                    'Subir',
                    () => _run(
                      () => structure.swapOrder(
                        structure.topicRef(_courseId, t.id),
                        structure.topicRef(_courseId, previous.id),
                      ),
                    ),
                  ),
                if (next != null)
                  _MenuAction(
                    'Bajar',
                    () => _run(
                      () => structure.swapOrder(
                        structure.topicRef(_courseId, t.id),
                        structure.topicRef(_courseId, next.id),
                      ),
                    ),
                  ),
                _MenuAction(
                  'Eliminar',
                  () => _delete(
                    'el tema «${t.name}»',
                    () => ref
                        .read(courseRepoProvider)
                        .deleteTopic(courseId: _courseId, topicId: t.id),
                  ),
                  danger: true,
                ),
              ],
      ),
      if (open) ...[
        for (var si = 0; si < subs.length; si++)
          ..._subtopicRows(
            t,
            subs[si],
            health,
            canEdit,
            previous: si > 0 ? subs[si - 1] : null,
            next: si + 1 < subs.length ? subs[si + 1] : null,
          ),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 2, 16, 6),
            child: _InlineAdd(
              label: '+ Subtema',
              hint: 'Nombre del subtema y Enter',
              onSubmit: (name) =>
                  _run(() => structure.addSubtopic(_courseId, t.id, name)),
            ),
          ),
      ],
    ];
  }

  List<Widget> _subtopicRows(
    TopicEntity t,
    SubtopicEntity s,
    Map<String, PartHealth> health,
    bool canEdit, {
    SubtopicEntity? previous,
    SubtopicEntity? next,
  }) {
    final structure = ref.read(courseStructureRepoProvider);
    final parts = [...s.listPart]
      ..sort((a, b) => _order(a.order).compareTo(_order(b.order)));
    final active = parts.where((p) => p.active).toList();
    final ready = active.where((p) => health[p.id]?.ready ?? false).length;
    final open = !_collapsed.contains(s.id);
    if (_onlyProblems && active.every((p) => health[p.id]?.ready ?? true)) {
      return const [];
    }
    return [
      _NodeRow(
        indent: 1,
        bold: true,
        open: open,
        onToggle: () => setState(
          () => open ? _collapsed.add(s.id) : _collapsed.remove(s.id),
        ),
        name: s.name,
        kind: 'SUBTEMA',
        inactive: !s.active,
        status: active.isEmpty
            ? const StatusPill('sin partes', tone: Tone.warn)
            : StatusPill(
                '$ready de ${active.length}',
                tone: ready == active.length ? Tone.success : Tone.warn,
              ),
        menu: !canEdit
            ? null
            : [
                _MenuAction(
                  'Renombrar',
                  () => _rename(
                    s.name,
                    (n) => structure.patchSubtopic(_courseId, t.id, s.id, {
                      'name': n,
                    }),
                  ),
                ),
                _MenuAction(
                  '+ Varias partes a la vez',
                  () => _addManyParts(t.id, s.id),
                ),
                if (previous != null)
                  _MenuAction(
                    'Subir',
                    () => _run(
                      () => structure.swapOrder(
                        structure.subtopicRef(_courseId, t.id, s.id),
                        structure.subtopicRef(_courseId, t.id, previous.id),
                      ),
                    ),
                  ),
                if (next != null)
                  _MenuAction(
                    'Bajar',
                    () => _run(
                      () => structure.swapOrder(
                        structure.subtopicRef(_courseId, t.id, s.id),
                        structure.subtopicRef(_courseId, t.id, next.id),
                      ),
                    ),
                  ),
                _MenuAction(
                  'Eliminar',
                  () => _delete(
                    'el subtema «${s.name}»',
                    () => ref
                        .read(courseRepoProvider)
                        .deleteSubtopic(
                          courseId: _courseId,
                          topicId: t.id,
                          subtopicId: s.id,
                        ),
                  ),
                  danger: true,
                ),
              ],
      ),
      if (open) ...[
        for (var pi = 0; pi < parts.length; pi++)
          if (!_onlyProblems || !(health[parts[pi].id]?.ready ?? true))
            _PartRow(
              part: parts[pi],
              health: health[parts[pi].id],
              onOpen: () => context.go(
                '/courses/$_courseId/part/${parts[pi].id}?topic=${t.id}&subtopic=${s.id}',
              ),
              menu: !canEdit
                  ? null
                  : [
                      _MenuAction(
                        'Renombrar',
                        () => _rename(
                          parts[pi].name,
                          (n) => structure.patchPart(
                            _courseId,
                            t.id,
                            s.id,
                            parts[pi].id,
                            {'name': n},
                          ),
                        ),
                      ),
                      _MenuAction(
                        'Duplicar',
                        () => _run(
                          () => structure.duplicatePart(
                            _courseId,
                            t.id,
                            s.id,
                            parts[pi].id,
                          ),
                          'Parte duplicada.',
                        ),
                      ),
                      if (pi > 0)
                        _MenuAction(
                          'Subir',
                          () => _run(
                            () => structure.movePart(
                              _courseId,
                              t.id,
                              s.id,
                              parts[pi].id,
                              -1,
                            ),
                          ),
                        ),
                      if (pi + 1 < parts.length)
                        _MenuAction(
                          'Bajar',
                          () => _run(
                            () => structure.movePart(
                              _courseId,
                              t.id,
                              s.id,
                              parts[pi].id,
                              1,
                            ),
                          ),
                        ),
                      _MenuAction(
                        parts[pi].active
                            ? 'Ocultar a los alumnos'
                            : 'Mostrar a los alumnos',
                        () => _run(
                          () => structure.patchPart(
                            _courseId,
                            t.id,
                            s.id,
                            parts[pi].id,
                            {'active': !parts[pi].active},
                          ),
                        ),
                      ),
                      _MenuAction(
                        'Eliminar',
                        () => _delete(
                          'la parte «${parts[pi].name}»',
                          () => ref
                              .read(courseRepoProvider)
                              .deletePart(
                                courseId: _courseId,
                                topicId: t.id,
                                subtopicId: s.id,
                                partId: parts[pi].id,
                              ),
                        ),
                        danger: true,
                      ),
                    ],
            ),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 2, 16, 6),
            child: _InlineAdd(
              label: '+ Parte',
              hint:
                  'Nombre de la parte y Enter (sigue escribiendo la siguiente)',
              onSubmit: (name) =>
                  _run(() => structure.addParts(_courseId, t.id, s.id, [name])),
            ),
          ),
      ],
    ];
  }

  Future<void> _rename(
    String current,
    Future<void> Function(String) save,
  ) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            onSubmitted: (v) => Navigator.pop(context, v.trim()),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty || name == current) return;
    await _run(() => save(name));
  }

  Future<void> _delete(String what, Future<void> Function() action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar $what?'),
        content: const Text(
          'Si todavía hay preguntas o plantillas que lo usan, no se elimina y '
          'te decimos cuáles. Si es una parte y solo quieres que los alumnos '
          'no la vean, usa «Ocultar a los alumnos».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await _run(action, 'Eliminado.');
  }

  Future<void> _addManyParts(String topicId, String subtopicId) async {
    final ctrl = TextEditingController();
    final names = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Varias partes a la vez'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            minLines: 5,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText:
                  'Una parte por línea:\nConceptos\nGráficas\nProblemas de encuentro',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              ctrl.text
                  .split('\n')
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList(),
            ),
            child: const Text('Crear partes'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (names == null || names.isEmpty) return;
    await _run(
      () => ref
          .read(courseStructureRepoProvider)
          .addParts(_courseId, topicId, subtopicId, names),
      '${names.length} parte(s) creadas.',
    );
  }

  Future<void> _pasteSyllabus() async {
    final result = await showDialog<List<SyllabusNode>>(
      context: context,
      builder: (_) => const _SyllabusDialog(),
    );
    if (result == null || result.isEmpty) return;
    await _run(() async {
      final counts = await ref
          .read(courseStructureRepoProvider)
          .createFromSyllabus(_courseId, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Listo: ${counts.topics} tema(s), ${counts.subtopics} subtema(s) y ${counts.parts} parte(s).',
            ),
          ),
        );
      }
    });
  }

  Future<void> _copyFromCourse() async {
    final courses = await ref.read(courseRepoProvider).watchCourses().first;
    if (!mounted) return;
    final source = await showDialog<CourseEntity>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Copiar la estructura de…'),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Se copian los nombres de temas, subtemas y partes (sin '
              'contenido ni preguntas) al final de este curso.',
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          ),
          for (final c in courses.where((c) => c.id != _courseId))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Text(c.name),
            ),
        ],
      ),
    );
    if (source == null) return;
    await _run(() async {
      final repo = ref.read(courseStructureRepoProvider);
      final structure = await repo.structureOf(source.id);
      await repo.createFromSyllabus(_courseId, structure);
    }, 'Estructura copiada de «${source.name}».');
  }
}

class _MenuAction {
  const _MenuAction(this.label, this.onTap, {this.danger = false});

  final String label;
  final VoidCallback onTap;
  final bool danger;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: AppTheme.muted,
      letterSpacing: .4,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(child: Text('NOMBRE', style: style)),
          _Col('VIDEO', style),
          _Col('LECCIÓN', style),
          _Col('EJEMPLOS', style),
          _Col('EXAMEN', style),
          SizedBox(
            width: 110,
            child: Text('ESTADO', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _Col extends StatelessWidget {
  const _Col(this.text, this.style);

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 78,
    child: Text(text, style: style, textAlign: TextAlign.center),
  );
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.indent,
    required this.name,
    required this.kind,
    required this.open,
    required this.onToggle,
    required this.status,
    required this.menu,
    this.bold = false,
    this.inactive = false,
  });

  final int indent;
  final String name;
  final String kind;
  final bool open;
  final VoidCallback onToggle;
  final Widget? status;
  final List<_MenuAction>? menu;
  final bool bold;
  final bool inactive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: indent == 0
            ? Border(top: BorderSide(color: AppTheme.rowLine))
            : null,
      ),
      padding: EdgeInsets.fromLTRB(8 + indent * 24.0, 4, 16, 4),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onToggle,
            icon: Icon(
              open ? Icons.expand_more_rounded : Icons.chevron_right_rounded,
              size: 20,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                      color: inactive ? AppTheme.faint : AppTheme.ink,
                      decoration: inactive ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  kind,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.muted,
                  ),
                ),
                if (inactive) ...[
                  const SizedBox(width: 8),
                  const StatusPill('oculto'),
                ],
              ],
            ),
          ),
          SizedBox(width: 110, child: Center(child: status)),
          SizedBox(width: 40, child: _Menu(menu)),
        ],
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu(this.actions);

  final List<_MenuAction>? actions;

  @override
  Widget build(BuildContext context) {
    final list = actions;
    if (list == null || list.isEmpty) return const SizedBox();
    return PopupMenuButton<_MenuAction>(
      tooltip: 'Más acciones',
      icon: const Icon(Icons.more_horiz_rounded, size: 20),
      onSelected: (a) => a.onTap(),
      itemBuilder: (_) => [
        for (final a in list)
          PopupMenuItem(
            value: a,
            child: Text(
              a.label,
              style: TextStyle(color: a.danger ? AppTheme.error : AppTheme.ink),
            ),
          ),
      ],
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.part,
    required this.health,
    required this.onOpen,
    required this.menu,
  });

  final SubtopicPartEntity part;
  final PartHealth? health;
  final VoidCallback onOpen;
  final List<_MenuAction>? menu;

  @override
  Widget build(BuildContext context) {
    final h = health;
    Widget dot(PartElement e) {
      final state = h?.elements[e];
      final color = switch (state) {
        ElementState.ready => AppTheme.success,
        ElementState.partial => AppTheme.warn,
        _ => AppTheme.lineStrong,
      };
      return SizedBox(
        width: 78,
        child: Center(
          child: Tooltip(
            message: switch (state) {
              ElementState.ready => '${e.label}: listo',
              ElementState.partial => '${e.label}: a medias',
              _ => '${e.label}: falta',
            },
            child: Icon(
              state == ElementState.partial
                  ? Icons.contrast_rounded
                  : (state == ElementState.ready
                        ? Icons.circle
                        : Icons.circle_outlined),
              size: 13,
              color: color,
            ),
          ),
        ),
      );
    }

    final blocking = h?.blocking ?? false;
    return Material(
      color: blocking ? AppTheme.errorSoft : Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(64, 6, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  part.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: part.active ? AppTheme.brand : AppTheme.faint,
                    decoration: part.active ? null : TextDecoration.lineThrough,
                  ),
                ),
              ),
              if (!part.active)
                SizedBox(
                  width: 312,
                  child: Center(
                    child: Text(
                      'oculta a los alumnos',
                      style: TextStyle(color: AppTheme.muted, fontSize: 12),
                    ),
                  ),
                )
              else ...[
                dot(PartElement.video),
                dot(PartElement.lesson),
                dot(PartElement.examples),
                SizedBox(
                  width: 78,
                  child: Text(
                    h?.examLabel ?? '—',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: switch (h?.elements[PartElement.exam]) {
                        ElementState.ready => AppTheme.success,
                        _ => AppTheme.error,
                      },
                    ),
                  ),
                ),
              ],
              SizedBox(
                width: 110,
                child: Center(
                  child: !part.active
                      ? const SizedBox()
                      : blocking
                      ? const StatusPill('bloquea', tone: Tone.error)
                      : (h?.issues.isNotEmpty ?? false)
                      ? const StatusPill('mejorable', tone: Tone.warn)
                      : const StatusPill('lista', tone: Tone.success),
                ),
              ),
              SizedBox(width: 40, child: _Menu(menu)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineAdd extends StatefulWidget {
  const _InlineAdd({
    required this.label,
    required this.hint,
    required this.onSubmit,
  });

  final String label;
  final String hint;
  final Future<void> Function(String) onSubmit;

  @override
  State<_InlineAdd> createState() => _InlineAddState();
}

class _InlineAddState extends State<_InlineAdd> {
  bool _editing = false;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _editing = false);
      return;
    }
    _ctrl.clear();
    await widget.onSubmit(name);
    if (mounted) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () {
            setState(() => _editing = true);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _focus.requestFocus(),
            );
          },
          child: Text(widget.label),
        ),
      );
    }
    return SizedBox(
      width: 520,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              setState(() => _editing = false),
        },
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            suffixIcon: IconButton(
              tooltip: 'Listo',
              onPressed: () => setState(() => _editing = false),
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: AppTheme.muted)),
    ],
  );
}

class _PartTemplateBar extends StatelessWidget {
  const _PartTemplateBar({
    required this.templateId,
    required this.templates,
    required this.canEdit,
    required this.onChange,
  });

  final String templateId;
  final Map<String, TemplateInfo> templates;
  final bool canEdit;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final usable = templates.values.where((t) => t.usable).toList();
    final current = templates[templateId];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: AppTheme.cardDeco(color: AppTheme.subtle),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Plantilla de parte del curso:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            current == null
                ? 'ninguna (las partes nuevas nacen sin examen)'
                : '${current.title} · ${current.questionCount} preguntas'
                      '${current.passPercent == null ? '' : ' · aprueba con más de ${current.passPercent} %'}',
            style: TextStyle(
              color: current == null ? AppTheme.warn : AppTheme.body,
            ),
          ),
          if (canEdit)
            PopupMenuButton<String>(
              tooltip: 'Cambiar la plantilla',
              onSelected: onChange,
              itemBuilder: (_) => [
                for (final t in usable)
                  PopupMenuItem(
                    value: t.id,
                    child: Text('${t.title} · ${t.questionCount} preguntas'),
                  ),
              ],
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  'Cambiar',
                  style: TextStyle(
                    color: AppTheme.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SyllabusDialog extends StatefulWidget {
  const _SyllabusDialog();

  @override
  State<_SyllabusDialog> createState() => _SyllabusDialogState();
}

class _SyllabusDialogState extends State<_SyllabusDialog> {
  final _ctrl = TextEditingController();
  List<SyllabusNode> _parsed = const [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final counts = countSyllabus(_parsed);
    return AlertDialog(
      title: const Text('Pegar un temario'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Copias el índice del sílabo y se arma solo. La sangría (o la '
              'numeración 1. / 1.1 / 1.1.1) define el nivel: tema, subtema y '
              'parte.',
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 8,
              maxLines: 16,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                hintText:
                    'Dinámica\n  Leyes de Newton\n    Primera ley\n    '
                    'Segunda ley\n  Rozamiento',
              ),
              onChanged: (v) => setState(() => _parsed = parseSyllabus(v)),
            ),
            const SizedBox(height: 10),
            Text(
              _parsed.isEmpty
                  ? 'Pega el temario para ver qué se creará.'
                  : counts.summary,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _parsed.isEmpty ? AppTheme.muted : AppTheme.success,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _parsed.isEmpty
              ? null
              : () => Navigator.pop(context, _parsed),
          child: const Text('Crear estructura'),
        ),
      ],
    );
  }
}

/// Lee una parte por id desde el subtema (para el editor de parte).
SubtopicPartEntity? findPart(
  List<SubtopicEntity> subs,
  String subtopicId,
  String partId,
) {
  final s = subs.where((x) => x.id == subtopicId).firstOrNull;
  return s?.listPart.where((p) => p.id == partId).firstOrNull;
}

/// Para que el editor de parte use el mismo mapeo que la salud.
SubtopicPartEntity partFromRaw(Map<String, dynamic> raw) =>
    ContentHealthRepo.partFromMap(raw);
