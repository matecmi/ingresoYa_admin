import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/entities/course_entity.dart';
import 'package:ingresoya_admin/src/domain/entities/topic_entity.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:ingresoya_admin/src/ui/widgets/content_builder_sheet.dart';
import 'package:ingresoya_admin/src/ui/widgets/exam_question.dart';

class CourseDetailsSheet extends ConsumerStatefulWidget {
  const CourseDetailsSheet({super.key, required this.course});
  final CourseEntity course;

  @override
  ConsumerState<CourseDetailsSheet> createState() => _CourseDetailsSheetState();
}

class _CourseDetailsSheetState extends ConsumerState<CourseDetailsSheet> {
  String? _topicSelectedId;
  String? _topicSelectedName;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(courseRepoProvider);
    final c = widget.course;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .62,
      maxChildSize: .97,
      builder: (context, scroll) {
        return DefaultTabController(
          length: 3,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.26),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.92),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(.85)),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  indicatorColor: AppTheme.accent,
                  labelColor: Colors.white.withOpacity(.92),
                  unselectedLabelColor: Colors.white.withOpacity(.60),
                  tabs: const [
                    Tab(text: 'Datos'),
                    Tab(text: 'Temas'),
                    Tab(text: 'Subtemas'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _DatosTab(course: c),
                      _TopicsTab(
                        courseId: c.id,
                        repo: repo,
                        onTopicSelected: (id, name) {
                          setState(() {
                            _topicSelectedId = id;
                            _topicSelectedName = name;
                          });
                        },
                        selectedTopicId: _topicSelectedId,
                      ),
                      _SubtopicsTab(
                        courseId: c.id,
                        repo: repo,
                        topicId: _topicSelectedId,
                        topicName: _topicSelectedName,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DatosTab extends StatelessWidget {
  const _DatosTab({required this.course});
  final CourseEntity course;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        _InfoCard(
          icon: Icons.menu_book_rounded,
          title: course.name,
          subtitle: course.description.isEmpty ? 'Sin descripción' : course.description,
          pills: [
            _Pill(text: 'idDoc: ${course.idDoc}'),
          ],
        ),
      ],
    );
  }
}

class _TopicsTab extends StatelessWidget {
  const _TopicsTab({
    required this.courseId,
    required this.repo,
    required this.onTopicSelected,
    required this.selectedTopicId,
  });

