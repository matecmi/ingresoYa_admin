import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/settings_catalog.dart';
import '../../../domain/staff.dart';
import '../../../env/app_env.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';
import 'plan_settings_card.dart';
import 'rankings_settings_card.dart';
import 'simulator_settings_card.dart';
import 'xp_settings_card.dart';
import 'xp_student_tool.dart';

final _valuesProvider = StreamProvider.autoDispose<SettingsValues>(
  (ref) => ref.watch(settingsStoreProvider).watchAll(),
);

/// Configuración en lenguaje simple (tableros 18 y 20): cada ajuste es una
/// pregunta, con su efecto «en la práctica», el valor de fábrica, la pantalla
/// real donde lo ve el alumno y una sola barra para guardar.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _topicId = settingsTopics.first.id;
  String _query = '';
  String? _focused;
  final _drafts = <SettingsDoc, Map<String, dynamic>>{};
  final _errors = <String, String>{};
  final _openAdvanced = <String>{};
  bool _showFull = false;
  bool _saving = false;
  String? _saveError;

  static const _toolsId = 'tools';

  SettingsTopic? get _topic =>
      settingsTopics.where((t) => t.id == _topicId).firstOrNull;

  Object? _value(SettingsValues saved, SettingSpec s) =>
      readPath(_drafts[s.doc] ?? saved[s.doc], s.path);

  SettingsValues _merged(SettingsValues saved) => {
    for (final d in SettingsDoc.values) d: _drafts[d] ?? saved[d] ?? const {},
  };

  List<(SettingSpec, Object?, Object?)> _changes(SettingsValues saved) => [
    for (final s in allSettingSpecs)
      if (_drafts.containsKey(s.doc) &&
          readPath(_drafts[s.doc], s.path) != readPath(saved[s.doc], s.path))
        (s, readPath(saved[s.doc], s.path), readPath(_drafts[s.doc], s.path)),
  ];

  void _set(SettingsValues saved, SettingSpec s, Object? value) {
    setState(() {
      final base = _drafts[s.doc] ?? saved[s.doc] ?? const {};
      _drafts[s.doc] = writePath(base, s.path, value);
      final problem = s.check(value);
      if (problem == null) {
        _errors.remove(s.id);
      } else {
        _errors[s.id] = problem;
      }
      _focused = s.id;
      _saveError = null;
    });
  }

  void _applyPreset(SettingsValues saved, SettingsTopic t, SettingsPreset p) {
    for (final e in p.values.entries) {
      final spec = t.specs.where((s) => s.path.join('.') == e.key).firstOrNull;
      if (spec != null) _set(saved, spec, e.value);
    }
  }

  void _discard() => setState(() {
    _drafts.clear();
    _errors.clear();
    _saveError = null;
  });

  Future<void> _save(SettingsValues saved) async {
    if (_errors.isNotEmpty) {
      setState(() => _saveError = 'Corrige los valores marcados en rojo.');
      return;
    }
    final changedDocs = {for (final c in _changes(saved)) c.$1.doc};
    for (final doc in changedDocs) {
      final problem = validateDoc(doc, _drafts[doc]!);
      if (problem != null) {
        setState(() => _saveError = problem);
        return;
      }
    }
    setState(() => _saving = true);
    try {
      final editor = ref.read(adminSessionProvider).email;
      for (final doc in changedDocs) {
        await ref
            .read(settingsStoreProvider)
            .save(doc, _drafts[doc]!, editor: editor);
      }
      if (!mounted) return;
      setState(() {
        _drafts.clear();
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Guardado. La app lo aplica la próxima vez que lee la '
            'configuración (normalmente al abrirse).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e is StateError ? e.message : 'No se pudo guardar.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_valuesProvider);
    final canEdit = ref
        .watch(effectiveSessionProvider)
        .can(StaffSection.settings, StaffAction.edit);
    if (async.hasError) {
      return Center(
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'No se pudo leer la configuración',
          message: '${async.error}',
        ),
      );
    }
    final saved = async.value;
    if (saved == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final values = _merged(saved);
    final changes = _changes(saved);
    final topic = _topic;

    final nav = _TopicNav(
      selected: _topicId,
      query: _query,
      changedByTopic: {
        for (final t in settingsTopics)
          t.id: changes.where((c) => t.specs.contains(c.$1)).length,
      },
      onQuery: (q) => setState(() => _query = q),
      onSelect: (id) => setState(() {
        _topicId = id;
        _query = '';
        _showFull = false;
        _focused = null;
      }),
    );

    Widget main;
    if (_query.trim().length >= 2) {
      final results = searchSettings(_query);
      main = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            results.isEmpty
                ? 'No hay ajustes con «$_query».'
                : '${results.length} ajuste(s) con «$_query»',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),
          for (final (t, s) in results) ...[
            Text(
              t.label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 4),
            _card(s, saved, values, canEdit),
            const SizedBox(height: 12),
          ],
        ],
      );
    } else if (_topicId == _toolsId) {
      main = const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoNote(
            'Buscar a un alumno por correo o uid, ver su XP y revertir un '
            'movimiento con motivo.',
          ),
          SizedBox(height: 12),
          XpStudentTool(),
        ],
      );
    } else {
      final t = topic!;
      final basic = t.specs.where((s) => !s.advanced).toList();
      final advanced = t.specs.where((s) => s.advanced).toList();
      main = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (t.presets.isNotEmpty)
            _PresetBar(
              question: t.presetQuestion ?? 'Combinaciones listas',
              presets: t.presets,
              active: t.presets
                  .where(
                    (p) => p.values.entries.every(
                      (e) =>
                          readPath(
                            values[t.specs.first.doc],
                            e.key.split('.'),
                          ) ==
                          e.value,
                    ),
                  )
                  .firstOrNull,
              enabled: canEdit,
              onPick: (p) => _applyPreset(saved, t, p),
            ),
          for (final s in basic) ...[
            _card(s, saved, values, canEdit),
            const SizedBox(height: 12),
          ],
          if (advanced.isNotEmpty)
            _ExpandBar(
              label: 'Ajustes avanzados (${advanced.length})',
              open: _openAdvanced.contains(t.id),
              onTap: () => setState(
                () => _openAdvanced.contains(t.id)
                    ? _openAdvanced.remove(t.id)
                    : _openAdvanced.add(t.id),
              ),
            ),
          if (_openAdvanced.contains(t.id))
            for (final s in advanced) ...[
              const SizedBox(height: 12),
              _card(s, saved, values, canEdit),
            ],
          if (t.fullEditor != null) ...[
            const SizedBox(height: 12),
            _ExpandBar(
              label: switch (t.fullEditor) {
                'rankings' =>
                  'Más opciones: nombres de las etapas, palabras prohibidas, '
                      'nombres de usuario y reto de hoy',
                'xp' => 'Más opciones: escalera de rangos e imágenes',
                'simulator' => 'Más opciones: tamaños de la práctica',
                'plan' => 'Más opciones: sesiones por semana que puede elegir',
                _ => 'Más opciones',
              },
              open: _showFull,
              onTap: () => setState(() => _showFull = !_showFull),
            ),
            if (_showFull) ...[
              const SizedBox(height: 8),
              const InfoNote(
                'Este editor guarda por su cuenta con su propio botón.',
                tone: Tone.neutral,
              ),
              const SizedBox(height: 8),
              switch (t.fullEditor) {
                'rankings' => const RankingsSettingsSection(),
                'xp' => const XpSettingsSection(),
                'simulator' => const SimulatorSettingsSection(),
                'plan' => const PlanSettingsSection(),
                _ => const SizedBox.shrink(),
              },
            ],
          ],
        ],
      );
    }

    final focusedSpec = _focused == null ? null : specById(_focused!);
    final screen = focusedSpec?.screen ?? topic?.screen;
    final preview = screen == null
        ? const SizedBox.shrink()
        : _WhereInApp(
            screen: screen,
            caption: focusedSpec != null && focusedSpec.screen != null
                ? focusedSpec.shortLabel
                : null,
          );

    final body = LayoutBuilder(
      builder: (context, c) {
        final header = AdminPageHeader(
          title: _query.isNotEmpty
              ? 'Buscar en Configuración'
              : (_topicId == _toolsId
                    ? 'XP de un alumno'
                    : topic?.label ?? 'Configuración'),
          subtitle: _query.isNotEmpty || _topicId == _toolsId
              ? null
              : topic?.intro,
        );
        if (c.maxWidth < 1100) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            children: [
              nav,
              const SizedBox(height: 16),
              header,
              const SizedBox(height: 14),
              main,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 250,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 8, 120),
                children: [nav],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 120),
                children: [header, const SizedBox(height: 14), main],
              ),
            ),
            SizedBox(
              width: 330,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 18, 24, 120),
                children: [preview],
              ),
            ),
          ],
        );
      },
    );

    return Stack(
      children: [
        Positioned.fill(child: body),
        if (changes.isNotEmpty || _saveError != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SaveBar(
              changes: changes,
              error: _saveError,
              saving: _saving,
              canEdit: canEdit,
              onDiscard: _discard,
              onSave: () => _save(saved),
            ),
          ),
      ],
    );
  }

  Widget _card(
    SettingSpec s,
    SettingsValues saved,
    SettingsValues values,
    bool canEdit,
  ) {
    final value = _value(saved, s);
    final savedValue = readPath(saved[s.doc], s.path);
    final factory = readPath(factoryValues(s.doc), s.path);
    return _SettingCard(
      spec: s,
      value: value,
      savedValue: savedValue,
      factoryValue: factory,
      error: _errors[s.id],
      practice: s.inPractice?.call(values),
      focused: _focused == s.id,
      enabled: canEdit && !_saving,
      onChanged: (v) => _set(saved, s, v),
      onFocus: () => setState(() => _focused = s.id),
    );
  }
}

