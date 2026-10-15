import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repo/admission_exam_repo.dart';
import '../../../../domain/entities/admission_exam.dart';
import '../../../../domain/entities/exam_simulator_rules.dart';
import '../../../../domain/entities/university_entities.dart';
import '../../../../providers/providers.dart';

/// Rules of a past exam in the app's Simulator: time, scoring, question
/// order, minimum admission score per career and whether it is offered.
class ExamSimulatorDialog extends ConsumerStatefulWidget {
  const ExamSimulatorDialog({
    super.key,
    required this.university,
    required this.exam,
  });

  final UniversityEntity university;
  final AdmissionExam exam;

  @override
  ConsumerState<ExamSimulatorDialog> createState() =>
      _ExamSimulatorDialogState();
}

class _ExamSimulatorDialogState extends ConsumerState<ExamSimulatorDialog> {
  late ExamSimulatorRules rules = widget.exam.simulator;
  late final questionCount = _number(rules.questionCount, allowZero: false);
  late final duration = _number(rules.durationMinutes);
  late final maxScore = _number(rules.maxScore);
  late final correct = _decimal(rules.correctPoints);
  late final incorrect = _decimal(rules.incorrectPoints);
  late final blank = _decimal(rules.blankPoints);
  late final Map<String, TextEditingController> cutoffs = {
    for (final career in widget.university.professions)
      career.id: TextEditingController(
        text: rules.cutoffs[career.id]?.toString() ?? '',
      ),
  };
  late String order = rules.questionOrder;
  late bool available = rules.available;
  bool saving = false;
  String? error;

  static TextEditingController _number(int value, {bool allowZero = true}) =>
      TextEditingController(
        text: value == 0 && !allowZero ? '' : value.toString(),
      );

  static TextEditingController _decimal(double value) => TextEditingController(
    text: value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString(),
  );

  @override
  void dispose() {
    for (final controller in [
      questionCount,
      duration,
      maxScore,
      correct,
      incorrect,
      blank,
      ...cutoffs.values,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  ExamSimulatorRules? _read() {
    int? integer(TextEditingController c) => int.tryParse(c.text.trim());
    double? decimal(TextEditingController c) =>
        double.tryParse(c.text.trim().replaceAll(',', '.'));
    final values = [
      integer(questionCount),
      integer(duration),
      integer(maxScore),
      decimal(correct),
      decimal(incorrect),
      decimal(blank),
    ];
    if (values.any((value) => value == null)) {
      setState(() => error = 'Completa todos los números.');
      return null;
    }
    final careerCutoffs = <String, int>{};
    for (final entry in cutoffs.entries) {
      final text = entry.value.text.trim();
      if (text.isEmpty) continue;
      final score = int.tryParse(text);
      if (score == null) {
        setState(() => error = 'Los mínimos de ingreso deben ser enteros.');
        return null;
      }
      careerCutoffs[entry.key] = score;
    }
    return rules.copyWith(
      questionCount: values[0] as int,
      durationMinutes: values[1] as int,
      maxScore: values[2] as int,
      correctPoints: values[3] as double,
      incorrectPoints: values[4] as double,
      blankPoints: values[5] as double,
      questionOrder: order,
      available: available,
      cutoffs: careerCutoffs,
    );
  }

  Future<void> _save() async {
    if (saving) return;
    final next = _read();
    if (next == null) return;
    final invalid = next.validate();
    if (invalid != null) {
      setState(() => error = invalid);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final saved = await ref
          .read(admissionExamRepoProvider)
          .saveSimulatorRules(widget.university.id, widget.exam.id, next);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved.complete
                ? 'Reglas guardadas · ${saved.publishedQuestions} de ${saved.questionCount} preguntas.'
                : 'Reglas guardadas. El examen aún está incompleto.',
          ),
        ),
      );
    } on ExamCatalogException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'No se pudieron guardar las reglas. Reintenta.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))];
    final signed = [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]'))];
    Widget field(
      TextEditingController controller,
      String label, {
      String? helper,
      bool decimal = false,
    }) => SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        inputFormatters: decimal ? signed : digits,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
        ),
      ),
    );

    return AlertDialog(
      title: Text('Simulador · ${widget.exam.name}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CompletenessBanner(rules: rules),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  field(
                    questionCount,
                    'Preguntas del examen original',
                    helper: 'Cuántas tuvo el examen real.',
                  ),
                  field(duration, 'Duración (min)'),
                  field(maxScore, 'Puntaje máximo'),
                  field(correct, 'Por correcta', decimal: true),
                  field(
                    incorrect,
                    'Por incorrecta',
                    helper: '0 o negativo',
                    decimal: true,
                  ),
                  field(blank, 'En blanco', decimal: true),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: order,
                decoration: const InputDecoration(
                  labelText: 'Orden de las preguntas',
                  helperText:
                      'Original usa el «Número original» de cada pregunta; todas deben tenerlo.',
                  helperMaxLines: 2,
                ),
                items: const [
                  DropdownMenuItem(value: 'original', child: Text('Original')),
                  DropdownMenuItem(value: 'shuffled', child: Text('Mezclado')),
                ],
                onChanged: (value) => setState(() => order = value!),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: available,
                onChanged: (value) => setState(() => available = value),
                title: const Text('Disponible en el Simulador'),
                subtitle: const Text(
                  'Solo se guarda si el examen está completo al guardar.',
                ),
              ),
              const Divider(height: 28),
              Text(
                'Puntaje mínimo de ingreso por carrera',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              const Text(
                'Opcional. Sin dato, la app no muestra «¿te alcanzaba?» para esa carrera.',
              ),
              const SizedBox(height: 8),
              if (widget.university.professions.isEmpty)
                const Text('Esta universidad aún no tiene carreras.')
              else
                for (final career in widget.university.professions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(career.name)),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            key: ValueKey('cutoff-${career.id}'),
                            controller: cutoffs[career.id],
                            keyboardType: TextInputType.number,
                            inputFormatters: digits,
                            decoration: const InputDecoration(
                              hintText: 'Mínimo',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }
}

class _CompletenessBanner extends StatelessWidget {
  const _CompletenessBanner({required this.rules});
  final ExamSimulatorRules rules;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final checked = rules.questionCount > 0;
    final text = !checked
        ? 'Aún sin revisar: guarda las reglas para contar sus preguntas.'
        : rules.complete
        ? 'Completo: ${rules.publishedQuestions} de ${rules.questionCount} preguntas publicadas.'
        : 'Incompleto: ${rules.publishedQuestions} de ${rules.questionCount} publicadas'
              '${rules.questionOrder == 'original' ? ', ${rules.numberedQuestions} con número original' : ''}.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (rules.complete ? Colors.green : scheme.tertiary).withValues(
          alpha: .12,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text),
    );
  }
}
