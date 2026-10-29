import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/tour_settings.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

/// «Más opciones» de Recorridos del búho: el título, el texto y el gesto de
/// cada paso. Vacío = el texto de fábrica de la app (se ve como sugerencia).
class TourTextsSection extends ConsumerWidget {
  const TourTextsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<TourSettings>(
      stream: ref.watch(appConfigRepoProvider).watchTourSettings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('No se pudieron leer los recorridos: ${snapshot.error}');
        }
        final settings = snapshot.data;
        if (settings == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return TourTextsCard(
          key: ValueKey(settings.toMap().toString().hashCode),
          settings: settings,
        );
      },
    );
  }
}

class TourTextsCard extends ConsumerStatefulWidget {
  const TourTextsCard({super.key, required this.settings});

  final TourSettings settings;

  @override
  ConsumerState<TourTextsCard> createState() => _TourTextsCardState();
}

class _TourTextsCardState extends ConsumerState<TourTextsCard> {
  final _titles = <String, TextEditingController>{};
  final _texts = <String, TextEditingController>{};
  final _poses = <String, String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final tour in tourCatalog) {
      for (final step in tour.steps) {
        final key = '${tour.id}.${step.id}';
        final saved = widget.settings.stepOf(tour.id, step.id);
        _titles[key] = TextEditingController(text: saved.title);
        _texts[key] = TextEditingController(text: saved.text);
        _poses[key] = saved.pose;
      }
    }
  }

  @override
  void dispose() {
    for (final c in [..._titles.values, ..._texts.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = widget.settings.copyWith(
      steps: {
        for (final key in _titles.keys)
          key: TourStepText(
            title: _titles[key]!.text,
            text: _texts[key]!.text,
            pose: _poses[key] ?? '',
          ),
      }..removeWhere((_, step) => step.isEmpty),
    );
    final problem = settings.validate();
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(appConfigRepoProvider)
          .saveTourSettings(settings, editor: _editor());
      messenger.showSnackBar(
        const SnackBar(content: Text('Textos guardados. La app los usa ya.')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _editor() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      return user?.email ?? user?.uid ?? 'admin';
    } catch (_) {
      return 'admin';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Lo que señala cada paso lo fija la app. Aquí cambias el texto y el '
          'gesto del búho; deja vacío para usar el de fábrica (en gris). '
          '{nombre} = nombre del alumno.',
          style: TextStyle(color: AppTheme.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        for (final tour in tourCatalog)
          ExpansionTile(
            key: ValueKey('tour-${tour.id}'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              tour.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text('${tour.steps.length} pasos'),
            children: [
              for (final (index, step) in tour.steps.indexed)
                _stepEditor(tour, step, index),
            ],
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text(_saving ? 'Guardando…' : 'Guardar textos'),
          ),
        ),
      ],
    );
  }

  Widget _stepEditor(TourInfo tour, TourStepInfo step, int index) {
    final key = '${tour.id}.${step.id}';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Paso ${index + 1} de ${tour.steps.length} · ${step.id}',
            style: TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titles[key],
            maxLength: TourSettings.maxTitle,
            decoration: InputDecoration(
              labelText: 'Título',
              hintText: step.title,
            ),
          ),
          TextField(
            controller: _texts[key],
            maxLength: TourSettings.maxText,
            maxLines: 2,
            decoration: InputDecoration(labelText: 'Texto', hintText: step.text),
          ),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Gesto:', style: TextStyle(color: AppTheme.muted)),
              for (final MapEntry(key: pose, value: label) in tourPoses.entries)
                ChoiceChip(
                  label: Text(label),
                  selected:
                      (_poses[key]!.isEmpty ? step.pose : _poses[key]) == pose,
                  onSelected: (_) => setState(
                    () => _poses[key] = pose == step.pose ? '' : pose,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
