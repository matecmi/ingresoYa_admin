import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/audit_repo.dart';
import 'package:ingresoya_admin/src/ui/screens/history/history_screen.dart';

void main() {
  test('qué se puede restaurar y cómo se lee', () async {
    final db = FakeFirebaseFirestore();
    final col = db.collection('iya-admin-audit-test');
    await col.doc('a').set({
      'at': Timestamp.now(),
      'actor': {'email': 'kevin@x.pe', 'type': 'user'},
      'kind': 'update', 'section': 'settings', 'kindKey': 'config',
      'path': 'iya-config-test/rankings', 'title': 'Configuración · Rankings',
      'changes': [{'field': 'league.promotePercent', 'before': '15', 'after': '20'}],
      'before': {'x': 1}, 'after': {'x': 2},
    });
    await col.doc('b').set({
      'at': Timestamp.now(), 'actor': {'type': 'system'},
      'kind': 'update', 'section': 'questions', 'kindKey': 'questions',
      'path': 'iya-questions-test/q', 'statusBefore': 'published', 'statusAfter': 'draft',
      'changes': [], 'before': {'x': 1}, 'after': {'x': 2},
    });
    await col.doc('c').set({
      'at': Timestamp.now(), 'actor': {'type': 'user', 'email': 'a@b.c'},
      'kind': 'create', 'section': 'courses', 'kindKey': 'topics',
      'path': 'iya-courses-test/c/topics/t', 'changes': [], 'before': null, 'after': {'x': 1},
    });
    final entries = {
      for (final d in (await col.get()).docs) d.id: AuditEntry.fromDoc(d),
    };
    expect(entries['a']!.restorable, isTrue);
    expect(entries['a']!.verb, 'cambió');
    expect(humanField(entries['a']!, 'league.promotePercent'), 'Suben de liga');
    expect(entries['b']!.restorable, isFalse);
    expect(entries['b']!.actorLabel, 'Sistema');
    expect(entries['c']!.restorable, isFalse);
    expect(entries['c']!.verb, 'creó');
    expect(humanField(entries['c']!, 'listPart «Caída».active'), 'Parte «Caída» · Visible para alumnos');
    expect(humanValue('retired'), 'Archivada');
  });
}
