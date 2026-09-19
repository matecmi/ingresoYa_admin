import 'package:flutter/material.dart';
import '../../../../data/repo/question_repo.dart';
import '../../../../domain/editor_document.dart';
import '../../../widgets/content_editor/content_editor.dart';
import '../../../widgets/content_editor/content_preview.dart';

class ExplanationPanel extends StatefulWidget {
  const ExplanationPanel({
    super.key,
    required this.repo,
    required this.questionId,
  });
  final QuestionRepo repo;
  final String questionId;
  @override
  State<ExplanationPanel> createState() => _ExplanationPanelState();
}

class _ExplanationPanelState extends State<ExplanationPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  EditorDocument? document;
  String? error;
  bool busy = false;
  bool dirty = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.repo.readExplanation(widget.questionId);
      if (mounted) setState(() => document = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo leer la explicación. Comprueba la conexión y los permisos.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repo.saveExplanation(widget.questionId, document!);
      if (mounted) setState(() => dirty = false);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'No se pudo guardar. El contenido sigue aquí; vuelve a intentarlo.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Explicación de la respuesta',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Contenido editorial privado. No se incluye en el enunciado público.',
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (document == null && !busy)
          TextButton(onPressed: load, child: const Text('Volver a cargar')),
        if (document != null) ...[
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        final result = await editContent(
                          context,
                          initial: document!,
                          title: 'Explicación',
                        );
                        if (mounted && result != null) {
                          setState(() {
                            document = result;
                            dirty = true;
                          });
                        }
                      },
                child: const Text('Editar explicación'),
              ),
              FilledButton(
                onPressed: busy || !dirty ? null : save,
                child: const Text('Guardar explicación'),
              ),
            ],
          ),
          if (dirty) const Text('Cambios sin guardar'),
          ContentPreview(document: document!),
        ],
      ],
    );
  }
}
