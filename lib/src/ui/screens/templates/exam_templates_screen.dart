import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/question_contract/question_contract.dart';
import '../../../domain/exam_template_record.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';

class ExamTemplatesScreen extends ConsumerWidget {
  const ExamTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppTheme.bg,
      child: StreamBuilder<List<ExamTemplateRecord>>(
        stream: ref.watch(examTemplateRepoProvider).watchTemplates(),
        builder: (context, snapshot) {
          return Column(
            children: [
              _Header(onCreate: () => _openForm(context)),
              Expanded(
                child: snapshot.hasError
                    ? const Center(
                        child: Text('No se pudieron cargar las plantillas.'),
                      )
                    : !snapshot.hasData
                    ? const Center(child: CircularProgressIndicator())
                    : _TemplateList(
                        records: snapshot.data!,
                        onEdit: (record) => _openForm(context, record: record),
                        onToggle: (record) => _toggle(context, ref, record),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {ExamTemplateRecord? record}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ExamTemplateFormSheet(record: record),
      );

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    ExamTemplateRecord record,
  ) async {
    try {
      await ref
          .read(examTemplateRepoProvider)
          .setActive(record.template, !record.active);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              record.active ? 'Plantilla desactivada.' : 'Plantilla activada.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class ExamTemplateFormSheet extends ConsumerStatefulWidget {
  const ExamTemplateFormSheet({super.key, this.record});
  final ExamTemplateRecord? record;

  @override
  ConsumerState<ExamTemplateFormSheet> createState() =>
      _ExamTemplateFormSheetState();
}

class _ExamTemplateFormSheetState extends ConsumerState<ExamTemplateFormSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _priorityUniversity = TextEditingController();
  final _count = TextEditingController(text: '10');
  final _duration = TextEditingController();
  final _threshold = TextEditingController(text: '80');
  late String _id;
  String _purpose = 'practice';
  String _mode = 'dynamic';
  String _policy = 'strict';
  bool _active = true;
  final Set<String> _fallbackSources = <String>{};
  final List<_BlockDraft> _blocks = <_BlockDraft>[];
  final List<_FixedQuestionDraft> _fixed = <_FixedQuestionDraft>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final template = widget.record?.template;
    _id = template?.id ?? const Uuid().v4();
    if (template == null) {
      _blocks.add(_BlockDraft());
      return;
    }
    _title.text = template.title;
    _description.text = template.description;
    _priorityUniversity.text = template.priorityUniversityId;
    _count.text = '${template.questionCount}';
    _duration.text = template.durationSeconds?.toString() ?? '';
    _threshold.text = '${template.passPercentExclusive}';
    _purpose = template.purpose;
    _mode = template.mode;
    _policy = template.selectionPolicy;
    _active = template.active;
    _fallbackSources.addAll(template.allowedFallbackSources);
    _blocks.addAll(template.blocks.map(_BlockDraft.fromContract));
    _fixed.addAll(
      template.fixedQuestions.map(_FixedQuestionDraft.fromContract),
    );
    if (_blocks.isEmpty && _mode == 'dynamic') _blocks.add(_BlockDraft());
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _priorityUniversity.dispose();
    _count.dispose();
    _duration.dispose();
    _threshold.dispose();
    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  int get _questionCount => int.tryParse(_count.text.trim()) ?? 0;
  int get _passPercent => int.tryParse(_threshold.text.trim()) ?? -1;
  int get _blockCount => _blocks.fold(0, (sum, block) => sum + block.count);
  int get _requiredCorrect => _questionCount > 0 && _passPercent >= 0
      ? _questionCount * _passPercent ~/ 100 + 1
      : 0;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: .92,
      minChildSize: .55,
      maxChildSize: .98,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _form,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.record == null
                    ? 'Nueva plantilla'
                    : 'Nueva versión de plantilla',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cada guardado crea una revisión inmutable; los intentos existentes no cambian.',
                style: TextStyle(color: Colors.white.withValues(alpha: .68)),
              ),
              const SizedBox(height: 20),
              _section('Datos generales', [
                _text(_title, 'Título', required: true),
                _text(_description, 'Descripción', maxLines: 3),
                _enum('Propósito', _purpose, const {
                  'practice': 'Práctica',
                  'part_completion': 'Completar parte',
                  'simulation': 'Simulación',
                }, (value) => setState(() => _purpose = value!)),
                _text(
                  _priorityUniversity,
                  'ID de universidad prioritaria (opcional)',
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  title: const Text('Plantilla activa'),
                  subtitle: const Text(
                    'Sólo una plantilla activa y válida puede generar intentos.',
                  ),
                ),
              ]),
              _section('Reglas del examen', [
                _enum(
                  'Tipo de selección',
                  _mode,
                  const {
                    'dynamic': 'Banco dinámico por bloques',
                    'fixed': 'Lista fija de revisiones',
                  },
                  (value) {
                    setState(() {
                      _mode = value!;
                      if (_mode == 'dynamic' && _blocks.isEmpty) {
                        _blocks.add(_BlockDraft());
                      }
                    });
                  },
                ),
                _enum(
                  'Política',
                  _policy,
                  const {
                    'strict': 'Estricto',
                    'prefer_profile_university':
                        'Preferir universidad del perfil',
                  },
                  (value) => setState(() {
                    _policy = value!;
                    if (_policy == 'strict') _fallbackSources.clear();
                  }),
                ),
                _number(_count, 'Cantidad total', min: 1),
                _number(_duration, 'Duración en segundos (opcional)', min: 1),
                _number(
                  _threshold,
                  'Porcentaje mínimo exclusivo',
                  min: 0,
                  max: 99,
                ),
                _metric(
                  'Respuestas correctas requeridas',
                  '$_requiredCorrect de $_questionCount',
                ),
                if (_policy == 'prefer_profile_university') _fallbackEditor(),
              ]),
              const SizedBox(height: 18),
              if (_mode == 'dynamic') _dynamicEditor() else _fixedEditor(),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Guardando…' : 'Guardar nueva versión'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dynamicEditor() => _section('Distribución dinámica', [
    Text(
      'Suma actual: $_blockCount / $_questionCount preguntas',
      style: TextStyle(
        color: _blockCount == _questionCount
            ? const Color(0xFF86EFAC)
            : const Color(0xFFFCD34D),
        fontWeight: FontWeight.w800,
      ),
    ),
    const SizedBox(height: 8),
    for (var index = 0; index < _blocks.length; index++)
      _BlockEditor(
        key: ValueKey(_blocks[index]),
        draft: _blocks[index],
        index: index,
        canRemove: _blocks.length > 1,
        onChanged: () => setState(() {}),
        onRemove: () => setState(() => _blocks.removeAt(index).dispose()),
      ),
    OutlinedButton.icon(
      onPressed: () => setState(() => _blocks.add(_BlockDraft())),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Añadir bloque'),
    ),
  ]);

  Widget _fixedEditor() => _section('Preguntas fijas', [
    Text(
      'La cantidad debe coincidir con las revisiones listadas.',
      style: TextStyle(color: Colors.white.withValues(alpha: .7)),
    ),
    const SizedBox(height: 8),
    for (final item in _fixed)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('${item.questionId} · v${item.version}'),
        trailing: IconButton(
          onPressed: () => setState(() => _fixed.remove(item)),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    OutlinedButton.icon(
      onPressed: _addFixedQuestion,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Añadir pregunta fija'),
    ),
  ]);

  Widget _fallbackEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      const Text('Fuentes complementarias autorizadas'),
      Wrap(
        spacing: 8,
        children: _sourceTypes
            .map(
              (source) => FilterChip(
                label: Text(_sourceLabels[source]!),
                selected: _fallbackSources.contains(source),
                onSelected: (selected) => setState(() {
                  selected
                      ? _fallbackSources.add(source)
                      : _fallbackSources.remove(source);
                }),
              ),
            )
            .toList(),
      ),
    ],
  );

  Future<void> _addFixedQuestion() async {
    final id = TextEditingController();
    final version = TextEditingController(text: '1');
    final value = await showDialog<_FixedQuestionDraft>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Pregunta fija'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _text(id, 'questionId', required: true),
            _number(version, 'Versión', min: 1),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(version.text);
              if (id.text.trim().isNotEmpty && parsed != null && parsed > 0) {
                Navigator.pop(
                  dialog,
                  _FixedQuestionDraft(id.text.trim(), parsed),
                );
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    id.dispose();
    version.dispose();
    if (value != null && mounted) setState(() => _fixed.add(value));
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_mode == 'dynamic' && _blockCount != _questionCount) {
      _message('La suma de bloques debe ser igual a la cantidad total.');
      return;
    }
    if (_mode == 'fixed' && _fixed.length != _questionCount) {
      _message(
        'La lista fija debe tener exactamente la cantidad total de preguntas.',
      );
      return;
    }
    try {
      final template = ExamTemplate.fromJson({
        'schemaVersion': 2,
        'id': _id,
        'version': widget.record?.template.version ?? 1,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'priorityUniversityId': _priorityUniversity.text.trim(),
        'active': _active,
        'purpose': _purpose,
        'mode': _mode,
        'selectionPolicy': _policy,
        'allowedFallbackSources': _fallbackSources.toList(),
        'questionCount': _questionCount,
        if (_duration.text.trim().isNotEmpty)
          'durationSeconds': int.parse(_duration.text.trim()),
        'passPercentExclusive': _passPercent,
        'blocks': _mode == 'dynamic'
            ? _blocks.map((block) => block.toJson()).toList()
            : [],
        'fixedQuestions': _mode == 'fixed'
            ? _fixed.map((item) => item.toJson()).toList()
            : [],
      });
      setState(() => _saving = true);
      await ref.read(examTemplateRepoProvider).save(template);
      if (mounted) Navigator.pop(context);
    } on FormatException catch (error) {
      _message(error.message.toString());
    } catch (error) {
      _message(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Widget _section(String title, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: AppTheme.cardDeco(radius: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  Widget _text(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? 'Este campo es obligatorio.'
                : null
          : null,
    ),
  );

  Widget _number(
    TextEditingController controller,
    String label, {
    required int min,
    int? max,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return label.contains('opcional') ? null : 'Ingresa un número.';
        }
        final parsed = int.tryParse(value.trim());
        if (parsed == null || parsed < min || (max != null && parsed > max)) {
          return 'Valor inválido.';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    ),
  );

  Widget _enum(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map(
            (item) =>
                DropdownMenuItem(value: item.key, child: Text(item.value)),
          )
          .toList(),
      onChanged: onChanged,
    ),
  );

  Widget _metric(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
  );
}

class _BlockEditor extends StatefulWidget {
  const _BlockEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });
  final _BlockDraft draft;
  final int index;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<_BlockEditor> {
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    color: Colors.white.withValues(alpha: .04),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bloque ${widget.index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (widget.canRemove)
                IconButton(
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          _field(widget.draft.countController, 'Cantidad', numeric: true),
          _select(
            'Tipo de fuente',
            widget.draft.sourceType,
            {'any': 'Cualquiera', ..._sourceLabels},
            (value) {
              widget.draft.sourceType = value!;
              widget.onChanged();
            },
          ),
          _select(
            'Dificultad',
            widget.draft.difficulty,
            const {
              'any': 'Cualquiera',
              'easy': 'Fácil',
              'medium': 'Media',
              'hard': 'Difícil',
            },
            (value) {
              widget.draft.difficulty = value!;
              widget.onChanged();
            },
          ),
          _field(widget.draft.universityId, 'ID universidad'),
          _field(widget.draft.modalityId, 'ID modalidad'),
          _field(widget.draft.sourceExamId, 'ID examen de origen'),
          Row(
            children: [
              Expanded(
                child: _field(
                  widget.draft.yearFrom,
                  'Año desde',
                  numeric: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(widget.draft.yearTo, 'Año hasta', numeric: true),
              ),
            ],
          ),
          const Divider(),
          _field(widget.draft.courseId, 'ID curso'),
          _field(widget.draft.topicId, 'ID tema'),
          _field(widget.draft.subtopicId, 'ID subtema'),
          _field(widget.draft.partId, 'ID parte'),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      onChanged: (_) => widget.onChanged(),
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );

  Widget _select(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String?> changed,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: options.entries
          .map(
            (entry) =>
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          )
          .toList(),
      onChanged: changed,
    ),
  );
}

class _BlockDraft {
  _BlockDraft()
    : countController = TextEditingController(text: '1'),
      universityId = TextEditingController(),
      modalityId = TextEditingController(),
      sourceExamId = TextEditingController(),
      yearFrom = TextEditingController(),
      yearTo = TextEditingController(),
      courseId = TextEditingController(),
      topicId = TextEditingController(),
      subtopicId = TextEditingController(),
      partId = TextEditingController();

  factory _BlockDraft.fromContract(ExamTemplateBlock block) {
    final result = _BlockDraft();
    result.countController.text = '${block.count}';
    final filter = block.filter;
    result.universityId.text = filter.universityId;
    result.modalityId.text = filter.modalityId;
    result.sourceExamId.text = filter.sourceExamId;
    result.yearFrom.text = filter.yearFrom?.toString() ?? '';
    result.yearTo.text = filter.yearTo?.toString() ?? '';
    result.courseId.text = filter.courseId;
    result.topicId.text = filter.topicId;
    result.subtopicId.text = filter.subtopicId;
    result.partId.text = filter.partId;
    result.sourceType = filter.sourceType;
    result.difficulty = filter.difficulty;
    return result;
  }

  final TextEditingController countController,
      universityId,
      modalityId,
      sourceExamId,
      yearFrom,
      yearTo,
      courseId,
      topicId,
      subtopicId,
      partId;
  String sourceType = 'any';
  String difficulty = 'any';
  int get countValue => int.tryParse(countController.text.trim()) ?? 0;
  int get count => countValue;

  Map<String, dynamic> toJson() => {
    'count': countValue,
    'filter': {
      'universityId': universityId.text.trim(),
      'sourceExamId': sourceExamId.text.trim(),
      'modalityId': modalityId.text.trim(),
      'courseId': courseId.text.trim(),
      'topicId': topicId.text.trim(),
      'subtopicId': subtopicId.text.trim(),
      'partId': partId.text.trim(),
      'sourceType': sourceType,
      'difficulty': difficulty,
      if (yearFrom.text.trim().isNotEmpty)
        'yearFrom': int.tryParse(yearFrom.text.trim()),
      if (yearTo.text.trim().isNotEmpty)
        'yearTo': int.tryParse(yearTo.text.trim()),
    },
  };

  void dispose() {
    for (final controller in [
      countController,
      universityId,
      modalityId,
      sourceExamId,
      yearFrom,
      yearTo,
      courseId,
      topicId,
      subtopicId,
      partId,
    ]) {
      controller.dispose();
    }
  }
}

class _FixedQuestionDraft {
  const _FixedQuestionDraft(this.questionId, this.version);
  _FixedQuestionDraft.fromContract(QuestionVersionRef ref)
    : this(ref.questionId, ref.version);
  final String questionId;
  final int version;
  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'version': version,
  };
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});
  final VoidCallback onCreate;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: AppTheme.headerGradient(),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Plantillas de examen',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .94),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Crear'),
        ),
      ],
    ),
  );
}

