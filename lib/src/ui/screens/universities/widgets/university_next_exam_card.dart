import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/university_entities.dart';
import '../../../../domain/staff.dart';
import '../../../../providers/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/admin_ui.dart';
import '../../news/news_format.dart';

/// «Próximo examen de admisión» de una universidad: la app lo usa para la
/// cuenta regresiva del Inicio («Faltan 45 días»).
class UniversityNextExamCard extends ConsumerWidget {
  UniversityNextExamCard({super.key, required UniversityEntity university})
    : universityId = university.id,
      acronym = university.acronym,
      nextExam = university.nextExam;

  const UniversityNextExamCard.raw({
    super.key,
    required this.universityId,
    required this.acronym,
    required this.nextExam,
  });

  final String universityId;
  final String acronym;
  final UniversityNextExam? nextExam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exam = nextExam;
    final canEdit = ref
        .watch(effectiveSessionProvider)
        .can(StaffSection.universities, StaffAction.edit);
    final days = exam == null ? null : daysUntil(exam.at, DateTime.now());
    final who = acronym.isEmpty ? 'esta universidad' : acronym;
    return SectionCard(
      title: 'Próximo examen de admisión',
      trailing: canEdit
          ? TextButton.icon(
              onPressed: () => _edit(context, ref),
              icon: const Icon(Icons.edit_calendar_outlined, size: 18),
              label: Text(exam == null ? 'Poner fecha' : 'Cambiar'),
            )
          : null,
      child: exam == null
          ? Text(
              'Sin fecha. Los alumnos de $who no ven la cuenta regresiva en '
              'su Inicio.',
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.name.isEmpty ? 'Examen de admisión' : exam.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatNewsDate(exam.at)} · ${switch (days!) {
                    < 0 => 'ya pasó: actualiza la fecha',
                    0 => 'es hoy',
                    1 => 'falta 1 día',
                    _ => 'faltan $days días',
                  }}',
                  style: TextStyle(
                    color: days < 0 ? AppTheme.error : AppTheme.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<_NextExamResult>(
      context: context,
      builder: (_) => _NextExamDialog(initial: nextExam),
    );
    if (result == null) return;
    await ref
        .read(universityRepoProvider)
        .setNextExam(universityId, name: result.name, at: result.at);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.at == null ? 'Fecha quitada.' : 'Fecha del examen guardada.',
        ),
      ),
    );
  }
}

class _NextExamResult {
  const _NextExamResult(this.name, this.at);

  final String name;
  final DateTime? at;
}

class _NextExamDialog extends StatefulWidget {
  const _NextExamDialog({required this.initial});

  final UniversityNextExam? initial;

  @override
  State<_NextExamDialog> createState() => _NextExamDialogState();
}

class _NextExamDialogState extends State<_NextExamDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late DateTime? _at = widget.initial?.at;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await pickDateTime(
      context,
      initial: _at ?? DateTime.now().add(const Duration(days: 30)),
      defaultHour: 8,
    );
    if (picked != null) setState(() => _at = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Próximo examen de admisión'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nombre del examen',
                hintText: 'Examen Ordinario 2026-II',
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(
                _at == null ? 'Elegir fecha y hora' : formatNewsDate(_at!),
              ),
            ),
            const SizedBox(height: 12),
            const InfoNote(
              'Cuando la universidad mueva la fecha, cámbiala aquí: la cuenta '
              'regresiva de la app se actualiza sola. Si es un cambio '
              'importante, publica además un aviso en Noticias.',
            ),
          ],
        ),
      ),
      actions: [
        if (widget.initial != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _NextExamResult('', null)),
            child: const Text('Quitar fecha'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _at == null
              ? null
              : () => Navigator.pop(context, _NextExamResult(_name.text, _at)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
