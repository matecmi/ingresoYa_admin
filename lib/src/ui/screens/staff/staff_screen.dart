import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repo/staff_repo.dart';
import '../../../domain/entities/course_entity.dart';
import '../../../domain/staff.dart';
import '../../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_ui.dart';

final _rolesProvider = StreamProvider.autoDispose<List<StaffRole>>(
  (ref) => ref.watch(staffRepoProvider).watchRoles(),
);
final _membersProvider = StreamProvider.autoDispose<List<StaffMember>>(
  (ref) => ref.watch(staffRepoProvider).watchMembers(),
);
final _invitesProvider = StreamProvider.autoDispose<List<StaffInvite>>(
  (ref) => ref.watch(staffRepoProvider).watchInvites(),
);
final _coursesProvider = StreamProvider.autoDispose<List<CourseEntity>>(
  (ref) => ref.watch(courseRepoProvider).watchCourses(),
);

/// Secciones con «Publicar»: sin él, publicar pide revisión.
const _publishable = {
  StaffSection.questions,
  StaffSection.courses,
  StaffSection.universities,
};

/// Perfiles y permisos (tablero 13 del lienzo).
class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  String _selected = 'editor';
  StaffPerms? _draft;
  bool _saving = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(staffErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(_rolesProvider).value ?? builtinStaffRoles;
    final members = ref.watch(_membersProvider).value ?? const [];
    final invites = ref.watch(_invitesProvider).value ?? const [];
    final canEdit = ref
        .watch(effectiveSessionProvider)
        .can(StaffSection.staff, StaffAction.edit);
    final role = roles.firstWhere(
      (r) => r.id == _selected,
      orElse: () => roles.first,
    );
    final perms = _draft ?? role.perms;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 40),
      children: [
        AdminPageHeader(
          title: 'Perfiles y permisos',
          subtitle:
              'Un perfil es un conjunto de permisos. Asignas un perfil a cada '
              'persona y solo ve las secciones que le tocan. Si alguien '
              'necesita algo puntual, le agregas una excepción sin crear otro '
              'perfil.',
          actions: [
            if (canEdit)
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => _openMemberDialog(roles: roles),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Invitar persona'),
              ),
            if (canEdit)
              FilledButton.icon(
                onPressed: _saving ? null : () => _openRoleDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nuevo perfil'),
              ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final list = _RoleList(
              roles: roles,
              members: members,
              selected: role.id,
              onSelect: (id) => setState(() {
                _selected = id;
                _draft = null;
              }),
            );
            final matrix = _PermissionMatrix(
              role: role,
              perms: perms,
              editable: canEdit && !role.isOwner && !_saving,
              dirty: _draft != null,
              onToggle: (s, a, on) =>
                  setState(() => _draft = perms.toggled(s, a, on)),
              onDiscard: () => setState(() => _draft = null),
              onSave: () => _run(
                () async {
                  await ref
                      .read(staffRepoProvider)
                      .saveRole(
                        roleId: role.id,
                        name: role.name,
                        description: role.description,
                        perms: perms,
                      );
                  if (mounted) setState(() => _draft = null);
                },
                'Perfil «${role.name}» guardado. Sus miembros lo verán al volver a entrar.',
              ),
              onPreview: () {
                ref
                    .read(staffPreviewProvider.notifier)
                    .preview(
                      StaffRole(
                        id: role.id,
                        name: role.name,
                        description: role.description,
                        perms: perms,
                        builtIn: role.builtIn,
                      ),
                    );
                context.go('/');
              },
              onDelete: role.builtIn || !canEdit
                  ? null
                  : () => _run(() async {
                      await ref.read(staffRepoProvider).deleteRole(role.id);
                      if (mounted) setState(() => _selected = 'editor');
                    }, 'Perfil borrado.'),
              onEditInfo: !canEdit || role.isOwner
                  ? null
                  : () => _openRoleDialog(role: role),
            );
            if (!wide) {
              return Column(
                children: [list, const SizedBox(height: 16), matrix],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 300, child: list),
                const SizedBox(width: 16),
                Expanded(child: matrix),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _PeopleCard(
          members: members,
          invites: invites,
          roles: roles,
          canEdit: canEdit && !_saving,
          myUid: ref.watch(adminSessionProvider).uid,
          onChange: (m) => _openMemberDialog(roles: roles, member: m),
          onRevoke: (m) => _confirmRevoke(m),
          onCancelInvite: (i) => _run(
            () => ref.read(staffRepoProvider).cancelInvite(i.email),
            'Invitación cancelada.',
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRevoke(StaffMember m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Quitar el acceso de ${m.displayName}?'),
        content: const Text(
          'Se cierra su sesión y deja de entrar al admin. Sus cambios '
          'anteriores quedan en el historial. Puedes volver a invitarle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar acceso'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => ref.read(staffRepoProvider).revoke(m.uid),
      'Acceso quitado.',
    );
  }

  Future<void> _openRoleDialog({StaffRole? role}) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _RoleInfoDialog(role: role),
    );
    if (result == null) return;
    await _run(
      () async {
        final id = await ref
            .read(staffRepoProvider)
            .saveRole(
              roleId: role?.id,
              name: result.$1,
              description: result.$2,
              perms: role?.perms ?? const StaffPerms({'questions': 'v'}),
            );
        if (mounted) setState(() => _selected = id);
      },
      role == null
          ? 'Perfil creado: ahora marca sus permisos.'
          : 'Perfil guardado.',
    );
  }

  Future<void> _openMemberDialog({
    required List<StaffRole> roles,
    StaffMember? member,
  }) async {
    final courses = ref.read(_coursesProvider).value ?? const [];
    final result = await showDialog<_MemberEdit>(
      context: context,
      builder: (_) => _MemberDialog(
        roles: roles,
        member: member,
        courses: courses,
        callerIsOwner: ref.read(adminSessionProvider).isOwner,
      ),
    );
    if (result == null) return;
    final repo = ref.read(staffRepoProvider);
    if (member == null) {
      await _run(() async {
        final res = await repo.invite(
          email: result.email,
          roleId: result.roleId,
          extra: result.extra,
          scope: result.scope,
        );
        if (res['status'] == 'invited' && mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Invitación lista'),
              content: Text(
                'Cuando ${result.email} entre al admin con su cuenta de Google '
                'tendrá el perfil elegido. La invitación vence en 14 días. '
                'Envíale la dirección del admin por el medio que prefieras.',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        }
      }, 'Listo.');
    } else {
      await _run(
        () => repo.update(
          uid: member.uid,
          roleId: result.roleId,
          extra: result.extra,
          scope: result.scope,
        ),
        'Cambios guardados. Se aplican la próxima vez que entre.',
      );
    }
  }
}

class _RoleList extends StatelessWidget {
  const _RoleList({
    required this.roles,
    required this.members,
    required this.selected,
    required this.onSelect,
  });

  final List<StaffRole> roles;
  final List<StaffMember> members;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final r in roles) ...[
          _RoleCard(
            role: r,
            count: members.where((m) => m.active && m.roleId == r.id).length,
            selected: r.id == selected,
            onTap: () => onSelect(r.id),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final StaffRole role;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.brandTint : AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.brand : AppTheme.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      role.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    count == 1 ? '1 persona' : '$count personas',
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
              if (role.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  role.description,
                  style: TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionMatrix extends StatelessWidget {
  const _PermissionMatrix({
    required this.role,
    required this.perms,
    required this.editable,
    required this.dirty,
    required this.onToggle,
    required this.onDiscard,
    required this.onSave,
    required this.onPreview,
    required this.onDelete,
    required this.onEditInfo,
  });

  final StaffRole role;
  final StaffPerms perms;
  final bool editable;
  final bool dirty;
  final void Function(StaffSection, StaffAction, bool) onToggle;
  final VoidCallback onDiscard;
  final VoidCallback onSave;
  final VoidCallback onPreview;
  final VoidCallback? onDelete;
  final VoidCallback? onEditInfo;

  @override
  Widget build(BuildContext context) {
    final head = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppTheme.muted,
    );
    return Container(
      decoration: AppTheme.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${role.name} · qué puede hacer',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    if (onEditInfo != null)
                      TextButton(
                        onPressed: onEditInfo,
                        child: const Text('Nombre y descripción'),
                      ),
                    if (onDelete != null)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.error,
                        ),
                        onPressed: onDelete,
                        child: const Text('Borrar perfil'),
                      ),
                    TextButton(
                      onPressed: onPreview,
                      child: const Text('Ver el admin como este perfil →'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (role.isOwner)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: InfoNote(
                'El Dueño puede todo y no se edita. Debe haber al menos uno.',
              ),
            ),
          Container(
            color: AppTheme.subtle,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Sección', style: head)),
                for (final a in StaffAction.values)
                  Expanded(
                    flex: 2,
                    child: Text(
                      a.label,
                      textAlign: TextAlign.center,
                      style: head,
                    ),
                  ),
              ],
            ),
          ),
          for (final s in StaffSection.values)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.rowLine)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          s.hint,
                          style: TextStyle(fontSize: 12, color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                  for (final a in StaffAction.values)
                    Expanded(flex: 2, child: Center(child: _cell(s, a))),
                ],
              ),
            ),
          if (dirty)
            Container(
              color: AppTheme.bar,
              padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cambios sin guardar en este perfil',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: onDiscard,
                    child: const Text('Descartar'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF101828),
                    ),
                    onPressed: onSave,
                    child: const Text('Guardar perfil'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(StaffSection s, StaffAction a) {
    final on = perms.can(s, a);
    final reviewHint =
        a == StaffAction.publish &&
        !on &&
        _publishable.contains(s) &&
        perms.can(s, StaffAction.edit);
    if (!editable) {
      if (reviewHint) {
        return Text(
          'pide revisión',
          style: TextStyle(
            color: AppTheme.warn,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        );
      }
      return on
          ? Icon(Icons.check_rounded, color: AppTheme.success, size: 20)
          : Text('—', style: TextStyle(color: AppTheme.faint));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(value: on, onChanged: (v) => onToggle(s, a, v ?? false)),
        if (reviewHint)
          Text(
            'pide revisión',
            style: TextStyle(color: AppTheme.warn, fontSize: 11),
          ),
      ],
    );
  }
}

class _PeopleCard extends StatelessWidget {
  const _PeopleCard({
    required this.members,
    required this.invites,
    required this.roles,
    required this.canEdit,
    required this.myUid,
    required this.onChange,
    required this.onRevoke,
    required this.onCancelInvite,
  });

  final List<StaffMember> members;
  final List<StaffInvite> invites;
  final List<StaffRole> roles;
  final bool canEdit;
  final String myUid;
  final ValueChanged<StaffMember> onChange;
  final ValueChanged<StaffMember> onRevoke;
  final ValueChanged<StaffInvite> onCancelInvite;

  String _roleName(String id) =>
      roles.where((r) => r.id == id).map((r) => r.name).firstOrNull ?? id;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final m in members) {
      final extras = [
        for (final s in StaffSection.values)
          if (m.extra.letters(s).isNotEmpty)
            '${s.label}: ${m.extra.letters(s).replaceAll('v', '').isEmpty ? 'ver' : StaffAction.values.where((a) => a != StaffAction.view && m.extra.letters(s).contains(a.letter)).map((a) => a.label.toLowerCase()).join(', ')}',
      ];
      rows.add(
        _PersonRow(
          title: m.displayName,
          subtitle: m.name.isNotEmpty ? m.email : null,
          role: m.active ? _roleName(m.roleId) : 'Sin acceso',
          notes: [
            if (m.scope.courseIds.isNotEmpty)
              'Solo ${m.scope.courseIds.length} curso(s)',
            if (extras.isNotEmpty) '+ ${extras.join(' · ')}',
          ],
          status: m.active
              ? (m.lastSeenAt == null
                    ? 'aún no entra'
                    : 'activo ${_ago(m.lastSeenAt!)}')
              : 'acceso quitado',
          statusTone: m.active ? Tone.neutral : Tone.error,
          actions: [
            if (canEdit)
              TextButton(
                onPressed: () => onChange(m),
                child: Text(m.active ? 'Cambiar' : 'Devolver acceso'),
              ),
            if (canEdit && m.active && m.uid != myUid)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                onPressed: () => onRevoke(m),
                child: const Text('Quitar acceso'),
              ),
          ],
        ),
      );
    }
    for (final i in invites) {
      final days = i.expiresAt?.difference(DateTime.now()).inDays;
      rows.add(
        _PersonRow(
          title: i.email,
          subtitle: 'invitación enviada',
          role: _roleName(i.roleId),
          notes: const [],
          status: days == null
              ? 'pendiente'
              : (days < 0 ? 'vencida' : 'vence en $days días'),
          statusTone: Tone.warn,
          actions: [
            if (canEdit)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                onPressed: () => onCancelInvite(i),
                child: const Text('Cancelar'),
              ),
          ],
        ),
      );
    }
    return SectionCard(
      title: 'Personas con acceso',
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: rows.isEmpty
          ? const EmptyState(
              title: 'Aún no hay nadie registrado',
              message:
                  'Tu ficha se crea la primera vez que entras con los permisos '
                  'nuevos. Invita a alguien con «Invitar persona».',
            )
          : Column(children: rows),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return 'hace un momento';
    if (d.inHours < 24) return 'hoy';
    if (d.inDays == 1) return 'ayer';
    return 'hace ${d.inDays} días';
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.title,
    required this.role,
    required this.notes,
    required this.status,
    required this.statusTone,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String role;
  final List<String> notes;
  final String status;
  final Tone statusTone;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.rowLine)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role),
                for (final n in notes)
                  Text(
                    n,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warn,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          StatusPill(status, tone: statusTone),
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );
  }
}

