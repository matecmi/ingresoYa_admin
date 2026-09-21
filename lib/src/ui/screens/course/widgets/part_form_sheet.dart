import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/domain/part_learning_contract.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/course_entity_form_sheet.dart';
import 'package:ingresoya_admin/src/ui/widgets/dialog_tf.dart';
import 'package:uuid/uuid.dart';

class PartFormSheet extends ConsumerStatefulWidget {
  const PartFormSheet({
    super.key,
    required this.courseId,
    required this.topicId,
    required this.subtopicId,
    this.part,
  });

  final String courseId;
  final String topicId;
  final String subtopicId;
  final SubtopicPartEntity? part;

  @override
  ConsumerState<PartFormSheet> createState() => _PartFormSheetState();
}

class _PartFormSheetState extends ConsumerState<PartFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _orderCtrl;
  late final TextEditingController _videoCtrl;
  late final TextEditingController _pdfCtrl;
  late final TextEditingController _summaryCtrl;
  late final TextEditingController _minutesCtrl;
  late final TextEditingController _contentCtrl;
  late String _difficulty;
  late List<String> _objectives;
  late List<String> _keyPoints;
  late List<Map<String, dynamic>> _formulas;
  late List<Map<String, dynamic>> _examples;
  late List<Map<String, dynamic>> _exercises;
  late List<Map<String, dynamic>> _images;
  late List<Map<String, dynamic>> _externalLinks;
  late List<Map<String, dynamic>> _flashcards;
  late List<Map<String, dynamic>> _quizQuestions;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.part?.name ?? '');
    _orderCtrl = TextEditingController(text: widget.part?.order ?? '1');
    _videoCtrl = TextEditingController(text: widget.part?.linkVideo ?? '');
    _pdfCtrl = TextEditingController(text: widget.part?.linkPdf ?? '');
    _summaryCtrl = TextEditingController(text: widget.part?.summary ?? '');
    _minutesCtrl = TextEditingController(
      text: widget.part?.estimatedMinutes?.toString() ?? '',
    );
    _contentCtrl = TextEditingController(text: widget.part?.content ?? '');
    _difficulty = widget.part?.difficulty ?? 'basic';
    _objectives = [...?widget.part?.objectives];
    _keyPoints = [...?widget.part?.keyPoints];
    _formulas = _cloneList(widget.part?.formulas);
    _examples = _cloneList(widget.part?.examples);
    _exercises = _cloneList(widget.part?.exercises);
    _images = _cloneList(widget.part?.images);
    _externalLinks = _cloneList(widget.part?.externalLinks);
    _flashcards = _cloneList(widget.part?.flashcards);
    _quizQuestions = _cloneList(widget.part?.quizQuestions);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orderCtrl.dispose();
    _videoCtrl.dispose();
    _pdfCtrl.dispose();
    _contentCtrl.dispose();
    _summaryCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final order = int.tryParse(_orderCtrl.text.trim()) ?? 0;
    if (_nameCtrl.text.trim().isEmpty) {
      _showMessage('Nombre es requerido');
      return;
    }
    if (order <= 0) {
      _showMessage('Orden debe ser > 0');
      return;
    }
    if (_contentCtrl.text.trim().isEmpty) {
      _showMessage('Descripción es requerida');
      return;
    }
    if (!_validUrlOrEmpty(_videoCtrl.text) ||
        !_validUrlOrEmpty(_pdfCtrl.text)) {
      _showMessage('Los links de video y PDF deben ser URLs http(s) válidas');
      return;
    }
    final minutesText = _minutesCtrl.text.trim();
    final minutes = minutesText.isEmpty ? null : int.tryParse(minutesText);
    if (minutesText.isNotEmpty && (minutes == null || minutes <= 0)) {
      _showMessage('Los minutos estimados deben ser un número mayor que 0');
      return;
    }
    final collectionError = _validateCollections();
    if (collectionError != null) {
      _showMessage(collectionError);
      return;
    }

    var closed = false;
    setState(() => _saving = true);
    try {
      final part = SubtopicPartEntity(
        id: widget.part?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        idSubtopic: widget.subtopicId,
        idTopic: widget.topicId,
        content: _singleBackslashes(_contentCtrl.text.trim()),
        order: order.toString(),
        linkVideo: _singleBackslashes(_videoCtrl.text.trim()),
        linkPdf: _singleBackslashes(_pdfCtrl.text.trim()),
        summary: _singleBackslashes(_summaryCtrl.text.trim()),
        objectives: _objectives.map(_singleBackslashes).toList(),
        keyPoints: _keyPoints.map(_singleBackslashes).toList(),
        estimatedMinutes: minutes,
        difficulty: _difficulty,
        formulas: _normaliseMaps(_formulas),
        examples: _normaliseMaps(_examples),
        exercises: _normaliseMaps(_exercises),
        images: _normaliseMaps(_images),
        externalLinks: _normaliseMaps(_externalLinks),
        flashcards: _normaliseMaps(_flashcards),
        quizQuestions: _normaliseMaps(_quizQuestions),
      );
      final repo = ref.read(courseRepoProvider);
      if (widget.part == null) {
        await repo.addPart(
          courseId: widget.courseId,
          topicId: widget.topicId,
          subtopicId: widget.subtopicId,
          part: part,
        );
      } else {
        await repo.updatePart(
          courseId: widget.courseId,
          topicId: widget.topicId,
          subtopicId: widget.subtopicId,
          part: part,
        );
      }

      if (!mounted) return;
      HapticFeedback.selectionClick();
      closed = true;
      Navigator.of(context).pop();
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (!closed && mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openJsonImport() async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _PartJsonImportDialog(),
    );
    if (data == null || !mounted) return;

    try {
      setState(() {
        _nameCtrl.text = (data['name'] ?? '').toString();
        _orderCtrl.text = (data['order'] ?? '1').toString();
        _contentCtrl.text = (data['content'] ?? '').toString();
        _videoCtrl.text = (data['linkVideo'] ?? '').toString();
        _pdfCtrl.text = (data['linkPdf'] ?? '').toString();
        _summaryCtrl.text = (data['summary'] ?? '').toString();
        _minutesCtrl.text = data['estimatedMinutes']?.toString() ?? '';
        _difficulty = _difficulties.contains(data['difficulty'])
            ? data['difficulty'].toString()
            : 'basic';
        _objectives = _asStrings(data['objectives']);
        _keyPoints = _asStrings(data['keyPoints']);
        _formulas = _asEntries(data['formulas']);
        _examples = _asEntries(data['examples']);
        _exercises = _asEntries(data['exercises']);
        _images = _asEntries(data['images']);
        _externalLinks = _asEntries(data['externalLinks']);
        _flashcards = _asEntries(data['flashcards']);
        _quizQuestions = _asEntries(data['quizQuestions']);
      });
      _showMessage('Datos importados. Revisa y guarda la parte.');
    } catch (_) {
      _showMessage('No se pudieron interpretar los datos de la parte.');
    }
  }

  List<String> _asStrings(dynamic value) =>
      value is List ? value.map((item) => item.toString()).toList() : [];

  List<Map<String, dynamic>> _asEntries(dynamic value) {
    if (value is! List) return [];
    return value.whereType<Map>().map((source) {
      final entry = Map<String, dynamic>.from(source);
      entry['id'] = (entry['id']?.toString().trim().isNotEmpty ?? false)
          ? entry['id'].toString()
          : const Uuid().v4();
      return entry;
    }).toList();
  }

  List<Map<String, dynamic>> _cloneList(List<Map<String, dynamic>>? source) =>
      PartLearningContract.normaliseEntries(source ?? const []);

  bool _validUrlOrEmpty(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return true;
    return PartLearningContract.validHttpUrl(raw);
  }

  String? _validateCollections() {
    return PartLearningContract.validateCollections(
      images: _images,
      externalLinks: _externalLinks,
      exercises: _exercises,
      quizQuestions: _quizQuestions,
    );
  }

  List<Map<String, dynamic>> _normaliseMaps(
    List<Map<String, dynamic>> source,
  ) => PartLearningContract.normaliseEntries(source);

  String _singleBackslashes(String value) =>
      PartLearningContract.singleBackslashes(value);

  @override
  Widget build(BuildContext context) {
    final editing = widget.part != null;
    return CourseEntityFormSheet(
      title: editing ? 'Editar parte' : 'Nueva parte',
      description: 'Añade una sección, contenido y recursos de apoyo.',
      icon: Icons.article_rounded,
      saving: _saving,
      onSave: _save,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _openJsonImport,
              icon: const Icon(Icons.data_object_rounded),
              label: const Text('Importar JSON'),
            ),
          ),
          const SizedBox(height: 8),
          DialogTF(
            ctrl: _nameCtrl,
            label: 'Nombre *',
            onChanged: (_) => setState(() {}),
          ),
          DialogTF(
            ctrl: _orderCtrl,
            label: 'Orden *',
            keyboardType: TextInputType.number,
          ),
          DialogTF(
            ctrl: _videoCtrl,
            label: 'Link video',
            onChanged: (_) => setState(() {}),
          ),
          DialogTF(
            ctrl: _pdfCtrl,
            label: 'Link PDF',
            onChanged: (_) => setState(() {}),
          ),
          DialogTF(
            ctrl: _contentCtrl,
            label: 'Descripción *',
            maxLines: 8,
            onChanged: (_) => setState(() {}),
          ),
          DialogTF(
            ctrl: _summaryCtrl,
            label: 'Resumen',
            maxLines: 3,
            onChanged: (_) => setState(() {}),
          ),
          DialogTF(
            ctrl: _minutesCtrl,
            label: 'Minutos estimados',
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          _DifficultySelector(
            value: _difficulty,
            onChanged: (value) => setState(() => _difficulty = value),
          ),
          const SizedBox(height: 12),
          _StringListEditor(
            title: 'Objetivos',
            values: _objectives,
            onChanged: (values) => setState(() => _objectives = values),
          ),
          const SizedBox(height: 12),
          _StringListEditor(
            title: 'Puntos clave',
            values: _keyPoints,
            onChanged: (values) => setState(() => _keyPoints = values),
          ),
          const SizedBox(height: 12),
          _LearningCollectionEditor(
            spec: _EntrySpec.formulas,
            items: _formulas,
            onChanged: (items) => setState(() => _formulas = items),
          ),
          const SizedBox(height: 12),
          _LearningCollectionEditor(
            spec: _EntrySpec.examples,
            items: _examples,
            onChanged: (items) => setState(() => _examples = items),
          ),
          const SizedBox(height: 12),
          _LearningCollectionEditor(
            spec: _EntrySpec.exercises,
            items: _exercises,
            onChanged: (items) => setState(() => _exercises = items),
          ),
          const SizedBox(height: 12),
          _LearningCollectionEditor(
            spec: _EntrySpec.images,
            items: _images,
            onChanged: (items) => setState(() => _images = items),
          ),
          const SizedBox(height: 12),
          _LearningCollectionEditor(
            spec: _EntrySpec.externalLinks,
            items: _externalLinks,
            onChanged: (items) => setState(() => _externalLinks = items),
          ),
          const SizedBox(height: 12),
          _LearningCollectionEditor(
            spec: _EntrySpec.flashcards,
            items: _flashcards,
            onChanged: (items) => setState(() => _flashcards = items),
          ),
          const SizedBox(height: 12),
          _LearningCollectionEditor(
            spec: _EntrySpec.quizQuestions,
            items: _quizQuestions,
            onChanged: (items) => setState(() => _quizQuestions = items),
          ),
          const SizedBox(height: 12),
          _MobilePartPreview(
            name: _nameCtrl.text,
            content: _contentCtrl.text,
            summary: _summaryCtrl.text,
            difficulty: _difficulty,
            minutes: _minutesCtrl.text,
            objectives: _objectives,
            keyPoints: _keyPoints,
            formulas: _formulas,
            examples: _examples,
            images: _images,
            exercises: _exercises,
            externalLinks: _externalLinks,
            flashcards: _flashcards,
            quizQuestions: _quizQuestions,
            linkVideo: _videoCtrl.text,
            linkPdf: _pdfCtrl.text,
          ),
        ],
      ),
    );
  }
}

