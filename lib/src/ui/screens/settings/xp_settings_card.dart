import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/xp_settings.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/settings_screen.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

String adminEditor() {
  try {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email ?? user?.uid ?? 'admin';
  } catch (_) {
    return 'admin';
  }
}

/// Watches `{config}/xp` and shows its editor.
class XpSettingsSection extends ConsumerWidget {
  const XpSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<XpSettings>(
      stream: ref.watch(xpRepoProvider).watchSettings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('No se pudo leer XP y rangos: ${snapshot.error}');
        }
        final settings = snapshot.data;
        if (settings == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return XpSettingsCard(
          key: ValueKey(settings.toMap().toString().hashCode),
          settings: settings,
        );
      },
    );
  }
}

class XpSettingsCard extends ConsumerStatefulWidget {
  const XpSettingsCard({super.key, required this.settings});

  final XpSettings settings;

  @override
  ConsumerState<XpSettingsCard> createState() => _XpSettingsCardState();
}

class _XpSettingsCardState extends ConsumerState<XpSettingsCard> {
  final _names = <TextEditingController>[];
  final _minXp = <TextEditingController>[];
  final _images = <String>[];
  final _amounts = <String, TextEditingController>{};
  final _limits = <String, TextEditingController>{};
  late bool _stars;
  late bool _topEnabled;
  final _topSize = TextEditingController();
  final _topUniversityMin = TextEditingController();
  final _bannedWords = TextEditingController();
  bool _saving = false;

  static const _limitKeys = [
    'xpPerStar',
    'dailyCap',
    'minQuestionsPerSession',
    'repeatWindowDays',
    'minSecondsPerQuestion',
    'pastExamEveryDays',
  ];

  @override
  void initState() {
    super.initState();
    _load(widget.settings);
  }

  void _load(XpSettings settings) {
    for (final c in [..._names, ..._minXp]) {
      c.dispose();
    }
    _names
      ..clear()
      ..addAll(
        settings.ranks.map((rank) => TextEditingController(text: rank.name)),
      );
    _minXp
      ..clear()
      ..addAll(
        settings.ranks.map(
          (rank) => TextEditingController(text: '${rank.minXp}'),
        ),
      );
    _images
      ..clear()
      ..addAll(settings.ranks.map((rank) => rank.image));
    for (final (key, _, _) in xpAmountFields) {
      (_amounts[key] ??= TextEditingController()).text =
          '${settings.amounts[key]}';
    }
    final map = settings.toMap();
    for (final key in _limitKeys) {
      (_limits[key] ??= TextEditingController()).text = '${map[key]}';
    }
    _stars = settings.starsEnabled;
    final board = settings.leaderboard;
    _topEnabled = board.enabled;
    _topSize.text = '${board.size}';
    _topUniversityMin.text = '${board.universityFilterMin}';
    _bannedWords.text = board.bannedWords.join(', ');
  }

