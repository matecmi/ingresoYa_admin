import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/simulator_settings.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/settings_widgets.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

/// Watches `{config}/simulator` and shows its editor.
class SimulatorSettingsSection extends ConsumerWidget {
  const SimulatorSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<SimulatorSettingsRecord>(
      stream: ref.watch(appConfigRepoProvider).watchSimulatorSettings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'No se pudo leer la configuración del Simulador: ${snapshot.error}',
          );
        }
        final record = snapshot.data;
        if (record == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SimulatorSettingsCard(
          // Rebuild the form when someone else saves.
          key: ValueKey(Object.hashAll(record.settings.toMap().values)),
          record: record,
        );
      },
    );
  }
}

class SimulatorSettingsCard extends ConsumerStatefulWidget {
  const SimulatorSettingsCard({super.key, required this.record});

  final SimulatorSettingsRecord record;

  @override
  ConsumerState<SimulatorSettingsCard> createState() =>
      _SimulatorSettingsCardState();
}

class _SizeControllers {
  _SizeControllers(PracticeSize size)
    : key = size.key,
      label = TextEditingController(text: size.label),
      questions = TextEditingController(text: '${size.questions}'),
      minutes = TextEditingController(text: '${size.minutes}');

  final String key;
  final TextEditingController label, questions, minutes;

  void dispose() {
    label.dispose();
    questions.dispose();
    minutes.dispose();
  }
}