class _TemplateList extends StatelessWidget {
  const _TemplateList({
    required this.records,
    required this.onEdit,
    required this.onToggle,
  });
  final List<ExamTemplateRecord> records;
  final ValueChanged<ExamTemplateRecord> onEdit;
  final ValueChanged<ExamTemplateRecord> onToggle;
  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('Aún no hay plantillas.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final record = records[index];
        final template = record.template;
        return Container(
          decoration: AppTheme.cardDeco(radius: 20),
          child: ListTile(
            title: Text(
              template.title,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              '${template.mode == 'dynamic' ? 'Dinámica' : 'Fija'} · ${template.questionCount} preguntas · v${template.version}\n${template.requiredCorrectAnswers} correctas requeridas · ${record.active ? 'Activa' : 'Inactiva'}',
            ),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 2,
              children: [
                IconButton(
                  onPressed: () => onToggle(record),
                  icon: Icon(
                    record.active
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                  ),
                ),
                IconButton(
                  onPressed: () => onEdit(record),
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

const _sourceTypes = <String>[
  'admission_exam',
  'official_practice',
  'other',
  'original',
  'adapted',
];
const _sourceLabels = <String, String>{
  'admission_exam': 'Examen de admisión',
  'official_practice': 'Práctica oficial',
  'other': 'Otro',
  'original': 'Original',
  'adapted': 'Adaptada',
};