class _PartJsonImportDialog extends StatefulWidget {
  const _PartJsonImportDialog();

  @override
  State<_PartJsonImportDialog> createState() => _PartJsonImportDialogState();
}

class _PartJsonImportDialogState extends State<_PartJsonImportDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _import() {
    try {
      final data = PartLearningContract.decodeJsonObject(_controller.text);
      Navigator.pop(context, data);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(
        () => _error = 'JSON inválido. Revisa comas, comillas y barras.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Importar JSON de parte'),
    content: SizedBox(
      width: 620,
      child: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 18,
        decoration: InputDecoration(
          hintText: '{ "name": "...", "formulas": [] }',
          alignLabelWithHint: true,
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      ElevatedButton(onPressed: _import, child: const Text('Importar')),
    ],
  );
}

const _difficulties = ['basic', 'intermediate', 'advanced'];

class _DifficultySelector extends StatelessWidget {
  const _DifficultySelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: _difficulties.contains(value) ? value : 'basic',
    decoration: const InputDecoration(labelText: 'Dificultad'),
    items: _difficulties
        .map((item) => DropdownMenuItem(value: item, child: Text(item)))
        .toList(),
    onChanged: (item) => item == null ? null : onChanged(item),
  );
}

class _StringListEditor extends StatelessWidget {
  const _StringListEditor({
    required this.title,
    required this.values,
    required this.onChanged,
  });
  final String title;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) => _EditorCard(
    title: title,
    count: values.length,
    onAdd: () => onChanged([...values, '']),
    children: [
      for (var i = 0; i < values.length; i++)
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: values[i],
                decoration: InputDecoration(labelText: '$title ${i + 1}'),
                onChanged: (value) {
                  final next = [...values];
                  next[i] = value;
                  onChanged(next);
                },
              ),
            ),
            IconButton(
              onPressed: i == 0
                  ? null
                  : () {
                      final next = [...values];
                      final item = next.removeAt(i);
                      next.insert(i - 1, item);
                      onChanged(next);
                    },
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
            IconButton(
              onPressed: i == values.length - 1
                  ? null
                  : () {
                      final next = [...values];
                      final item = next.removeAt(i);
                      next.insert(i + 1, item);
                      onChanged(next);
                    },
              icon: const Icon(Icons.arrow_downward_rounded),
            ),
            IconButton(
              onPressed: () {
                final next = [...values]..removeAt(i);
                onChanged(next);
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
    ],
  );
}

