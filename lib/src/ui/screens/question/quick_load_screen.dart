import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/question_contract/question_contract.dart';
import '../../../app_preview/app_exam_preview.dart';
import '../../../data/repo/quick_question_saver.dart';
import '../../../domain/entities/course_entity.dart';
import '../../../domain/entities/subtopic_entity.dart';
import '../../../domain/entities/topic_entity.dart';
import '../../../domain/plain_text.dart';
import '../../../domain/quick_question_parser.dart';
import '../../../domain/staff.dart';
import '../../../env/app_env.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import 'widgets/question_form_sheet.dart';

final _coursesProvider = StreamProvider.autoDispose<List<CourseEntity>>(
  (ref) => ref.watch(courseRepoProvider).watchCourses(),
);
final _topicsProvider = StreamProvider.autoDispose
    .family<List<TopicEntity>, String>(
      (ref, courseId) => ref.watch(courseRepoProvider).watchTopics(courseId),
    );
final _subtopicsProvider = StreamProvider.autoDispose
    .family<List<SubtopicEntity>, (String, String)>(
      (ref, ids) => ref
          .watch(courseRepoProvider)
          .watchSubtopics(courseId: ids.$1, topicId: ids.$2),
    );

const _difficulties = {
  'easy': 'Fácil',
  'medium': 'Media',
  'hard': 'Difícil',
};

class _Saved {
  const _Saved({
    required this.id,
    required this.statement,
    required this.hasExplanation,
  });

  final String id;
  final String statement;
  final bool hasExplanation;
}

/// Carga rápida de preguntas (tablero 15): pegar, marcar la correcta y seguir.
class QuickLoadScreen extends ConsumerStatefulWidget {
  const QuickLoadScreen({
    super.key,
    this.initialCourseId,
    this.initialTopicId,
    this.initialSubtopicId,
    this.initialPartId,
  });

  /// Abre ya fijada en una parte (desde el editor de parte).
  final String? initialCourseId;
  final String? initialTopicId;
  final String? initialSubtopicId;
  final String? initialPartId;

  @override
  ConsumerState<QuickLoadScreen> createState() => _QuickLoadScreenState();
}

class _QuickLoadScreenState extends ConsumerState<QuickLoadScreen> {
  final _raw = TextEditingController();
  final _explanation = TextEditingController();
  final _rawFocus = FocusNode();

  String _courseId = '';
  String _topicId = '';
  String _subtopicId = '';
  String _partId = '';
  String _difficulty = 'medium';
  CourseEntity? _course;
  TopicEntity? _topic;
  SubtopicEntity? _subtopic;
  SubtopicPartEntity? _part;

  ParsedQuestion _parsed = ParsedQuestion.empty;
  int? _correct;
  bool _correctFromText = false;
  AppExamPlace _place = AppExamPlace.partExam;
  bool _saving = false;
  bool _publishing = false;
  String? _error;
  final _saved = <_Saved>[];

