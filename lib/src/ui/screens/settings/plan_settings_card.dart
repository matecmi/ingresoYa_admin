import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/plan_settings.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/settings_screen.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

/// Watches the `plan` of `{config}/simulator` and shows its editor.
class PlanSettingsSection extends ConsumerWidget {
  const PlanSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<PlanSettings>(
      stream: ref.watch(appConfigRepoProvider).watchPlanSettings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('No se pudo leer el plan: ${snapshot.error}');
        }
        final plan = snapshot.data;
        if (plan == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return PlanSettingsCard(
          key: ValueKey(Object.hashAll(plan.toMap().values)),
          plan: plan,
        );
      },
    );
  }
}

class PlanSettingsCard extends ConsumerStatefulWidget {
  const PlanSettingsCard({super.key, required this.plan});

  final PlanSettings plan;

  @override
  ConsumerState<PlanSettingsCard> createState() => _PlanSettingsCardState();
}

class _PlanSettingsCardState extends ConsumerState<PlanSettingsCard> {
  final _fields = <String, TextEditingController>{};
  late Set<int> _options;
  late int _recommended;
  late int _mockDay;
  late bool _showWhy;
  late bool _freeExamsCount;
  bool _saving = false;

  static const _numbers = [
    'dailyQuestions',
    'dailyMinutes',
    'weakSharePercent',
    'weakThresholdPercent',
    'minAnswersToJudge',
    'diagnosticPerCourse',
    'diagnosticMinutes',
    'minQuestionsPerSession',
    'streakGraceDays',
  ];

  @override
  void initState() {
    super.initState();
    for (final key in [..._numbers, 'defaultReminderTime']) {
      _fields[key] = TextEditingController();
    }
    _load(widget.plan);
  }

  void _load(PlanSettings plan) {
    final map = plan.toMap();
    for (final key in _fields.keys) {
      _fields[key]!.text = '${map[key]}';
    }
    _options = plan.sessionOptions.toSet();
    _recommended = plan.recommendedSessions;
    _mockDay = plan.defaultMockDay;
    _showWhy = plan.showWhy;
    _freeExamsCount = plan.freeExamsCount;
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  PlanSettings? _read() {
    final values = <String, int>{};
    for (final key in _numbers) {
      final value = int.tryParse(_fields[key]!.text.trim());
      if (value == null) return null;
      values[key] = value;
    }
    return PlanSettings(
      sessionOptions: _options.toList()..sort(),
      recommendedSessions: _recommended,
      dailyQuestions: values['dailyQuestions']!,
      dailyMinutes: values['dailyMinutes']!,
      weakSharePercent: values['weakSharePercent']!,
      weakThresholdPercent: values['weakThresholdPercent']!,
      minAnswersToJudge: values['minAnswersToJudge']!,
      diagnosticPerCourse: values['diagnosticPerCourse']!,
      diagnosticMinutes: values['diagnosticMinutes']!,
      showWhy: _showWhy,
      defaultMockDay: _mockDay,
      defaultReminderTime: _fields['defaultReminderTime']!.text.trim(),
      minQuestionsPerSession: values['minQuestionsPerSession']!,
      streakGraceDays: values['streakGraceDays']!,
      freeExamsCount: _freeExamsCount,
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final plan = _read();
    final problem = plan == null
        ? 'Completa los números con enteros.'
        : plan.validate();
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(appConfigRepoProvider)
          .savePlanSettings(plan!, editor: _editor());
      HapticFeedback.selectionClick();
      messenger.showSnackBar(
        const SnackBar(content: Text('Plan guardado. La app lo usa ya.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _editor() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user?.email ?? user?.uid ?? 'admin';
    } catch (_) {
      return 'admin';
    }
  }

  Widget _number(String key, String label, String suffix, String helper) =>
      SettingsNumberField(
        key: ValueKey('plan-$key'),
        controller: _fields[key]!,
        enabled: !_saving,
        label: label,
        suffix: suffix,
        helper: helper,
      );

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: .6);
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
          const Row(
            children: [
              Icon(Icons.event_note_rounded),
              SizedBox(width: 10),
              Text(
                'Plan de entrenamiento',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '«Hoy te toca», diagnóstico inicial, semana y racha del '
            'Simulador. La fecha del examen, las sesiones elegidas, el día '
            'del simulacro y el recordatorio los elige cada alumno.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sesiones por semana que puede elegir',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Wrap(
            spacing: 6,
            children: [
              for (var n = 1; n <= 7; n++)
                FilterChip(
                  key: ValueKey('plan-option-$n'),
                  label: Text('$n'),
                  selected: _options.contains(n),
                  onSelected: _saving
                      ? null
                      : (on) => setState(() {
                          on ? _options.add(n) : _options.remove(n);
                        }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: const ValueKey('plan-recommended'),
            initialValue: _options.contains(_recommended) ? _recommended : null,
            decoration: const InputDecoration(
              labelText: 'Recomendadas',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final n in _options.toList()..sort())
                DropdownMenuItem(value: n, child: Text('$n por semana')),
            ],
            onChanged: _saving
                ? null
                : (v) => setState(() => _recommended = v ?? _recommended),
          ),
          _number(
            'dailyQuestions',
            'Sesión del día: preguntas',
            'preguntas',
            'Lo que propone «Hoy te toca» (5 a 40).',
          ),
          _number('dailyMinutes', 'Sesión del día: tiempo', 'min', '5 a 120.'),
          _number(
            'weakSharePercent',
            'Preguntas de temas débiles en la sesión',
            '%',
            'El resto, de todos sus cursos.',
          ),
          _number(
            'weakThresholdPercent',
            'Un tema es débil si sus aciertos están bajo',
            '%',
            'Medido en el Simulador.',
          ),
          _number(
            'minAnswersToJudge',
            'Respuestas mínimas para juzgar un tema',
            'respuestas',
            'Con menos, el tema aún no cuenta como débil.',
          ),
          _number(
            'diagnosticPerCourse',
            'Diagnóstico inicial: preguntas por curso',
            'por curso',
            'Primera sesión sin historial, de todos sus cursos con preguntas.',
          ),
          _number(
            'diagnosticMinutes',
            'Diagnóstico inicial: tiempo',
            'min',
            '5 a 180.',
          ),
          toggle(
            'plan-show-why',
            _showWhy,
            (v) => _showWhy = v,
            'Mostrar «¿Por qué?» en la recomendación',
            'Ej.: «Fallaste 4 de 6 en Sucesiones».',
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            key: const ValueKey('plan-mock-day'),
            initialValue: _mockDay,
            decoration: const InputDecoration(
              labelText: 'Día por defecto del simulacro semanal',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final entry in PlanSettings.weekDays.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _saving
                ? null
                : (v) => setState(() => _mockDay = v ?? _mockDay),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextField(
              key: const ValueKey('plan-defaultReminderTime'),
              controller: _fields['defaultReminderTime'],
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Hora por defecto del recordatorio (HH:mm)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(height: 24),
          _number(
            'minQuestionsPerSession',
            'Mínimo de preguntas para contar como sesión',
            'preguntas',
            'Cualquier examen entregado desde este tamaño.',
          ),
          _number(
            'streakGraceDays',
            'Días sin practicar antes de perder la racha',
            'días',
            '0 = se pierde si falta un día.',
          ),
          toggle(
            'plan-free-count',
            _freeExamsCount,
            (v) => _freeExamsCount = v,
            'Cuentan los exámenes libres para el plan',
            'Por curso, mezcla, aleatorio y exámenes pasados.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('plan-save'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Guardar plan'),
              ),
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() => _load(PlanSettings.defaults)),
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
