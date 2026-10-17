import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/data/repo/xp_repo.dart';
import 'package:ingresoya_admin/src/domain/xp_settings.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/xp_settings_card.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

/// «XP de un alumno»: find a student, read the XP ledger, revert an event.
class XpStudentTool extends ConsumerStatefulWidget {
  const XpStudentTool({super.key});

  @override
  ConsumerState<XpStudentTool> createState() => _XpStudentToolState();
}

class _XpStudentToolState extends ConsumerState<XpStudentTool> {
  final _query = TextEditingController();
  List<XpStudent>? _results;
  XpStudent? _selected;
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      final results = await ref.read(xpRepoProvider).findStudents(_query.text);
      setState(() {
        _results = results;
        _selected = results.length == 1 ? results.first : null;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo buscar: $error')));
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.ink.withValues(alpha: .6);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_search_rounded),
              SizedBox(width: 10),
              Text(
                'XP de un alumno',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Busca por correo o uid, revisa su libro de XP y revierte un evento si hubo un error o una trampa. '
            'Un evento revertido no se vuelve a otorgar.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('xp-student-query'),
                  controller: _query,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Correo o uid del alumno',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const ValueKey('xp-student-search'),
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Buscar'),
              ),
            ],
          ),
          if (_results != null && _results!.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'No encontramos a ese alumno.',
                style: TextStyle(color: muted),
              ),
            ),
          if (_results != null && _results!.length > 1)
            for (final student in _results!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(student.name.isEmpty ? student.uid : student.name),
                subtitle: Text('${student.email} · ${student.career}'),
                selected: _selected?.uid == student.uid,
                onTap: () => setState(() => _selected = student),
              ),
          if (_selected != null)
            _StudentLedger(key: ValueKey(_selected!.uid), student: _selected!),
        ],
      ),
    );
  }
}

class _StudentLedger extends ConsumerWidget {
  const _StudentLedger({super.key, required this.student});

  final XpStudent student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(xpRepoProvider);
    final muted = AppTheme.ink.withValues(alpha: .6);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: StreamBuilder<XpSettings>(
        stream: repo.watchSettings(),
        builder: (context, settingsSnapshot) {
          final settings = settingsSnapshot.data ?? XpSettings.defaults;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                student.name.isEmpty ? student.uid : student.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              Text(
                '${student.email} · ${student.career} · ${student.uid}',
                style: TextStyle(color: muted, fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              StreamBuilder<XpStudentState>(
                stream: repo.watchState(student.uid),
                builder: (context, snapshot) {
                  final state = snapshot.data ?? XpStudentState.empty;
                  final rank = state.rankStep < settings.ranks.length
                      ? settings.ranks[state.rankStep].name
                      : '-';
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        key: const ValueKey('xp-student-total'),
                        label: Text('${state.total} XP'),
                      ),
                      Chip(label: Text(rank)),
                      Chip(label: Text('Semana: ${state.weekXp} XP')),
                      Chip(
                        label: Text(
                          'Hoy con tope: ${state.todayCapped} / ${settings.dailyCap}',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              StreamBuilder<List<XpLedgerEvent>>(
                stream: repo.watchLedger(student.uid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('No se pudo leer el libro: ${snapshot.error}');
                  }
                  final events = snapshot.data;
                  if (events == null) return const LinearProgressIndicator();
                  if (events.isEmpty) {
                    return Text(
                      'Todavía no tiene XP.',
                      style: TextStyle(color: muted),
                    );
                  }
                  return Column(
                    children: [
                      for (final event in events)
                        ListTile(
                          key: ValueKey('xp-event-${event.id}'),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            '${xpEventLabels[event.type] ?? event.type} · ${event.reverted ? 'revertido' : '+${event.xp} XP'}',
                            style: TextStyle(
                              decoration: event.reverted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            '${event.day} · ${event.id}'
                            '${event.xp < event.requested ? ' · tope: pedía ${event.requested}' : ''}'
                            '${event.reverted ? ' · motivo: ${event.revertReason ?? ''}' : ''}',
                            style: TextStyle(color: muted),
                          ),
                          trailing: event.reverted || event.xp == 0
                              ? null
                              : TextButton(
                                  key: ValueKey('xp-revert-${event.id}'),
                                  onPressed: () => _revert(context, ref, event),
                                  child: const Text('Revertir'),
                                ),
                        ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _revert(
    BuildContext context,
    WidgetRef ref,
    XpLedgerEvent event,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revertir ${event.xp} XP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${xpEventLabels[event.type] ?? event.type} del ${event.day}. El alumno pierde estos XP y el evento no se vuelve a otorgar.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('xp-revert-reason'),
              controller: reason,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const ValueKey('xp-revert-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revertir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(xpRepoProvider)
          .revert(
            student.uid,
            event.id,
            reason: reason.text,
            editor: adminEditor(),
          );
      messenger.showSnackBar(
        SnackBar(content: Text('Revertidos ${event.xp} XP.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo revertir: ${error is StateError ? error.message : error}',
          ),
        ),
      );
    } finally {
      reason.dispose();
    }
  }
}
