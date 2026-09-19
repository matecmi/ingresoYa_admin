import 'package:flutter/material.dart';
import 'question_catalog_fields.dart';
import '../../../../domain/entities/admission_exam.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ingresoya_admin/src/domain/entities/question_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

// ✅ ajusta a tu ruta real
import 'package:ingresoya_admin/src/ui/widgets/content_editor/content_editor.dart';
import 'package:ingresoya_admin/src/ui/widgets/content_editor/content_preview.dart';
import 'package:ingresoya_admin/src/domain/editor_document.dart';

class QuestionFormSheet extends ConsumerStatefulWidget {
  const QuestionFormSheet({super.key, this.question});
  final QuestionEntity? question;

  @override
  ConsumerState<QuestionFormSheet> createState() => _QuestionFormSheetState();
}

class _QuestionFormSheetState extends ConsumerState<QuestionFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController numberCtrl;
  late final TextEditingController courseId;
  late final TextEditingController courseName;
  late final TextEditingController topicId;
  late final TextEditingController topicName;
  late final TextEditingController examId;
  late final TextEditingController label;

  String statementRaw = '';
  late EditorDocument content;
  bool saving = false;
  AdmissionExam? admissionExam;
  bool originChanged = false;
  bool active = true;

  @override
  void initState() {
    final q = widget.question;
    admissionExam = q?.admissionExam;

    numberCtrl = TextEditingController(text: (q?.number ?? 1).toString());
    courseId = TextEditingController(text: q?.courseId ?? '');
    courseName = TextEditingController(text: q?.courseName ?? '');
    topicId = TextEditingController(text: q?.topicId ?? '');
    topicName = TextEditingController(text: q?.topicName ?? '');
    examId = TextEditingController(text: q?.examId ?? '');
    label = TextEditingController(text: q?.label ?? '');

    statementRaw = q?.statementText ?? '';
    content = q?.editorContent ?? EditorDocument.read({}, statementRaw);
    active = q?.isActive ?? true;

    super.initState();
  }

  @override
  void dispose() {
    numberCtrl.dispose();
    courseId.dispose();
    courseName.dispose();
    topicId.dispose();
    topicName.dispose();
    examId.dispose();
    label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.question != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .62,
      maxChildSize: .97,
      builder: (context, scroll) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: .08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .26),
                blurRadius: 26,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              physics: const BouncingScrollPhysics(),
              children: [
                _topBar(isEdit),
                const SizedBox(height: 10),

                _sectionTitle('Datos'),
                const SizedBox(height: 10),

                _row2(
                  _tf(
                    numberCtrl,
                    'Número *',
                    keyboardType: TextInputType.number,
                    requiredField: true,
                  ),
                  _activePill(),
                ),

                QuestionCatalogFields(
                  courseId: courseId,
                  courseName: courseName,
                  topicId: topicId,
                  topicName: topicName,
                  examId: examId,
                  label: label,
                  initialExam: widget.question?.admissionExam,
                  allowLegacyOrigin:
                      widget.question != null &&
                      widget.question!.admissionExam == null,
                  onExamChanged: (exam) {
                    admissionExam = exam;
                    originChanged = true;
                  },
                ),

                const SizedBox(height: 12),
                _contentBox(),
                const SizedBox(height: 16),

                _primaryActions(isEdit),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(bool isEdit) {
    return Row(
      children: [
        Expanded(
          child: Text(
            isEdit ? 'Editar pregunta' : 'Nueva pregunta',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .92),
              fontWeight: FontWeight.w900,
              fontSize: 16.5,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.close_rounded,
            color: Colors.white.withValues(alpha: .85),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: TextStyle(
        color: Colors.white.withValues(alpha: .92),
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _tf(
    TextEditingController c,
    String label, {
    bool requiredField = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .92),
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: .70)),
          filled: true,
          fillColor: Colors.white.withValues(alpha: .05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: AppTheme.accent.withValues(alpha: .65),
            ),
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        validator: (v) {
          if (!requiredField) return null;
          if (v == null || v.trim().isEmpty) return 'Requerido';
          return null;
        },
      ),
    );
  }

  Widget _row2(Widget a, Widget b) {
    return Row(
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
  }

  Widget _activePill() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: active
                ? const Color(0xFF22C55E).withValues(alpha: .90)
                : const Color(0xFFEF4444).withValues(alpha: .90),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              active ? 'Activa' : 'Inactiva',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .90),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Switch(
            value: active,
            onChanged: (v) {
              setState(() => active = v);
              HapticFeedback.selectionClick();
            },
            activeThumbColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _contentBox() {
    return Container(
      decoration: AppTheme.cardDeco(
        radius: 20,
        color: Colors.white.withValues(alpha: .03),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Enunciado *',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .92),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _miniIconBtn(
                tooltip: 'Constructor',
                icon: Icons.build_circle_rounded,
                onTap: () async {
                  final res = await editContent(
                    context,
                    initial: content,
                    title: 'Enunciado',
                  );
                  if (res != null && mounted) {
                    setState(() {
                      content = res;
                      statementRaw = res.legacy;
                    });
                    HapticFeedback.selectionClick();
                  }
                },
              ),
              const SizedBox(width: 8),
              _miniIconBtn(
                tooltip: 'Copiar raw',
                icon: Icons.copy_rounded,
                onTap: statementRaw.trim().isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: statementRaw),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Raw copiado ✅')),
                        );
                      },
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (content.content.blocks.isNotEmpty)
            ContentPreview(document: content),
          if (content.content.blocks.isEmpty)
            Text(
              statementRaw.trim().isEmpty
                  ? 'Aún no definiste el enunciado. Usa el Constructor.'
                  : _short(statementRaw),
              style: TextStyle(
                color: Colors.white.withValues(alpha: .72),
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
        ],
      ),
    );
  }

  Widget _primaryActions(bool isEdit) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(
              isEdit ? 'Guardar cambios' : 'Crear pregunta',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniIconBtn({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: onTap == null ? .35 : 1,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: .10)),
              ),
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: .90),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (courseId.text.isEmpty ||
        topicId.text.isEmpty ||
        (admissionExam == null && (widget.question == null || originChanged))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona curso, tema, universidad y examen de admisión.',
          ),
        ),
      );
      return;
    }
    if (!content.hasContent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enunciado es requerido')));
      return;
    }

    final repo = ref.read(questionRepoProvider);

    final number = int.tryParse(numberCtrl.text.trim()) ?? 0;
    if (number <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Número debe ser > 0')));
      return;
    }

    final act = active ? 'Y' : 'N';
    setState(() => saving = true);
    try {
      if (widget.question == null) {
        await repo.createQuestion(
          editorContent: content,
          admissionExam: admissionExam,
          number: number,
          statementText: statementRaw,
          active: act,
          topicId: topicId.text.trim(),
          topicName: topicName.text.trim(),
          courseId: courseId.text.trim(),
          courseName: courseName.text.trim(),
          examId: examId.text.trim(), // puede ser ""
          label: label.text.trim().isEmpty ? null : label.text.trim(),
        );
      } else {
        await repo.updateQuestion(
          widget.question!.id,
          patch: {
            ...content.toFields(),
            'number': number,
            'statementText': statementRaw,
            'active': act,
            'topicId': topicId.text.trim(),
            'topicName': topicName.text.trim(),
            'courseId': courseId.text.trim(),
            'courseName': courseName.text.trim(),
            'examId': examId.text.trim(),
            'label': label.text.trim(),
            if (admissionExam != null) ...admissionExam!.questionFields,
          },
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo guardar. Tus cambios siguen en el formulario; vuelve a intentarlo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _short(String s, {int max = 220}) {
    final x = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (x.length <= max) return x;
    return '${x.substring(0, max).trim()}…';
  }
}
