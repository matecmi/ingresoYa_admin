// GENERADO por tool/sync_app_preview.py — NO EDITAR A MANO.
// Copia fiel de iya-app/lib/features/simulator/presentation/pages/exam_view/part_exam_attempt_widgets.dart (commit 783bb74) para que la vista
// previa del admin sea idéntica a la app. Textos tomados de app_es.arb.
// ignore_for_file: type=lint, deprecated_member_use

import 'package:flutter/material.dart';
import 'app_theme.g.dart';
import 'question_content_renderer.g.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';

class PartExamAlternativeTile extends StatelessWidget {
  const PartExamAlternativeTile({
    super.key,
    required this.alternative,
    required this.selectedAlternativeId,
    required this.enabled,
    required this.onTap,
  });

  final QuestionAlternative alternative;
  final String? selectedAlternativeId;
  final bool enabled;
  final VoidCallback onTap;

  bool get selected => selectedAlternativeId == alternative.id;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    selected: selected,
    label: 'Alternativa ${alternative.label}',
    button: true,
    child: Material(
      color: selected
          ? context.appColors.primaryContainer
          : context.appColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? context.appColors.primary
              : context.appColors.outline,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? context.appColors.primary
                      : context.appColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  alternative.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? context.appColors.onPrimary
                        : context.appColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: QuestionAlternativeRenderer(alternative: alternative),
              ),
              if (selected) ...[
                const SizedBox(width: 10),
                Icon(
                  Icons.check_circle_rounded,
                  color: context.appColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class PartExamProgressHeader extends StatelessWidget {
  const PartExamProgressHeader({
    super.key,
    required this.questionIndex,
    required this.questionCount,
    required this.answeredCount,
    this.remaining,
    this.expired = false,
  });

  final int questionIndex;
  final int questionCount;
  final int answeredCount;
  final String? remaining;
  final bool expired;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.appColors.outline),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pregunta ${questionIndex + 1} de ${questionCount}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (remaining != null)
              Semantics(
                label: 'Tiempo restante ${remaining!}',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: expired
                        ? context.appColors.errorContainer
                        : context.appColors.primaryContainer,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 15,
                        color: expired
                            ? context.appColors.error
                            : context.appColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        remaining!,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Semantics(
                label:
                    '${answeredCount} de ${questionCount} preguntas respondidas',
                child: LinearProgressIndicator(
                  value: questionCount == 0 ? 0 : answeredCount / questionCount,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${answeredCount}/${questionCount} respondidas',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.appColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class PartExamSourceCard extends StatelessWidget {
  const PartExamSourceCard({
    super.key,
    required this.sourceLabel,
    required this.sourceType,
  });

  final String sourceLabel;
  final String sourceType;

  @override
  Widget build(BuildContext context) {
    final fromExam =
        sourceType == 'admission_exam' ||
        sourceType == 'official_practice' ||
        sourceLabel.toLowerCase().contains('examen');
    final heading = sourceType == 'adapted'
        ? 'Pregunta adaptada de'
        : fromExam
        ? 'Pregunta tomada de'
        : 'Origen de la pregunta';
    return Semantics(
      label: '${heading}: ${sourceLabel}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.appColors.elevatedSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appColors.outline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 19,
              color: context.appColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.appColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sourceLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
