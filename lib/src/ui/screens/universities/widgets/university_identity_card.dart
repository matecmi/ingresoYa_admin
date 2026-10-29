import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app_preview/gen/owl_mascot.g.dart';
import '../../../../domain/university_identity.dart';
import '../../../../domain/university_profile.dart';
import '../../../../providers/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/admin_ui.dart';

/// «Identidad para el alumno» (lienzo «Personalización por universidad»):
/// colores de la bufanda del búho, cómo llamar al ingresante, la frase al
/// subir de rango y «¿habrías ingresado?». Con la vista previa del búho real
/// de la app (copia generada en `app_preview/gen`).
class UniversityIdentityCard extends ConsumerStatefulWidget {
  const UniversityIdentityCard({super.key, required this.data});

  final UniversityStudentData data;

  @override
  ConsumerState<UniversityIdentityCard> createState() =>
      _UniversityIdentityCardState();
}

class _UniversityIdentityCardState
    extends ConsumerState<UniversityIdentityCard> {
  late UniversityIdentity _identity = widget.data.identity;
  late final _primary = TextEditingController(text: _identity.primaryColor);
  late final _secondary = TextEditingController(text: _identity.secondaryColor);
  late final _freshman = TextEditingController(text: _identity.freshmanName);
  late final _phrase = TextEditingController(text: _identity.rankUpPhrase);
  bool _saving = false;

  bool get _dirty =>
      _identity.toMap().toString() != widget.data.identity.toMap().toString();

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    _freshman.dispose();
    _phrase.dispose();
    super.dispose();
  }

  static Color? _color(String hex) {
    final value = hex.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return Color(0xFF000000 | int.parse(value, radix: 16));
  }

  Future<void> _save() async {
    final problem = _identity.validate();
    final messenger = ScaffoldMessenger.of(context);
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(universityRepoProvider)
          .setIdentity(widget.data.universityId, _identity);
      messenger.showSnackBar(
        const SnackBar(content: Text('Identidad guardada.')),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('No se guardó: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _colorField({
    required String label,
    required String help,
    required TextEditingController controller,
    required void Function(String) onChanged,
  }) {
    final color = _color(controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: (value) => setState(() => onChanged(value)),
          decoration: InputDecoration(
            labelText: label,
            hintText: '#15803D',
            helperText: help,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: color ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.line),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final MapEntry(key: hex, value: name)
                in UniversityIdentity.presets.entries)
              Tooltip(
                message: name,
                child: InkWell(
                  onTap: () => setState(() {
                    controller.text = hex;
                    onChanged(hex);
                  }),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _color(hex),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.line),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = _color(_identity.primaryColor);
    final outfit = primary == null
        ? null
        : OwlOutfit(
            scarf: primary,
            stripe: _color(_identity.secondaryColor) ?? Colors.white,
          );
    final who = widget.data.acronym.isEmpty
        ? 'la universidad'
        : widget.data.acronym;
    return SectionCard(
      title: 'Identidad para el alumno',
      trailing: FilledButton.icon(
        onPressed: _saving || !_dirty ? null : _save,
        icon: const Icon(Icons.save_outlined, size: 18),
        label: Text(_saving ? 'Guardando…' : 'Guardar identidad'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final form = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _colorField(
                label: 'Color principal',
                help: 'Bufanda del búho, confeti y el puntito del chip.',
                controller: _primary,
                onChanged: (v) =>
                    _identity = _identity.copyWith(primaryColor: v),
              ),
              const SizedBox(height: 14),
              _colorField(
                label: 'Color secundario',
                help: 'Rayas de la bufanda y borla del birrete.',
                controller: _secondary,
                onChanged: (v) =>
                    _identity = _identity.copyWith(secondaryColor: v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _freshman,
                maxLength: UniversityIdentity.maxFreshmanName,
                onChanged: (v) => setState(
                  () => _identity = _identity.copyWith(freshmanName: v),
                ),
                decoration: const InputDecoration(
                  labelText: 'Cómo llamar al ingresante',
                  hintText: 'cachimbo',
                  helperText:
                      'En el Inicio: «Tu examen · 33 días · para ser cachimbo». '
                      'Vacío: «ingresante».',
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phrase,
                maxLength: UniversityIdentity.maxRankUpPhrase,
                onChanged: (v) => setState(
                  () => _identity = _identity.copyWith(rankUpPhrase: v),
                ),
                decoration: const InputDecoration(
                  labelText: 'Frase del búho al subir de rango',
                  hintText: 'Un paso más cerca de la {uni}, {nombre}.',
                  helperText:
                      '{uni} = sigla de la universidad, {nombre} = nombre del '
                      'alumno. Vacío: la frase de siempre.',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _identity.showWouldHaveEntered,
                onChanged: (v) => setState(
                  () => _identity = _identity.copyWith(showWouldHaveEntered: v),
                ),
                title: const Text(
                  'Mostrar «¿habrías ingresado?» en exámenes pasados',
                ),
                subtitle: const Text(
                  '«¡Con este puntaje habrías ingresado a Sistemas!» y las '
                  'carreras vecinas con su ingreso.',
                ),
              ),
            ],
          );
          final preview = Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F2C),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text(
                  'ASÍ LO VE EL ALUMNO',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .6,
                  ),
                ),
                const SizedBox(height: 12),
                OwlOutfitScope(
                  outfit: outfit,
                  child: const OwlMascot(
                    size: 150,
                    mood: OwlMood.happy,
                    cap: true,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  outfit == null
                      ? 'Sin colores: el búho de siempre.'
                      : 'Bufanda de $who. En el Inicio el búho va sin '
                            'birrete; lo usa en las celebraciones.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sin escudos ni logos oficiales: solo colores y texto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
              ],
            ),
          );
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [form, const SizedBox(height: 16), preview],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: form),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: preview),
            ],
          );
        },
      ),
    );
  }
}