class _EntrySpec {
  const _EntrySpec(
    this.title,
    this.icon,
    this.fields, {
    this.listFields = const [],
    this.latex = false,
    this.quiz = false,
    this.exercise = false,
  });
  final String title;
  final IconData icon;
  final List<_EntryField> fields;
  final List<_EntryField> listFields;
  final bool latex;
  final bool quiz;
  final bool exercise;

  static const formulas = _EntrySpec('Fórmulas', Icons.functions_rounded, [
    _EntryField('title', 'Título'),
    _EntryField('latex', 'LaTeX', multiline: true),
    _EntryField('description', 'Descripción', multiline: true),
  ], latex: true);
  static const examples = _EntrySpec(
    'Ejemplos',
    Icons.lightbulb_outline_rounded,
    [
      _EntryField('title', 'Título'),
      _EntryField('problem', 'Problema', multiline: true),
      _EntryField('answer', 'Respuesta', multiline: true),
    ],
    listFields: [_EntryField('steps', 'Pasos')],
  );
  static const exercises = _EntrySpec('Ejercicios', Icons.edit_note_rounded, [
    _EntryField('statement', 'Enunciado', multiline: true),
    _EntryField('hint', 'Pista', multiline: true),
    _EntryField('answer', 'Respuesta', multiline: true),
    _EntryField('difficulty', 'Dificultad'),
  ], exercise: true);
  static const images = _EntrySpec('Imágenes', Icons.image_outlined, [
    _EntryField('url', 'URL de imagen', url: true),
    _EntryField('caption', 'Pie de imagen'),
  ]);
  static const externalLinks =
      _EntrySpec('Enlaces externos', Icons.link_rounded, [
        _EntryField('title', 'Título'),
        _EntryField('url', 'URL', url: true),
        _EntryField('type', 'Tipo'),
      ]);
  static const flashcards = _EntrySpec('Tarjetas', Icons.style_outlined, [
    _EntryField('front', 'Frente', multiline: true),
    _EntryField('back', 'Reverso', multiline: true),
  ]);
  static const quizQuestions = _EntrySpec(
    'Preguntas de quiz',
    Icons.quiz_outlined,
    [
      _EntryField('question', 'Pregunta', multiline: true),
      _EntryField('correctIndex', 'Índice correcto (0, 1, ...)', number: true),
      _EntryField('explanation', 'Explicación', multiline: true),
    ],
    listFields: [_EntryField('options', 'Opciones')],
    quiz: true,
  );
}

