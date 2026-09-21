import 'package:flutter/material.dart';
import '../../../../data/repo/question_repo.dart';
import '../../../../domain/editor_document.dart';
import '../../../../domain/entities/alternative_entity.dart';
import '../../../widgets/content_editor/content_editor.dart';
import '../../../widgets/content_editor/content_preview.dart';

class AlternativeFormDialog extends StatefulWidget {
  const AlternativeFormDialog({
    super.key,
    required this.repo,
    required this.questionId,
    this.editing,
  });
  final QuestionRepo repo;
  final String questionId;
  final AlternativeEntity? editing;
  @override
  State<AlternativeFormDialog> createState() => _AlternativeFormDialogState();
}

class _AlternativeFormDialogState extends State<AlternativeFormDialog> {
  late final value = TextEditingController(text: widget.editing?.value ?? 'A');
  late EditorDocument document =
      widget.editing?.editorContent ??
      EditorDocument.read({}, widget.editing?.descriptionText ?? '');
  late bool correct = widget.editing?.correct ?? false;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (value.text.trim().isEmpty || !document.hasContent) {
      setState(
        () => error = 'Indica la letra y el contenido de la alternativa.',
      );
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repo.upsertAlternative(
        questionId: widget.questionId,
        alternativeId: widget.editing?.id,
        value: value.text.trim(),
        descriptionText: document.legacy,
        editorContent: document,
        isCorrect: correct ? 'Y' : 'N',
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo guardar. Conservamos tus cambios para volver a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.editing == null ? 'Nueva alternativa' : 'Editar alternativa',
    ),
    content: SizedBox(
      width: 620,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: value,
              decoration: const InputDecoration(labelText: 'Letra (A, B, C…)'),
            ),
            OutlinedButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      final result = await editContent(
                        context,
                        initial: document,
                        title: 'Contenido de la alternativa',
                      );
                      if (mounted && result != null) {
                        setState(() => document = result);
                      }
                    },
              icon: const Icon(Icons.edit),
              label: const Text('Editar contenido'),
            ),
            ContentPreview(document: document),
            SwitchListTile(
              title: const Text('Es la respuesta correcta'),
              value: correct,
              onChanged: saving ? null : (v) => setState(() => correct = v),
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
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? 'Guardando…' : 'Guardar'),
      ),
    ],
  );
}
