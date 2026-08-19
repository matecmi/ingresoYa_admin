import 'package:flutter/material.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/part_form_sheet.dart';
import 'package:ingresoya_admin/src/ui/widgets/confirm_pro.dart';
import 'package:ingresoya_admin/src/ui/widgets/empty_card.dart';
import 'package:ingresoya_admin/src/ui/widgets/pill_tone.dart';
import 'package:ingresoya_admin/src/ui/widgets/row_card.dart';
import 'package:ingresoya_admin/src/ui/widgets/section_header.dart';

class SubtopicsPartTab extends StatelessWidget {
  const SubtopicsPartTab({
    super.key,
    required this.courseId,
    required this.repo,
    required this.topicId,
    required this.topicName,
    required this.subtopicName,
    required this.subtopicId,
  });

  final String courseId;
  final dynamic repo;
  final String? topicId;
  final String? topicName;
  final String? subtopicName;
  final String? subtopicId;

  @override
  Widget build(BuildContext context) {
    if (topicId == null || subtopicId == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: EmptyCard(
          text: 'Primero selecciona un subtema en la pestaña "Subtemas".',
        ),
      );
    }

    return StreamBuilder<List<SubtopicEntity>>(
      stream: repo.watchSubtopics(courseId: courseId, topicId: topicId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final subtopics = snapshot.data ?? const <SubtopicEntity>[];
        final matches = subtopics.where((item) => item.id == subtopicId);
        if (matches.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: EmptyCard(
              text:
                  'El subtema seleccionado ya no está disponible. Selecciona otro.',
            ),
          );
        }

        final subtopic = matches.first;
        final parts = [...subtopic.listPart]
          ..sort((a, b) => _orderOf(a).compareTo(_orderOf(b)));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          physics: const BouncingScrollPhysics(),
          children: [
            SectionHeader(
              title: 'Partes',
              subtitle: 'Subtema: ${subtopic.name} • ${parts.length} items',
              actionLabel: 'Agregar',
              onAction: () => _openForm(context),
              icon: Icons.add_rounded,
            ),
            const SizedBox(height: 10),
            if (parts.isEmpty) const EmptyCard(text: 'Aún no hay partes.'),
            ...parts.map(
              (part) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RowCard(
                  icon: Icons.article_rounded,
                  title: '${part.order}. ${part.name}',
                  subtitle: _subtitle(part),
                  rightPill: 'Orden ${part.order}',
                  rightPillTone: PillTone.neutral,
                  onEdit: () => _openForm(context, part: part),
                  onDelete: () => _deletePart(context, part),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  int _orderOf(SubtopicPartEntity part) => int.tryParse(part.order) ?? 0;

  String _subtitle(SubtopicPartEntity part) {
    if (part.linkVideo.isNotEmpty) return part.linkVideo;
    if (part.linkPdf.isNotEmpty) return part.linkPdf;
    if (part.content.isNotEmpty) return part.content;
    return 'Sin contenido ni recursos';
  }

  void _openForm(BuildContext context, {SubtopicPartEntity? part}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PartFormSheet(
        courseId: courseId,
        topicId: topicId!,
        subtopicId: subtopicId!,
        part: part,
      ),
    );
  }

  Future<void> _deletePart(
    BuildContext context,
    SubtopicPartEntity part,
  ) async {
    final confirmed = await confirmPro(
      context,
      title: 'Eliminar parte',
      message: 'Se eliminará "${part.name}".',
      primary: 'Eliminar',
    );
    if (!confirmed) return;

    await repo.deletePart(
      courseId: courseId,
      topicId: topicId!,
      subtopicId: subtopicId!,
      partId: part.id,
    );
  }
}
