import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/entities/subtopic_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/course/widgets/course_entity_form_sheet.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'package:ingresoya_admin/src/ui/widgets/content_builder_sheet.dart';
import 'package:ingresoya_admin/src/ui/widgets/dialog_tf.dart';
import 'package:ingresoya_admin/src/ui/widgets/exam_question.dart';
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
  late String _contentRaw;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.part?.name ?? '');
    _orderCtrl = TextEditingController(text: widget.part?.order ?? '1');
    _videoCtrl = TextEditingController(text: widget.part?.linkVideo ?? '');
    _pdfCtrl = TextEditingController(text: widget.part?.linkPdf ?? '');
    _contentRaw = widget.part?.content ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orderCtrl.dispose();
    _videoCtrl.dispose();
    _pdfCtrl.dispose();
    super.dispose();
  }

  String _shortRawPreview(String raw, {int maxChars = 220}) {
    final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxChars) return compact;
    return '${compact.substring(0, maxChars).trim()}…';
  }

  Future<void> _openContentBuilder() async {
    final content = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ContentBuilderSheet(initialRaw: _contentRaw),
    );
    if (content == null || !mounted) return;

    setState(() => _contentRaw = content);
    HapticFeedback.selectionClick();
  }

  Future<void> _copyContent() async {
    if (_contentRaw.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _contentRaw));
    HapticFeedback.selectionClick();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Raw copiado ✅')));
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
    if (_contentRaw.trim().isEmpty) {
      _showMessage('Define el contenido con el Constructor');
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
        content: _contentRaw.trim(),
        order: order.toString(),
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
      HapticFeedback.selectionClick();
      closed = true;
      Navigator.of(context, rootNavigator: true).pop();
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (!closed && mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

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
          DialogTF(ctrl: _nameCtrl, label: 'Nombre *'),
          DialogTF(ctrl: _orderCtrl, label: 'Orden *', keyboardType: TextInputType.number),
          DialogTF(ctrl: _videoCtrl, label: 'Link video'),
          DialogTF(ctrl: _pdfCtrl, label: 'Link PDF'),
          const SizedBox(height: 10),
          _ContentCard(
            contentRaw: _contentRaw,
            preview: _shortRawPreview(_contentRaw),
            onCopy: _contentRaw.trim().isEmpty ? null : _copyContent,
            onBuild: _openContentBuilder,
          ),
          if (_contentRaw.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.03),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vista previa', style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  ExamQuestion(raw: _contentRaw, useCard: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({
    required this.contentRaw,
    required this.preview,
    required this.onCopy,
    required this.onBuild,
  });

  final String contentRaw;
  final String preview;
  final VoidCallback? onCopy;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Contenido (raw)',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.92),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _IconAction(
                tooltip: 'Copiar raw',
                icon: Icons.copy_rounded,
                onTap: onCopy,
              ),
              const SizedBox(width: 8),
              _IconAction(
                tooltip: 'Constructor',
                icon: Icons.build_circle_rounded,
                onTap: onBuild,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            contentRaw.trim().isEmpty
                ? 'Aún no definiste el contenido. Usa el Constructor.'
                : preview,
            style: TextStyle(
              color: Colors.white.withOpacity(.75),
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .35 : 1,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(.10)),
              ),
              child: Icon(icon, color: Colors.white.withOpacity(.90), size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
