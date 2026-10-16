import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/data/repo/xp_repo.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/xp_settings_card.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

/// «Top 100 y alias»: the list students see, and removing an inappropriate
/// alias (the student leaves the top and is asked for another).
class LeaderboardModerationTool extends ConsumerWidget {
  const LeaderboardModerationTool({super.key});

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    LeaderboardRow row,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _ReasonDialog(alias: row.alias),
    );
    if (reason == null) return;
    try {
      await ref
          .read(xpRepoProvider)
          .removeAlias(
            row.uid,
            row.alias,
            reason: reason,
            editor: adminEditor(),
          );
      messenger.showSnackBar(
        SnackBar(content: Text('Alias «${row.alias}» retirado del top.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo retirar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Colors.white.withValues(alpha: .6);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.leaderboard_rounded),
              SizedBox(width: 10),
              Text(
                'Top 100 y alias',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Lo que ven los alumnos en «Los más dedicados». Si un alias es ofensivo o parece un nombre real, '
            'retíralo con un motivo: el alumno sale del top y la app le pide otro alias.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<LeaderboardRow>>(
            stream: ref.watch(xpRepoProvider).watchTop(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('No se pudo leer el top: ${snapshot.error}');
              }
              final rows = snapshot.data;
              if (rows == null) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (rows.isEmpty) {
                return Text(
                  'Todavía ningún alumno activó «Aparecer en rankings».',
                  style: TextStyle(color: muted),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    ListTile(
                      key: ValueKey('top-row-${rows[i].uid}'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: SizedBox(
                        width: 32,
                        child: Text(
                          '${i + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      title: Text(rows[i].alias),
                      subtitle: Text(
                        [
                          '${rows[i].total} XP',
                          rows[i].career,
                          rows[i].uid,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      trailing: TextButton.icon(
                        key: ValueKey('top-remove-${rows[i].uid}'),
                        onPressed: () => _remove(context, ref, rows[i]),
                        icon: const Icon(Icons.person_off_outlined),
                        label: const Text('Retirar alias'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.alias});

  final String alias;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Retirar «${widget.alias}»'),
    content: TextField(
      key: const ValueKey('top-remove-reason'),
      controller: _reason,
      autofocus: true,
      decoration: const InputDecoration(
        labelText: 'Motivo (lo verá el alumno)',
        hintText: 'p. ej. parece un nombre real',
      ),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('top-remove-confirm'),
        onPressed: _reason.text.trim().length < 3
            ? null
            : () => Navigator.of(context).pop(_reason.text.trim()),
        child: const Text('Retirar'),
      ),
    ],
  );
}
