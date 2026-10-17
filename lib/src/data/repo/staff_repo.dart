import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/staff.dart';
import '../../env/app_env.dart';

/// Lee perfiles, fichas e invitaciones; los cambios van por la callable
/// `manageAdminStaff` (solo las Functions escriben y fijan claims).
class StaffRepo {
  StaffRepo(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions? _functions;

  Stream<List<StaffRole>> watchRoles() {
    return _db.collection(AppEnv.staffRolesCollection).snapshots().map((snap) {
      final byId = {
        for (final r in builtinStaffRoles) r.id: r,
        for (final d in snap.docs) d.id: StaffRole.fromJson(d.id, d.data()),
      };
      final order = builtinStaffRoles.map((r) => r.id).toList();
      final roles = byId.values.toList()
        ..sort((a, b) {
          final ia = order.indexOf(a.id);
          final ib = order.indexOf(b.id);
          if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
          if (ia >= 0) return -1;
          if (ib >= 0) return 1;
          return a.name.compareTo(b.name);
        });
      return roles;
    });
  }

  Stream<List<StaffMember>> watchMembers() {
    return _db
        .collection(AppEnv.staffCollection)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) {
                final seen = d.data()['lastSeenAt'];
                return StaffMember.fromJson(
                  d.id,
                  d.data(),
                  lastSeenAt: seen is Timestamp ? seen.toDate() : null,
                );
              }).toList()..sort((a, b) {
                if (a.active != b.active) return a.active ? -1 : 1;
                return a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                );
              }),
        );
  }

  Stream<List<StaffInvite>> watchInvites() {
    return _db
        .collection(AppEnv.staffInvitesCollection)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final exp = d.data()['expiresAt'];
            return StaffInvite(
              email: (d.data()['email'] as String?) ?? d.id,
              roleId: (d.data()['roleId'] as String?) ?? '',
              expiresAt: exp is Timestamp ? exp.toDate() : null,
            );
          }).toList(),
        );
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    final functions = _functions;
    if (functions == null) {
      throw StateError('Functions not available');
    }
    final result = await functions.httpsCallable(name).call(data);
    final value = result.data;
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  /// Crea la ficha desde una invitación o recalcula los claims. Devuelve si
  /// los claims cambiaron (hay que refrescar el token).
  Future<bool> syncAccess() async {
    final res = await _call('syncAdminAccess', const {});
    return res['changed'] == true;
  }

  Future<Map<String, dynamic>> invite({
    required String email,
    required String roleId,
    StaffPerms extra = const StaffPerms.none(),
    StaffScope scope = const StaffScope(),
  }) => _call('manageAdminStaff', {
    'action': 'invite',
    'email': email,
    'roleId': roleId,
    'extra': extra.toJson(),
    'scope': scope.toJson(),
  });

  Future<void> update({
    required String uid,
    String? roleId,
    StaffPerms? extra,
    StaffScope? scope,
  }) => _call('manageAdminStaff', {
    'action': 'update',
    'uid': uid,
    'roleId': ?roleId,
    if (extra != null) 'extra': extra.toJson(),
    if (scope != null) 'scope': scope.toJson(),
  });

  Future<void> revoke(String uid) =>
      _call('manageAdminStaff', {'action': 'revoke', 'uid': uid});

  Future<void> cancelInvite(String email) =>
      _call('manageAdminStaff', {'action': 'cancelInvite', 'email': email});

  Future<String> saveRole({
    String? roleId,
    required String name,
    required String description,
    required StaffPerms perms,
  }) async {
    final res = await _call('manageAdminStaff', {
      'action': 'saveRole',
      'roleId': ?roleId,
      'name': name,
      'description': description,
      'perms': perms.toJson(),
    });
    return (res['roleId'] as String?) ?? roleId ?? '';
  }

  Future<void> deleteRole(String roleId) =>
      _call('manageAdminStaff', {'action': 'deleteRole', 'roleId': roleId});
}

/// Mensaje claro para cada `reason` de `manageAdminStaff`.
String staffErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final details = error.details;
    final reason = details is Map ? details['reason'] : null;
    switch (reason) {
      case 'owner_only':
        return 'Solo un Dueño puede asignar o quitar el perfil Dueño.';
      case 'last_owner':
        return 'Debe quedar al menos un Dueño.';
      case 'self_revoke':
        return 'No puedes quitarte el acceso a ti mismo.';
      case 'role_in_use':
        return 'Ese perfil todavía tiene personas. Cámbialas de perfil primero.';
      case 'builtin_role':
        return 'Los perfiles de fábrica no se borran (el Dueño tampoco se edita).';
      case 'staff_forbidden':
      case 'not_staff':
        return 'Tu perfil no puede cambiar perfiles y permisos.';
      case 'invalid_email':
        return 'Escribe un correo válido.';
      case 'invalid_scope':
        return 'El alcance admite hasta 20 cursos o universidades.';
      case 'invalid_role':
        return 'El nombre del perfil debe tener entre 2 y 40 letras.';
    }
  }
  return 'No se pudo guardar. Revisa tu conexión y vuelve a intentarlo.';
}
