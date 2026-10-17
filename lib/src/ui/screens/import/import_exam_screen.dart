import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/question_contract/question_contract.dart';
import '../../../data/repo/quick_question_saver.dart';
import '../../../domain/entities/admission_exam.dart';
import '../../../domain/entities/question_entity.dart';
import '../../../domain/entities/university_entities.dart';
import '../../../domain/exam_import_parser.dart';
import '../../../domain/plain_text.dart';
import '../../../domain/quick_question_parser.dart';
import '../../../domain/staff.dart';
import '../../../domain/subtopic_classifier.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';

final _universitiesProvider =
    StreamProvider.autoDispose<List<UniversityEntity>>(
      (ref) => ref.watch(universityRepoProvider).watchUniversities(),
    );
final _examsProvider = StreamProvider.autoDispose
    .family<List<AdmissionExam>, String>(
      (ref, uni) => ref.watch(admissionExamRepoProvider).watch(uni),
    );
final _allQuestionsProvider = StreamProvider.autoDispose<List<QuestionEntity>>(
  (ref) => ref.watch(questionRepoProvider).watchQuestions(),
);

const _difficulties = {'easy': 'Fácil', 'medium': 'Media', 'hard': 'Difícil'};

/// Asistente para importar un examen pasado completo (tablero 9).
class ImportExamScreen extends ConsumerStatefulWidget {
  const ImportExamScreen({super.key, this.universityId, this.examId});

  final String? universityId;
  final String? examId;

  @override
  ConsumerState<ImportExamScreen> createState() => _ImportExamScreenState();
}

class _ImportExamScreenState extends ConsumerState<ImportExamScreen> {
  int _step = 0;
  late String? _uni = widget.universityId;
  late String? _examId = widget.examId;
  final _text = TextEditingController();
  ImportResult? _result;
  List<ImportedQuestion> _items = [];
  final _accepted = <int>{};
  final _explanations = <int, String>{};
  final _targets = <int, ClassTarget>{};
  String _difficulty = 'medium';
  bool _onlyReview = false;
  bool _working = false;
  int _done = 0;
  String? _summary;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  AdmissionExam? _exam(List<AdmissionExam> exams) =>
      exams.where((e) => e.id == _examId).firstOrNull;

  List<String> _openIssues(ImportedQuestion q) => [
    for (final i in q.issues)
      if (!_accepted.contains(q.number) || i.startsWith('Falta la clave')) i,
  ];

  void _read() {
    final r = parseExam(_text.text);
    setState(() {
      _result = r;
      _items = r.questions;
      _accepted.clear();
      _step = 2;
    });
  }

  void _classify(SubtopicClassifier classifier) {
    for (final q in _items) {
      _targets.putIfAbsent(q.number, () {
        final s = classifier.suggest(
          '${q.parsed.statement} ${q.parsed.alternatives.join(' ')}',
        );
        return s ??
            const ClassTarget(
              courseId: '',
              courseName: '',
              topicId: '',
              topicName: '',
              subtopicId: '',
              subtopicName: '',
              partId: '',
              partName: '',
            );
      });
    }
  }

