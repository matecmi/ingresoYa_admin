import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ingresoya_admin/src/domain/entities/question_entity.dart';
import 'package:ingresoya_admin/src/domain/question_bank_filter.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'widgets/question_form_sheet.dart';
import 'widgets/question_details_sheet.dart';
import 'widgets/question_bank_filter_sheet.dart';

class QuestionsScreen extends ConsumerStatefulWidget {
  const QuestionsScreen({super.key});

  @override
  ConsumerState<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends ConsumerState<QuestionsScreen> {
  final _search = TextEditingController();
  Timer? _searchDebounce;
  QuestionBankFilter _filter = const QuestionBankFilter();
  List<QuestionEntity> _items = const [];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loading = false;
  bool _hasMore = false;
  String? _loadError;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    if (_loading && !reset) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _loadError = null;
      if (reset) {
        _items = const [];
        _cursor = null;
        _hasMore = false;
      }
    });
    try {
      final page = await ref
          .read(questionRepoProvider)
          .fetchQuestionPage(_filter, after: reset ? null : _cursor);
      if (!mounted || request != _request) return;
      setState(() {
        _items = reset ? page.items : [..._items, ...page.items];
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() => _loadError = 'No se pudo cargar esta página del banco.');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _filter = _filter.copyWith(text: value);
      _load(reset: true);
    });
  }

  Future<void> _openFilters(BuildContext context) async {
    final next = await showModalBottomSheet<QuestionBankFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => QuestionBankFilterSheet(initial: _filter),
    );
    if (next == null || !mounted) return;
    setState(() => _filter = next);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: Column(
        children: [
          // header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: AppTheme.headerGradient(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Preguntas',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.92),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                _GlassBtn(
                  icon: Icons.filter_alt_rounded,
                  label: 'Filtros',
                  onTap: () => _openFilters(context),
                ),
                const SizedBox(width: 8),
                _GlassBtn(
                  icon: Icons.add_rounded,
                  label: 'Crear',
                  onTap: () => _openQuestionForm(context),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: _SearchBar(
              controller: _search,
              onChanged: _onSearchChanged,
              onClear: () {
                _search.clear();
                _onSearchChanged('');
              },
            ),
          ),

          Expanded(child: _bankList(context)),
        ],
      ),
    );
  }

  Widget _bankList(BuildContext context) {
    if (_loadError != null && _items.isEmpty) {
      return Center(
        child: TextButton(
          onPressed: () => _load(reset: true),
          child: Text('$_loadError Reintentar'),
        ),
      );
    }
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: AppTheme.cardDeco(radius: 22),
          padding: const EdgeInsets.all(16),
          child: Text(
            'No hay preguntas para estos filtros.',
            style: TextStyle(
              color: Colors.white.withOpacity(.75),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _items.length + (_hasMore || _loading ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == _items.length) {
          return Center(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  )
                : OutlinedButton.icon(
                    onPressed: () => _load(reset: false),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: const Text('Cargar más'),
                  ),
          );
        }
        final q = _items[index];
        return _QuestionCard(
          q: q,
          onOpen: () => _openQuestionDetails(context, q),
          onEdit: q.editorialStatus == 'retired'
              ? () => _showRetiredMessage(context)
              : () => _openQuestionForm(context, q: q),
          onDelete: q.editorialStatus == 'retired'
              ? () => _showRetiredMessage(context)
              : q.editorialStatus == 'published'
              ? () => _retireQuestion(context, q)
              : () => _deleteQuestion(context, q),
          isPublished: q.editorialStatus == 'published',
          isRetired: q.editorialStatus == 'retired',
        );
      },
    );
  }

  Future<void> _deleteQuestion(BuildContext context, QuestionEntity q) async {
    final ok = await _confirmPro(
      context,
      title: 'Eliminar pregunta',
      message: q.originalNumber == null
          ? 'Se eliminará la pregunta y sus alternativas.'
          : 'Se eliminará la pregunta N.º ${q.originalNumber} de su examen de origen y sus alternativas.',
      primary: 'Eliminar',
    );
    if (!ok) return;

    await ref.read(questionRepoProvider).deleteQuestion(q.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Eliminada ✅')));
    _load(reset: true);
  }

  Future<void> _retireQuestion(BuildContext context, QuestionEntity q) async {
    final ok = await _confirmPro(
      context,
      title: 'Retirar pregunta',
      message:
          '${q.originalNumber == null ? 'La pregunta' : 'La pregunta N.º ${q.originalNumber} de su examen de origen'} dejará de entrar en nuevos exámenes. Los intentos existentes conservarán su versión congelada.',
      primary: 'Retirar',
    );
    if (!ok) return;

    await ref.read(publishableQuestionRepoProvider).retirePublished(q.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pregunta retirada de nuevos exámenes.')),
    );
    _load(reset: true);
  }

  void _showRetiredMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Una pregunta retirada no se edita desde el formulario.'),
      ),
    );
  }

  Future<void> _openQuestionForm(
    BuildContext context, {
    QuestionEntity? q,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => QuestionFormSheet(question: q),
    );
    if (mounted) _load(reset: true);
  }

  Future<void> _openQuestionDetails(
    BuildContext context,
    QuestionEntity q,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => QuestionDetailsSheet(q: q),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.q,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.isPublished,
    required this.isRetired,
  });

  final QuestionEntity q;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isPublished;
  final bool isRetired;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(.10)),
                  ),
                  child: Center(
                    child: q.originalNumber == null
                        ? Icon(
                            Icons.quiz_outlined,
                            color: Colors.white.withValues(alpha: .92),
                          )
                        : Text(
                            '${q.originalNumber}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .92),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q.courseName.isEmpty ? '—' : q.courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.92),
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Pill(text: q.topicName.isEmpty ? '—' : q.topicName),
                          if ((q.label ?? '').trim().isNotEmpty)
                            _Pill(text: q.label!.trim()),
                          _Pill(
                            text: q.examId.trim().isEmpty
                                ? 'Sin examen'
                                : 'Con examen',
                          ),
                          _Pill(
                            text: q.isActive ? 'Activa' : 'Inactiva',
                            tone: q.isActive ? _PillTone.good : _PillTone.bad,
                          ),
                          _Pill(text: _editorialStatus(q.editorialStatus)),
                          _Pill(text: 'v${q.version}'),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Procedencia: ${q.sourceLabel.isEmpty ? 'Pendiente' : q.sourceLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Clasificación: ${_classification(q)} · ${_updatedAt(q.updatedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .62),
                          fontSize: 12,
                        ),
                      ),
                      if (q.editorialWarnings.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          '⚠ ${q.editorialWarnings.join(' · ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _IconMiniBtn(icon: Icons.edit_rounded, onTap: onEdit),
                const SizedBox(width: 8),
                _IconMiniBtn(
                  icon: isPublished
                      ? Icons.archive_outlined
                      : isRetired
                      ? Icons.lock_outline_rounded
                      : Icons.delete_outline_rounded,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _editorialStatus(String status) => switch (status) {
    'published' => 'Publicada',
    'retired' => 'Retirada',
    _ => 'Borrador',
  };

  String _classification(QuestionEntity question) {
    final values = [
      question.courseName,
      question.topicName,
      question.subtopicName,
      if (question.partIds.isNotEmpty) '${question.partIds.length} parte(s)',
    ].where((value) => value.trim().isNotEmpty);
    return values.isEmpty ? 'Pendiente' : values.join(' › ');
  }

  String _updatedAt(DateTime? value) {
    if (value == null) return 'Sin fecha de actualización';
    final date = value.toLocal();
    return 'Actualizada ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _IconMiniBtn extends StatelessWidget {
  const _IconMiniBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.10)),
          ),
          child: Icon(icon, color: Colors.white.withOpacity(.90), size: 18),
        ),
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  const _GlassBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(.14)),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white.withOpacity(.92), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(.92),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 20),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.white.withOpacity(.78)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(
                color: Colors.white.withOpacity(.92),
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar por curso, tema, enunciado, número…',
                hintStyle: TextStyle(color: Colors.white.withOpacity(.45)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          _IconMiniBtn(icon: Icons.close_rounded, onTap: onClear),
        ],
      ),
    );
  }
}

enum _PillTone { neutral, good, bad }

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.tone = _PillTone.neutral});
  final String text;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    if (tone == _PillTone.good) {
      bg = const Color(0xFF22C55E).withOpacity(.14);
      border = const Color(0xFF22C55E).withOpacity(.35);
    } else if (tone == _PillTone.bad) {
      bg = const Color(0xFFEF4444).withOpacity(.14);
      border = const Color(0xFFEF4444).withOpacity(.35);
    } else {
      bg = Colors.white.withOpacity(.06);
      border = Colors.white.withOpacity(.10);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(.90),
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ✅ confirm pro (seguro, no rompe navegación)
Future<bool> _confirmPro(
  BuildContext context, {
  required String title,
  required String message,
  required String primary,
}) async {
  if (!context.mounted) return false;

  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(.92),
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withOpacity(.80), height: 1.25),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final nav = Navigator.of(dialogContext, rootNavigator: true);
              if (nav.canPop()) nav.pop(false);
            },
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.white.withOpacity(.78)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final nav = Navigator.of(dialogContext, rootNavigator: true);
              if (nav.canPop()) nav.pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              primary,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      );
    },
  );

  return res == true;
}
