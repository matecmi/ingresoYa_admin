import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ingresoya_admin/src/domain/entities/question_entity.dart';
import 'package:ingresoya_admin/src/domain/entities/alternative_entity.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

// ✅ tu renderer
import 'package:ingresoya_admin/src/ui/widgets/exam_question.dart';

class QuestionDetailsSheet extends ConsumerWidget {
  const QuestionDetailsSheet({super.key, required this.q});
  final QuestionEntity q;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(questionRepoProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .92,
      minChildSize: .62,
      maxChildSize: .97,
      builder: (context, scroll) {
        return DefaultTabController(
          length: 2,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withOpacity(.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.26),
                  blurRadius: 26,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _topBar(context),
                TabBar(
                  indicatorColor: AppTheme.accent,
                  labelColor: Colors.white.withOpacity(.92),
                  unselectedLabelColor: Colors.white.withOpacity(.65),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w900),
                  tabs: const [
                    Tab(text: 'Datos'),
                    Tab(text: 'Alternativas'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _datosTab(scroll),
                      _alternativesTab(context, repo),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Pregunta #${q.number}',
              style: TextStyle(
                color: Colors.white.withOpacity(.92),
                fontWeight: FontWeight.w900,
                fontSize: 16.5,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(.85)),
          ),
        ],
      ),
    );
  }