class _SimulatorSettingsCardState extends ConsumerState<SimulatorSettingsCard> {
  late List<_SizeControllers> _sizes;
  late String _defaultSize;
  late bool _timer;
  late bool _penalty;
  late final TextEditingController _repeatDays;
  late String _source;
  late String _difficulty;
  late bool _otherUniversities;
  late bool _onlyComplete;
  late bool _explanations;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repeatDays = TextEditingController();
    _load(widget.record.settings);
  }

  void _load(SimulatorSettings settings) {
    _sizes = settings.practiceSizes.map(_SizeControllers.new).toList();
    _defaultSize = settings.practiceSizes
        .firstWhere(
          (size) => size.isDefault,
          orElse: () => settings.practiceSizes.first,
        )
        .key;
    _timer = settings.practiceTimerDefault;
    _penalty = settings.practicePenalty;
    _repeatDays.text = '${settings.repeatWindowDays}';
    _source = settings.defaultSource;
    _difficulty = settings.defaultDifficulty;
    _otherUniversities = settings.showOtherUniversities;
    _onlyComplete = settings.onlyCompleteExams;
    _explanations = settings.showExplanations;
  }

  @override
  void dispose() {
    for (final size in _sizes) {
      size.dispose();
    }
    _repeatDays.dispose();
    super.dispose();
  }

  SimulatorSettings? _read() {
    final sizes = <PracticeSize>[];
    for (final size in _sizes) {
      final questions = int.tryParse(size.questions.text.trim());
      final minutes = int.tryParse(size.minutes.text.trim());
      if (questions == null || minutes == null) return null;
      sizes.add(
        PracticeSize(
          key: size.key,
          label: size.label.text.trim(),
          questions: questions,
          minutes: minutes,
          isDefault: size.key == _defaultSize,
        ),
      );
    }
    final days = int.tryParse(_repeatDays.text.trim());
    if (days == null) return null;
    return SimulatorSettings(
      practiceSizes: sizes,
      practiceTimerDefault: _timer,
      practicePenalty: _penalty,
      repeatWindowDays: days,
      defaultSource: _source,
      defaultDifficulty: _difficulty,
      showOtherUniversities: _otherUniversities,
      onlyCompleteExams: _onlyComplete,
      showExplanations: _explanations,
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
          .read(appConfigRepoProvider)
          .saveSimulatorSettings(settings!, editor: _editor());
      HapticFeedback.selectionClick();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Guardado. La app y los exámenes nuevos lo usan desde ahora.',
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

  /// Who saved, for the «Guardado · fecha · editor» line.
  static String _editor() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user?.email ?? user?.uid ?? 'admin';
    } catch (_) {
      // No Firebase app (widget tests).
      return 'admin';
    }
  }

  void _addSize() {
    if (_sizes.length >= 5) return;
    var index = _sizes.length + 1;
    while (_sizes.any((size) => size.key == 'size$index')) {
      index++;
    }
    setState(
      () => _sizes.add(
        _SizeControllers(
          PracticeSize(
            key: 'size$index',
            label: 'Nuevo',
            questions: 30,
            minutes: 45,
          ),
        ),
      ),
    );
  }

  void _removeSize(_SizeControllers size) {
    if (_sizes.length <= 1) return;
    setState(() {
      _sizes.remove(size);
      if (_defaultSize == size.key) _defaultSize = _sizes.first.key;
    });
    size.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final muted = AppTheme.ink.withValues(alpha: .6);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    Widget toggle(
      String key,
      bool value,
      ValueChanged<bool> onChanged,
      String title,
      String subtitle,
    ) => SwitchListTile(
      key: ValueKey(key),
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: _saving ? null : (v) => setState(() => onChanged(v)),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(color: muted)),
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Simulador',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Text(
                record.exists
                    ? 'Guardado${settingsUpdatedLabel(record.updatedAt, record.updatedBy)}'
                    : 'Usando valores por defecto',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Práctica libre (por curso, mezcla o aleatorio) y lista de '
            'exámenes pasados. Las reglas de cada examen pasado se editan en '
            'Universidades → Exámenes de origen.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tamaños de práctica',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            'El alumno elige uno; no escribe la cantidad. Entre '
            '${SimulatorSettings.minQuestions} y '
            '${SimulatorSettings.maxQuestions} preguntas.',
            style: TextStyle(color: muted, fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: _defaultSize,
            onChanged: (value) {
              if (!_saving && value != null) {
                setState(() => _defaultSize = value);
              }
            },
            child: Column(
              children: [
                for (final size in _sizes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Radio<String>(
                          key: ValueKey('size-default-${size.key}'),
                          value: size.key,
                        ),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            key: ValueKey('size-label-${size.key}'),
                            controller: size.label,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            key: ValueKey('size-questions-${size.key}'),
                            controller: size.questions,
                            inputFormatters: digits,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Preguntas',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            key: ValueKey('size-minutes-${size.key}'),
                            controller: size.minutes,
                            inputFormatters: digits,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minutos',
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar tamaño',
                          onPressed: _saving || _sizes.length <= 1
                              ? null
                              : () => _removeSize(size),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (_sizes.length < 5)
            TextButton.icon(
              onPressed: _saving ? null : _addSize,
              icon: const Icon(Icons.add),
              label: const Text('Agregar tamaño'),
            ),
          const Divider(height: 24),
          toggle(
            'sim-timer',
            _timer,
            (v) => _timer = v,
            'Reloj activado por defecto en práctica',
            'El alumno puede apagarlo; sin reloj también cuenta.',
          ),
          toggle(
            'sim-penalty',
            _penalty,
            (v) => _penalty = v,
            'Restar por incorrecta en práctica',
            'Los exámenes pasados siempre usan sus propias reglas.',
          ),
          SettingsNumberField(
            key: const ValueKey('sim-repeat-days'),
            controller: _repeatDays,
            enabled: !_saving,
            label: 'No repetir preguntas vistas en los últimos',
            suffix: 'días',
            helper:
                'Si no alcanzan las preguntas nuevas, el examen avisa '
                '(0 a ${SimulatorSettings.maxRepeatWindowDays}).',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('sim-source'),
                  initialValue: _source,
                  decoration: const InputDecoration(
                    labelText: 'Origen por defecto',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in SimulatorSettings.sources.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _source = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: const ValueKey('sim-difficulty'),
                  initialValue: _difficulty,
                  decoration: const InputDecoration(
                    labelText: 'Dificultad por defecto',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final entry in SimulatorSettings.difficulties.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _difficulty = v!),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          toggle(
            'sim-other-universities',
            _otherUniversities,
            (v) => _otherUniversities = v,
            'Mostrar exámenes de otras universidades',
            'Debajo de los de su universidad.',
          ),
          toggle(
            'sim-only-complete',
            _onlyComplete,
            (v) => _onlyComplete = v,
            'Ocultar exámenes incompletos',
            'Apagado: se muestran como «Pronto», sin poder rendirlos.',
          ),
          toggle(
            'sim-explanations',
            _explanations,
            (v) => _explanations = v,
            'Mostrar explicaciones al revisar',
            'Al terminar cada examen.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('sim-save'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Guardar'),
              ),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        for (final size in _sizes) {
                          size.dispose();
                        }
                        _load(SimulatorSettings.defaults);
                      }),
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
