import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:uuid/uuid.dart';


class PartFormSheet extends ConsumerStatefulWidget {
  final String courseId;
  final String topicId;
  final String subtopicId;

  final SubtopicPartEntity? part;

  const PartFormSheet({
    super.key,
    required this.courseId,
    required this.topicId,
    required this.subtopicId,
    this.part,
  });

  @override
  ConsumerState<PartFormSheet> createState() =>
      _PartFormSheetState();
}

class _PartFormSheetState
    extends ConsumerState<PartFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _orderCtrl;
  late final TextEditingController _videoCtrl;
  late final TextEditingController _pdfCtrl;
  late final TextEditingController _contentCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameCtrl = TextEditingController(
      text: widget.part?.name ?? '',
    );

    _orderCtrl = TextEditingController(
      text: widget.part?.order ?? '1',
    );

    _videoCtrl = TextEditingController(
      text: widget.part?.linkVideo ?? '',
    );

    _pdfCtrl = TextEditingController(
      text: widget.part?.linkPdf ?? '',
    );

    _contentCtrl = TextEditingController(
      text: widget.part?.content ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orderCtrl.dispose();
    _videoCtrl.dispose();
    _pdfCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese un nombre'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final part = SubtopicPartEntity(
        id: widget.part?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        idSubtopic: widget.subtopicId,
        idTopic: widget.topicId,
        content: _contentCtrl.text.trim(),
        order: _orderCtrl.text.trim(),
        linkVideo: _videoCtrl.text.trim(),
        linkPdf: _pdfCtrl.text.trim(),
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

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.part != null;

    return Container(
      height: MediaQuery.of(context).size.height * .92,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(
              editing
                  ? 'Editar Parte'
                  : 'Nueva Parte',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _orderCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Orden',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _videoCtrl,
              decoration: const InputDecoration(
                labelText: 'Video URL',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _pdfCtrl,
              decoration: const InputDecoration(
                labelText: 'PDF URL',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _contentCtrl,
              minLines: 10,
              maxLines: 20,
              decoration: const InputDecoration(
                labelText: 'Contenido',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  editing
                      ? 'Actualizar'
                      : 'Guardar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}