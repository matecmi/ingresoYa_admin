import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../shared/question_contract/question_contract.dart';
import '../../../domain/editor_document.dart';
import '../../../data/repo/question_image_store.dart';
import 'content_preview.dart';
import 'image_paste.dart';

typedef ImageUploader =
    Future<Map<String, dynamic>> Function(Uint8List, String);

Future<EditorDocument?> editContent(
  BuildContext context, {
  required EditorDocument initial,
  String title = 'Editar contenido',
}) => showDialog<EditorDocument>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ContentEditor(initial: initial, title: title),
);

class ContentEditor extends StatefulWidget {
  const ContentEditor({
    super.key,
    required this.initial,
    this.title = 'Editar contenido',
    this.uploadImage = QuestionImageStore.upload,
  });
  final EditorDocument initial;
  final String title;
  final ImageUploader uploadImage;
  @override
  State<ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<ContentEditor> {
  late List<Json> blocks;
  late Map<String, double> sizes;
  final history = EditorHistory();
  late void Function() stopPaste;
  bool busy = false;
  bool preview = false;
  bool dirty = false;
  int epoch = 0;
  String? error;
  final invalidUrls = <String>{};

  EditorDocument get document =>
      EditorDocument(QuestionContent.fromJson(blocks), sizes);
  @override
  void initState() {
    super.initState();
    blocks = widget.initial.content.toJson();
    sizes = {...widget.initial.imageSizes};
    stopPaste = listenForImagePaste((bytes, name) {
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        _upload(bytes, name, blocks.length);
      }
    });
  }

  @override
  void dispose() {
    stopPaste();
    super.dispose();
  }

  void change(VoidCallback action) {
    history.remember(document);
    setState(() {
      action();
      dirty = true;
      error = null;
    });
  }

  void add(int at, String type) => change(
    () => blocks.insert(at, {
      'id': const Uuid().v4(),
      'type': type,
      if (type == 'paragraph')
        'spans': <Json>[
          {'type': 'text', 'text': ''},
        ],
      if (type == 'formula') ...{'latex': '', 'displayMode': 'block'},
      if (type == 'image') ...{
        'url': 'https://example.com/image.png',
        'altText': '',
        'caption': '',
      },
    }),
  );

