import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repo/student_repo.dart';
import '../../../data/repo/xp_repo.dart';
import '../../../domain/rankings_settings.dart';
import '../../../domain/staff.dart';
import '../../../domain/xp_settings.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';

/// Buscar alumno por correo, nombre de usuario o uid.
class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final _ctrl = TextEditingController();
  List<XpStudent>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final results = await ref.read(studentRepoProvider).search(_ctrl.text);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
    if (results.length == 1) context.go('/students/${results.single.uid}');
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
      children: [
        const AdminPageHeader(
          crumbs: ['Alumnos'],
          title: 'Buscar alumno',
          subtitle:
              'Por correo, nombre de usuario (con o sin tildes) o uid. La ficha '
              'reúne su avance, exámenes, XP y nombre de usuario.',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onSubmitted: (_) => _search(),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Correo, nombre de usuario o uid',
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              onPressed: _searching ? null : _search,
              child: Text(_searching ? 'Buscando…' : 'Buscar'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (results != null && results.isEmpty)
          const SectionCard(
            child: EmptyState(
              title: 'No encontramos a nadie',
              message:
                  'Revisa el correo completo (el de su cuenta de Google) o el '
                  'nombre de usuario exacto.',
            ),
          ),
        if (results != null && results.length > 1)
          SectionCard(
            title: '${results.length} alumnos',
            child: Column(
              children: [
                for (final s in results)
                  ListTile(
                    title: Text(s.name.isEmpty ? s.email : s.name),
                    subtitle: Text('${s.email} · ${s.career}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.go('/students/${s.uid}'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

final _profileProvider = StreamProvider.autoDispose
    .family<StudentProfile?, String>(
      (ref, uid) => ref.watch(studentRepoProvider).watchProfile(uid),
    );
final _rankingProvider = StreamProvider.autoDispose
    .family<StudentRanking, String>(
      (ref, uid) => ref.watch(studentRepoProvider).watchRanking(uid),
    );
final _xpStateProvider = StreamProvider.autoDispose
    .family<XpStudentState, String>(
      (ref, uid) => ref.watch(xpRepoProvider).watchState(uid),
    );
final _xpSettingsProvider = StreamProvider.autoDispose<XpSettings>(
  (ref) => ref.watch(xpRepoProvider).watchSettings(),
);
final _rankingsSettingsProvider = StreamProvider.autoDispose<RankingsSettings>(
  (ref) => ref.watch(rankingsRepoProvider).watchSettings(),
);
final _ledgerProvider = StreamProvider.autoDispose
    .family<List<XpLedgerEvent>, String>(
      (ref, uid) => ref.watch(xpRepoProvider).watchLedger(uid, limit: 60),
    );
final _resultsProvider = StreamProvider.autoDispose
    .family<List<SimulatorResultRow>, String>(
      (ref, uid) => ref.watch(studentRepoProvider).watchResults(uid),
    );
final _partsProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, uid) => ref.watch(studentRepoProvider).approvedParts(uid),
);

String _ago(int ms) {
  if (ms == 0) return '—';
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  final d = DateTime.now().difference(t);
  final hm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (d.inDays == 0 && DateTime.now().day == t.day) return 'hoy $hm';
  if (d.inDays <= 1) return 'ayer $hm';
  return '${t.day}/${t.month} $hm';
}

/// Ficha del alumno en un solo lugar (tablero 10).
class StudentFileScreen extends ConsumerStatefulWidget {
  const StudentFileScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<StudentFileScreen> createState() => _StudentFileScreenState();
}

class _StudentFileScreenState extends ConsumerState<StudentFileScreen> {
  int _tab = 0;

  String get _uid => widget.uid;

  Future<String?> _askReason(String title, String message) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Motivo'),
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
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return reason;
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message : 'No se pudo guardar.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref
        .watch(effectiveSessionProvider)
        .can(StaffSection.students, StaffAction.edit);
    final profile = ref.watch(_profileProvider(_uid));
    final p = profile.value;
    final ranking =
        ref.watch(_rankingProvider(_uid)).value ?? const StudentRanking();
    final xp = ref.watch(_xpStateProvider(_uid)).value ?? XpStudentState.empty;
    final xpSettings = ref.watch(_xpSettingsProvider).value;
    final rankSettings = ref.watch(_rankingsSettingsProvider).value;
    final ledger = ref.watch(_ledgerProvider(_uid)).value ?? const [];
    final results = ref.watch(_resultsProvider(_uid)).value ?? const [];
    final parts = ref.watch(_partsProvider(_uid)).value;
    final editor = ref.read(adminSessionProvider).email;

    if (profile.isLoading && p == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p == null) {
      return const Center(
        child: EmptyState(
          title: 'No existe un alumno con ese uid',
          icon: Icons.person_off_outlined,
        ),
      );
    }
    final rankName =
        xpSettings == null || xp.rankStep >= xpSettings.ranks.length
        ? ''
        : xpSettings.ranks[xp.rankStep].name;
    final stages =
        rankSettings?.stageNames ?? RankingsSettings.defaultStageNames;
    final stage = ranking.stage < stages.length ? stages[ranking.stage] : '';
    final avg = results.isEmpty
        ? null
        : (results.fold<double>(0, (a, r) => a + r.percentage) / results.length)
              .round();
    final lastActivity = ledger.isEmpty ? 0 : ledger.first.atMs;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
      children: [
        Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                child: InkWell(
                  onTap: () => context.go('/students'),
                  child: Text(
                    'Alumnos',
                    style: TextStyle(color: AppTheme.brand, fontSize: 13),
                  ),
                ),
              ),
              TextSpan(text: ' / ${p.displayName}'),
            ],
          ),
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        SectionCard(
          child: Wrap(
            spacing: 18,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.brandSoft,
                child: Text(
                  p.displayName[0].toUpperCase(),
                  style: TextStyle(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 280, maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        p.email,
                        p.university,
                        p.career,
                      ].where((s) => s.isNotEmpty).join(' · '),
                      style: TextStyle(fontSize: 13, color: AppTheme.muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusPill(
                          ranking.alias == null
                              ? 'Sin nombre de usuario'
                              : 'Nombre de usuario: ${ranking.alias}',
                        ),
                        if (ranking.hidden)
                          const StatusPill(
                            'Oculto en los rankings',
                            tone: Tone.warn,
                          ),
                        StatusPill(
                          '${rankName.isEmpty ? 'Rango' : rankName} · ${xp.total} XP',
                          tone: Tone.info,
                        ),
                        if (stage.isNotEmpty)
                          StatusPill('Liga: $stage', tone: Tone.success),
                      ],
                    ),
                    if (ranking.moderatedReason != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Nombre retirado: «${ranking.moderatedReason}»',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.warn),
                      ),
                    ],
                  ],
                ),
              ),
              if (canEdit && ranking.alias != null)
                OutlinedButton(
                  onPressed: () async {
                    final reason = await _askReason(
                      'Retirar el nombre de usuario',
                      'La app le asigna uno al azar y le muestra el motivo hasta '
                          'que elija otro.',
                    );
                    if (reason == null || reason.isEmpty) return;
                    await _run(
                      () => ref
                          .read(rankingsRepoProvider)
                          .removeUsername(
                            _uid,
                            ranking.alias!,
                            reason: reason,
                            editor: editor,
                          ),
                      'Nombre de usuario retirado.',
                    );
                  },
                  child: const Text('Retirar nombre de usuario'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          children: [
            for (final (i, label) in [
              'Resumen',
              'Exámenes · ${results.length}',
              'Libro de XP',
            ].indexed)
              ChoiceChip(
                label: Text(label),
                selected: _tab == i,
                onSelected: (_) => setState(() => _tab = i),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (_tab == 0) ...[
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth >= 900 ? (c.maxWidth - 36) / 4 : c.maxWidth;
              Widget tile(String label, String value, String hint) => SizedBox(
                width: w,
                child: KpiTile(label: label, value: value, hint: hint),
              );
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  tile(
                    'Guía de estudio',
                    parts == null ? '…' : '$parts',
                    'partes aprobadas',
                  ),
                  tile(
                    'Simulador',
                    results.length == 1
                        ? '1 examen'
                        : '${results.length} exámenes',
                    avg == null ? 'sin exámenes' : '$avg % de acierto promedio',
                  ),
                  tile('Esta semana', '${xp.weekXp} XP', 'cuenta para la liga'),
                  tile(
                    'Última actividad',
                    _ago(lastActivity),
                    ledger.isEmpty
                        ? ''
                        : (xpEventLabels[ledger.first.type] ??
                              ledger.first.type),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _LedgerCard(
            events: ledger.take(6).toList(),
            canEdit: canEdit,
            onRevert: _revert,
            title: 'Últimos movimientos de XP',
          ),
        ],
        if (_tab == 1)
          SectionCard(
            title: 'Exámenes del Simulador',
            child: results.isEmpty
                ? const EmptyState(title: 'Aún no rinde exámenes')
                : Column(
                    children: [
                      for (final r in results)
                        Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppTheme.rowLine),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 110,
                                child: Text(
                                  _ago(r.atMs),
                                  style: TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Expanded(child: Text(r.title)),
                              Text(
                                '${r.correct}/${r.total} · ${r.percentage.round()} %',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        if (_tab == 2)
          _LedgerCard(
            events: ledger,
            canEdit: canEdit,
            onRevert: _revert,
            title: 'Libro de XP',
          ),
      ],
    );
  }

  Future<void> _revert(XpLedgerEvent e) async {
    final reason = await _askReason(
      'Revertir ${xpEventLabels[e.type] ?? e.type} (+${e.xp} XP)',
      'El alumno pierde estos XP y el evento no se vuelve a otorgar.',
    );
    if (reason == null || reason.isEmpty) return;
    await _run(
      () => ref
          .read(xpRepoProvider)
          .revert(
            _uid,
            e.id,
            reason: reason,
            editor: ref.read(adminSessionProvider).email,
          ),
      'Revertido.',
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.events,
    required this.canEdit,
    required this.onRevert,
    required this.title,
  });

  final List<XpLedgerEvent> events;
  final bool canEdit;
  final ValueChanged<XpLedgerEvent> onRevert;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: events.isEmpty
          ? const EmptyState(title: 'Sin movimientos de XP')
          : Column(
              children: [
                for (final e in events)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: AppTheme.rowLine)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: Text(
                            _ago(e.atMs),
                            style: TextStyle(
                              color: AppTheme.muted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            e.reverted
                                ? '${xpEventLabels[e.type] ?? e.type} · revertido: «${e.revertReason ?? ''}»'
                                : (xpEventLabels[e.type] ?? e.type),
                            style: TextStyle(
                              color: e.reverted ? AppTheme.muted : AppTheme.ink,
                              decoration: e.reverted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: Text(
                            e.reverted ? '0' : '+${e.xp}',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: e.reverted
                                  ? AppTheme.muted
                                  : AppTheme.success,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: canEdit && !e.reverted && e.xp > 0
                              ? TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppTheme.error,
                                  ),
                                  onPressed: () => onRevert(e),
                                  child: const Text('Revertir'),
                                )
                              : const SizedBox(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