class _EntryField {
  const _EntryField(
    this.key,
    this.label, {
    this.multiline = false,
    this.url = false,
    this.number = false,
  });
  final String key;
  final String label;
  final bool multiline;
  final bool url;
  final bool number;
}

class _LearningCollectionEditor extends StatelessWidget {
  const _LearningCollectionEditor({
    required this.spec,
    required this.items,
    required this.onChanged,
  });
  final _EntrySpec spec;
  final List<Map<String, dynamic>> items;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  Future<void> _edit(BuildContext context, [int? index]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EntryDialog(
        spec: spec,
        initial: index == null ? null : items[index],
      ),
    );
    if (result == null) return;
    final next = items.map((item) => Map<String, dynamic>.from(item)).toList();
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) => _EditorCard(
    title: spec.title,
    count: items.length,
    onAdd: () => _edit(context),
    children: [
      for (var i = 0; i < items.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(spec.icon, size: 18)),
          title: Text(_entryTitle(items[i], spec, i)),
          subtitle: Text(
            'ID: ${(items[i]['id'] ?? '').toString().substring(0, (items[i]['id'] ?? '').toString().length.clamp(0, 8))}',
          ),
          trailing: Wrap(
            spacing: 0,
            children: [
              IconButton(
                onPressed: i == 0
                    ? null
                    : () {
                        final next = [...items];
                        final item = next.removeAt(i);
                        next.insert(i - 1, item);
                        onChanged(next);
                      },
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                onPressed: i == items.length - 1
                    ? null
                    : () {
                        final next = [...items];
                        final item = next.removeAt(i);
                        next.insert(i + 1, item);
                        onChanged(next);
                      },
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              IconButton(
                onPressed: () => _edit(context, i),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: () {
                  final next = [...items]..removeAt(i);
                  onChanged(next);
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ),
    ],
  );
}

String _entryTitle(Map<String, dynamic> item, _EntrySpec spec, int index) =>
    (item['title'] ??
            item['question'] ??
            item['statement'] ??
            item['front'] ??
            item['url'] ??
            '${spec.title} ${index + 1}')
        .toString();

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.title,
    required this.count,
    required this.onAdd,
    required this.children,
  });
  final String title;
  final int count;
  final VoidCallback onAdd;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.035),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$title ($count)',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar'),
            ),
          ],
        ),
        ...children,
      ],
    ),
  );
}