  final String courseId;
  final dynamic repo; // (CourseRepo)
  final void Function(String topicId, String topicName) onTopicSelected;
  final String? selectedTopicId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TopicEntity>>(
      stream: repo.watchTopics(courseId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? const [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          physics: const BouncingScrollPhysics(),
          children: [
            _SectionHeader(
              title: 'Temas',
              subtitle: '${items.length} registrados',
              actionLabel: 'Agregar',
              onAction: () => _topicDialog(context, repo, courseId),
              icon: Icons.add_rounded,
            ),
            const SizedBox(height: 10),

            if (items.isEmpty) _EmptyCard(text: 'Aún no hay temas.'),

            ...items.map((t) {
              final selected = selectedTopicId == t.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RowCard(
                  selected: selected,
                  icon: Icons.layers_rounded,
                  title: '${t.order}. ${t.name}',
                  subtitle: t.summary.isEmpty ? t.description : t.summary,
                  rightPill: 'Orden ${t.order}',
                  rightPillTone: _PillTone.neutral,
                  onTap: () => onTopicSelected(t.id, t.name),
                  onEdit: () => _topicDialog(context, repo, courseId, editing: t),
                  onDelete: () async {
                    final ok = await _confirmPro(
                      context,
                      title: 'Eliminar tema',
                      message: 'Se eliminará "${t.name}" y sus subtemas.',
                      primary: 'Eliminar',
                    );
                    if (!ok) return;
                    await repo.deleteTopic(courseId: courseId, topicId: t.id);
                  },
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Future<void> _topicDialog(
    BuildContext context,
    dynamic repo,
    String courseId, {
    TopicEntity? editing,
  }) async {
    final name = TextEditingController(text: editing?.name ?? '');
    final desc = TextEditingController(text: editing?.description ?? '');
    final summary = TextEditingController(text: editing?.summary ?? '');
    final orderCtrl = TextEditingController(text: editing?.order.toString() ?? '1');

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          editing == null ? 'Nuevo tema' : 'Editar tema',
          style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogTF(ctrl: name, label: 'Nombre *'),
              _DialogTF(ctrl: orderCtrl, label: 'Orden (int) *', keyboardType: TextInputType.number),
              _DialogTF(ctrl: summary, label: 'Resumen'),
              _DialogTF(ctrl: desc, label: 'Descripción', maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final nav = Navigator.of(dialogContext, rootNavigator: true);
              if (nav.canPop()) nav.pop();
            },
            child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(.75))),
          ),
          ElevatedButton(
            onPressed: () async {
              final order = int.tryParse(orderCtrl.text.trim()) ?? 0;
              await repo.upsertTopic(
                courseId: courseId,
                topicId: editing?.id,
                name: name.text,
                description: desc.text,
                order: order,
                summary: summary.text,
              );
              HapticFeedback.selectionClick();
              if (dialogContext.mounted) Navigator.of(dialogContext, rootNavigator: true).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _SubtopicsTab extends StatelessWidget {
  const _SubtopicsTab({
    required this.courseId,
    required this.repo,
    required this.topicId,
    required this.topicName,
  });

  final String courseId;
  final dynamic repo; // (CourseRepo)
  final String? topicId;
  final String? topicName;

  @override
  Widget build(BuildContext context) {
    if (topicId == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _EmptyCard(text: 'Primero selecciona un tema en la pestaña "Temas".'),
      );
    }

    return StreamBuilder<List<SubtopicEntity>>(
      stream: repo.watchSubtopics(courseId: courseId, topicId: topicId!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? const [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          physics: const BouncingScrollPhysics(),
          children: [
            _SectionHeader(
              title: 'Subtemas',
              subtitle: 'Tema: ${topicName ?? "—"} • ${items.length} items',
              actionLabel: 'Agregar',
              onAction: () => _subtopicDialog(context, repo, courseId, topicId!),
              icon: Icons.add_rounded,
            ),
            const SizedBox(height: 10),

            if (items.isEmpty) _EmptyCard(text: 'Aún no hay subtemas.'),

            ...items.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RowCard(
                  icon: Icons.article_rounded,
                  title: '${s.order}. ${s.name}',
                  subtitle: s.linkVideo.isEmpty ? 'Sin video' : s.linkVideo,
                  rightPill: 'Orden ${s.order}',
                  rightPillTone: _PillTone.neutral,
                  onEdit: () => _subtopicDialog(context, repo, courseId, topicId!, editing: s),
                  onDelete: () async {
                    final ok = await _confirmPro(
                      context,
                      title: 'Eliminar subtema',
                      message: 'Se eliminará "${s.name}".',
                      primary: 'Eliminar',
                    );
                    if (!ok) return;
                    await repo.deleteSubtopic(courseId: courseId, topicId: topicId!, subtopicId: s.id);
                  },
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _miniIconBtn({
  required String tooltip,
  required IconData icon,
  required VoidCallback? onTap,
}) {
  return Opacity(
    opacity: onTap == null ? .35 : 1,
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(.10)),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(.90), size: 20),
          ),
        ),
      ),
    ),
  );
}

String _shortRawPreview(String raw, {int maxChars = 220}) {
  final s = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length <= maxChars) return s;
  return '${s.substring(0, maxChars).trim()}…';
}
Future<void> _subtopicDialog(
  BuildContext context,
  dynamic repo,
  String courseId,
  String topicId, {
  SubtopicEntity? editing,
}) async {
  final name = TextEditingController(text: editing?.name ?? '');
  final orderCtrl = TextEditingController(
    text: (editing?.order ?? 1).toString(),
  );
  final link = TextEditingController(text: editing?.linkVideo ?? '');

  // ✅ ya no usaremos TextEditingController para el contenido como editor principal
  String contentRaw = editing?.content ?? '';

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        editing == null ? 'Nuevo subtema' : 'Editar subtema',
        style: TextStyle(
          color: Colors.white.withOpacity(.92),
          fontWeight: FontWeight.w900,
        ),
      ),
      content: StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogTF(ctrl: name, label: 'Nombre *'),

                _DialogTF(
                  ctrl: orderCtrl,
                  label: 'Orden (int) *',
                  keyboardType: TextInputType.number,
                ),

                _DialogTF(ctrl: link, label: 'Link video'),

                const SizedBox(height: 10),

                // ✅ Contenido: acciones + resumen
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(.10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Contenido (raw)',
                              style: TextStyle(
                                color: Colors.white.withOpacity(.92),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _miniIconBtn(
                            tooltip: 'Copiar raw',
                            icon: Icons.copy_rounded,
                            onTap: contentRaw.trim().isEmpty
                                ? null
                                : () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: contentRaw),
                                    );
                                    HapticFeedback.selectionClick();
                                    if (dialogContext.mounted) {
                                      ScaffoldMessenger.of(dialogContext)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Raw copiado ✅'),
                                        ),
                                      );
                                    }
                                  },
                          ),
                          const SizedBox(width: 8),
                          _miniIconBtn(
                            tooltip: 'Constructor',
                            icon: Icons.build_circle_rounded,
                            onTap: () async {
                              final res =
                                  await showModalBottomSheet<String>(
                                context: dialogContext,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                useSafeArea: true,
                                builder: (_) => ContentBuilderSheet(
                                  initialRaw: contentRaw,
                                ),
                              );

                              if (res != null) {
                                setStateDialog(() => contentRaw = res);
                                HapticFeedback.selectionClick();
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        contentRaw.trim().isEmpty
                            ? 'Aún no definiste el contenido. Usa el Constructor.'
                            : _shortRawPreview(contentRaw),
                        style: TextStyle(
                          color: Colors.white.withOpacity(.75),
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ Preview render (opcional pero recomendado)
                if (contentRaw.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.03),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vista previa',
                          style: TextStyle(
                            color: Colors.white.withOpacity(.92),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ExamQuestion(raw: contentRaw, useCard: true),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            final nav = Navigator.of(dialogContext, rootNavigator: true);
            if (nav.canPop()) nav.pop();
          },
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.white.withOpacity(.75)),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            final n = name.text.trim();
            final order = int.tryParse(orderCtrl.text.trim()) ?? 0;

            if (n.isEmpty) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Nombre es requerido')),
              );
              return;
            }
            if (order <= 0) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Orden debe ser > 0')),
              );
              return;
            }
            if (contentRaw.trim().isEmpty) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Define el contenido con el Constructor')),
              );
              return;
            }

