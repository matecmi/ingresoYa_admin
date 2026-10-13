import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/study_review_rules.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/settings_screen.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

/// Watches `{config}/study` and shows its editor.
class StudyReviewRulesSection extends ConsumerWidget {
  const StudyReviewRulesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<StudyReviewRulesRecord>(
      stream: ref.watch(appConfigRepoProvider).watchStudyReviewRules(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'No se pudieron leer las reglas de revisión: ${snapshot.error}',
          );
        }
        final record = snapshot.data;
        if (record == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return StudyReviewRulesCard(
          // Rebuild the form when someone else saves.
          key: ValueKey(record.rules.hashCode),
          record: record,
        );
      },
    );
  }
}

class StudyReviewRulesCard extends ConsumerStatefulWidget {
  const StudyReviewRulesCard({super.key, required this.record});

  final StudyReviewRulesRecord record;

  @override
  ConsumerState<StudyReviewRulesCard> createState() =>
      _StudyReviewRulesCardState();
}

class _StudyReviewRulesCardState extends ConsumerState<StudyReviewRulesCard> {
  late bool _strict;
  late final TextEditingController _videoPercent;
  late final TextEditingController _sectionSeconds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final rules = widget.record.rules;
    _strict = rules.strict;
    _videoPercent = TextEditingController(text: '${rules.videoMinPercent}');
    _sectionSeconds = TextEditingController(text: '${rules.sectionMinSeconds}');
  }

  @override
  void dispose() {
    _videoPercent.dispose();
    _sectionSeconds.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final percent = int.tryParse(_videoPercent.text.trim());
    final seconds = int.tryParse(_sectionSeconds.text.trim());
    final rules = percent == null || seconds == null
        ? null
        : StudyReviewRules(
            strict: _strict,
            videoMinPercent: percent,
            sectionMinSeconds: seconds,
          );
    final problem = rules == null
        ? 'Completa los dos valores con números enteros.'
        : rules.validate();
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await ref
          .read(appConfigRepoProvider)
          .saveStudyReviewRules(
            rules!,
            editor: user?.email ?? user?.uid ?? 'admin',
          );
      HapticFeedback.selectionClick();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Guardado. La app lo aplicará la próxima vez que se abra.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _restoreDefaults() {
    const defaults = StudyReviewRules.defaults;
    setState(() {
      _strict = defaults.strict;
      _videoPercent.text = '${defaults.videoMinPercent}';
      _sectionSeconds.text = '${defaults.sectionMinSeconds}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final muted = Colors.white.withValues(alpha: .6);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Revisión de la guía de estudio',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Text(
                record.exists
                    ? 'Guardado${settingsUpdatedLabel(record.updatedAt, record.updatedBy)}'
                    : 'Usando valores por defecto',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cuándo una sección de una parte (Video, Lección, Ejemplos, '
            'Repasar, Recursos) queda como «Revisado». Con todas revisadas se '
            'habilita el examen de la parte. Solo se exigen las secciones que '
            'la parte tiene con contenido.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const ValueKey('study-strict'),
            contentPadding: EdgeInsets.zero,
            value: _strict,
            onChanged: _saving ? null : (v) => setState(() => _strict = v),
            title: const Text('Exigir tiempo mínimo y porcentaje de video'),
            subtitle: Text(
              _strict
                  ? 'Activado: se aplican los valores de abajo'
                  : 'Desactivado: basta con entrar a la sección y, en el '
                        'video, con reproducirlo',
              style: TextStyle(color: muted),
            ),
          ),
          SettingsNumberField(
            key: const ValueKey('study-video-percent'),
            controller: _videoPercent,
            enabled: _strict && !_saving,
            label: 'Video: porcentaje mínimo visto',
            suffix: '%',
            helper:
                'Solo cuenta la reproducción real; adelantar no suma '
                '(${StudyReviewRules.minVideoPercent} a '
                '${StudyReviewRules.maxVideoPercent} %).',
          ),
          SettingsNumberField(
            key: const ValueKey('study-section-seconds'),
            controller: _sectionSeconds,
            enabled: _strict && !_saving,
            label:
                'Lección, Ejemplos, Repasar y Recursos: tiempo mínimo abierta',
            suffix: 's',
            helper:
                'Se marca al cerrarla si estuvo abierta al menos este tiempo '
                '(0 a ${StudyReviewRules.maxSectionSeconds} s).',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('study-save'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Guardar'),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _restoreDefaults,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Valores por defecto'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