class _TopicNav extends StatelessWidget {
  const _TopicNav({
    required this.selected,
    required this.query,
    required this.changedByTopic,
    required this.onQuery,
    required this.onSelect,
  });

  final String selected;
  final String query;
  final Map<String, int> changedByTopic;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget item(String id, String label, IconData icon) {
      final active = selected == id && query.isEmpty;
      final changed = changedByTopic[id] ?? 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: active ? AppTheme.brandSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelect(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: active ? AppTheme.brandInk : AppTheme.body,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? AppTheme.brandInk : AppTheme.ink,
                      ),
                    ),
                  ),
                  if (changed > 0) StatusPill('$changed', tone: Tone.warn),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: onQuery,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search_rounded, size: 20),
            hintText: '¿Qué quieres cambiar?',
          ),
        ),
        const SizedBox(height: 12),
        for (final t in settingsTopics) item(t.id, t.label, t.icon),
        const Divider(height: 20),
        item(
          _SettingsScreenState._toolsId,
          'XP de un alumno',
          Icons.person_search_outlined,
        ),
      ],
    );
  }
}

class _PresetBar extends StatelessWidget {
  const _PresetBar({
    required this.question,
    required this.presets,
    required this.active,
    required this.enabled,
    required this.onPick,
  });

  final String question;
  final List<SettingsPreset> presets;
  final SettingsPreset? active;
  final bool enabled;
  final ValueChanged<SettingsPreset> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              question,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final p in presets)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: identical(p, active),
                    onSelected: enabled ? (_) => onPick(p) : null,
                  ),
                ChoiceChip(
                  label: const Text('A medida'),
                  selected: active == null,
                  onSelected: null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandBar extends StatelessWidget {
  const _ExpandBar({
    required this.label,
    required this.open,
    required this.onTap,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.subtle,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.line),
          ),
          child: Row(
            children: [
              Icon(
                open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: AppTheme.body,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingCard extends StatelessWidget {
  const _SettingCard({
    required this.spec,
    required this.value,
    required this.savedValue,
    required this.factoryValue,
    required this.error,
    required this.practice,
    required this.focused,
    required this.enabled,
    required this.onChanged,
    required this.onFocus,
  });

  final SettingSpec spec;
  final Object? value;
  final Object? savedValue;
  final Object? factoryValue;
  final String? error;
  final String? practice;
  final bool focused;
  final bool enabled;
  final ValueChanged<Object?> onChanged;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final changed = value != savedValue;
    final input = switch (spec.kind) {
      SettingKind.toggle => Switch(
        value: value == true,
        onChanged: enabled ? onChanged : null,
      ),
      SettingKind.choice => DropdownButton<Object>(
        value: spec.choices.containsKey(value) ? value : null,
        onChanged: enabled ? onChanged : null,
        underline: const SizedBox.shrink(),
        items: [
          for (final e in spec.choices.entries)
            DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
      ),
      SettingKind.integer => _NumberField(
        value: value is int ? value as int : null,
        unit: spec.unit,
        enabled: enabled,
        onChanged: onChanged,
        onFocus: onFocus,
      ),
      SettingKind.time => _TextValueField(
        value: '${value ?? ''}',
        enabled: enabled,
        onChanged: onChanged,
        onFocus: onFocus,
      ),
    };

    return GestureDetector(
      onTap: onFocus,
      behavior: HitTestBehavior.translucent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: AppTheme.cardDeco(
          borderColor: error != null
              ? AppTheme.error
              : (focused ? AppTheme.brand : null),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.question,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (spec.help.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          spec.help,
                          style: TextStyle(fontSize: 13, color: AppTheme.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                input,
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: [
                if (changed)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Guardado: ${spec.format(savedValue)} · ',
                          style: TextStyle(color: AppTheme.warn),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: InkWell(
                            onTap: enabled ? () => onChanged(savedValue) : null,
                            child: Text(
                              'volver',
                              style: TextStyle(
                                color: AppTheme.warn,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.underline,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                if (factoryValue != null)
                  Text(
                    value == factoryValue
                        ? 'valor de fábrica'
                        : 'De fábrica: ${spec.format(factoryValue)}',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 6),
              Text(
                error!,
                style: TextStyle(
                  color: AppTheme.error,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (practice != null && error == null) ...[
              const SizedBox(height: 10),
              InfoNote('En la práctica: $practice'),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.value,
    required this.unit,
    required this.enabled,
    required this.onChanged,
    required this.onFocus,
  });

  final int? value;
  final String unit;
  final bool enabled;
  final ValueChanged<Object?> onChanged;
  final VoidCallback onFocus;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _ctrl = TextEditingController(text: '${widget.value ?? ''}');

  @override
  void didUpdateWidget(covariant _NumberField old) {
    super.didUpdateWidget(old);
    if (int.tryParse(_ctrl.text) != widget.value && widget.value != null) {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: _ctrl,
        enabled: widget.enabled,
        onTap: widget.onFocus,
        textAlign: TextAlign.right,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          isDense: true,
          suffixText: widget.unit,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        onChanged: (v) => widget.onChanged(int.tryParse(v)),
      ),
    );
  }
}

class _TextValueField extends StatefulWidget {
  const _TextValueField({
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onFocus,
  });

  final String value;
  final bool enabled;
  final ValueChanged<Object?> onChanged;
  final VoidCallback onFocus;

  @override
  State<_TextValueField> createState() => _TextValueFieldState();
}

class _TextValueFieldState extends State<_TextValueField> {
  late final _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _TextValueField old) {
    super.didUpdateWidget(old);
    if (_ctrl.text != widget.value) _ctrl.text = widget.value;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 110,
    child: TextField(
      controller: _ctrl,
      enabled: widget.enabled,
      onTap: widget.onFocus,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      decoration: const InputDecoration(isDense: true, hintText: 'HH:mm'),
      onChanged: widget.onChanged,
    ),
  );
}

class _WhereInApp extends StatelessWidget {
  const _WhereInApp({required this.screen, this.caption});

  final AppScreenShot screen;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    const width = 270.0;
    const height = width * 1200 / 540;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Dónde lo ve el alumno',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        if (caption != null)
          Text(
            caption!,
            style: TextStyle(fontSize: 12.5, color: AppTheme.brandInk),
          ),
        const SizedBox(height: 10),
        Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(screen.asset, fit: BoxFit.cover),
                  ),
                ),
                for (final (i, z) in screen.zones.indexed)
                  Positioned(
                    left: z.left * width - 4,
                    top: z.top * height - 4,
                    width: z.width * width + 8,
                    height: z.height * height + 8,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: i == 0 ? 3 : 2,
                        ),
                        color: const Color(0xFFF59E0B).withValues(alpha: .10),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Se ve en: ${screen.path}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Captura real del teléfono (app de prueba). Lo marcado en naranja es '
          'lo que cambia este ajuste.',
          style: TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
      ],
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.changes,
    required this.error,
    required this.saving,
    required this.canEdit,
    required this.onDiscard,
    required this.onSave,
  });

  final List<(SettingSpec, Object?, Object?)> changes;
  final String? error;
  final bool saving;
  final bool canEdit;
  final VoidCallback onDiscard;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final summary = changes
        .take(3)
        .map(
          (c) =>
              '«${c.$1.shortLabel}» ${c.$1.format(c.$2)} → ${c.$1.format(c.$3)}',
        )
        .join(' · ');
    final env = AppEnv.environment == AdminEnvironment.production
        ? 'Guardar en PRODUCCIÓN'
        : 'Guardar en TEST';
    return Material(
      color: AppTheme.bar,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    changes.length == 1
                        ? '1 cambio sin guardar'
                        : '${changes.length} cambios sin guardar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (summary.isNotEmpty)
                    Text(
                      '$summary${changes.length > 3 ? ' · …' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .8),
                        fontSize: 13,
                      ),
                    ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: saving ? null : onDiscard,
              child: const Text('Descartar'),
            ),
            const SizedBox(width: 8),
            if (canEdit)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF101828),
                ),
                onPressed: saving || changes.isEmpty ? null : onSave,
                child: Text(saving ? 'Guardando…' : env),
              ),
          ],
        ),
      ),
    );
  }
}
