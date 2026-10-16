import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/data/repo/rankings_repo.dart';
import 'package:ingresoya_admin/src/domain/rankings_settings.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/settings_screen.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/xp_settings_card.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

/// Watches `{config}/rankings` and shows its editor.
class RankingsSettingsSection extends ConsumerWidget {
  const RankingsSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<RankingsSettings>(
      stream: ref.watch(rankingsRepoProvider).watchSettings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('No se pudo leer Rankings: ${snapshot.error}');
        }
        final settings = snapshot.data;
        if (settings == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return RankingsSettingsCard(
          key: ValueKey(settings.toMap().toString().hashCode),
          settings: settings,
        );
      },
    );
  }
}

/// «Configuración → Rankings» (docs/rankings_contract.md §2): the master
/// switch and every rule of the league and the daily challenge.
class RankingsSettingsCard extends ConsumerStatefulWidget {
  const RankingsSettingsCard({super.key, required this.settings, this.now});

  final RankingsSettings settings;

  /// Fixed in tests.
  final DateTime? now;

  @override
  ConsumerState<RankingsSettingsCard> createState() =>
      _RankingsSettingsCardState();
}

class _RankingsSettingsCardState extends ConsumerState<RankingsSettingsCard> {
  late bool _enabled;
  late bool _preferSame;
  late bool _weekPositions;
  late bool _challenge;
  final _stages = TextEditingController();
  final _banned = TextEditingController();
  final _numbers = <String, TextEditingController>{};
  bool _saving = false;
  Future<int>? _active;