  @override
  void dispose() {
    for (final c in [
      ..._names,
      ..._minXp,
      ..._amounts.values,
      ..._limits.values,
      _topSize,
      _topUniversityMin,
      _bannedWords,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  XpSettings? _read() {
    int? n(TextEditingController c) => int.tryParse(c.text.trim());
    final ranks = <RankStep>[];
    for (var i = 0; i < _names.length; i++) {
      final minXp = n(_minXp[i]);
      if (minXp == null) return null;
      ranks.add(
        RankStep(name: _names[i].text.trim(), minXp: minXp, image: _images[i]),
      );
    }
    final amounts = <String, int>{};
    for (final (key, _, _) in xpAmountFields) {
      final value = n(_amounts[key]!);
      if (value == null) return null;
      amounts[key] = value;
    }
    final limits = <String, int>{};
    for (final key in _limitKeys) {
      final value = n(_limits[key]!);
      if (value == null) return null;
      limits[key] = value;
    }
    final topSize = n(_topSize);
    final topUniversityMin = n(_topUniversityMin);
    if (topSize == null || topUniversityMin == null) return null;
    return XpSettings(
      ranks: ranks,
      starsEnabled: _stars,
      xpPerStar: limits['xpPerStar']!,
      amounts: amounts,
      dailyCap: limits['dailyCap']!,
      minQuestionsPerSession: limits['minQuestionsPerSession']!,
      repeatWindowDays: limits['repeatWindowDays']!,
      minSecondsPerQuestion: limits['minSecondsPerQuestion']!,
      pastExamEveryDays: limits['pastExamEveryDays']!,
      leaderboard: LeaderboardSettings(
        enabled: _topEnabled,
        size: topSize,
        universityFilterMin: topUniversityMin,
        bannedWords: [
          for (final word in _bannedWords.text.split(RegExp(r'[,\n]')))
            if (word.trim().length >= 2) word.trim().toLowerCase(),
        ],
      ),
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
          .read(xpRepoProvider)
          .saveSettings(settings!, editor: adminEditor());
      HapticFeedback.selectionClick();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'XP y rangos guardados. Se aplican desde el próximo evento.',
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

  Widget _small(
    TextEditingController c,
    String label, {
    String? key,
    double width = 110,
  }) => SizedBox(
    width: width,
    child: TextField(
      key: key == null ? null : ValueKey(key),
      controller: c,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: .6);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.military_tech_rounded),
              SizedBox(width: 10),
              Text(
                'XP y rangos',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'El XP lo da solo el servidor, una vez por evento. El rango sale del XP total y nunca baja. '
            'Los cambios se aplican desde el próximo evento; poner 0 desactiva un evento.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          const Text(
            'Escalera de rangos',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Empieza en 0 y crece siempre. La imagen se elige de las que trae la app.',
            style: TextStyle(color: muted, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _names.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${i + 1}', style: TextStyle(color: muted)),
                  ),
                  Expanded(
                    child: TextField(
                      key: ValueKey('xp-rank-name-$i'),
                      controller: _names[i],
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _small(_minXp[i], 'XP desde', key: 'xp-rank-min-$i'),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 170,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('xp-rank-image-$i'),
                      initialValue: _images[i],
                      isDense: true,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Imagen',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final image in rankImages)
                          DropdownMenuItem(
                            value: image,
                            child: Text(image, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _images[i] = v ?? _images[i]),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar rango',
                    onPressed: _saving || _names.length <= 1
                        ? null
                        : () => setState(() {
                            _names.removeAt(i).dispose();
                            _minXp.removeAt(i).dispose();
                            _images.removeAt(i);
                          }),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: _saving || _names.length >= 40
                ? null
                : () => setState(() {
                    final last =
                        int.tryParse(_minXp.isEmpty ? '0' : _minXp.last.text) ??
                        0;
                    _names.add(TextEditingController(text: 'Nuevo rango'));
                    _minXp.add(TextEditingController(text: '${last + 1000}'));
                    _images.add(rankImages.last);
                  }),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Agregar rango'),
          ),
          SwitchListTile(
            key: const ValueKey('xp-stars'),
            contentPadding: EdgeInsets.zero,
            value: _stars,
            onChanged: _saving ? null : (v) => setState(() => _stars = v),
            title: const Text('Estrellas después del último rango'),
            subtitle: Text(
              'Una estrella cada cierta cantidad de XP, sin límite.',
              style: TextStyle(color: muted),
            ),
          ),
          SettingsNumberField(
            controller: _limits['xpPerStar']!,
            enabled: !_saving,
            label: 'XP por cada estrella',
            suffix: 'XP',
            helper: '100 a 100 000.',
          ),
          const Divider(height: 28),
          const Text(
            'XP por evento',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (key, label, _) in xpAmountFields)
                SizedBox(
                  width: 210,
                  child: TextField(
                    key: ValueKey('xp-amount-$key'),
                    controller: _amounts[key],
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: label,
                      suffixText: 'XP',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 28),
          const Text(
            'Límites y juego limpio',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SettingsNumberField(
            controller: _limits['dailyCap']!,
            enabled: !_saving,
            label: 'Tope diario',
            suffix: 'XP',
            helper:
                'Para sesiones, respuestas correctas y racha. Los logros únicos no tienen tope.',
          ),
          SettingsNumberField(
            controller: _limits['minQuestionsPerSession']!,
            enabled: !_saving,
            label: 'Mínimo de preguntas para que una sesión dé XP',
            suffix: 'preguntas',
            helper:
                'También define qué cuenta para la racha y la meta semanal.',
          ),
          SettingsNumberField(
            controller: _limits['repeatWindowDays']!,
            enabled: !_saving,
            label:
                'Una respuesta correcta no suma si la pregunta se vio hace menos de',
            suffix: 'días',
            helper: '0 = siempre suma.',
          ),
          SettingsNumberField(
            controller: _limits['minSecondsPerQuestion']!,
            enabled: !_saving,
            label: 'Segundos mínimos por pregunta (promedio)',
            suffix: 's',
            helper: 'Una sesión más rápida no da XP.',
          ),
          SettingsNumberField(
            controller: _limits['pastExamEveryDays']!,
            enabled: !_saving,
            label: 'Un examen pasado completo da XP cada',
            suffix: 'días',
            helper: 'Por examen.',
          ),
          const Divider(height: 28),
          const Text(
            'Top 100 «Los más dedicados» y alias',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Solo aparecen los alumnos que activan «Aparecer en rankings» con un alias. '
            'Los demás ven el alias, el XP, el rango y la universidad y carrera; nunca el nombre ni el correo.',
            style: TextStyle(color: muted, fontSize: 12.5),
          ),
          SwitchListTile(
            key: const ValueKey('xp-top-enabled'),
            contentPadding: EdgeInsets.zero,
            value: _topEnabled,
            onChanged: _saving ? null : (v) => setState(() => _topEnabled = v),
            title: const Text('Mostrar el top en la app'),
            subtitle: Text(
              'Apagado, la app no lo muestra; los puestos se siguen guardando.',
              style: TextStyle(color: muted),
            ),
          ),
          SettingsNumberField(
            controller: _topSize,
            enabled: !_saving,
            label: 'Alumnos en el top',
            suffix: 'alumnos',
            helper: '10 a 500. Fuera del top, cada alumno igual ve su puesto.',
          ),
          SettingsNumberField(
            controller: _topUniversityMin,
            enabled: !_saving,
            label: 'Filtro por universidad desde',
            suffix: 'alumnos',
            helper:
                'Una universidad tiene su propia lista cuando tiene esa cantidad de alumnos visibles.',
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('xp-banned-words'),
            controller: _bannedWords,
            enabled: !_saving,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              labelText:
                  'Palabras prohibidas en el alias (además de las de fábrica)',
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
                key: const ValueKey('xp-save'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar XP y rangos'),
              ),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() => _load(XpSettings.defaults)),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Valores por defecto'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
