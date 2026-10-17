import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/plain_text.dart';
import '../../../domain/quality_settings.dart';
import '../../../domain/question_signals.dart';
import '../../../domain/staff.dart';
import '../../../env/app_env.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import '../question/widgets/question_form_sheet.dart';

final _settingsProvider = StreamProvider.autoDispose<QualitySettings>(
  (ref) => ref.watch(appConfigRepoProvider).watchQualitySettings(),
);
final _statsProvider = StreamProvider.autoDispose
    .family<List<QuestionStat>, int>(
      (ref, min) => ref.watch(qualityRepoProvider).watch(minAnswers: min),
    );
final _updatedProvider = StreamProvider.autoDispose<DateTime?>(
  (ref) => ref.watch(qualityRepoProvider).watchUpdatedAt(),
);

/// Datos de la pregunta para mostrarla (enunciado, alternativas, ubicación).
class _QuestionInfo {
  const _QuestionInfo({
    required this.statement,
    required this.alternatives,
    required this.where,
    required this.status,
    required this.version,
  });

  final String statement;
  final Map<String, String> alternatives;
  final String where;
  final String status;
  final int version;
}

final _questionProvider = FutureProvider.autoDispose
    .family<_QuestionInfo?, String>((ref, id) async {
      final doc = await ref
          .watch(firestoreProvider)
          .collection(AppEnv.questionsCollection)
          .doc(id)
          .get();
      final d = doc.data();
      if (d == null) return null;
      String text(Object? content) {
        if (content is! List) return '';
        final parts = <String>[];
        for (final b in content.whereType<Map>()) {
          switch (b['type']) {
            case 'text':
              parts.add('${b['text'] ?? ''}');
            case 'formula':
              parts.add('${b['latex'] ?? ''}');
            case 'paragraph':
              for (final s
                  in (b['spans'] as List? ?? const []).whereType<Map>()) {
                parts.add('${s['text'] ?? s['latex'] ?? ''}');
              }
            case 'image':
              parts.add('[imagen]');
            case 'legacy':
              parts.add(plainStatement('${b['raw'] ?? ''}'));
          }
        }
        return parts.join(' ').trim();
      }

      final statement = text(d['content']);
      return _QuestionInfo(
        statement: statement.isNotEmpty
            ? statement
            : plainStatement('${d['statementText'] ?? ''}'),
        alternatives: {
          for (final a
              in (d['alternatives'] as List? ?? const []).whereType<Map>())
            '${a['id']}': text(a['content']),
        },
        where: [
          '${d['courseName'] ?? ''}',
          '${d['subtopicName'] ?? ''}',
          '${d['label'] ?? ''}',
        ].where((s) => s.trim().isNotEmpty).join(' · '),
        status: '${d['status'] ?? ''}',
        version: (d['version'] as num?)?.toInt() ?? 1,
      );
    });

/// Preguntas a revisar según las respuestas (tablero 11).
class QualityScreen extends ConsumerStatefulWidget {
  const QualityScreen({super.key});

  @override
  ConsumerState<QualityScreen> createState() => _QualityScreenState();
}

