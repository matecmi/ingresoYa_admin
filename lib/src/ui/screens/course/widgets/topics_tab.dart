
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ingresoya_admin/src/domain/entities/topic_entity.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:ingresoya_admin/src/ui/widgets/confirm_pro.dart' show confirmPro;
import 'package:ingresoya_admin/src/ui/widgets/dialog_tf.dart';
import 'package:ingresoya_admin/src/ui/widgets/empty_card.dart';
import 'package:ingresoya_admin/src/ui/widgets/pill_tone.dart';
import 'package:ingresoya_admin/src/ui/widgets/row_card.dart';
import 'package:ingresoya_admin/src/ui/widgets/section_header.dart';

class TopicsTab extends StatelessWidget {
  const TopicsTab({
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
            SectionHeader(
              title: 'Temas',
              subtitle: '${items.length} registrados',
              actionLabel: 'Agregar',
              onAction: () => _topicDialog(context, repo, courseId),
              icon: Icons.add_rounded,
            ),
            const SizedBox(height: 10),

            if (items.isEmpty) EmptyCard(text: 'Aún no hay temas.'),

            ...items.map((t) {
              final selected = selectedTopicId == t.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RowCard(
                  selected: selected,
                  icon: selected
                      ? Icons.check_circle_rounded
                      : Icons.layers_rounded,
                  title: '${t.order}. ${t.name}',
                  subtitle: t.summary.isEmpty ? t.description : t.summary,
                  rightPill: 'Orden ${t.order}',
                  rightPillTone: selected ? PillTone.good : PillTone.neutral,
                  onTap: () => onTopicSelected(t.id, t.name),
                  onEdit: () =>
                      _topicDialog(context, repo, courseId, editing: t),
                  onDelete: () async {
                    final ok = await confirmPro(
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
    final orderCtrl = TextEditingController(
      text: editing?.order.toString() ?? '1',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          editing == null ? 'Nuevo tema' : 'Editar tema',
          style: TextStyle(
            color: Colors.white.withOpacity(.92),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DialogTF(ctrl: name, label: 'Nombre *'),
              DialogTF(
                ctrl: orderCtrl,
                label: 'Orden (int) *',
                keyboardType: TextInputType.number,
              ),
              DialogTF(ctrl: summary, label: 'Resumen'),
              DialogTF(ctrl: desc, label: 'Descripción', maxLines: 3),
            ],
          ),
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
              if (dialogContext.mounted)
                Navigator.of(dialogContext, rootNavigator: true).pop();
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