  Future<void> _pick(int at, {String? replace}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (!mounted || result == null) return;
      final file = result.files.single;
      if (file.size > 5 * 1024 * 1024) {
        setState(() => error = 'Elige una imagen de hasta 5 MB.');
        return;
      }
      final bytes = file.bytes ?? await result.xFiles.single.readAsBytes();
      if (mounted) {
        await _upload(bytes, file.name, at, replace: replace);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo leer el archivo. Prueba seleccionarlo nuevamente.',
        );
      }
    }
  }

  Future<void> _url(int at) async {
    var urlText = '';
    final form = GlobalKey<FormState>();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insertar imagen por URL'),
        content: Form(
          key: form,
          child: TextFormField(
            onChanged: (value) => urlText = value,
            decoration: const InputDecoration(labelText: 'https://...'),
            validator: (v) {
              final uri = Uri.tryParse(v ?? '');
              return uri != null &&
                      ['http', 'https'].contains(uri.scheme) &&
                      uri.host.isNotEmpty
                  ? null
                  : 'Escribe una URL HTTP o HTTPS completa.';
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, urlText);
              }
            },
            child: const Text('Insertar'),
          ),
        ],
      ),
    );
    if (!mounted || url == null) return;
    change(
      () => blocks.insert(at, {
        'id': const Uuid().v4(),
        'type': 'image',
        'url': url,
        'altText': '',
        'caption': '',
      }),
    );
  }

  Future<void> _upload(
    Uint8List bytes,
    String name,
    int at, {
    String? replace,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final image = await widget.uploadImage(bytes, name);
      if (!mounted) return;
      change(() {
        final index = replace == null
            ? -1
            : blocks.indexWhere((b) => b['id'] == replace);
        final block = <String, dynamic>{
          'id': replace ?? const Uuid().v4(),
          'type': 'image',
          'altText': index < 0 ? '' : blocks[index]['altText'],
          'caption': index < 0 ? '' : blocks[index]['caption'],
          ...image,
        };
        if (index < 0) {
          blocks.insert(at.clamp(0, blocks.length), block);
        } else {
          blocks[index] = block;
        }
        epoch++;
        if (replace != null) invalidUrls.remove(replace);
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo cargar la imagen. Usa PNG, JPG o WebP de hasta 5 MB. '
              'Comprueba tu conexión y los permisos de Storage. Puedes volver a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> close() async {
    if (busy) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Descartar los cambios de este editor?'),
          content: const Text(
            'Usa «Aplicar contenido» para conservarlos en el formulario.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir editando'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !busy,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !busy) close();
    },
    child: Dialog(
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 1160,
        height: MediaQuery.sizeOf(context).height * .92,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Deshacer',
                    onPressed: busy || !history.canUndo
                        ? null
                        : () {
                            final old = history.undo();
                            invalidUrls.clear();
                            error = null;
                            setState(() {
                              blocks = old.content.toJson();
                              sizes = {...old.imageSizes};
                              epoch++;
                              dirty = true;
                            });
                          },
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Vista móvil',
                    onPressed: () => setState(() => preview = !preview),
                    icon: const Icon(Icons.phone_android),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: busy ? null : close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (invalidUrls.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                  'Corrige la URL de imagen antes de aplicar el contenido.',
                ),
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 850;
                  final editor = DropTarget(
                    enable: !busy && ModalRoute.of(context)?.isCurrent == true,
                    onDragDone: (detail) async {
                      if (detail.files.isNotEmpty && !busy) {
                        try {
                          final file = detail.files.first;
                          if (await file.length() > 5 * 1024 * 1024) {
                            if (mounted) {
                              setState(
                                () => error = 'Elige una imagen de hasta 5 MB.',
                              );
                            }
                            return;
                          }
                          if (!mounted) return;
                          await _upload(
                            await file.readAsBytes(),
                            file.name,
                            blocks.length,
                          );
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => error =
                                  'No se pudo leer la imagen. Usa el selector de archivos.',
                            );
                          }
                        }
                      }
                    },
                    child: AbsorbPointer(
                      absorbing: busy,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            kIsWeb
                                ? 'Arrastra una imagen o pégala con Ctrl+V / ⌘V. Máximo 5 MB.'
                                : 'Arrastra una imagen o usa «Subir imagen». Máximo 5 MB.',
                          ),
                          for (var i = 0; i <= blocks.length; i++) ...[
                            _insert(i),
                            if (i < blocks.length) _block(i),
                          ],
                        ],
                      ),
                    ),
                  );
                  final phone = SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Text('VISTA PREVIA · MÓVIL'),
                                const Divider(),
                                ContentPreview(document: document),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  if (wide) {
                    return Row(
                      children: [
                        Expanded(child: editor),
                        const VerticalDivider(),
                        SizedBox(width: 430, child: phone),
                      ],
                    );
                  }
                  return preview ? phone : editor;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Aplica el contenido y luego guarda la pregunta.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  FilledButton(
                    onPressed: busy || invalidUrls.isNotEmpty
                        ? null
                        : () => Navigator.pop(context, document),
                    child: const Text('Aplicar contenido'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _insert(int at) => Align(
    alignment: Alignment.centerLeft,
    child: PopupMenuButton<String>(
      tooltip: 'Agregar bloque',
      onSelected: (value) {
        if (value == 'upload') {
          _pick(at);
        } else if (value == 'image') {
          _url(at);
        } else {
          add(at, value);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'paragraph', child: Text('Texto')),
        PopupMenuItem(value: 'formula', child: Text('Fórmula')),
        PopupMenuItem(value: 'upload', child: Text('Subir imagen')),
        PopupMenuItem(value: 'image', child: Text('Imagen por URL')),
      ],
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('+ Agregar bloque'),
      ),
    ),
  );

  Widget _block(int index) {
    final b = blocks[index];
    final id = b['id'] as String;
    final type = b['type'];
    return Card(
      key: ValueKey('$id-$epoch'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${index + 1}. ${{'paragraph': 'Texto', 'text': 'Texto', 'image': 'Imagen', 'formula': 'Fórmula', 'legacy': 'Contenido anterior'}[type]}',
                  ),
                ),
                IconButton(
                  tooltip: 'Subir bloque',
                  onPressed: index == 0
                      ? null
                      : () => change(() {
                          blocks.insert(index - 1, blocks.removeAt(index));
                        }),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                ),
                IconButton(
                  tooltip: 'Bajar bloque',
                  onPressed: index == blocks.length - 1
                      ? null
                      : () => change(() {
                          blocks.insert(index + 1, blocks.removeAt(index));
                        }),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                ),
                IconButton(
                  tooltip: 'Duplicar bloque',
                  onPressed: () => change(() {
                    final newId = const Uuid().v4();
                    final copy = ContentBlock.fromJson(b).toJson()
                      ..['id'] = newId;
                    blocks.insert(index + 1, copy);
                    if (sizes.containsKey(id)) sizes[newId] = sizes[id]!;
                  }),
                  icon: const Icon(Icons.copy, size: 18),
                ),
                IconButton(
                  tooltip: 'Eliminar bloque',
                  onPressed: () => change(() {
                    blocks.removeAt(index);
                    sizes.remove(id);
                    invalidUrls.remove(id);
                  }),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
            if (type == 'paragraph') ..._spans(b),
            if (type == 'text') ...[
              _field('Texto', b['text'], (v) => change(() => b['text'] = v)),
              TextButton(
                onPressed: () => change(() {
                  b['type'] = 'paragraph';
                  b['spans'] = [
                    {'type': 'text', 'text': b.remove('text')},
                  ];
                  epoch++;
                }),
                child: const Text('Agregar formato e insertar fórmulas'),
              ),
            ],
            if (type == 'legacy') ...[
              const Text(
                'Este bloque conserva el formato anterior. Puedes editarlo sin convertir ni perder su contenido.',
              ),
              _field(
                'Contenido anterior',
                b['raw'],
                (v) => change(() => b['raw'] = v),
              ),
            ],
            if (type == 'formula')
              FormulaInput(
                initial: b['latex'],
                onChanged: (v) => change(() => b['latex'] = v),
              ),
            if (type == 'image') ...[
              if (b['url'] != null)
                _field('URL de imagen (https://...)', b['url'], (v) {
                  final uri = Uri.tryParse(v);
                  if (uri != null &&
                      ['http', 'https'].contains(uri.scheme) &&
                      uri.host.isNotEmpty) {
                    change(() {
                      b['url'] = v;
                      b.remove('width');
                      b.remove('height');
                      invalidUrls.remove(id);
                    });
                  } else {
                    setState(() {
                      invalidUrls.add(id);
                      error =
                          'Corrige la URL de imagen antes de aplicar el contenido.';
                      dirty = true;
                    });
                  }
                }, lines: 1),
              _field(
                'Descripción accesible',
                b['altText'] ?? '',
                (v) => change(() => b['altText'] = v),
                lines: 2,
              ),
              _field(
                'Pie de imagen (opcional)',
                b['caption'] ?? '',
                (v) => change(() => b['caption'] = v),
                lines: 2,
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pick(index, replace: id),
                    icon: const Icon(Icons.upload),
                    label: const Text('Reemplazar imagen'),
                  ),
                  for (final size in <String, double>{
                    'Pequeña': .4,
                    'Mediana': .7,
                    'Completa': 1,
                  }.entries)
                    ChoiceChip(
                      label: Text(size.key),
                      selected: (sizes[id] ?? 1) == size.value,
                      onSelected: (_) => change(() => sizes[id] = size.value),
                    ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  child: ContentPreview(
                    document: EditorDocument(
                      QuestionContent.fromJson([b]),
                      sizes,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _spans(Json block) {
    final spans = block['spans'] as List;
    return [
      for (var i = 0; i < spans.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: [
              if (spans[i]['type'] == 'formula')
                FormulaInput(
                  initial: spans[i]['latex'],
                  onChanged: (v) => change(() => spans[i]['latex'] = v),
                )
              else
                _field(
                  'Texto · fragmento ${i + 1}',
                  spans[i]['text'],
                  (v) => change(() => spans[i]['text'] = v),
                ),
              Row(
                children: [
                  if (spans[i]['type'] == 'text')
                    for (final mark in ['bold', 'italic'])
                      IconButton(
                        isSelected: (spans[i]['marks'] as List? ?? []).contains(
                          mark,
                        ),
                        tooltip: mark == 'bold' ? 'Negrita' : 'Cursiva',
                        icon: Icon(
                          mark == 'bold'
                              ? Icons.format_bold
                              : Icons.format_italic,
                        ),
                        onPressed: () => change(() {
                          final marks = List<String>.from(
                            spans[i]['marks'] ?? [],
                          );
                          marks.contains(mark)
                              ? marks.remove(mark)
                              : marks.add(mark);
                          spans[i]['marks'] = marks;
                        }),
                      ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Eliminar fragmento',
                    onPressed: () => change(() {
                      spans.removeAt(i);
                      epoch++;
                    }),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () =>
                change(() => spans.add({'type': 'text', 'text': ''})),
            child: const Text('+ Texto'),
          ),
          TextButton(
            onPressed: () =>
                change(() => spans.add({'type': 'formula', 'latex': 'x^2'})),
            child: const Text('+ Fórmula en línea'),
          ),
        ],
      ),
    ];
  }

  Widget _field(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    int lines = 4,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      initialValue: value,
      minLines: 1,
      maxLines: lines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
    ),
  );
}

class FormulaInput extends StatefulWidget {
  const FormulaInput({
    super.key,
    required this.initial,
    required this.onChanged,
  });
  final String initial;
  final ValueChanged<String> onChanged;
  @override
  State<FormulaInput> createState() => _FormulaInputState();
}

class _FormulaInputState extends State<FormulaInput> {
  late final TextEditingController controller = TextEditingController(
    text: widget.initial,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void insert(String value) {
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : controller.text.length;
    final end = selection.isValid ? selection.end : start;
    controller.value = TextEditingValue(
      text: controller.text.replaceRange(start, end, value),
      selection: TextSelection.collapsed(offset: start + value.length),
    );
    widget.onChanged(controller.text);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 4,
        children:
            <String, String>{
                  'Fracción': r'\frac{a}{b}',
                  'Potencia': r'x^{2}',
                  'Raíz': r'\sqrt{x}',
                  'Subíndice': r'x_{1}',
                  'π': r'\pi',
                  '±': r'\pm',
                  '≤': r'\leq',
                  '×': r'\times',
                  'Ecuación': r'ax^{2}+bx+c=0',
                  'Sistema': r'\begin{cases}x+y=3\\x-y=1\end{cases}',
                }.entries
                .map(
                  (e) => TextButton(
                    onPressed: () => insert(e.value),
                    child: Text(e.key),
                  ),
                )
                .toList(),
      ),
      TextField(
        controller: controller,
        maxLines: null,
        decoration: const InputDecoration(
          labelText: 'Fórmula LaTeX',
          border: OutlineInputBorder(),
        ),
        onChanged: widget.onChanged,
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: formulaPreview(controller.text),
      ),
    ],
  );
}