class _RoleInfoDialog extends StatefulWidget {
  const _RoleInfoDialog({this.role});

  final StaffRole? role;

  @override
  State<_RoleInfoDialog> createState() => _RoleInfoDialogState();
}

class _RoleInfoDialogState extends State<_RoleInfoDialog> {
  late final _name = TextEditingController(text: widget.role?.name ?? '');
  late final _desc = TextEditingController(
    text: widget.role?.description ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.role == null ? 'Nuevo perfil' : 'Editar perfil'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej.: Profesor de Física',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              maxLength: 160,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Para qué sirve',
                hintText: 'Ej.: Carga y edita preguntas de Física.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().length < 2) return;
            Navigator.pop(context, (_name.text.trim(), _desc.text.trim()));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _MemberEdit {
  const _MemberEdit({
    required this.email,
    required this.roleId,
    required this.extra,
    required this.scope,
  });

  final String email;
  final String roleId;
  final StaffPerms extra;
  final StaffScope scope;
}

class _MemberDialog extends StatefulWidget {
  const _MemberDialog({
    required this.roles,
    required this.courses,
    required this.callerIsOwner,
    this.member,
  });

  final List<StaffRole> roles;
  final List<CourseEntity> courses;
  final bool callerIsOwner;
  final StaffMember? member;

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  late final _email = TextEditingController(text: widget.member?.email ?? '');
  late String _roleId = widget.member?.roleId ?? 'editor';
  late StaffPerms _extra = widget.member?.extra ?? const StaffPerms.none();
  late Set<String> _courses = {...?widget.member?.scope.courseIds};
  late bool _limit = _courses.isNotEmpty;
  bool _showExtra = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roles = [
      for (final r in widget.roles)
        if (!r.isOwner || widget.callerIsOwner) r,
    ];
    final role = roles.where((r) => r.id == _roleId).firstOrNull;
    return AlertDialog(
      title: Text(
        widget.member == null
            ? 'Invitar persona'
            : 'Cambiar a ${widget.member!.displayName}',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.member == null) ...[
                TextField(
                  controller: _email,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Correo de Google',
                    hintText: 'nombre@gmail.com',
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                initialValue: role?.id,
                decoration: const InputDecoration(labelText: 'Perfil'),
                items: [
                  for (final r in roles)
                    DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: (v) => setState(() => _roleId = v ?? _roleId),
              ),
              if (role != null && role.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    role.description,
                    style: TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ),
              if (_roleId != 'owner') ...[
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _limit,
                  title: const Text('Limitar a ciertos cursos'),
                  subtitle: const Text(
                    'Ej.: un profesor de Física solo ve y edita Física.',
                  ),
                  onChanged: (v) => setState(() => _limit = v),
                ),
                if (_limit)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in widget.courses)
                        FilterChip(
                          label: Text(c.name),
                          selected: _courses.contains(c.id),
                          onSelected: (on) => setState(() {
                            _courses = {..._courses};
                            on ? _courses.add(c.id) : _courses.remove(c.id);
                          }),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                  onPressed: () => setState(() => _showExtra = !_showExtra),
                  icon: Icon(
                    _showExtra
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  label: Text(
                    'Excepciones para esta persona'
                    '${_extra.bySection.isEmpty ? '' : ' (${_extra.bySection.length})'}',
                  ),
                ),
                if (_showExtra)
                  for (final s in StaffSection.values)
                    if (s != StaffSection.staff && s != StaffSection.production)
                      Row(
                        children: [
                          Expanded(child: Text(s.label)),
                          for (final a in StaffAction.values)
                            Tooltip(
                              message: a.label,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Checkbox(
                                    value:
                                        _extra.can(s, a) ||
                                        (role?.perms.can(s, a) ?? false),
                                    onChanged: (role?.perms.can(s, a) ?? false)
                                        ? null
                                        : (v) => setState(
                                            () => _extra = _extra.toggled(
                                              s,
                                              a,
                                              v ?? false,
                                            ),
                                          ),
                                  ),
                                  Text(
                                    a.letter.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final email = _email.text.trim().toLowerCase();
            if (widget.member == null && !email.contains('@')) {
              setState(() => _error = 'Escribe un correo válido.');
              return;
            }
            Navigator.pop(
              context,
              _MemberEdit(
                email: email,
                roleId: _roleId,
                extra: _roleId == 'owner' ? const StaffPerms.none() : _extra,
                scope: StaffScope(
                  courseIds: _limit && _roleId != 'owner'
                      ? _courses.toList()
                      : const [],
                ),
              ),
            );
          },
          child: Text(widget.member == null ? 'Invitar' : 'Guardar'),
        ),
      ],
    );
  }
}
