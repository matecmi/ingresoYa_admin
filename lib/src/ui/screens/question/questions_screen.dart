import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ingresoya_admin/src/domain/entities/question_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';
import 'widgets/question_form_sheet.dart';
import 'widgets/question_details_sheet.dart';

class QuestionsScreen extends ConsumerStatefulWidget {
  const QuestionsScreen({super.key});

  @override
  ConsumerState<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends ConsumerState<QuestionsScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(questionRepoProvider);

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
              onChanged: (v) => setState(() => _q = v),
              onClear: () {
                _search.clear();
                setState(() => _q = '');
              },
            ),
          ),

          Expanded(
            child: StreamBuilder<List<QuestionEntity>>(
              stream: repo.watchQuestions(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data ?? const [];

                final filtered = _q.trim().isEmpty
                    ? all
                    : all.where((x) {
                        final q = _q.toLowerCase();
                        return x.courseName.toLowerCase().contains(q) ||
                            x.topicName.toLowerCase().contains(q) ||
                            x.statementText.toLowerCase().contains(q) ||
                            (x.label ?? '').toLowerCase().contains(q) ||
                            x.number.toString().contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: AppTheme.cardDeco(radius: 22),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No hay preguntas (o tu búsqueda no encontró resultados).',
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
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final q = filtered[i];
                    return _QuestionCard(
                      q: q,
                      onOpen: () => _openQuestionDetails(context, q),
                      onEdit: () => _openQuestionForm(context, q: q),
                      onDelete: () => _deleteQuestion(context, q),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteQuestion(BuildContext context, QuestionEntity q) async {
    final ok = await _confirmPro(
      context,
      title: 'Eliminar pregunta',
      message: 'Se eliminará la pregunta #${q.number} y sus alternativas.',
      primary: 'Eliminar',
    );
    if (!ok) return;

    await ref.read(questionRepoProvider).deleteQuestion(q.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Eliminada ✅')),
    );
  }

  Future<void> _openQuestionForm(BuildContext context, {QuestionEntity? q}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => QuestionFormSheet(question: q),
    );
  }

  Future<void> _openQuestionDetails(BuildContext context, QuestionEntity q) async {
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
  });

  final QuestionEntity q;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                    child: Text(
                      '${q.number}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.92),
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
                            text: q.examId.trim().isEmpty ? 'Sin examen' : 'Con examen',
                          ),
                          _Pill(
                            text: q.isActive ? 'Activa' : 'Inactiva',
                            tone: q.isActive ? _PillTone.good : _PillTone.bad,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _IconMiniBtn(icon: Icons.edit_rounded, onTap: onEdit),
                const SizedBox(width: 8),
                _IconMiniBtn(icon: Icons.delete_outline_rounded, onTap: onDelete),
              ],
            ),
          ),
        ),
      ),
    );
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