  Widget _datosTab(ScrollController scroll) {
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      physics: const BouncingScrollPhysics(),
      children: [
        _pillRow(),
        const SizedBox(height: 12),
        ExamQuestion(raw: q.statementText, useCard: true),
        const SizedBox(height: 12),
        _kv('Curso', q.courseName),
        _kv('Tema', q.topicName),
        _kv('ExamId', q.examId.trim().isEmpty ? '—' : q.examId),
        _kv('Label', (q.label ?? '').trim().isEmpty ? '—' : q.label!),
        _kv('Activo', q.isActive ? 'Y' : 'N'),
      ],
    );
  }

  Widget _pillRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Pill(text: q.courseName.isEmpty ? '—' : q.courseName),
        _Pill(text: q.topicName.isEmpty ? '—' : q.topicName),
        _Pill(
          text: q.isActive ? 'Activa' : 'Inactiva',
          tone: q.isActive ? _PillTone.good : _PillTone.bad,
        ),
        _Pill(text: q.examId.trim().isEmpty ? 'Sin examen' : 'Con examen'),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: AppTheme.cardDeco(radius: 18, color: Colors.white.withOpacity(.03)),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                k,
                style: TextStyle(
                  color: Colors.white.withOpacity(.70),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                v,
                style: TextStyle(
                  color: Colors.white.withOpacity(.90),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alternativesTab(BuildContext context, dynamic repo) {
    return StreamBuilder<List<AlternativeEntity>>(
      stream: repo.watchAlternatives(q.id),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snap.data ?? const [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          physics: const BouncingScrollPhysics(),
          children: [
            _SectionHeader(
              title: 'Alternativas',
              subtitle: '${items.length} registradas',
              actionLabel: 'Agregar',
              onAction: () => _altDialog(context, repo, q.id),
              icon: Icons.add_rounded,
            ),
            const SizedBox(height: 10),

            if (items.isEmpty)
              _EmptyCard(text: 'Aún no hay alternativas.'),

            ...items.map((a) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AltRow(
                  alt: a,
                  onMakeCorrect: () async {
                    await repo.setCorrectAlternative(
                      questionId: q.id,
                      alternativeId: a.id,
                    );
                    HapticFeedback.selectionClick();
                  },
                  onEdit: () => _altDialog(context, repo, q.id, editing: a),
                  onDelete: () async {
                    final ok = await _confirmMini(
                      context,
                      title: 'Eliminar alternativa',
                      message: 'Se eliminará "${a.value}".',
                      primary: 'Eliminar',
                    );
                    if (!ok) return;
                    await repo.deleteAlternative(
                      questionId: q.id,
                      alternativeId: a.id,
                    );
                  },
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Future<void> _altDialog(
    BuildContext context,
    dynamic repo,
    String questionId, {
    AlternativeEntity? editing,
  }) async {
    final valueCtrl = TextEditingController(text: editing?.value ?? 'A');
    final descCtrl = TextEditingController(text: editing?.descriptionText ?? '');
    bool correct = (editing?.isCorrect ?? 'N') == 'Y';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          editing == null ? 'Nueva alternativa' : 'Editar alternativa',
          style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogTF(ctrl: valueCtrl, label: 'Valor (A/B/C/...) *'),
              _DialogTF(ctrl: descCtrl, label: 'Texto *', maxLines: 4),
              SwitchListTile(
                value: correct,
                onChanged: (v) => correct = v,
                activeColor: AppTheme.accent,
                title: Text(
                  'Es correcta',
                  style: TextStyle(color: Colors.white.withOpacity(.90), fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final nav = Navigator.of(dialogContext, rootNavigator: true);
              if (nav.canPop()) nav.pop();
            },
            child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(.75))),
          ),
          ElevatedButton(
            onPressed: () async {
              final v = valueCtrl.text.trim();
              final d = descCtrl.text.trim();
              if (v.isEmpty || d.isEmpty) return;

              await repo.upsertAlternative(
                questionId: questionId,
                alternativeId: editing?.id,
                value: v,
                descriptionText: d,
                isCorrect: correct ? 'Y' : 'N',
              );

              // si lo marcaste correcta, aseguras que sea única
              if (correct) {
                await repo.setCorrectAlternative(
                  questionId: questionId,
                  alternativeId: editing?.id ?? '', // ojo, si es create no sabemos id
                );
                // ✅ para create, lo más simple es: después de crear, que el usuario toque “Hacer correcta”
                // (si quieres, te lo mejoro con retorno de id)
              }

              HapticFeedback.selectionClick();
              if (dialogContext.mounted) Navigator.of(dialogContext, rootNavigator: true).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _AltRow extends StatelessWidget {
  const _AltRow({
    required this.alt,
    required this.onMakeCorrect,
    required this.onEdit,
    required this.onDelete,
  });

  final AlternativeEntity alt;
  final VoidCallback onMakeCorrect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isCorrect = alt.isCorrect == 'Y';

    return Container(
      decoration: AppTheme.cardDeco(radius: 22),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isCorrect
                    ? const Color(0xFF22C55E).withOpacity(.14)
                    : Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCorrect
                      ? const Color(0xFF22C55E).withOpacity(.35)
                      : Colors.white.withOpacity(.10),
                ),
              ),
              child: Center(
                child: Text(
                  alt.value,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.92),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                alt.descriptionText,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(.86),
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 10),

            _miniIcon(icon: Icons.check_circle_rounded, onTap: onMakeCorrect, hint: 'Hacer correcta'),
            const SizedBox(width: 8),
            _miniIcon(icon: Icons.edit_rounded, onTap: onEdit, hint: 'Editar'),
            const SizedBox(width: 8),
            _miniIcon(icon: Icons.delete_outline_rounded, onTap: onDelete, hint: 'Eliminar'),
          ],
        ),
      ),
    );
  }

  Widget _miniIcon({
    required IconData icon,
    required VoidCallback onTap,
    required String hint,
  }) {
    return Tooltip(
      message: hint,
      child: Material(
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
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22, color: Colors.white.withOpacity(.03)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.92),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(.65),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: Icon(icon, size: 18),
            label: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDeco(radius: 22, color: Colors.white.withOpacity(.03)),
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(.70),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DialogTF extends StatelessWidget {
  const _DialogTF({
    required this.ctrl,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController ctrl;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: TextStyle(
          color: Colors.white.withOpacity(.92),
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(.70)),
          filled: true,
          fillColor: Colors.white.withOpacity(.05),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withOpacity(.10)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.accent.withOpacity(.65)),
          ),
        ),
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

Future<bool> _confirmMini(
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
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        title,
        style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w900),
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
          child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(.78))),
        ),
        ElevatedButton(
          onPressed: () {
            final nav = Navigator.of(dialogContext, rootNavigator: true);
            if (nav.canPop()) nav.pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(primary, style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      ],
    ),
  );

  return res == true;
}