  static const _fields = [
    ('groupSize', 'Alumnos por grupo', 'alumnos', '5 a 100.'),
    (
      'promotePercent',
      'Suben al cerrar la semana',
      '%',
      'Del grupo. Al menos 1 si hay alguien.',
    ),
    ('demotePercent', 'Bajan al cerrar la semana', '%', 'Del grupo.'),
    (
      'minGroupForDemotion',
      'Nadie baja en grupos de menos de',
      'alumnos',
      'Para no castigar grupos chicos.',
    ),
    (
      'weekMinCareerPlayers',
      'Puesto por carrera de la semana desde',
      'alumnos',
      'Con menos, solo se muestra el de la universidad.',
    ),
    (
      'questionCount',
      'Preguntas del reto del día',
      'preguntas',
      '3 a 30. Iguales para toda la universidad.',
    ),
    ('minutes', 'Tiempo del reto', 'min', '3 a 120.'),
    (
      'bonusXp',
      'Bono por completar el reto',
      'XP',
      'Además del XP de una sesión normal. También suma a la liga.',
    ),
    (
      'ownPastExamQuestions',
      'Preguntas de exámenes pasados de la propia universidad',
      'preguntas',
      'Hasta este número (las que haya); el resto, de otras universidades o propias de IngresoYa.',
    ),
    (
      'noRepeatDays',
      'No repetir preguntas de retos de los últimos',
      'días',
      '0 = pueden repetirse.',
    ),
    (
      'challengeMinCareerPlayers',
      'Pestaña «Mi carrera» del reto desde',
      'jugadores',
      'Con menos, solo se muestra el puesto propio.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _enabled = s.enabled;
    _preferSame = s.preferSameUniversity;
    _weekPositions = s.showWeekPositions;
    _challenge = s.challengeEnabled;
    _stages.text = s.stageNames.join(', ');
    _banned.text = s.bannedWords.join(', ');
    final values = {
      'groupSize': s.groupSize,
      'promotePercent': s.promotePercent,
      'demotePercent': s.demotePercent,
      'minGroupForDemotion': s.minGroupForDemotion,
      'weekMinCareerPlayers': s.weekMinCareerPlayers,
      'questionCount': s.questionCount,
      'minutes': s.minutes,
      'bonusXp': s.bonusXp,
      'ownPastExamQuestions': s.ownPastExamQuestions,
      'noRepeatDays': s.noRepeatDays,
      'challengeMinCareerPlayers': s.challengeMinCareerPlayers,
    };
    for (final (key, _, _, _) in _fields) {
      _numbers[key] = TextEditingController(text: '${values[key]}');
    }
    _active = ref
        .read(rankingsRepoProvider)
        .activeStudents(currentPeruMonday(widget.now ?? DateTime.now()));
  }

  @override
  void dispose() {
    for (final c in [_stages, _banned, ..._numbers.values]) {
      c.dispose();
    }
    super.dispose();
  }

  RankingsSettings? _read() {
    final numbers = <String, int>{};
    for (final (key, _, _, _) in _fields) {
      final value = int.tryParse(_numbers[key]!.text.trim());
      if (value == null) return null;
      numbers[key] = value;
    }
    List<String> list(String text) => [
      for (final part in text.split(RegExp(r'[,\n]')))
        if (part.trim().isNotEmpty) part.trim(),
    ];
    return RankingsSettings(
      enabled: _enabled,
      startWeek: widget.settings.startWeek,
      bannedWords: [for (final w in list(_banned.text)) w.toLowerCase()],
      stageNames: list(_stages.text),
      groupSize: numbers['groupSize']!,
      promotePercent: numbers['promotePercent']!,
      demotePercent: numbers['demotePercent']!,
      minGroupForDemotion: numbers['minGroupForDemotion']!,
      preferSameUniversity: _preferSame,
      showWeekPositions: _weekPositions,
      weekMinCareerPlayers: numbers['weekMinCareerPlayers']!,
      challengeEnabled: _challenge,
      questionCount: numbers['questionCount']!,
      minutes: numbers['minutes']!,
      bonusXp: numbers['bonusXp']!,
      ownPastExamQuestions: numbers['ownPastExamQuestions']!,
      noRepeatDays: numbers['noRepeatDays']!,
      challengeMinCareerPlayers: numbers['challengeMinCareerPlayers']!,
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = _read();
    final problem = settings == null
        ? 'Completa los números con enteros.'
        : settings.validate();
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(rankingsRepoProvider)
          .saveSettings(settings!, editor: adminEditor(), now: widget.now);
      HapticFeedback.selectionClick();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            settings.enabled && !widget.settings.enabled
                ? 'Rankings activados: la liga empieza el lunes ${nextPeruMonday(widget.now ?? DateTime.now())}.'
                : 'Rankings guardados.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _number(String key) {
    final (_, label, suffix, helper) = _fields.firstWhere(
      (field) => field.$1 == key,
    );
    return SettingsNumberField(
      key: ValueKey('rankings-$key'),
      controller: _numbers[key]!,
      enabled: !_saving,
      label: label,
      suffix: suffix,
      helper: helper,
    );
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.ink.withValues(alpha: .6);
    final s = widget.settings;
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
                'Rankings',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Liga semanal y reto del día. Todos tienen nombre de usuario; en los rankings nunca se ve el nombre real, '
            'el correo ni las respuestas, y cada alumno puede ocultarse.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          SwitchListTile(
            key: const ValueKey('rankings-enabled'),
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: _saving ? null : (v) => setState(() => _enabled = v),
            title: const Text(
              'Rankings activados',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              _enabled
                  ? s.enabled
                        ? 'Encendidos. La liga corre desde el lunes ${s.startWeek}.'
                        : 'Al guardar, la liga empieza el lunes ${nextPeruMonday(widget.now ?? DateTime.now())} (semana completa).'
                  : 'Apagados: la app no muestra Rankings, liga ni reto. El nombre de usuario existe igual.',
              style: TextStyle(color: muted),
            ),
          ),
          FutureBuilder<int>(
            future: _active,
            builder: (context, snapshot) => Text(
              snapshot.hasData
                  ? 'Alumnos que ganaron XP esta semana: ${snapshot.data}'
                  : snapshot.hasError
                  ? 'No se pudo contar los alumnos activos.'
                  : 'Contando alumnos activos…',
              key: const ValueKey('rankings-active'),
              style: TextStyle(color: muted, fontSize: 12.5),
            ),
          ),
          const Divider(height: 28),
          const Text(
            'Liga semanal',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Puntos = XP ganado de lunes a domingo (Lima). Cada alumno entra a un grupo de su etapa al ganar su primer XP de la semana; '
            'el domingo a medianoche los primeros suben de etapa y los últimos bajan.',
            style: TextStyle(color: muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('rankings-stages'),
            controller: _stages,
            enabled: !_saving,
            decoration: const InputDecoration(
              labelText: 'Etapas, de menor a mayor (separadas por comas)',
              border: OutlineInputBorder(),
            ),
          ),
          _number('groupSize'),
          _number('promotePercent'),
          _number('demotePercent'),
          _number('minGroupForDemotion'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _preferSame,
            onChanged: _saving ? null : (v) => setState(() => _preferSame = v),
            title: const Text('Grupos de la misma universidad'),
            subtitle: Text(
              'Útil cuando haya muchos alumnos por universidad.',
              style: TextStyle(color: muted),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _weekPositions,
            onChanged: _saving
                ? null
                : (v) => setState(() => _weekPositions = v),
            title: const Text(
              'Mostrar «Esta semana» en la universidad y la carrera',
            ),
          ),
          _number('weekMinCareerPlayers'),
          const Divider(height: 28),
          SwitchListTile(
            key: const ValueKey('rankings-challenge'),
            contentPadding: EdgeInsets.zero,
            value: _challenge,
            onChanged: _saving ? null : (v) => setState(() => _challenge = v),
            title: const Text(
              'Reto del día',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              'Las mismas preguntas para toda la universidad, un intento, respuestas al día siguiente.',
              style: TextStyle(color: muted),
            ),
          ),
          _number('questionCount'),
          _number('minutes'),
          _number('bonusXp'),
          _number('ownPastExamQuestions'),
          _number('noRepeatDays'),
          _number('challengeMinCareerPlayers'),
          const Divider(height: 28),
          TextField(
            key: const ValueKey('rankings-banned'),
            controller: _banned,
            enabled: !_saving,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              labelText:
                  'Palabras prohibidas en el nombre de usuario (además de las de fábrica)',
              helperText:
                  'Separadas por comas. Se comparan sin tildes ni mayúsculas.',
              helperStyle: TextStyle(color: muted),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('rankings-save'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar Rankings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// «Nombres de usuario y reto de hoy»: find a username and remove it, see
/// who is hidden, and look at (or fix) today's challenges.
class RankingsTools extends ConsumerStatefulWidget {
  const RankingsTools({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<RankingsTools> createState() => _RankingsToolsState();
}

class _RankingsToolsState extends ConsumerState<RankingsTools> {
  final _query = TextEditingController();
  UsernameCard? _found;
  bool _searched = false;
  Future<List<ChallengeDay>>? _challenges;
  Future<List<UsernameCard>>? _hidden;

  String get _today {
    final lima = (widget.now ?? DateTime.now()).toUtc().subtract(
      const Duration(hours: 5),
    );
    return lima.toIso8601String().substring(0, 10);
  }

  @override
  void initState() {
    super.initState();
    _challenges = ref.read(rankingsRepoProvider).challenges(_today);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final found = await ref
        .read(rankingsRepoProvider)
        .findUsername(_query.text);
    setState(() {
      _found = found;
      _searched = true;
    });
  }

  Future<String?> _ask(String title, String label) => showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(title: title, label: label),
  );

  Future<void> _remove(UsernameCard card) async {
    final messenger = ScaffoldMessenger.of(context);
    final reason = await _ask(
      'Retirar «${card.alias}»',
      'Motivo (lo verá el alumno)',
    );
    if (reason == null) return;
    try {
      await ref
          .read(rankingsRepoProvider)
          .removeUsername(
            card.uid,
            card.alias!,
            reason: reason,
            editor: adminEditor(),
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Nombre retirado. La app le asignará uno al azar y le mostrará el motivo.',
          ),
        ),
      );
      await _search();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo retirar: $error')),
      );
    }
  }

  Future<void> _swap(ChallengeDay challenge, String oldId) async {
    final messenger = ScaffoldMessenger.of(context);
    final newId = await _ask('Cambiar $oldId', 'ID de la pregunta nueva');
    if (newId == null) return;
    try {
      await ref
          .read(rankingsRepoProvider)
          .swapChallengeQuestion(challenge, oldId, newId);
      setState(
        () => _challenges = ref.read(rankingsRepoProvider).challenges(_today),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Pregunta cambiada.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo cambiar: $error')),
      );
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
              Icon(Icons.badge_rounded),
              SizedBox(width: 10),
              Text(
                'Nombres de usuario y reto de hoy',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Si un nombre de usuario es ofensivo o parece un nombre real, retíralo con un motivo: '
            'la app le asigna otro al azar y le explica por qué.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('username-query'),
                  controller: _query,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Nombre de usuario o uid',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const ValueKey('username-search'),
                onPressed: _search,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Buscar'),
              ),
            ],
          ),
          if (_searched && _found == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No encontramos ese nombre de usuario.',
                style: TextStyle(color: muted),
              ),
            ),
          if (_found case final card?)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(card.alias ?? '(sin nombre de usuario)'),
              subtitle: Text(
                [
                  if (card.hidden) 'Oculto en los rankings',
                  '${card.weekXp} XP esta semana',
                  card.career,
                  card.uid,
                ].where((s) => s.isNotEmpty).join(' · '),
                style: TextStyle(color: muted, fontSize: 12),
              ),
              trailing: card.alias == null
                  ? null
                  : TextButton.icon(
                      key: const ValueKey('username-remove'),
                      onPressed: () => _remove(card),
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('Retirar'),
                    ),
            ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => setState(
              () => _hidden = ref.read(rankingsRepoProvider).hiddenStudents(),
            ),
            icon: const Icon(Icons.visibility_off_outlined),
            label: const Text('Ver quiénes se ocultaron'),
          ),
          if (_hidden != null)
            FutureBuilder<List<UsernameCard>>(
              future: _hidden,
              builder: (context, snapshot) => Text(switch (snapshot.data) {
                null => 'Cargando…',
                [] => 'Nadie se ocultó.',
                final list =>
                  list.map((card) => '${card.uid} (${card.career})').join('\n'),
              }, style: TextStyle(color: muted, fontSize: 12.5)),
            ),
          const Divider(height: 28),
          Text(
            'Reto de hoy ($_today)',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          FutureBuilder<List<ChallengeDay>>(
            future: _challenges,
            builder: (context, snapshot) {
              final list = snapshot.data;
              if (snapshot.hasError) {
                return Text('No se pudo leer: ${snapshot.error}');
              }
              if (list == null) return const LinearProgressIndicator();
              if (list.isEmpty) {
                return Text(
                  'Aún no se generó ninguno hoy: se crea cuando el primer alumno de cada universidad lo abre.',
                  style: TextStyle(color: muted, fontSize: 12.5),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final challenge in list)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Universidad ${challenge.universityId}'),
                      subtitle: Text(
                        '${challenge.questionIds.length} preguntas · ${challenge.ownPastExamCount} de sus exámenes pasados',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                      children: [
                        for (final id in challenge.questionIds)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(id),
                            trailing: TextButton(
                              onPressed: () => _swap(challenge, id),
                              child: const Text('Cambiar'),
                            ),
                          ),
                      ],
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

class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      key: const ValueKey('rankings-dialog-text'),
      controller: _text,
      autofocus: true,
      decoration: InputDecoration(labelText: widget.label),
      onChanged: (_) => setState(() {}),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('rankings-dialog-ok'),
        onPressed: _text.text.trim().length < 3
            ? null
            : () => Navigator.of(context).pop(_text.text.trim()),
        child: const Text('Aceptar'),
      ),
    ],
  );
}
