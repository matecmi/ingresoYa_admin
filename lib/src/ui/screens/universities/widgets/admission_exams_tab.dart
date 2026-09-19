import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../domain/entities/admission_exam.dart';
import '../../../../domain/entities/university_entities.dart';
import '../../../../providers/providers.dart';
import '../../../../providers/question_catalog_providers.dart';

class AdmissionExamsTab extends ConsumerWidget {
  const AdmissionExamsTab({super.key, required this.university});
  final UniversityEntity university;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Expanded(child: Text('Historial de exámenes de admisión')),
            FilledButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: const Text('Agregar examen'),
            ),
          ],
        ),
      ),
      Expanded(
        child: ref
            .watch(universityExamsProvider(university.id))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, stack) => Center(
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(universityExamsProvider(university.id)),
                  child: const Text(
                    'No se pudieron cargar los exámenes. Reintentar',
                  ),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Text(
                        'Agrega el primer examen de esta universidad.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final exam = items[index];
                        return ListTile(
                          title: Text(exam.name),
                          subtitle: Text(
                            '${exam.modalityName} · ${exam.year}${exam.period.isEmpty ? '' : ' · Período ${exam.period}'}${exam.active ? '' : ' · Inactivo'}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Editar examen',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _edit(context, exam),
                          ),
                          onTap: () => _edit(context, exam),
                        );
                      },
                    ),
            ),
      ),
    ],
  );
  void _edit(BuildContext context, [AdmissionExam? exam]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AdmissionExamDialog(university: university, exam: exam),
  );
}

class AdmissionExamDialog extends ConsumerStatefulWidget {
  const AdmissionExamDialog({super.key, required this.university, this.exam});
  final UniversityEntity university;
  final AdmissionExam? exam;
  @override
  ConsumerState<AdmissionExamDialog> createState() =>
      _AdmissionExamDialogState();
}

class _AdmissionExamDialogState extends ConsumerState<AdmissionExamDialog> {
  final form = GlobalKey<FormState>();
  late final id = widget.exam?.id ?? const Uuid().v4();
  late final name = TextEditingController(text: widget.exam?.name ?? '');
  late final year = TextEditingController(
    text: widget.exam?.year.toString() ?? DateTime.now().year.toString(),
  );
  late String modalityId = widget.exam?.modalityId ?? '';
  late String modalityName = widget.exam?.modalityName ?? '';
  late String period = widget.exam?.period ?? '';
  late bool active = widget.exam?.active ?? true;
  bool customName = false;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    customName = widget.exam != null;
  }

  @override
  void dispose() {
    name.dispose();
    year.dispose();
    super.dispose();
  }

  void suggest() {
    name.text =
        'EXAMEN DE ADMISIÓN ${modalityName.toUpperCase()} ${year.text.trim()}${period.isEmpty ? '' : ' $period'}'
            .trim();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final modes = ref
        .read(universityModesProvider(widget.university.id))
        .asData
        ?.value;
    if (modes == null || !modes.any((e) => e.id == modalityId)) {
      setState(
        () =>
            error = 'Selecciona una modalidad disponible de esta universidad.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final u = widget.university;
      final exam = AdmissionExam.fromJson({
        'id': id,
        'name': name.text.trim(),
        'year': int.parse(year.text.trim()),
        'universityId': u.id,
        'universityName': u.name,
        'universityAcronym': u.acronym,
        'modalityId': modalityId,
        'modalityName': modalityName,
        'period': period,
        'active': active,
      });
      await ref.read(admissionExamRepoProvider).save(exam);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo guardar. Revisa la conexión, la sigla de universidad y la modalidad. Tus datos se conservan.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.exam == null
          ? 'Agregar examen de admisión'
          : 'Editar examen de admisión',
    ),
    content: SizedBox(
      width: 580,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ref
                  .watch(universityModesProvider(widget.university.id))
                  .when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, stack) => TextButton(
                      onPressed: () => ref.invalidate(
                        universityModesProvider(widget.university.id),
                      ),
                      child: const Text(
                        'No se pudieron cargar las modalidades. Reintentar',
                      ),
                    ),
                    data: (items) {
                      final options = items
                          .where((m) => m.active || m.id == modalityId)
                          .toList();
                      return Column(
                        children: [
                          if (options.isEmpty)
                            const Text(
                              'Primero registra una modalidad en la pestaña Modalidades.',
                            ),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'mode-$modalityId-${options.map((m) => m.id).join()}',
                            ),
                            initialValue: options.any((m) => m.id == modalityId)
                                ? modalityId
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Modalidad',
                            ),
                            items: options
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m.id,
                                    child: Text(m.name),
                                  ),
                                )
                                .toList(),
                            onChanged: saving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() {
                                        modalityId = value;
                                        modalityName = options
                                            .firstWhere((m) => m.id == value)
                                            .name;
                                        if (!customName) suggest();
                                      });
                                    }
                                  },
                            validator: (value) => value == null
                                ? 'Selecciona una modalidad'
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
              TextFormField(
                controller: year,
                enabled: !saving,
                decoration: const InputDecoration(labelText: 'Año'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {
                  if (!customName) suggest();
                }),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed < 1900 || parsed > 2100
                      ? 'Ingresa un año entre 1900 y 2100'
                      : null;
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Período'),
                items: ['', 'I', 'II', 'III']
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.isEmpty ? 'Sin período' : p),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (value) => setState(() {
                        period = value ?? '';
                        if (!customName) suggest();
                      }),
              ),
              TextFormField(
                controller: name,
                enabled: !saving,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo del examen',
                  helperText:
                      'Incluye año y período en el nombre que verá el alumno.',
                ),
                onChanged: (_) => setState(() => customName = true),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Ingresa el nombre del examen'
                    : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: saving
                      ? null
                      : () => setState(() {
                          customName = false;
                          suggest();
                        }),
                  child: const Text('Usar nombre sugerido'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.university.acronym} - ${name.text}',
                key: const ValueKey('exam-label-preview'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible para nuevas preguntas'),
                value: active,
                onChanged: saving ? null : (v) => setState(() => active = v),
              ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Guardando…' : 'Guardar examen'),
      ),
    ],
  );
}
