import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/course_entity_form_sheet.dart';
import 'package:ingresoya_admin/src/ui/widgets/confirm_pro.dart';
import 'package:ingresoya_admin/src/ui/widgets/dialog_tf.dart';
import 'package:ingresoya_admin/src/ui/widgets/empty_card.dart';
import 'package:ingresoya_admin/src/ui/widgets/pill_tone.dart';
import 'package:ingresoya_admin/src/ui/widgets/row_card.dart';
import 'package:ingresoya_admin/src/ui/widgets/section_header.dart';

class SubtopicsTab extends StatelessWidget {
  const SubtopicsTab({
    super.key,
    required this.courseId,
    required this.repo,
    required this.topicId,
    required this.topicName,
    required this.onSubtopicSelected,
    required this.selectedSubtopicId,
  });

  final String courseId;
  final dynamic repo; // (CourseRepo)
  final String? topicId;
  final String? topicName;
  final String? selectedSubtopicId;
  final void Function(String topicId, String topicName) onSubtopicSelected;

  @override
  Widget build(BuildContext context) {
    if (topicId == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: EmptyCard(
          text: 'Primero selecciona un tema en la pestaña "Temas".',
        ),
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
            SectionHeader(
              title: 'Subtemas',
              subtitle: 'Tema: ${topicName ?? "—"} • ${items.length} items',
              actionLabel: 'Agregar',
              onAction: () =>
                  _subtopicDialog(context, repo, courseId, topicId!),
              icon: Icons.add_rounded,
            ),
            const SizedBox(height: 10),

            if (items.isEmpty) EmptyCard(text: 'Aún no hay subtemas.'),

            ...items.map((s) {
              final selected = selectedSubtopicId == s.id;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RowCard(
                  selected: selected,
                  icon: selected
                      ? Icons.check_circle_rounded
                      : Icons.layers_rounded,
                  title: '${s.order}. ${s.name}',
                  subtitle: s.linkVideo.isEmpty ? 'Sin video' : s.linkVideo,
                  rightPill: 'Orden ${s.order}',
                  rightPillTone: selected ? PillTone.good : PillTone.neutral,
                  onTap: () => onSubtopicSelected(s.id, s.name),
                  onEdit: () => _subtopicDialog(
                    context,
                    repo,
                    courseId,
                    topicId!,
                    editing: s,
                  ),
                  onDelete: () async {
                    final ok = await confirmPro(
                      context,
                      title: 'Eliminar subtema',
                      message: 'Se eliminará "${s.name}".',
                      primary: 'Eliminar',
                    );
                    if (!ok) return;
                    await repo.deleteSubtopic(
                      courseId: courseId,
                      topicId: topicId!,
                      subtopicId: s.id,
                    );
                  },
                ),
              );
            }),
          ],
        );
      },
    );
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
    final description = TextEditingController(text: editing?.content ?? '');
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (sheetContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: StatefulBuilder(
          builder: (dialogContext, setStateDialog) => CourseEntityFormSheet(
            title: editing == null ? 'Nuevo subtema' : 'Editar subtema',
            description: 'Agrega contenido y recursos para este tema.',
            icon: Icons.account_tree_rounded,
            saving: saving,
            child: Column(
              children: [
                DialogTF(ctrl: name, label: 'Nombre *'),
                DialogTF(
                  ctrl: orderCtrl,
                  label: 'Orden *',
                  keyboardType: TextInputType.number,
                ),
                DialogTF(ctrl: link, label: 'Link video'),
                DialogTF(
                  ctrl: description,
                  label: 'Descripción *',
                  maxLines: 6,
                ),
              ],
            ),
            onSave: () async {
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
              if (description.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Descripción es requerida')),
                );
                return;
              }
              var closed = false;
              setStateDialog(() => saving = true);
              try {
                await repo.upsertSubtopic(
                  courseId: courseId,
                  topicId: topicId,
                  subtopicId: editing?.id,
                  name: n,
                  content: description.text.trim(),
                  order: order,
                  linkVideo: link.text.trim(),
                );
                HapticFeedback.selectionClick();
                if (sheetContext.mounted) {
                  closed = true;
                  Navigator.of(sheetContext).pop();
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('No se pudo guardar el subtema: $error'),
                    ),
                  );
                }
              } finally {
                if (!closed && dialogContext.mounted) {
                  setStateDialog(() => saving = false);
                }
              }
            },
          ),
        ),
      ),
    );

    name.dispose();
    orderCtrl.dispose();
    link.dispose();
    description.dispose();
  }
}
