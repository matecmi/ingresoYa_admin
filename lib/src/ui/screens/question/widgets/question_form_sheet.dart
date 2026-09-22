import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'question_catalog_fields.dart';
import '../../../../domain/entities/admission_exam.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:ingresoya_admin/src/domain/entities/question_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

// ✅ ajusta a tu ruta real
import 'package:ingresoya_admin/src/ui/widgets/content_editor/content_editor.dart';
import 'package:ingresoya_admin/src/ui/widgets/content_editor/content_preview.dart';
import 'package:ingresoya_admin/src/domain/editor_document.dart';
import 'package:ingresoya_admin/shared/question_contract/question_contract.dart';

class QuestionFormSheet extends ConsumerStatefulWidget {
  const QuestionFormSheet({super.key, this.question});
  final QuestionEntity? question;

  @override
  ConsumerState<QuestionFormSheet> createState() => _QuestionFormSheetState();
}

class _QuestionFormSheetState extends ConsumerState<QuestionFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController numberCtrl;
  late final TextEditingController originalNumberCtrl;
  late final TextEditingController courseId;
  late final TextEditingController courseName;
  late final TextEditingController topicId;
  late final TextEditingController topicName;
  late final TextEditingController subtopicId;
  late final TextEditingController subtopicName;
  late final TextEditingController examId;
  late final TextEditingController label;

  String statementRaw = '';
  late EditorDocument content;
  bool saving = false;
  AdmissionExam? admissionExam;
  bool originChanged = false;
  bool active = true;
  late final List<String> partIds;
  late final Map<String, String> partNames;
  late List<_AlternativeDraft> alternatives;
  late EditorDocument explanation;
  String? correctAlternativeId;
  String difficulty = 'unknown';
  String editorialStatus = 'draft';
  bool loadingEditorial = false;

  static const _minimumAlternatives = 2;

  @override
  void initState() {
    final q = widget.question;
    admissionExam = q?.admissionExam;

    numberCtrl = TextEditingController(text: (q?.number ?? 1).toString());
    originalNumberCtrl = TextEditingController(
      text: q?.originalNumber?.toString() ?? '',
    );
    courseId = TextEditingController(text: q?.courseId ?? '');
    courseName = TextEditingController(text: q?.courseName ?? '');
    topicId = TextEditingController(text: q?.topicId ?? '');
    topicName = TextEditingController(text: q?.topicName ?? '');
    subtopicId = TextEditingController(text: q?.subtopicId ?? '');
    subtopicName = TextEditingController(text: q?.subtopicName ?? '');
    partIds = List<String>.from(q?.partIds ?? const []);
    partNames = Map<String, String>.from(q?.partNames ?? const {});
    examId = TextEditingController(text: q?.examId ?? '');
    label = TextEditingController(text: q?.label ?? '');

    statementRaw = q?.statementText ?? '';
    content = q?.editorContent ?? EditorDocument.read({}, statementRaw);
    active = q?.isActive ?? true;
    difficulty = ['unknown', 'easy', 'medium', 'hard'].contains(q?.difficulty)
        ? q!.difficulty
        : 'unknown';
    editorialStatus = q?.editorialStatus ?? 'draft';
    alternatives = List.generate(
      _minimumAlternatives,
      (_) => _AlternativeDraft.empty(),
    );
    explanation = EditorDocument.read({}, '');
    if (q != null) _loadEditorialData(q);

    super.initState();
  }

  @override
  void dispose() {
    numberCtrl.dispose();
    originalNumberCtrl.dispose();
    courseId.dispose();
    courseName.dispose();
    topicId.dispose();
    topicName.dispose();
    subtopicId.dispose();
    subtopicName.dispose();
    examId.dispose();
    label.dispose();
    super.dispose();
  }

  Future<void> _loadEditorialData(QuestionEntity question) async {
    setState(() => loadingEditorial = true);
    try {
      final publicRepo = ref.read(publishableQuestionRepoProvider);
      final current = await publicRepo.readQuestionDocument(question.id);
      if (current != null) {
        final answer = await publicRepo.readAnswerKey(
          question.id,
          current.ref.version,
        );
        if (!mounted) return;
        setState(() {
          editorialStatus = current.status;
          difficulty = current.difficulty;
          alternatives = current.alternatives
              .map(_AlternativeDraft.fromContract)
              .toList();
          correctAlternativeId = answer?.correctAlternativeId;
          explanation = answer == null
              ? EditorDocument.read({}, '')
              : EditorDocument(answer.explanation);
        });
        return;
      }
      final legacyAlternatives = await ref
          .read(questionRepoProvider)
          .watchAlternatives(question.id)
          .first;
      final legacyExplanation = await ref
          .read(questionRepoProvider)
          .readExplanation(question.id);
      if (!mounted) return;
      setState(() {
        alternatives = legacyAlternatives
            .map(
              (alternative) => _AlternativeDraft(
                id: alternative.id,
                content:
                    alternative.editorContent ??
                    EditorDocument.read({}, alternative.descriptionText),
              ),
            )
            .toList();
        while (alternatives.length < _minimumAlternatives) {
          alternatives.add(_AlternativeDraft.empty());
        }
        correctAlternativeId = legacyAlternatives
            .where((alternative) => alternative.correct)
            .map((alternative) => alternative.id)
            .firstOrNull;
        explanation = legacyExplanation;
      });
    } finally {
      if (mounted) setState(() => loadingEditorial = false);
    }
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
                _row2(
                  _tf(
                    originalNumberCtrl,
                    'Número original',
                    keyboardType: TextInputType.number,
                  ),
                  _difficultySelect(),
                ),
                _editorialStatusCard(),

                QuestionCatalogFields(
                  courseId: courseId,
                  courseName: courseName,
                  topicId: topicId,
                  topicName: topicName,
                  subtopicId: subtopicId,
                  subtopicName: subtopicName,
                  partIds: partIds,
                  partNames: partNames,
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
                _sectionTitle('Alternativas'),
                const SizedBox(height: 8),
                _alternativesEditor(),
                const SizedBox(height: 16),
                _sectionTitle('Explicación privada'),
                const SizedBox(height: 8),
                _explanationEditor(),
                const SizedBox(height: 16),
                _sectionTitle('Vista previa'),
                const SizedBox(height: 8),
                _fullPreview(),
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

  Widget _difficultySelect() => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: DropdownButtonFormField<String>(
      initialValue: difficulty,
      decoration: const InputDecoration(
        labelText: 'Dificultad',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'unknown', child: Text('Pendiente')),
        DropdownMenuItem(value: 'easy', child: Text('Fácil')),
        DropdownMenuItem(value: 'medium', child: Text('Media')),
        DropdownMenuItem(value: 'hard', child: Text('Difícil')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => difficulty = value);
      },
    ),
  );

  Widget _editorialStatusCard() => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: AppTheme.cardDeco(
      radius: 16,
      color: Colors.white.withValues(alpha: .03),
    ),
    child: Row(
      children: [
        const Icon(Icons.edit_note_rounded),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Estado editorial: ${_statusLabel(editorialStatus)} · v${widget.question?.version ?? 1}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

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

  Widget _alternativesEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (loadingEditorial) const LinearProgressIndicator(),
      RadioGroup<String>(
        groupValue: correctAlternativeId,
        onChanged: (id) => setState(() => correctAlternativeId = id),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: alternatives.length,
          onReorder: (oldIndex, newIndex) => setState(() {
            if (newIndex > oldIndex) newIndex -= 1;
            final item = alternatives.removeAt(oldIndex);
            alternatives.insert(newIndex, item);
          }),
          itemBuilder: (context, index) {
            final alternative = alternatives[index];
            final label = _alternativeLabel(index);
            return Container(
              key: ValueKey(alternative.id),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardDeco(
                radius: 16,
                color: Colors.white.withValues(alpha: .03),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Icon(Icons.drag_handle_rounded),
                    ),
                  ),
                  Radio<String>(value: alternative.id),
                  Expanded(
                    child: InkWell(
                      onTap: () => _editAlternative(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$label. ${alternative.content.hasContent ? 'Editar contenido' : 'Agregar contenido'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            alternative.content.hasContent
                                ? ContentPreview(document: alternative.content)
                                : Text(
                                    'Usa el editor visual para definir la alternativa.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: .65,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Eliminar alternativa',
                    onPressed: alternatives.length <= _minimumAlternatives
                        ? null
                        : () => setState(() {
                            final removed = alternatives.removeAt(index);
                            if (correctAlternativeId == removed.id) {
                              correctAlternativeId = null;
                            }
                          }),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      OutlinedButton.icon(
        onPressed: () =>
            setState(() => alternatives.add(_AlternativeDraft.empty())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar alternativa'),
      ),
      const SizedBox(height: 4),
      Text(
        'Mínimo $_minimumAlternatives. Arrastra para reordenar; el ID interno no cambia.',
        style: TextStyle(color: Colors.white.withValues(alpha: .65)),
      ),
    ],
  );

  Future<void> _editAlternative(int index) async {
    final result = await editContent(
      context,
      initial: alternatives[index].content,
      title: 'Alternativa ${_alternativeLabel(index)}',
    );
    if (result != null && mounted) {
      setState(
        () => alternatives[index] = alternatives[index].copyWith(result),
      );
    }
  }

  Widget _explanationEditor() => Container(
    padding: const EdgeInsets.all(12),
    decoration: AppTheme.cardDeco(
      radius: 16,
      color: Colors.white.withValues(alpha: .03),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Solo se almacena en la clave privada; la app móvil no puede leerla antes de entregar.',
          style: TextStyle(color: Colors.white.withValues(alpha: .68)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final result = await editContent(
              context,
              initial: explanation,
              title: 'Explicación',
            );
            if (result != null && mounted) setState(() => explanation = result);
          },
          icon: const Icon(Icons.edit_rounded),
          label: Text(
            explanation.hasContent
                ? 'Editar explicación'
                : 'Agregar explicación',
          ),
        ),
        if (explanation.hasContent) ...[
          const SizedBox(height: 8),
          ContentPreview(document: explanation),
        ],
      ],
    ),
  );

  Widget _fullPreview() => Container(
    padding: const EdgeInsets.all(12),
    decoration: AppTheme.cardDeco(
      radius: 16,
      color: Colors.white.withValues(alpha: .03),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.text.isEmpty ? 'Procedencia pendiente' : label.text),
        const SizedBox(height: 10),
        ContentPreview(document: content),
        const SizedBox(height: 10),
        for (var index = 0; index < alternatives.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_alternativeLabel(index)}. ',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Expanded(
                  child: alternatives[index].content.hasContent
                      ? ContentPreview(document: alternatives[index].content)
                      : const Text('Sin contenido'),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  String _alternativeLabel(int index) {
    var value = index;
    var label = '';
    do {
      label = String.fromCharCode(65 + value % 26) + label;
      value = value ~/ 26 - 1;
    } while (value >= 0);
    return label;
  }

  String _statusLabel(String status) => switch (status) {
    'published' => 'Publicada',
    'retired' => 'Retirada',
    _ => 'Borrador',
  };

  Widget _primaryActions(bool isEdit) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: saving ? null : () => _save(publish: false),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(
              isEdit ? 'Guardar borrador' : 'Crear borrador',
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
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: saving ? null : () => _save(publish: true),
            icon: const Icon(Icons.publish_rounded, size: 18),
            label: const Text(
              'Publicar',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
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

  Future<void> _save({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;

    if (courseId.text.isEmpty ||
        topicId.text.isEmpty ||
        subtopicId.text.isEmpty ||
        partIds.isEmpty ||
        (admissionExam == null && (widget.question == null || originChanged))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selecciona curso, tema, subtema, al menos una parte y el examen de origen.',
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
    final publicRepo = ref.read(publishableQuestionRepoProvider);

    final number = int.tryParse(numberCtrl.text.trim()) ?? 0;
    if (number <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Número debe ser > 0')));
      return;
    }
    final originalNumber = originalNumberCtrl.text.trim().isEmpty
        ? null
        : int.tryParse(originalNumberCtrl.text.trim());
    if (originalNumberCtrl.text.trim().isNotEmpty &&
        (originalNumber == null || originalNumber <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número original debe ser > 0')),
      );
      return;
    }
    if (publish &&
        (alternatives.length < _minimumAlternatives ||
            alternatives.any(
              (alternative) => !alternative.content.hasContent,
            ) ||
            correctAlternativeId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Para publicar completa al menos dos alternativas y marca una correcta.',
          ),
        ),
      );
      return;
    }

    final act = active ? 'Y' : 'N';
    setState(() => saving = true);
    try {
      var questionId = widget.question?.id;
      var version = widget.question?.version ?? 1;
      if (widget.question?.editorialStatus == 'published') {
        version = (await publicRepo.forkPublishedForEdit(questionId!)).version;
      }
      if (widget.question == null) {
        questionId = await repo.createQuestion(
          editorContent: content,
          admissionExam: admissionExam,
          number: number,
          statementText: statementRaw,
          active: act,
          topicId: topicId.text.trim(),
          topicName: topicName.text.trim(),
          subtopicId: subtopicId.text.trim(),
          subtopicName: subtopicName.text.trim(),
          partIds: List<String>.from(partIds),
          partNames: Map<String, String>.from(partNames),
          difficulty: difficulty,
          originalNumber: originalNumber,
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
            'subtopicId': subtopicId.text.trim(),
            'subtopicName': subtopicName.text.trim(),
            'partIds': List<String>.from(partIds),
            'partNames': Map<String, String>.from(partNames),
            'difficulty': difficulty,
            'originalNumber': originalNumber ?? FieldValue.delete(),
            'courseId': courseId.text.trim(),
            'courseName': courseName.text.trim(),
            'examId': examId.text.trim(),
            'label': label.text.trim(),
            if (admissionExam != null) ...admissionExam!.questionFields,
          },
        );
      }

      final resolvedQuestionId = questionId!;

      final contractAlternatives = [
        for (var index = 0; index < alternatives.length; index++)
          QuestionAlternative.fromJson({
            'id': alternatives[index].id,
            'label': _alternativeLabel(index),
            'content': alternatives[index].content.content.toJson(),
          }),
      ];
      final source = admissionExam?.source;
      final draft = QuestionDocument.fromJson({
        'schemaVersion': 2,
        'questionId': resolvedQuestionId,
        'version': version,
        'status': 'draft',
        'sourceType': source?.examType ?? 'unknown',
        if (source != null) 'sourceExam': source.toJson(),
        if (originalNumber != null) 'originalNumber': originalNumber,
        'courseId': courseId.text.trim(),
        'topicId': topicId.text.trim(),
        'subtopicId': subtopicId.text.trim(),
        'partIds': partIds,
        'difficulty': difficulty,
        'content': content.content.toJson(),
        'alternatives': contractAlternatives
            .map((alternative) => alternative.toJson())
            .toList(),
      });
      final answerKey = correctAlternativeId == null
          ? null
          : QuestionAnswerKey.fromJson({
              'schemaVersion': 2,
              'questionId': resolvedQuestionId,
              'version': version,
              'correctAlternativeId': correctAlternativeId,
              'explanation': explanation.content.toJson(),
            });
      await publicRepo.saveDraft(draft, answerKey: answerKey);
      await repo.mirrorV2Alternatives(
        questionId: resolvedQuestionId,
        alternatives: contractAlternatives,
        correctAlternativeId: correctAlternativeId,
      );
      if (explanation.hasContent) {
        await repo.saveExplanation(resolvedQuestionId, explanation);
      }
      if (publish) await publicRepo.publishDraft(resolvedQuestionId);

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

class _AlternativeDraft {
  _AlternativeDraft({required this.id, required this.content});

  factory _AlternativeDraft.empty() => _AlternativeDraft(
    id: const Uuid().v4(),
    content: EditorDocument.read({}, ''),
  );

  factory _AlternativeDraft.fromContract(QuestionAlternative alternative) =>
      _AlternativeDraft(
        id: alternative.id,
        content: EditorDocument(alternative.content),
      );

  final String id;
  final EditorDocument content;

  _AlternativeDraft copyWith(EditorDocument next) =>
      _AlternativeDraft(id: id, content: next);
}
