import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/content_health.dart';
import '../../../domain/staff.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';

/// Ruta para resolver un problema: el editor de la parte o el curso.
String healthRoute(HealthIssue i) => i.partId == null
    ? '/courses/${i.courseId}'
    : '/courses/${i.courseId}/part/${i.partId}?topic=${i.topicId}&subtopic=${i.subtopicId}';

/// «Salud del contenido» en Inicio (tablero 7): lo que bloquea al alumno y lo
/// que le resta calidad, cada cosa con su «Resolver».
class ContentHealthSection extends ConsumerWidget {
  const ContentHealthSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(effectiveSessionProvider);
    if (!session.can(StaffSection.courses, StaffAction.view)) {
      return const SizedBox.shrink();
    }
    final health = ref.watch(contentHealthProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Salud del contenido',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: health.isLoading
                  ? null
                  : () => refreshContentHealth(ref),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Revisar ahora'),
            ),
          ],
        ),
        Text(
          health.isLoading
              ? 'Revisando cursos, partes, plantillas y preguntas…'
              : 'Revisado ${_ago(health.value?.checkedAt)} · cada problema dice '
                    'qué le pasa al alumno.',
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 12),
        if (health.hasError)
          const InfoNote(
            'No se pudo revisar el contenido. Vuelve a intentarlo con «Revisar '
            'ahora».',
            tone: Tone.error,
          )
        else if (health.isLoading && !health.hasValue)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          _Body(report: health.value!),
      ],
    );
  }

  static String _ago(DateTime? t) {
    if (t == null || t.millisecondsSinceEpoch == 0) return 'recién';
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 1) return 'hace un momento';
    if (m < 60) return 'hace $m min';
    return 'hace ${m ~/ 60} h';
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.report});

  final ContentHealthReport report;

  @override
  Widget build(BuildContext context) {
    final blocking = report.blocking;
    final quality = report.quality;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final tiles = [
              KpiTile(
                label: 'Bloquean al alumno',
                value: '${blocking.length}',
                hint: 'no puede aprobar o abrir algo',
                tone: blocking.isEmpty ? Tone.success : Tone.error,
              ),
              KpiTile(
                label: 'Le restan calidad',
                value: '${quality.length}',
                hint: 'funciona, pero se puede mejorar',
                tone: quality.isEmpty ? Tone.success : Tone.warn,
              ),
              KpiTile(
                label: 'Partes listas',
                value: '${report.readyParts} de ${report.parts.length}',
                hint: 'contenido + examen funcionando',
                tone: Tone.success,
              ),
            ];
            final cols = c.maxWidth >= 760 ? 3 : 1;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final t in tiles)
                  SizedBox(
                    width: cols == 1
                        ? c.maxWidth
                        : (c.maxWidth - 12 * (cols - 1)) / cols,
                    child: t,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        if (blocking.isEmpty && quality.isEmpty)
          const InfoNote(
            'Todo en orden: cada parte activa tiene su examen con preguntas '
            'suficientes.',
            tone: Tone.success,
            icon: Icons.check_circle_outline_rounded,
          ),
        if (blocking.isNotEmpty)
          _IssueList(
            title: 'Bloquean al alumno',
            color: AppTheme.error,
            issues: blocking,
          ),
        if (blocking.isNotEmpty && quality.isNotEmpty)
          const SizedBox(height: 12),
        if (quality.isNotEmpty)
          _IssueList(
            title: 'Le restan calidad',
            color: AppTheme.warn,
            issues: quality,
          ),
      ],
    );
  }
}

class _IssueList extends StatefulWidget {
  const _IssueList({
    required this.title,
    required this.color,
    required this.issues,
  });

  final String title;
  final Color color;
  final List<HealthIssue> issues;

  @override
  State<_IssueList> createState() => _IssueListState();
}

class _IssueListState extends State<_IssueList> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final shown = _all ? widget.issues : widget.issues.take(5).toList();
    return SectionCard(
      title: '${widget.title} · ${widget.issues.length}',
      titleColor: widget.color,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Column(
        children: [
          for (final i in shown)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.rowLine)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          i.detail,
                          style: TextStyle(fontSize: 13, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(healthRoute(i)),
                    child: const Text('Resolver →'),
                  ),
                ],
              ),
            ),
          if (widget.issues.length > 5)
            TextButton(
              onPressed: () => setState(() => _all = !_all),
              child: Text(
                _all ? 'Ver menos' : 'Ver los ${widget.issues.length}',
              ),
            ),
        ],
      ),
    );
  }
}