  List<(Set<String>, String)> _existing = const [];
  String? _similar;
  int? _partHave;
  int? _partNeed;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _courseId = widget.initialCourseId ?? '';
    _topicId = widget.initialTopicId ?? '';
    _subtopicId = widget.initialSubtopicId ?? '';
    _partId = widget.initialPartId ?? '';
    _raw.addListener(_onRawChanged);
    if (_subtopicId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadSubtopicContext(),
      );
    }
  }

  /// Completa los nombres cuando la pantalla se abrió con ids (enlace).
  void _resolveInitial(
    List<CourseEntity> courses,
    List<TopicEntity> topics,
    List<SubtopicEntity> subtopics,
  ) {
    var changed = false;
    if (_course == null && _courseId.isNotEmpty) {
      _course = courses.where((c) => c.id == _courseId).firstOrNull;
      changed |= _course != null;
    }
    if (_topic == null && _topicId.isNotEmpty) {
      _topic = topics.where((t) => t.id == _topicId).firstOrNull;
      changed |= _topic != null;
    }
    if (_subtopic == null && _subtopicId.isNotEmpty) {
      _subtopic = subtopics.where((x) => x.id == _subtopicId).firstOrNull;
      if (_subtopic != null && _partId.isNotEmpty) {
        _part = _subtopic!.listPart.where((p) => p.id == _partId).firstOrNull;
      }
      changed |= _subtopic != null;
    }
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {});
        _loadPartCount();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _raw.dispose();
    _explanation.dispose();
    _rawFocus.dispose();
    super.dispose();
  }

  void _onRawChanged() {
    final parsed = parseQuickQuestion(_raw.text);
    setState(() {
      _parsed = parsed;
      if (parsed.correctIndex != null) {
        _correct = parsed.correctIndex;
        _correctFromText = true;
      } else if (_correctFromText) {
        _correct = null;
        _correctFromText = false;
      }
      if (_correct != null && _correct! >= parsed.alternatives.length) {
        _correct = null;
      }
      if (parsed.explanation.isNotEmpty && _explanation.text.isEmpty) {
        _explanation.text = parsed.explanation;
      }
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _checkSimilar);
  }

  void _checkSimilar() {
    final tokens = similarityTokens(_parsed.statement);
    String? best;
    var bestScore = .6;
    for (final (other, text) in _existing) {
      final score = statementSimilarity(tokens, other);
      if (score >= bestScore) {
        bestScore = score;
        best = text;
      }
    }
    if (mounted && best != _similar) setState(() => _similar = best);
  }

  Future<void> _loadSubtopicContext() async {
    final repo = ref.read(questionRepoProvider);
    if (_subtopicId.isEmpty) {
      setState(() => _existing = const []);
      return;
    }
    final questions = await repo.questionsOfSubtopic(_subtopicId);
    if (!mounted) return;
    setState(() {
      _existing = [
        for (final q in questions)
          if (q.editorialStatus != 'retired')
            (
              similarityTokens(plainStatement(q.statementText)),
              plainStatement(q.statementText),
            ),
      ];
    });
    _checkSimilar();
  }

  Future<void> _loadPartCount() async {
    final part = _part;
    if (part == null) {
      setState(() {
        _partHave = null;
        _partNeed = null;
      });
      return;
    }
    final have = await ref
        .read(questionRepoProvider)
        .publishedCountForPart(part.id);
    int? need;
    if (part.examTemplateId.isNotEmpty) {
      final t = await ref
          .read(firestoreProvider)
          .collection(AppEnv.examTemplatesCollection)
          .doc(part.examTemplateId)
          .get();
      final count = t.data()?['questionCount'];
      need = count is num ? count.toInt() : null;
    }
    if (!mounted) return;
    setState(() {
      _partHave = have;
      _partNeed = need;
    });
  }

  QuickQuestionTarget get _target => QuickQuestionTarget(
    courseId: _courseId,
    courseName: _course?.name ?? '',
    topicId: _topicId,
    topicName: _topic?.name ?? '',
    subtopicId: _subtopicId,
    subtopicName: _subtopic?.name ?? '',
    partId: _partId,
    partName: _part?.name ?? '',
    difficulty: _difficulty,
  );

  List<String> get _problems => [
    if (!_target.complete) 'Elige curso, tema, subtema y parte arriba.',
    if (_parsed.statement.isEmpty) 'Falta el enunciado.',
    if (_parsed.alternatives.length < 2)
      'No encontramos al menos 2 alternativas (a) b) …).',
    if (_parsed.alternatives.any((a) => a.isEmpty))
      'Hay una alternativa vacía.',
    if (_correct == null) 'Marca la alternativa correcta.',
  ];

  QuestionContent get _statementContent =>
      contentFromPlainText(_parsed.statement, 'st');

  List<QuestionAlternative> _alternatives(String Function(int) id) => [
    for (var i = 0; i < _parsed.alternatives.length; i++)
      QuestionAlternative.fromJson({
        'id': id(i),
        'label': alternativeLabel(i),
        'content': contentFromPlainText(
          _parsed.alternatives[i],
          'alt$i',
        ).toJson(),
      }),
  ];

  Future<void> _save() async {
    if (_saving) return;
    final problems = _problems;
    if (problems.isNotEmpty) {
      setState(() => _error = problems.first);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ids = [for (final _ in _parsed.alternatives) const Uuid().v4()];
      final alternatives = _alternatives((i) => ids[i]);
      final explanation = contentFromPlainText(_explanation.text, 'ex');
      final saver = QuickQuestionSaver(
        ref.read(questionRepoProvider),
        ref.read(publishableQuestionRepoProvider),
      );
      final id = await saver.saveNew(
        target: _target,
        statement: _statementContent,
        alternatives: alternatives,
        correctAlternativeId: ids[_correct!],
        explanation: explanation,
      );
      if (!mounted) return;
      setState(() {
        _saved.insert(
          0,
          _Saved(
            id: id,
            statement: _parsed.statement.split('\n').first,
            hasExplanation: _explanation.text.trim().isNotEmpty,
          ),
        );
        _existing = [
          ..._existing,
          (similarityTokens(_parsed.statement), _parsed.statement),
        ];
        _raw.clear();
        _explanation.clear();
        _correct = null;
        _correctFromText = false;
        _similar = null;
      });
      _rawFocus.requestFocus();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo guardar. Revisa tu conexión y vuelve a intentarlo; '
              'el texto sigue aquí.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _finishSession(bool canPublish) async {
    if (_saved.isEmpty || _publishing) return;
    setState(() => _publishing = true);
    final session = ref.read(adminSessionProvider);
    final repo = ref.read(questionRepoProvider);
    final publicRepo = ref.read(publishableQuestionRepoProvider);
    var ok = 0;
    final failed = <String>[];
    for (final s in _saved) {
      try {
        if (canPublish) {
          await publicRepo.publishDraft(s.id);
        } else {
          await repo.requestReview(
            s.id,
            uid: session.uid,
            email: session.email,
          );
        }
        ok++;
      } catch (_) {
        failed.add(s.statement);
      }
    }
    if (!mounted) return;
    setState(() {
      _publishing = false;
      _saved.removeWhere((s) => !failed.contains(s.statement));
    });
    await _loadPartCount();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${canPublish ? 'Publicadas' : 'Enviadas a revisión'}: $ok.'
          '${failed.isEmpty ? '' : ' ${failed.length} no se pudieron: ábrelas para ver qué falta.'}',
        ),
      ),
    );
  }

  Future<void> _openSaved(_Saved s) async {
    final q = await ref.read(questionRepoProvider).getQuestion(s.id);
    if (q == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => QuestionFormSheet(question: q),
    );
  }

  void _markCorrect(int index) {
    if (index < _parsed.alternatives.length) {
      setState(() {
        _correct = index;
        _correctFromText = false;
      });
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    if (keys.isControlPressed &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      _save();
      return KeyEventResult.handled;
    }
    if (keys.isAltPressed) {
      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ];
      final i = digits.indexOf(event.logicalKey);
      if (i >= 0) {
        _markCorrect(i);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(effectiveSessionProvider);
    final canPublish = session.can(StaffSection.questions, StaffAction.publish);
    final canEdit = session.can(StaffSection.questions, StaffAction.edit);
    if (!canEdit) {
      return const Center(
        child: EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Tu perfil no puede cargar preguntas',
        ),
      );
    }
    final courses = ref.watch(_coursesProvider).value ?? const <CourseEntity>[];
    final topics = _courseId.isEmpty
        ? const <TopicEntity>[]
        : ref.watch(_topicsProvider(_courseId)).value ?? const <TopicEntity>[];
    final subtopics = _topicId.isEmpty
        ? const <SubtopicEntity>[]
        : ref.watch(_subtopicsProvider((_courseId, _topicId))).value ??
              const <SubtopicEntity>[];
    _resolveInitial(courses, topics, subtopics);
    return Focus(
      onKeyEvent: _onKey,
      child: Column(
        children: [
          _StickyBar(
            courses: courses,
            topics: topics,
            subtopics: subtopics,
            courseId: _courseId,
            topicId: _topicId,
            subtopicId: _subtopicId,
            partId: _partId,
            difficulty: _difficulty,
            onCourse: (c) {
              setState(() {
                _course = c;
                _courseId = c?.id ?? '';
                _topic = null;
                _topicId = '';
                _subtopic = null;
                _subtopicId = '';
                _part = null;
                _partId = '';
              });
              _loadSubtopicContext();
              _loadPartCount();
            },
            onTopic: (t) {
              setState(() {
                _topic = t;
                _topicId = t?.id ?? '';
                _subtopic = null;
                _subtopicId = '';
                _part = null;
                _partId = '';
              });
              _loadSubtopicContext();
              _loadPartCount();
            },
            onSubtopic: (s) {
              setState(() {
                _subtopic = s;
                _subtopicId = s?.id ?? '';
                _part = null;
                _partId = '';
              });
              _loadSubtopicContext();
              _loadPartCount();
            },
            onPart: (p) {
              setState(() {
                _part = p;
                _partId = p?.id ?? '';
              });
              _loadPartCount();
            },
            onDifficulty: (d) => setState(() => _difficulty = d),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 1100;
                final editor = _EditorCard(
                  number: _saved.length + 1,
                  raw: _raw,
                  rawFocus: _rawFocus,
                  explanation: _explanation,
                  parsed: _parsed,
                  correct: _correct,
                  similar: _similar,
                  error: _error,
                  saving: _saving,
                  onCorrect: _markCorrect,
                  onSave: _save,
                );
                final side = _SidePanel(
                  preview: _parsed.isEmpty
                      ? null
                      : AppExamQuestionScreen(
                          statement: _statementContent,
                          alternatives: _alternatives((i) => 'p$i'),
                          place: _place,
                          questionIndex: 2,
                          questionCount: 10,
                          answeredCount: 2,
                          sourceLabel: 'Pregunta de práctica IngresoYa',
                          sourceType: 'original',
                        ),
                  place: _place,
                  onPlace: (p) => setState(() => _place = p),
                  saved: _saved,
                  partName: _part?.name,
                  partHave: _partHave,
                  partNeed: _partNeed,
                  canPublish: canPublish,
                  publishing: _publishing,
                  onOpen: _openSaved,
                  onFinish: () => _finishSession(canPublish),
                );
                if (!wide) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                    children: [editor, const SizedBox(height: 16), side],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(28, 18, 12, 32),
                        children: [editor],
                      ),
                    ),
                    SizedBox(
                      width: 380,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(4, 18, 24, 32),
                        children: [side],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyBar extends StatelessWidget {
  const _StickyBar({
    required this.courses,
    required this.topics,
    required this.subtopics,
    required this.courseId,
    required this.topicId,
    required this.subtopicId,
    required this.partId,
    required this.difficulty,
    required this.onCourse,
    required this.onTopic,
    required this.onSubtopic,
    required this.onPart,
    required this.onDifficulty,
  });

  final List<CourseEntity> courses;
  final List<TopicEntity> topics;
  final List<SubtopicEntity> subtopics;
  final String courseId;
  final String topicId;
  final String subtopicId;
  final String partId;
  final String difficulty;
  final ValueChanged<CourseEntity?> onCourse;
  final ValueChanged<TopicEntity?> onTopic;
  final ValueChanged<SubtopicEntity?> onSubtopic;
  final ValueChanged<SubtopicPartEntity?> onPart;
  final ValueChanged<String> onDifficulty;

  @override
  Widget build(BuildContext context) {
    final subtopic = subtopics.where((s) => s.id == subtopicId).firstOrNull;
    final parts = subtopic?.listPart ?? const <SubtopicPartEntity>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: const BoxDecoration(
        color: AppTheme.card,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/questions'),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Banco'),
          ),
          const Text(
            'Carga rápida',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          const Text(
            'Se queda fijo para las siguientes:',
            style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
          ),
          _Picker<CourseEntity>(
            hint: 'Curso',
            value: courses.where((c) => c.id == courseId).firstOrNull,
            items: courses,
            label: (c) => c.name,
            onChanged: onCourse,
          ),
          _Picker<TopicEntity>(
            hint: 'Tema',
            value: topics.where((t) => t.id == topicId).firstOrNull,
            items: topics,
            label: (t) => t.name,
            onChanged: onTopic,
          ),
          _Picker<SubtopicEntity>(
            hint: 'Subtema',
            value: subtopic,
            items: subtopics,
            label: (s) => s.name,
            onChanged: onSubtopic,
          ),
          _Picker<SubtopicPartEntity>(
            hint: 'Parte',
            value: parts.where((p) => p.id == partId).firstOrNull,
            items: parts,
            label: (p) => p.name,
            onChanged: onPart,
          ),
          _Picker<String>(
            hint: 'Dificultad',
            value: difficulty,
            items: _difficulties.keys.toList(),
            label: (d) => 'Dificultad: ${_difficulties[d]}',
            onChanged: (d) => onDifficulty(d ?? 'unknown'),
          ),
        ],
      ),
    );
  }
}

class _Picker<T> extends StatelessWidget {
  const _Picker({
    required this.hint,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value != null;
    return PopupMenuButton<T>(
      tooltip: hint,
      enabled: items.isNotEmpty,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem(value: item, child: Text(label(item))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.brandSoft : AppTheme.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppTheme.brandSoft : AppTheme.lineStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                selected ? label(value as T) : hint,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppTheme.brandInk
                      : (items.isEmpty ? AppTheme.faint : AppTheme.body),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: items.isEmpty ? AppTheme.faint : AppTheme.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({
    required this.number,
    required this.raw,
    required this.rawFocus,
    required this.explanation,
    required this.parsed,
    required this.correct,
    required this.similar,
    required this.error,
    required this.saving,
    required this.onCorrect,
    required this.onSave,
  });

  final int number;
  final TextEditingController raw;
  final FocusNode rawFocus;
  final TextEditingController explanation;
  final ParsedQuestion parsed;
  final int? correct;
  final String? similar;
  final String? error;
  final bool saving;
  final ValueChanged<int> onCorrect;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDeco(borderColor: AppTheme.brand),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            children: [
              Text(
                'Pregunta n.º $number de esta sesión',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Text(
                'Pega todo junto: enunciado y alternativas. Nosotros las '
                'separamos.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: raw,
            focusNode: rawFocus,
            autofocus: true,
            minLines: 5,
            maxLines: 14,
            style: const TextStyle(fontSize: 14, height: 1.5),
            decoration: const InputDecoration(
              hintText:
                  'Un auto parte del reposo y acelera a 3 m/s². ¿Qué rapidez '
                  'tiene a los 4 s?\na) 7 m/s  b) 12 m/s  c) 9 m/s  d) 3/4 m/s  '
                  'e) 15 m/s\nClave: b',
              helperText:
                  r'Fórmulas entre $…$ (ej.: $x^2+1$). «Clave: B» al final marca '
                  'la correcta; «Solución: …» llena la explicación.',
              helperMaxLines: 2,
            ),
          ),
          if (!parsed.isEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'ASÍ QUEDÓ · HAZ CLIC EN LA CORRECTA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              parsed.statement.isEmpty ? '(sin enunciado)' : parsed.statement,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            if (parsed.alternatives.isEmpty)
              const InfoNote(
                'No encontramos alternativas. Escríbelas como a) … b) … o en '
                'líneas A. … B. …',
                tone: Tone.warn,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < parsed.alternatives.length; i++)
                    _AltChip(
                      label: alternativeLabel(i),
                      text: parsed.alternatives[i],
                      selected: correct == i,
                      onTap: () => onCorrect(i),
                    ),
                ],
              ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: explanation,
            minLines: 1,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Explicación (hace falta para publicar)',
              hintText: 'v = v₀ + a·t = 0 + 3·4 = 12 m/s',
            ),
          ),
          if (similar != null) ...[
            const SizedBox(height: 12),
            InfoNote(
              'Parecida a «${similar!.length > 90 ? '${similar!.substring(0, 90)}…' : similar}» '
              '(ya existe en este subtema). ¿Es otra pregunta?',
              tone: Tone.warn,
              icon: Icons.copy_all_rounded,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            InfoNote(error!, tone: Tone.error, icon: Icons.error_outline),
          ],
          const Divider(height: 28),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Text(
                'Alt+1…5 marca la correcta · Ctrl+Enter guarda y abre la '
                'siguiente',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              FilledButton.icon(
                onPressed: saving ? null : onSave,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Guardar y siguiente'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AltChip extends StatelessWidget {
  const _AltChip({
    required this.label,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.successSoft : AppTheme.card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 120, maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.success : AppTheme.lineStrong,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label  ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: text.isEmpty ? '(vacía)' : text),
                if (selected)
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.preview,
    required this.place,
    required this.onPlace,
    required this.saved,
    required this.partName,
    required this.partHave,
    required this.partNeed,
    required this.canPublish,
    required this.publishing,
    required this.onOpen,
    required this.onFinish,
  });

  final Widget? preview;
  final AppExamPlace place;
  final ValueChanged<AppExamPlace> onPlace;
  final List<_Saved> saved;
  final String? partName;
  final int? partHave;
  final int? partNeed;
  final bool canPublish;
  final bool publishing;
  final ValueChanged<_Saved> onOpen;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Así la ve el alumno',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            if (preview != null)
              const StatusPill('● en vivo', tone: Tone.success),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<AppExamPlace>(
          segments: [
            for (final p in AppExamPlace.values)
              ButtonSegment(value: p, label: Text(p.label)),
          ],
          selected: {place},
          showSelectedIcon: false,
          onSelectionChanged: (s) => onPlace(s.first),
        ),
        const SizedBox(height: 10),
        Center(
          child: preview == null
              ? Container(
                  width: 300,
                  height: 200,
                  alignment: Alignment.center,
                  decoration: AppTheme.cardDeco(color: AppTheme.subtle),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Pega una pregunta y aquí verás la pantalla de la app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  ),
                )
              : AppPhoneFrame(width: 320, child: preview!),
        ),
        const SizedBox(height: 6),
        const Text(
          'Se dibuja con el mismo código de la app (tema, textos y '
          'componentes).',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Esta sesión · ${saved.length} guardadas',
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (partName != null && partHave != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    partNeed == null
                        ? '$partName: $partHave publicadas (su examen aún no tiene plantilla).'
                        : '$partName: $partHave publicadas de $partNeed que pide su examen'
                              '${partHave! >= partNeed! ? ' · completo' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: partNeed != null && partHave! >= partNeed!
                          ? AppTheme.success
                          : AppTheme.warn,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (saved.isEmpty)
                const Text(
                  'Se guardan como borrador al instante: puedes cerrar y '
                  'seguir mañana.',
                  style: TextStyle(fontSize: 13, color: AppTheme.muted),
                ),
              for (final s in saved.take(8))
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFF0F2F5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.statement,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      if (!s.hasExplanation)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Text(
                            'sin explicación: no se publica',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.warn,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () => onOpen(s),
                        child: const Text('Editar'),
                      ),
                    ],
                  ),
                ),
              if (saved.length > 8)
                Text(
                  '… ${saved.length - 8} más',
                  style: const TextStyle(color: AppTheme.muted),
                ),
              if (saved.isNotEmpty) ...[
                const SizedBox(height: 10),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.ink),
                  onPressed: publishing ? null : onFinish,
                  child: Text(
                    canPublish
                        ? 'Publicar las ${saved.length}'
                        : 'Enviar las ${saved.length} a revisión',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Otras formas de cargar',
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: () => context.go('/import-exam'),
                child: const Text(
                  'Pegar un examen entero (exámenes pasados) →',
                ),
              ),
              TextButton(
                onPressed: () => context.go('/questions'),
                child: const Text(
                  'Editor completo: imágenes, tablas, fórmulas →',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
