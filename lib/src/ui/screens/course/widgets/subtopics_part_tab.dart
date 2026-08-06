
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:ingresoya_admin/src/ui/widgets/confirm_pro.dart';
import 'package:ingresoya_admin/src/ui/widgets/content_builder_sheet.dart';
import 'package:ingresoya_admin/src/ui/widgets/dialog_tf.dart';
import 'package:ingresoya_admin/src/ui/widgets/empty_card.dart';
import 'package:ingresoya_admin/src/ui/widgets/exam_question.dart';
import 'package:ingresoya_admin/src/ui/widgets/pill_tone.dart';
import 'package:ingresoya_admin/src/ui/widgets/row_card.dart';
import 'package:ingresoya_admin/src/ui/widgets/section_header.dart';

class SubtopicsPartTab extends StatelessWidget {
  const SubtopicsPartTab({
    required this.courseId,
    required this.repo,
    required this.topicId,
    required this.topicName,
    required this.subtopicName,
    required this.subtopicId
  });

  final String courseId;
  final dynamic repo; // (CourseRepo)
  final String? topicId;
  final String? topicName;
  final String? subtopicName;
  final String? subtopicId;


  @override
  Widget build(BuildContext context) {
    if (topicId == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: EmptyCard(
          text: 'Primero selecciona un subtema en la pestaña "Subtemas".',
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RowCard(
                  icon: Icons.article_rounded,
                  title: '${s.order}. ${s.name}',
                  subtitle: s.linkVideo.isEmpty ? 'Sin video' : s.linkVideo,
                  rightPill: 'Orden ${s.order}',
                  rightPillTone: PillTone.neutral,
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
                  DialogTF(ctrl: name, label: 'Nombre *'),

                  DialogTF(
                    ctrl: orderCtrl,
                    label: 'Orden (int) *',
                    keyboardType: TextInputType.number,
                  ),

                  DialogTF(ctrl: link, label: 'Link video'),

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
                                        ScaffoldMessenger.of(
                                          dialogContext,
                                        ).showSnackBar(
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
                                final res = await showModalBottomSheet<String>(
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
                        border: Border.all(
                          color: Colors.white.withOpacity(.08),
                        ),
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
                  const SnackBar(
                    content: Text('Define el contenido con el Constructor'),
                  ),
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