class _QualityScreenState extends ConsumerState<QualityScreen> {
  SignalKind? _tab = SignalKind.wrongKey;
  bool _reviewedTab = false;
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final n = await ref.read(qualityRepoProvider).refreshNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            n == 0
                ? 'Ya estaba al día.'
                : 'Listo: se sumaron $n examen(es) entregados.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar. Vuelve a intentarlo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(_settingsProvider).value ?? QualitySettings.defaults;
    final async = ref.watch(_statsProvider(settings.minAnswers));
    final updated = ref.watch(_updatedProvider).value;
    final canEdit = ref
        .watch(effectiveSessionProvider)
        .can(StaffSection.questions, StaffAction.edit);
    final stats = async.value ?? const <QuestionStat>[];
    final flagged = [
      for (final s in stats) (s, signalsFor(s, settings)),
    ].where((x) => x.$2.isNotEmpty).toList();
    final pending = flagged.where((x) => !x.$1.reviewedRecently).toList();
    final reviewed = flagged.where((x) => x.$1.reviewedRecently).toList();
    int count(SignalKind k) =>
        pending.where((x) => x.$2.any((s) => s.kind == k)).length;
    final shown = _reviewedTab
        ? reviewed
        : pending.where((x) => x.$2.any((s) => s.kind == _tab)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
      children: [
        AdminPageHeader(
          crumbs: const ['Calidad'],
          title: 'Preguntas a revisar',
          subtitle:
              'Detectadas con las respuestas de los alumnos. Solo cuentan las '
              'preguntas respondidas al menos ${settings.minAnswers} veces, '
              'para no sacar conclusiones con pocos datos.',
          actions: [
            OutlinedButton.icon(
              onPressed: _refreshing ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_refreshing ? 'Actualizando…' : 'Actualizar ahora'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          updated == null
              ? 'Aún no se sumaron respuestas. Se suman cada noche o con «Actualizar ahora».'
              : 'Respuestas sumadas hasta ${_date(updated)} · se actualiza cada noche.',
          style: const TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in SignalKind.values)
              ChoiceChip(
                label: Text('${k.label} · ${count(k)}'),
                selected: !_reviewedTab && _tab == k,
                onSelected: (_) => setState(() {
                  _tab = k;
                  _reviewedTab = false;
                }),
              ),
            ChoiceChip(
              label: Text('Revisadas · ${reviewed.length}'),
              selected: _reviewedTab,
              onSelected: (_) => setState(() => _reviewedTab = true),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (async.isLoading && stats.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (shown.isEmpty)
          SectionCard(
            child: EmptyState(
              icon: Icons.verified_outlined,
              title: _reviewedTab
                  ? 'No hay preguntas marcadas como revisadas'
                  : 'Nada que revisar en esta lista',
              message: stats.isEmpty
                  ? 'Todavía ninguna pregunta llega a ${settings.minAnswers} '
                        'respuestas.'
                  : null,
            ),
          )
        else
          for (final (stat, signals) in shown) ...[
            _StatCard(
              stat: stat,
              signals: _reviewedTab
                  ? signals
                  : signals.where((s) => s.kind == _tab).toList(),
              canEdit: canEdit,
              reviewed: _reviewedTab,
              onReviewed: () => ref
                  .read(qualityRepoProvider)
                  .markReviewed(
                    stat,
                    editor: ref.read(adminSessionProvider).email,
                  ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  static String _date(DateTime t) =>
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _StatCard extends ConsumerWidget {
  const _StatCard({
    required this.stat,
    required this.signals,
    required this.canEdit,
    required this.reviewed,
    required this.onReviewed,
  });

  final QuestionStat stat;
  final List<QuestionSignal> signals;
  final bool canEdit;
  final bool reviewed;
  final VoidCallback onReviewed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(_questionProvider(stat.questionId)).value;
    final wrongKey = signals.any((s) => s.kind == SignalKind.wrongKey);
    final oldVersion = info != null && info.version != stat.version;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDeco(),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320, maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info?.where ?? '',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  info?.statement ?? 'Cargando…',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final s in signals) ...[
                  InfoNote(
                    s.message,
                    tone: s.kind == SignalKind.wrongKey
                        ? Tone.error
                        : Tone.warn,
                  ),
                  const SizedBox(height: 6),
                ],
                if (oldVersion)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Ya se publicó una versión nueva de esta pregunta: estos '
                      'datos son de la versión anterior.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
                    ),
                  ),
                if (reviewed && stat.reviewedBy != null)
                  Text(
                    'Revisada por ${stat.reviewedBy} con ${stat.reviewedAnswered} respuestas.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.muted,
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: wrongKey
                            ? AppTheme.brand
                            : AppTheme.card,
                        foregroundColor: wrongKey ? Colors.white : AppTheme.ink,
                        side: wrongKey
                            ? null
                            : const BorderSide(color: AppTheme.lineStrong),
                      ),
                      onPressed: () async {
                        final q = await ref
                            .read(questionRepoProvider)
                            .getQuestion(stat.questionId);
                        if (q == null || !context.mounted) return;
                        await showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          useSafeArea: true,
                          builder: (_) => QuestionFormSheet(question: q),
                        );
                      },
                      child: Text(
                        wrongKey ? 'Abrir y corregir' : 'Abrir la pregunta',
                      ),
                    ),
                    if (canEdit && !reviewed)
                      OutlinedButton(
                        onPressed: onReviewed,
                        child: const Text('Está bien así'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 380),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qué eligieron (${stat.answered} respuestas'
                  '${stat.blank > 0 ? ', ${stat.blank} en blanco' : ''})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final id in stat.alternativeIds)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            '${stat.label(id)}) ${info?.alternatives[id] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: id == stat.correctAlternativeId
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (id == stat.correctAlternativeId)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: AppTheme.success,
                            ),
                          ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: stat.percentOf(id) / 100,
                              minHeight: 10,
                              color: id == stat.correctAlternativeId
                                  ? AppTheme.success
                                  : (wrongKey && stat.percentOf(id) >= 50
                                        ? AppTheme.error
                                        : AppTheme.faint),
                              backgroundColor: const Color(0xFFF2F4F7),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${stat.percentOf(id)} %',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
