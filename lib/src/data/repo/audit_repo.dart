import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../env/app_env.dart';

/// Un cambio del historial (docs/admin_audit_contract.md).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.at,
    required this.actorEmail,
    required this.actorIsSystem,
    required this.kind,
    required this.section,
    required this.kindKey,
    required this.title,
    required this.path,
    required this.changes,
    required this.statusBefore,
    required this.statusAfter,
    required this.hasBefore,
    required this.hasAfter,
    required this.tooLarge,
  });

  final String id;
  final DateTime? at;
  final String actorEmail;
  final bool actorIsSystem;

  /// `create`, `update`, `delete` o `restore`.
  final String kind;

  /// `questions`, `courses`, `universities`, `settings` o `staff`.
  final String section;
  final String kindKey;
  final String title;
  final String path;
  final List<(String, String, String)> changes;
  final String statusBefore;
  final String statusAfter;
  final bool hasBefore;
  final bool hasAfter;
  final bool tooLarge;

  bool get isRetire => statusBefore == 'published' && statusAfter == 'retired';

  /// Se puede deshacer desde el historial (el servidor vuelve a validar).
  bool get restorable {
    if (tooLarge || !hasBefore) return false;
    if (kindKey == 'questions') {
      return isRetire ||
          (statusBefore == 'draft' &&
              (statusAfter == 'draft' || statusAfter.isEmpty));
    }
    return true;
  }

  String get actorLabel =>
      actorIsSystem ? 'Sistema' : (actorEmail.isEmpty ? 'Alguien' : actorEmail);

  String get verb => switch (kind) {
    'create' => 'creó',
    'delete' => 'eliminó',
    'restore' => 'restauró',
    _ => isRetire ? 'archivó' : 'cambió',
  };

  factory AuditEntry.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    final actor = data['actor'] is Map ? data['actor'] as Map : const {};
    final at = data['at'];
    return AuditEntry(
      id: d.id,
      at: at is Timestamp ? at.toDate() : null,
      actorEmail: '${actor['email'] ?? ''}',
      actorIsSystem: actor['type'] == 'system',
      kind: '${data['kind'] ?? 'update'}',
      section: '${data['section'] ?? ''}',
      kindKey: '${data['kindKey'] ?? ''}',
      title: '${data['title'] ?? ''}',
      path: '${data['path'] ?? ''}',
      changes: [
        for (final c in (data['changes'] as List? ?? const []))
          if (c is Map) ('${c['field']}', '${c['before']}', '${c['after']}'),
      ],
      statusBefore: '${data['statusBefore'] ?? ''}',
      statusAfter: '${data['statusAfter'] ?? ''}',
      hasBefore: data['before'] is Map,
      hasAfter: data['after'] is Map,
      tooLarge: data['tooLarge'] == true,
    );
  }
}

class AuditRepo {
  AuditRepo(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions? _functions;

  Stream<List<AuditEntry>> watch({String? section, int limit = 200}) {
    Query<Map<String, dynamic>> q = _db.collection(AppEnv.auditCollection);
    if (section != null) q = q.where('section', isEqualTo: section);
    return q
        .orderBy('at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(AuditEntry.fromDoc).toList());
  }

  /// Deshace un cambio. `force` pisa cambios posteriores.
  Future<void> restore(String entryId, {bool force = false}) async {
    final functions = _functions;
    if (functions == null) throw StateError('Functions not available');
    await functions.httpsCallable('restoreAuditEntry').call({
      'entryId': entryId,
      'force': force,
    });
  }
}

/// Mensaje claro para cada `reason` de `restoreAuditEntry`.
String auditErrorMessage(Object error) {
  final details = error is FirebaseFunctionsException ? error.details : null;
  final reason = details is Map ? details['reason'] : null;
  return switch (reason) {
    'changed_since' =>
      'Cambió después de este registro. Si restauras igual, se pierden los '
          'cambios posteriores.',
    'creation_restore_unsupported' =>
      'Para deshacer una creación, elimínalo desde su sección.',
    'question_restore_unsupported' =>
      'Una pregunta publicada no se restaura así: edítala y publica una '
          'versión nueva.',
    'too_large' => 'Este cambio es demasiado grande para restaurarlo aquí.',
    'staff_forbidden' => 'Tu perfil no puede restaurar en esa sección.',
    _ => 'No se pudo restaurar. Vuelve a intentarlo.',
  };
}