class _EntryDialog extends StatefulWidget {
  const _EntryDialog({required this.spec, this.initial});
  final _EntrySpec spec;
  final Map<String, dynamic>? initial;
  @override
  State<_EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<_EntryDialog> {
  late final Map<String, TextEditingController> _controllers;
  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in [...widget.spec.fields, ...widget.spec.listFields])
        field.key: TextEditingController(
          text: widget.spec.listFields.contains(field)
              ? ((widget.initial?[field.key] as List? ?? const []).join('\n'))
              : (widget.initial?[field.key] ?? '').toString(),
        ),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _url(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  void _save() {
    final item = <String, dynamic>{
      'id': widget.initial?['id'] ?? const Uuid().v4(),
    };
    for (final field in widget.spec.fields) {
      final value = _controllers[field.key]!.text.trim();
      if (field.url && !_url(value)) {
        _error('URL inválida para ${field.label}');
        return;
      }
      item[field.key] = field.number ? int.tryParse(value) : value;
    }
    for (final field in widget.spec.listFields) {
      item[field.key] = _controllers[field.key]!.text
          .split('\n')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
    }
    if (widget.spec.exercise && !_difficulties.contains(item['difficulty'])) {
      _error('Dificultad: basic, intermediate o advanced');
      return;
    }
    if (widget.spec.quiz) {
      final options = item['options'] as List;
      final correct = item['correctIndex'];
      if (correct is! int || correct < 0 || correct >= options.length) {
        _error('correctIndex debe referirse a una opción existente');
        return;
      }
    }
    Navigator.pop(context, item);
  }

  void _error(String value) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(value)));
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.spec.title),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.spec.fields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _controllers[field.key],
                  keyboardType: field.number
                      ? TextInputType.number
                      : field.url
                      ? TextInputType.url
                      : TextInputType.text,
                  maxLines: field.multiline ? 4 : 1,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: field.label),
                ),
              ),
            ),
            ...widget.spec.listFields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _controllers[field.key],
                  maxLines: 5,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: '${field.label} (una por línea)',
                  ),
                ),
              ),
            ),
            if (widget.spec.latex &&
                _controllers['latex']!.text.trim().isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Math.tex(
                  _controllers['latex']!.text.trim(),
                  textStyle: const TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      ElevatedButton(onPressed: _save, child: const Text('Guardar')),
    ],
  );
}

