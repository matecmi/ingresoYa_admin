import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repo/audit_repo.dart';
import '../../../domain/settings_catalog.dart';
import '../../../domain/staff.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';

final _entriesProvider = StreamProvider.autoDispose
    .family<List<AuditEntry>, String?>(
      (ref, section) => ref.watch(auditRepoProvider).watch(section: section),
    );

const _filters = <(String?, String)>[
  (null, 'Todo'),
  ('settings', 'Configuración'),
  ('questions', 'Preguntas'),
  ('courses', 'Cursos'),
  ('universities', 'Universidades'),
  ('news', 'Noticias'),
  ('staff', 'Personal'),
];

/// Historial de cambios con restaurar (tablero 12): quién cambió qué, antes
/// y después, y deshacer.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String? _section;
  String _query = '';
  bool _onlyArchived = false;
  String? _selectedId;
  bool _restoring = false;

  Future<void> _restore(AuditEntry e, {bool force = false}) async {
    setState(() => _restoring = true);
    try {
      await ref.read(auditRepoProvider).restore(e.id, force: force);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.isRetire || e.kind == 'delete'
                ? 'Recuperado. También quedó anotado en el historial.'
                : 'Restaurado. También quedó anotado en el historial: se puede '
                      'volver a deshacer.',
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      final msg = auditErrorMessage(err);
      final changed = msg.startsWith('Cambió después');
      if (changed && !force) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cambió después de este registro'),
            content: const Text(
              'Si restauras igual, se pierden los cambios que hicieron después '
              'en ese mismo elemento.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Restaurar igual'),
              ),
            ],
          ),
        );
        if (ok == true) {
          if (mounted) setState(() => _restoring = false);
          return _restore(e, force: true);
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(effectiveSessionProvider);
    final async = ref.watch(_entriesProvider(_section));
    final all = async.value ?? const <AuditEntry>[];
    final q = _query.toLowerCase();
    final entries = all.where((e) {
      if (_onlyArchived && !(e.isRetire || e.kind == 'delete')) return false;
      if (q.isEmpty) return true;
      return '${e.title} ${e.actorEmail} ${e.changes.map((c) => c.$1).join(' ')}'
          .toLowerCase()
          .contains(q);
    }).toList();
    final selected =
        entries.where((e) => e.id == _selectedId).firstOrNull ??
        entries.firstOrNull;
    bool canRestore(AuditEntry e) =>
        e.restorable &&
        session.can(StaffSection.history, StaffAction.view) &&
        (StaffSection.fromKey(e.section) == null ||
            session.can(StaffSection.fromKey(e.section)!, StaffAction.edit));

    final list = Container(
      decoration: AppTheme.cardDeco(),
      child: async.isLoading && all.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          : entries.isEmpty
          ? const EmptyState(
              icon: Icons.history_rounded,
              title: 'Aún no hay cambios anotados',
              message:
                  'Desde ahora, cada cambio en preguntas, cursos, plantillas, '
                  'universidades, configuración y personal queda aquí.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, e) in entries.indexed) ...[
                  if (i == 0 || !_sameDay(entries[i - 1].at, e.at))
                    Container(
                      color: AppTheme.subtle,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: Text(
                        _dayLabel(e.at),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.muted,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  _EntryRow(
                    entry: e,
                    selected: identical(e, selected),
                    onTap: () => setState(() => _selectedId = e.id),
                  ),
                ],
              ],
            ),
    );

    final detail = selected == null
        ? const SizedBox.shrink()
        : _Detail(
            entry: selected,
            canRestore: canRestore(selected),
            restoring: _restoring,
            onRestore: () => _restore(selected),
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
      children: [
        AdminPageHeader(
          title: 'Historial de cambios',
          subtitle:
              'Todo lo que se cambia en el admin queda aquí: quién, cuándo, qué '
              'había antes y qué hay ahora. Se puede deshacer.',
          actions: [
            SizedBox(
              width: 320,
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                  hintText: 'Buscar pregunta, curso, ajuste o persona',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final (key, label) in _filters)
              ChoiceChip(
                label: Text(label),
                selected: _section == key && !_onlyArchived,
                onSelected: (_) => setState(() {
                  _section = key;
                  _onlyArchived = false;
                  _selectedId = null;
                }),
              ),
            ChoiceChip(
              label: const Text('Archivados y eliminados'),
              selected: _onlyArchived,
              onSelected: (_) => setState(() {
                _onlyArchived = !_onlyArchived;
                _selectedId = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 1000) {
              return Column(
                children: [detail, const SizedBox(height: 12), list],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: list),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: detail),
              ],
            );
          },
        ),
      ],
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  static String _dayLabel(DateTime? t) {
    if (t == null) return 'AHORA';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'HOY';
    if (diff == 1) return 'AYER';
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${t.day} ${months[t.month - 1]}'.toUpperCase();
  }
}

const _fieldLabels = {
  'name': 'Nombre',
  'active': 'Visible para alumnos',
  'status': 'Estado',
  'statementText': 'Enunciado',
  'examTemplateId': 'Plantilla de examen',
  'masteryTemplateId': 'Examen de dominio',
  'linkVideo': 'Video',
  'linkPdf': 'PDF',
  'content': 'Contenido',
  'summary': 'Resumen',
  'order': 'Orden',
  'roleId': 'Perfil',
  'difficulty': 'Dificultad',
  'partIds': 'Partes',
  'listPart': 'Parte',
  'review.status': 'Revisión',
  'questionCount': 'Preguntas',
  'title': 'Título',
};

const _valueLabels = {
  'published': 'Publicada',
  'retired': 'Archivada',
  'draft': 'Borrador',
  'pending': 'En revisión',
  'returned': 'Devuelta',
};

/// «Suben de liga» en vez de «league.promotePercent».
String humanField(AuditEntry e, String field) {
  if (e.kindKey == 'config') {
    final docId = e.path.split('/').last;
    final id = docId == 'simulator' && field.startsWith('plan.')
        ? 'plan.${field.substring(5)}'
        : '$docId.$field';
    final spec = specById(id);
    if (spec != null) return spec.shortLabel;
  }
  final part = RegExp(r'^listPart «(.+)»(?:\.(.+))?$').firstMatch(field);
  if (part != null) {
    final sub = part.group(2);
    return 'Parte «${part.group(1)}»'
        '${sub == null ? '' : ' · ${_fieldLabels[sub] ?? sub}'}';
  }
  return _fieldLabels[field] ?? field;
}

String humanValue(String v) => _valueLabels[v] ?? v;

String _time(DateTime? t) => t == null
    ? '—'
    : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _sectionLabel = {
  'questions': 'Banco de preguntas',
  'courses': 'Cursos',
  'universities': 'Universidades',
  'news': 'Noticias',
  'settings': 'Configuración',
  'staff': 'Personal',
};

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final AuditEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final first = e.changes.firstOrNull;
    return Material(
      color: selected ? AppTheme.brandTint : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.rowLine),
              left: BorderSide(
                color: selected ? AppTheme.brand : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(15, 12, 18, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  _time(e.at),
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: e.actorLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: ' ${e.verb} '),
                          TextSpan(
                            text: e.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (e.kind == 'update' &&
                              first != null &&
                              !e.isRetire)
                            TextSpan(
                              text:
                                  ' · ${humanField(e, first.$1)}: ${humanValue(first.$2)} → ${humanValue(first.$3)}'
                                  '${e.changes.length > 1 ? ' (+${e.changes.length - 1})' : ''}',
                              style: TextStyle(color: AppTheme.body),
                            ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sectionLabel[e.section] ?? e.section,
                      style: TextStyle(fontSize: 12, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              if (e.kind == 'restore')
                const StatusPill('restaurado', tone: Tone.info)
              else if (e.isRetire)
                const StatusPill('archivado', tone: Tone.warn)
              else if (e.kind == 'delete')
                const StatusPill('eliminado', tone: Tone.error)
              else if (e.kind == 'create')
                const StatusPill('nuevo', tone: Tone.success),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.entry,
    required this.canRestore,
    required this.restoring,
    required this.onRestore,
  });

  final AuditEntry entry;
  final bool canRestore;
  final bool restoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final head = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppTheme.muted,
    );
    final recover = e.isRetire || e.kind == 'delete';
    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_time(e.at)} · ${e.actorLabel}',
            style: TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 2),
          Text(
            e.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (e.changes.isEmpty)
            Text(switch (e.kind) {
              'create' => 'Se creó este elemento.',
              'delete' => 'Se eliminó este elemento.',
              _ => 'Sin cambios visibles.',
            }, style: TextStyle(color: AppTheme.body))
          else
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: AppTheme.subtle),
                    children: [
                      for (final h in ['Campo', 'Antes', 'Ahora'])
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(h, style: head),
                        ),
                    ],
                  ),
                  for (final (field, before, after) in e.changes)
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppTheme.rowLine),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            humanField(e, field),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Container(
                          color: AppTheme.errorSoft,
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            humanValue(before),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.error,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        Container(
                          color: AppTheme.successSoft,
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            humanValue(after),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          if (e.section == 'settings')
            const InfoNote(
              'La app lo aplica la próxima vez que lee la configuración '
              '(normalmente al abrirse). Las ligas usan los valores nuevos '
              'desde el próximo cierre de semana.',
            ),
          const SizedBox(height: 12),
          if (canRestore)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: restoring ? null : onRestore,
                icon: Icon(
                  recover
                      ? Icons.restore_from_trash_rounded
                      : Icons.undo_rounded,
                  size: 18,
                ),
                label: Text(
                  restoring
                      ? 'Restaurando…'
                      : (recover ? 'Recuperar' : 'Restaurar valor anterior'),
                ),
              ),
            )
          else if (!e.restorable)
            Text(
              e.kind == 'create'
                  ? 'Para deshacer una creación, elimínalo desde su sección.'
                  : (e.tooLarge
                        ? 'Este cambio es demasiado grande para restaurarlo aquí.'
                        : 'Una pregunta publicada no se restaura así: edítala y '
                              'publica una versión nueva.'),
              style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
            ),
          const SizedBox(height: 8),
          Text(
            'Restaurar también queda registrado aquí, así que se puede volver a '
            'deshacer.',
            style: TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}