            await repo.upsertSubtopic(
              courseId: courseId,
              topicId: topicId,
              subtopicId: editing?.id,
              name: n,
              content: contentRaw, // ✅ aquí guardas el raw final
              order: order,
              linkVideo: link.text.trim(),
            );

            HapticFeedback.selectionClick();
            if (dialogContext.mounted) {
              Navigator.of(dialogContext, rootNavigator: true).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'Guardar',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}

}

// ---------- UI components PRO ----------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22, color: Colors.white.withOpacity(.03)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(.10)),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(.92)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(.92),
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.60),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rightPill,
    required this.rightPillTone,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String rightPill;
  final _PillTone rightPillTone;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? AppTheme.accent.withOpacity(.55)
        : Colors.white.withOpacity(.08);

    return Container(
      decoration: AppTheme.cardDeco(radius: 22).copyWith(
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(.10)),
                  ),
                  child: Icon(icon, color: Colors.white.withOpacity(.92)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.92),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.70),
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _PillPro(text: rightPill, tone: rightPillTone),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (onEdit != null) _MiniBtn(icon: Icons.edit_rounded, onTap: onEdit!),
                if (onDelete != null) ...[
                  const SizedBox(width: 8),
                  _MiniBtn(icon: Icons.delete_outline_rounded, onTap: onDelete!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(.90), size: 18),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22),
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(.75),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pills,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> pills;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(.10)),
            ),
            child: Icon(icon, color: Colors.white.withOpacity(.92)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.92),
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.72),
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: pills),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogTF extends StatelessWidget {
  const _DialogTF({
    required this.ctrl,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController ctrl;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          color: Colors.white.withOpacity(.92),
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(.70)),
          filled: true,
          fillColor: Colors.white.withOpacity(.05),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.accent.withOpacity(.65)),
          ),
        ),
      ),
    );
  }
}

enum _PillTone { neutral, good, bad }

class _PillPro extends StatelessWidget {
  const _PillPro({required this.text, this.tone = _PillTone.neutral});
  final String text;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    if (tone == _PillTone.good) {
      bg = const Color(0xFF22C55E).withOpacity(.14);
      border = const Color(0xFF22C55E).withOpacity(.35);
    } else if (tone == _PillTone.bad) {
      bg = const Color(0xFFEF4444).withOpacity(.14);
      border = const Color(0xFFEF4444).withOpacity(.35);
    } else {
      bg = Colors.white.withOpacity(.06);
      border = Colors.white.withOpacity(.10);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(.90),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return _PillPro(text: text, tone: _PillTone.neutral);
  }
}

Future<bool> _confirmPro(
  BuildContext context, {
  required String title,
  required String message,
  required String primary,
}) async {
  if (!context.mounted) return false;

  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(.92),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withOpacity(.80), height: 1.25),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final nav = Navigator.of(dialogContext, rootNavigator: true);
              if (nav.canPop()) nav.pop(false);
            },
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.white.withOpacity(.78)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final nav = Navigator.of(dialogContext, rootNavigator: true);
              if (nav.canPop()) nav.pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(primary, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      );
    },
  );

  return res == true;
}
