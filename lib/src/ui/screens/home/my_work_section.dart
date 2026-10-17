import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/question_entity.dart';
import '../../../domain/plain_text.dart';
import '../../../domain/staff.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import '../question/widgets/question_form_sheet.dart';

final _reviewQueueProvider = StreamProvider.autoDispose<List<QuestionEntity>>(
  (ref) => ref.watch(questionRepoProvider).watchReviewQueue(),
);

final _myReviewsProvider = StreamProvider.autoDispose
    .family<List<QuestionEntity>, String>(
      (ref, uid) => ref.watch(questionRepoProvider).watchMyReviews(uid),
    );

/// «Mi trabajo» en Inicio (tablero 14): lo que envié a revisión y, si puedo
/// publicar, lo que espera mi revisión.
class MyWorkSection extends ConsumerWidget {
  const MyWorkSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(effectiveSessionProvider);
    final canPublish = session.can(StaffSection.questions, StaffAction.publish);
    final canEdit = session.can(StaffSection.questions, StaffAction.edit);
    final sections = <Widget>[];

    if (canPublish) {
      final queue = ref.watch(_reviewQueueProvider).value ?? const [];
      sections.add(
        _ReviewList(
          title: 'Por revisar · ${queue.length}',
          empty: 'Nada espera tu revisión.',
          items: queue,
          subtitle: (q) =>
              'Enviada por ${q.review?.requestedByEmail.isEmpty ?? true ? 'un editor' : q.review!.requestedByEmail}'
              '${q.courseName.isEmpty ? '' : ' · ${q.courseName}'}',
          pill: (_) => const StatusPill('Por revisar', tone: Tone.warn),
        ),
      );
    }
    if (canEdit && !canPublish && session.uid.isNotEmpty) {
      final mine = ref.watch(_myReviewsProvider(session.uid)).value ?? const [];
      final returned = mine.where((q) => q.review!.returned).toList();
      final pending = mine.where((q) => q.review!.pending).toList();
      sections.add(
        _ReviewList(
          title: 'Mis envíos a revisión',
          empty:
              'Aún no enviaste preguntas a revisión. Cárgalas y toca «Enviar a '
              'revisión».',
          items: [...returned, ...pending],
          subtitle: (q) => q.review!.returned
              ? '«${q.review!.note}»'
              : 'Esperando revisión${q.courseName.isEmpty ? '' : ' · ${q.courseName}'}',
          pill: (q) => q.review!.returned
              ? const StatusPill('Devuelta', tone: Tone.error)
              : const StatusPill('En revisión', tone: Tone.warn),
        ),
      );
    }
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in sections) ...[s, const SizedBox(height: 16)],
      ],
    );
  }
}

class _ReviewList extends StatelessWidget {
  const _ReviewList({
    required this.title,
    required this.empty,
    required this.items,
    required this.subtitle,
    required this.pill,
  });

  final String title;
  final String empty;
  final List<QuestionEntity> items;
  final String Function(QuestionEntity) subtitle;
  final Widget Function(QuestionEntity) pill;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(empty, style: TextStyle(color: AppTheme.muted)),
            )
          : Column(
              children: [
                for (final q in items.take(8))
                  InkWell(
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      useSafeArea: true,
                      builder: (_) => QuestionFormSheet(question: q),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.rowLine),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plainStatement(q.statementText).isEmpty
                                      ? 'Pregunta sin enunciado'
                                      : plainStatement(q.statementText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  subtitle(q),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          pill(q),
                        ],
                      ),
                    ),
                  ),
                if (items.length > 8)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'y ${items.length - 8} más',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ),
              ],
            ),
    );
  }
}
