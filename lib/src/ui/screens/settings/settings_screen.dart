import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/domain/sync_settings.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

/// «Configuración»: values the student app reads at startup.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(appConfigRepoProvider).watchSyncSettings();
    return Container(
      color: AppTheme.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: AppTheme.headerGradient(),
            child: Text(
              'Configuración',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .92),
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<SyncSettingsRecord>(
              stream: records,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'No se pudo leer la configuración: ${snapshot.error}',
                    ),
                  );
                }
                final record = snapshot.data;
                if (record == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: SyncSettingsCard(
                          // Rebuild the form when someone else saves.
                          key: ValueKey(record.settings.hashCode),
                          record: record,
                        ),
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

class SyncSettingsCard extends ConsumerStatefulWidget {
  const SyncSettingsCard({super.key, required this.record});

  final SyncSettingsRecord record;

  @override
  ConsumerState<SyncSettingsCard> createState() => _SyncSettingsCardState();
}

class _SyncSettingsCardState extends ConsumerState<SyncSettingsCard> {
  late bool _enabled;
  late final TextEditingController _debounce;
  late final TextEditingController _maxWait;
  late final TextEditingController _refresh;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load(widget.record.settings);
  }

  void _load(SyncSettings settings) {
    _enabled = settings.autoSyncEnabled;
    _debounce = TextEditingController(text: '${settings.debounceSeconds}');
    _maxWait = TextEditingController(text: '${settings.maxWaitSeconds}');
    _refresh = TextEditingController(text: '${settings.refreshEveryHours}');
  }

  @override
  void dispose() {
    _debounce.dispose();
    _maxWait.dispose();
    _refresh.dispose();
    super.dispose();
  }

  SyncSettings? _readForm() {
    final debounce = int.tryParse(_debounce.text.trim());
    final maxWait = int.tryParse(_maxWait.text.trim());
    final refresh = int.tryParse(_refresh.text.trim());
    if (debounce == null || maxWait == null || refresh == null) return null;
    return SyncSettings(
      autoSyncEnabled: _enabled,
      debounceSeconds: debounce,
      maxWaitSeconds: maxWait,
      refreshEveryHours: refresh,
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = _readForm();
    final problem = settings == null
        ? 'Completa los tres valores con números enteros.'
        : settings.validate();
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await ref
          .read(appConfigRepoProvider)
          .saveSyncSettings(
            settings!,
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
    const defaults = SyncSettings.defaults;
    setState(() {
      _enabled = defaults.autoSyncEnabled;
      _debounce.text = '${defaults.debounceSeconds}';
      _maxWait.text = '${defaults.maxWaitSeconds}';
      _refresh.text = '${defaults.refreshEveryHours}';
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
              const Icon(Icons.sync_rounded),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sincronización del progreso',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Text(
                record.exists
                    ? 'Guardado${_updatedLabel(record)}'
                    : 'Usando valores por defecto',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Cuándo la app sube a Firestore el avance de la Guía de estudio. '
            'Además, siempre sube al salir de la app, al aprobar un examen y '
            'al abrirla con cambios pendientes.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const ValueKey('sync-enabled'),
            contentPadding: EdgeInsets.zero,
            value: _enabled,
            onChanged: _saving ? null : (v) => setState(() => _enabled = v),
            title: const Text('Sincronización automática'),
            subtitle: Text(
              _enabled
                  ? 'Activada'
                  : 'Desactivada: solo se sube al iniciar o cerrar sesión',
              style: TextStyle(color: muted),
            ),
          ),
          _NumberField(
            key: const ValueKey('sync-debounce'),
            controller: _debounce,
            enabled: _enabled && !_saving,
            label: 'Espera tras el último cambio',
            suffix: 's',
            helper:
                'Agrupa varios cambios en una sola escritura '
                '(${SyncSettings.minDebounceSeconds} a '
                '${SyncSettings.maxDebounceSeconds} s).',
          ),
          _NumberField(
            key: const ValueKey('sync-max-wait'),
            controller: _maxWait,
            enabled: _enabled && !_saving,
            label: 'Espera máxima si el alumno sigue estudiando',
            suffix: 's',
            helper:
                'Sube aunque sigan llegando cambios (hasta '
                '${SyncSettings.maxMaxWaitSeconds} s).',
          ),
          _NumberField(
            key: const ValueKey('sync-refresh'),
            controller: _refresh,
            enabled: _enabled && !_saving,
            label: 'Revisar cambios de otros dispositivos cada',
            suffix: 'h',
            helper:
                'Como máximo una vez por este intervalo, al volver a la app '
                '(${SyncSettings.minRefreshEveryHours} a '
                '${SyncSettings.maxRefreshEveryHours} h).',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const ValueKey('sync-save'),
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

  String _updatedLabel(SyncSettingsRecord record) {
    final at = record.updatedAt;
    final parts = [
      if (at != null)
        '${at.day.toString().padLeft(2, '0')}/'
            '${at.month.toString().padLeft(2, '0')}/${at.year}',
      if (record.updatedBy.isNotEmpty) record.updatedBy,
    ];
    return parts.isEmpty ? '' : ' · ${parts.join(' · ')}';
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.label,
    required this.suffix,
    required this.helper,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String suffix;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffix,
          helperText: helper,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