class _MobilePartPreview extends StatelessWidget {
  const _MobilePartPreview({
    required this.name,
    required this.content,
    required this.summary,
    required this.difficulty,
    required this.minutes,
    required this.objectives,
    required this.keyPoints,
    required this.formulas,
    required this.examples,
    required this.images,
    required this.exercises,
    required this.externalLinks,
    required this.flashcards,
    required this.quizQuestions,
    required this.linkVideo,
    required this.linkPdf,
  });
  final String name, content, summary, difficulty, minutes, linkVideo, linkPdf;
  final List<String> objectives, keyPoints;
  final List<Map<String, dynamic>> formulas, examples, images;
  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> externalLinks;
  final List<Map<String, dynamic>> flashcards;
  final List<Map<String, dynamic>> quizQuestions;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0A0F2C),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withOpacity(.14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vista previa móvil',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          name.isEmpty ? 'Título de la parte' : name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        Text(
          '$difficulty${minutes.isEmpty ? '' : ' • $minutes min'}',
          style: TextStyle(color: Colors.white.withOpacity(.65)),
        ),
        if (summary.trim().isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(summary)),
        if (content.trim().isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text(content)),
        if (objectives.isNotEmpty) _previewList('Objetivos', objectives),
        if (keyPoints.isNotEmpty) _previewList('Puntos clave', keyPoints),
        for (final formula in formulas)
          if ((formula['latex'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (formula['title'] ?? 'Fórmula').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Math.tex(
                    (formula['latex']).toString(),
                    textStyle: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
        if (examples.isNotEmpty)
          ...examples.map(
            (item) => _previewEntry(
              'Ejemplo',
              (item['title'] ?? '').toString(),
              (item['problem'] ?? '').toString(),
              details: [
                ...(item['steps'] as List? ?? const []).map((v) => '• $v'),
                if ((item['answer'] ?? '').toString().isNotEmpty)
                  'Respuesta: ${item['answer']}',
              ],
            ),
          ),
        ...exercises.map(
          (item) => _previewEntry(
            'Ejercicio • ${item['difficulty'] ?? 'basic'}',
            (item['statement'] ?? '').toString(),
            (item['hint'] ?? '').toString(),
            details: [
              if ((item['answer'] ?? '').toString().isNotEmpty)
                'Respuesta: ${item['answer']}',
            ],
          ),
        ),
        ...images.map(
          (item) => _previewEntry(
            'Imagen',
            (item['caption'] ?? '').toString(),
            (item['url'] ?? '').toString(),
          ),
        ),
        ...externalLinks.map(
          (item) => _previewEntry(
            'Enlace • ${item['type'] ?? ''}',
            (item['title'] ?? '').toString(),
            (item['url'] ?? '').toString(),
          ),
        ),
        ...flashcards.map(
          (item) => _previewEntry(
            'Tarjeta',
            (item['front'] ?? '').toString(),
            'Reverso: ${item['back'] ?? ''}',
          ),
        ),
        ...quizQuestions.map((item) {
          final options = item['options'] as List? ?? const [];
          final correct = item['correctIndex'];
          return _previewEntry(
            'Quiz',
            (item['question'] ?? '').toString(),
            '',
            details: [
              for (var i = 0; i < options.length; i++)
                '${i == correct ? '✓' : '○'} ${options[i]}',
              if ((item['explanation'] ?? '').toString().isNotEmpty)
                'Explicación: ${item['explanation']}',
            ],
          );
        }),
        if (linkVideo.trim().isNotEmpty)
          _previewEntry('Video', 'Recurso audiovisual', linkVideo),
        if (linkPdf.trim().isNotEmpty)
          _previewEntry('PDF', 'Material descargable', linkPdf),
      ],
    ),
  );
  Widget _previewList(String title, List<String> values) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        ...values.where((v) => v.trim().isNotEmpty).map((v) => Text('• $v')),
      ],
    ),
  );

  Widget _previewEntry(
    String section,
    String title,
    String body, {
    List<String> details = const [],
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section, style: const TextStyle(fontWeight: FontWeight.w900)),
          if (title.trim().isNotEmpty) Text(title),
          if (body.trim().isNotEmpty)
            Text(body, style: TextStyle(color: Colors.white.withOpacity(.72))),
          ...details.where((value) => value.trim().isNotEmpty).map(Text.new),
        ],
      ),
    ),
  );
}