  Future<void> _publish(AdmissionExam exam, bool canPublish) async {
    setState(() {
      _working = true;
      _done = 0;
      _summary = null;
    });
    final saver = QuickQuestionSaver(
      ref.read(questionRepoProvider),
      ref.read(publishableQuestionRepoProvider),
    );
    final publicRepo = ref.read(publishableQuestionRepoProvider);
    final session = ref.read(adminSessionProvider);
    var created = 0, published = 0, drafts = 0, failed = 0;
    for (final q in _items) {
      final target = _targets[q.number];
      try {
        final ids = [for (final _ in q.parsed.alternatives) const Uuid().v4()];
        final explanation = (_explanations[q.number] ?? q.parsed.explanation)
            .trim();
        final id = await saver.saveNew(
          target: QuickQuestionTarget(
            courseId: target?.courseId ?? '',
            courseName: target?.courseName ?? '',
            topicId: target?.topicId ?? '',
            topicName: target?.topicName ?? '',
            subtopicId: target?.subtopicId ?? '',
            subtopicName: target?.subtopicName ?? '',
            partId: target?.partId ?? '',
            partName: target?.partName ?? '',
            difficulty: _difficulty,
          ),
          statement: contentFromPlainText(q.parsed.statement, 'st'),
          alternatives: [
            for (var i = 0; i < q.parsed.alternatives.length; i++)
              QuestionAlternative.fromJson({
                'id': ids[i],
                'label': alternativeLabel(i),
                'content': contentFromPlainText(
                  q.parsed.alternatives[i],
                  'a$i',
                ).toJson(),
              }),
          ],
          correctAlternativeId: q.parsed.correctIndex == null
              ? null
              : ids[q.parsed.correctIndex!],
          explanation: contentFromPlainText(explanation, 'ex'),
          exam: exam,
          originalNumber: q.number,
        );
        created++;
        final ready =
            q.parsed.correctIndex != null &&
            explanation.isNotEmpty &&
            (target?.partId.isNotEmpty ?? false);
        if (ready) {
          try {
            if (canPublish) {
              await publicRepo.publishDraft(id);
            } else {
              await ref
                  .read(questionRepoProvider)
                  .requestReview(id, uid: session.uid, email: session.email);
            }
            published++;
          } catch (_) {
            drafts++;
          }
        } else {
          drafts++;
        }
      } catch (_) {
        failed++;
      }
      if (mounted) setState(() => _done++);
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _summary =
          'Se crearon $created pregunta(s): $published '
          '${canPublish ? 'publicadas' : 'enviadas a revisión'}, $drafts en '
          'borrador (les falta clave, explicación o parte)'
          '${failed > 0 ? ' y $failed no se pudieron guardar' : ''}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(effectiveSessionProvider);
    final canEdit = session.can(StaffSection.questions, StaffAction.edit);
    final canPublish = session.can(StaffSection.questions, StaffAction.publish);
    if (!canEdit) {
      return const Center(
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Tu perfil no puede cargar preguntas',
        ),
      );
    }
    final universities = ref.watch(_universitiesProvider).value ?? const [];
    final exams = _uni == null
        ? const <AdmissionExam>[]
        : ref.watch(_examsProvider(_uni!)).value ?? const [];
    final exam = _exam(exams);
    final result = _result;

    final steps = [
      'Elegir examen',
      'Pegar',
      'Revisar',
      'Clasificar',
      'Publicar',
    ];
    final header = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/universities'),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Salir'),
          ),
          Text(
            exam == null
                ? 'Importar examen pasado'
                : 'Importar · ${exam.label}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          for (final (i, s) in steps.indexed)
            StatusPill(
              '${i + 1} · $s',
              tone: i == _step
                  ? Tone.brand
                  : (i < _step ? Tone.success : Tone.neutral),
              icon: i < _step ? Icons.check_rounded : null,
            ),
        ],
      ),
    );

    Widget body;
    switch (_step) {
      case 0:
        body = SectionCard(
          title: '¿De qué examen son las preguntas?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _uni,
                decoration: const InputDecoration(labelText: 'Universidad'),
                items: [
                  for (final u in universities)
                    DropdownMenuItem(
                      value: u.id,
                      child: Text('${u.acronym} · ${u.name}'),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _uni = v;
                  _examId = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _examId,
                decoration: const InputDecoration(labelText: 'Examen'),
                items: [
                  for (final e in exams)
                    DropdownMenuItem(value: e.id, child: Text(e.name)),
                ],
                onChanged: (v) => setState(() => _examId = v),
              ),
              const SizedBox(height: 8),
              const Text(
                'Si el examen no existe, créalo primero en Universidades → '
                'Exámenes de origen.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: exam == null
                      ? null
                      : () => setState(() => _step = 1),
                  child: const Text('Siguiente: pegar el examen →'),
                ),
              ),
            ],
          ),
        );
      case 1:
        body = SectionCard(
          title: 'Pega el texto del examen',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Copia todo el texto del PDF (Ctrl+A, Ctrl+C) y pégalo aquí. '
                'Reconocemos las preguntas numeradas (25. …), sus alternativas '
                'y, si viene al final, la tabla de claves (CLAVES: 25. C 26. B …).',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                minLines: 14,
                maxLines: 24,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  hintText:
                      '25. Halle el valor de x si 3x − 7 = 11\n'
                      'A) 4   B) 5   C) 6   D) 7   E) 8\n…\n\nCLAVES\n25. C …',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => _read(),
                  child: const Text('Leer el examen →'),
                ),
              ),
            ],
          ),
        );
      case 2:
        final review = _items.where((q) => _openIssues(q).isNotEmpty).toList();
        final shown = _onlyReview ? review : _items;
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoNote(
              result == null || result.questions.isEmpty
                  ? 'No encontramos preguntas numeradas. Revisa que cada una '
                        'empiece con su número (25. …).'
                  : '${result.questions.length} preguntas detectadas '
                        '(n.º ${result.questions.first.number} a ${result.questions.last.number}) · '
                        '${_items.length - review.length} listas · '
                        '${review.length} por revisar · Clave encontrada al '
                        'final del documento: ${result.keyFound ? 'sí' : 'no'}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => _step = 1),
                  child: const Text('← Volver a pegar'),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => setState(() => _onlyReview = !_onlyReview),
                  child: Text(
                    _onlyReview
                        ? 'Ver todas'
                        : 'Ver solo las ${review.length} por revisar',
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _items.isEmpty
                      ? null
                      : () => setState(() => _step = 3),
                  child: const Text('Siguiente: clasificar →'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final q in shown) ...[
              _ReviewCard(
                question: q,
                issues: _openIssues(q),
                explanation: _explanations[q.number] ?? q.parsed.explanation,
                onCorrect: (i) => setState(() {
                  final idx = _items.indexOf(q);
                  _items[idx] = q.withCorrect(i);
                }),
                onAccept: () => setState(() => _accepted.add(q.number)),
                onExplanation: (v) => _explanations[q.number] = v,
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      case 3:
        final all = ref.watch(_allQuestionsProvider).value;
        if (all == null) {
          body = const Center(child: CircularProgressIndicator());
          break;
        }
        final examples = <(ClassTarget, String)>[
          for (final q in all)
            if (q.subtopicId.isNotEmpty && q.partIds.isNotEmpty)
              (
                ClassTarget(
                  courseId: q.courseId,
                  courseName: q.courseName,
                  topicId: q.topicId,
                  topicName: q.topicName,
                  subtopicId: q.subtopicId,
                  subtopicName: q.subtopicName,
                  partId: q.partIds.first,
                  partName: q.partNames[q.partIds.first] ?? '',
                ),
                plainStatement(q.statementText),
              ),
        ];
        final classifier = SubtopicClassifier(examples);
        _classify(classifier);
        final options = {
          for (final (t, _) in examples) t.key: t,
        }.values.toList()..sort((a, b) => a.label.compareTo(b.label));
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InfoNote(
              'Sugerimos curso, subtema y parte comparando cada pregunta con '
              'las que ya están clasificadas. Revisa y cambia lo que haga '
              'falta.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Dificultad de estas preguntas:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final e in _difficulties.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _difficulty == e.key,
                    onSelected: (_) => setState(() => _difficulty = e.key),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _step = 2),
                  child: const Text('← Revisar'),
                ),
                FilledButton(
                  onPressed: () => setState(() => _step = 4),
                  child: const Text('Siguiente: publicar →'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SectionCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  for (final q in _items)
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFFF0F2F5)),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: Text(
                              'N.º ${q.number}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              q.parsed.statement,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 380,
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value:
                                  (_targets[q.number]?.partId.isEmpty ?? true)
                                  ? null
                                  : _targets[q.number]!.key,
                              hint: const Text(
                                'Sin clasificar',
                                style: TextStyle(color: AppTheme.warn),
                              ),
                              underline: const SizedBox(),
                              items: [
                                for (final t in options)
                                  DropdownMenuItem(
                                    value: t.key,
                                    child: Text(
                                      t.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (k) => setState(
                                () => _targets[q.number] = options.firstWhere(
                                  (t) => t.key == k,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      default:
        final ready = _items.where(
          (q) =>
              q.parsed.correctIndex != null &&
              (_explanations[q.number] ?? q.parsed.explanation)
                  .trim()
                  .isNotEmpty &&
              (_targets[q.number]?.partId.isNotEmpty ?? false),
        );
        body = SectionCard(
          title: 'Publicar',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${_items.length} preguntas del ${exam?.label ?? 'examen'}. '
                '${ready.length} tienen clave, explicación y parte: se '
                '${canPublish ? 'publican' : 'envían a revisión'}. Las demás '
                'quedan en borrador para completarlas en el Banco.',
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 12),
              if (_working)
                LinearProgressIndicator(
                  value: _items.isEmpty ? 0 : _done / _items.length,
                ),
              if (_summary != null) InfoNote(_summary!, tone: Tone.success),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: _working
                        ? null
                        : () => setState(() => _step = 3),
                    child: const Text('← Clasificar'),
                  ),
                  const Spacer(),
                  if (_summary == null)
                    FilledButton(
                      onPressed: _working || exam == null
                          ? null
                          : () => _publish(exam, canPublish),
                      child: Text(
                        _working
                            ? 'Guardando $_done de ${_items.length}…'
                            : 'Crear las ${_items.length} preguntas',
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: () => context.go('/questions'),
                      child: const Text('Ir al Banco de preguntas'),
                    ),
                ],
              ),
            ],
          ),
        );
    }

    return Column(
      children: [
        header,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
            children: [body],
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.question,
    required this.issues,
    required this.explanation,
    required this.onCorrect,
    required this.onAccept,
    required this.onExplanation,
  });

  final ImportedQuestion question;
  final List<String> issues;
  final String explanation;
  final ValueChanged<int> onCorrect;
  final VoidCallback onAccept;
  final ValueChanged<String> onExplanation;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final review = issues.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDeco(
        borderColor: review ? AppTheme.warnLine : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'N.º ${q.number} · ${q.parsed.statement}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              StatusPill(
                review ? 'Por revisar' : 'Lista',
                tone: review ? Tone.warn : Tone.success,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < q.parsed.alternatives.length; i++)
                ChoiceChip(
                  label: Text(
                    '${alternativeLabel(i)}) ${q.parsed.alternatives[i]}',
                  ),
                  selected: q.parsed.correctIndex == i,
                  selectedColor: AppTheme.successSoft,
                  onSelected: (_) => onCorrect(i),
                ),
            ],
          ),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final i in issues)
              Text(
                '• $i',
                style: const TextStyle(color: Color(0xFF7A2E0E), fontSize: 13),
              ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            initialValue: explanation,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Explicación (hace falta para publicar)',
            ),
            onChanged: onExplanation,
          ),
          if (issues.any((i) => !i.startsWith('Falta la clave')))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onAccept,
                child: const Text('Así está bien'),
              ),
            ),
        ],
      ),
    );
  }
}
