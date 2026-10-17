import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/staff.dart';

import 'shot_harness.dart';

Future<FakeFirebaseFirestore> staffDb() async {
  final db = await sampleDb();
  final now = Timestamp.now();
  await db.doc('iya-admin-staff-test/kevin').set({
    'email': 'kevin@ingresoya.test',
    'name': 'Kevin',
    'roleId': 'owner',
    'status': 'active',
    'lastSeenAt': now,
  });
  await db.doc('iya-admin-staff-test/editor-lucia').set({
    'email': 'lucia@ingresoya.test',
    'name': 'Lucía R.',
    'roleId': 'editor',
    'status': 'active',
    'extra': {'questions': 'p'},
    'scope': {
      'courseIds': ['qa-fis'],
    },
    'lastSeenAt': Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 1)),
    ),
  });
  await db.doc('iya-admin-invites-test/marco@ingresoya.test').set({
    'email': 'marco@ingresoya.test',
    'roleId': 'reviewer',
    'expiresAt': Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 6)),
    ),
  });
  final q = await db.collection('iya-questions-test').limit(3).get();
  await q.docs[0].reference.update({
    'status': 'draft',
    'review': {
      'status': 'pending',
      'requestedBy': 'editor-lucia',
      'requestedByEmail': 'lucia@ingresoya.test',
      'requestedAt': now,
    },
  });
  await q.docs[1].reference.update({
    'status': 'draft',
    'review': {
      'status': 'returned',
      'requestedBy': 'editor-lucia',
      'note': 'La alternativa D está repetida.',
      'reviewedByEmail': 'marco@ingresoya.test',
    },
  });
  return db;
}

void main() {
  setUpAll(loadShotFonts);

  testWidgets('perfiles dueño', (t) async {
    await shot(t, name: 'f2_perfiles', location: '/staff', db: await staffDb());
  });

  testWidgets('perfiles editar matriz', (t) async {
    await shot(
      t,
      name: 'f2_perfiles_dirty',
      location: '/staff',
      db: await staffDb(),
      act: (t) async => t.tap(find.byType(Checkbox).at(2)),
    );
  });

  testWidgets('invitar', (t) async {
    await shot(
      t,
      name: 'f2_invitar',
      location: '/staff',
      db: await staffDb(),
      act: (t) async => t.tap(find.text('Invitar persona')),
    );
  });

  testWidgets('inicio editor', (t) async {
    await shot(
      t,
      name: 'f2_inicio_editor',
      location: '/',
      db: await staffDb(),
      session: editorSession(),
    );
  });

  testWidgets('inicio dueño con cola', (t) async {
    await shot(t, name: 'f2_inicio_dueno', location: '/', db: await staffDb());
  });

  testWidgets('vista previa', (t) async {
    await shot(
      t,
      name: 'f2_preview',
      location: '/settings',
      db: await staffDb(),
      preview: builtinStaffRoles.firstWhere((r) => r.id == 'editor'),
    );
  });

  testWidgets('sin acceso', (t) async {
    await shot(
      t,
      name: 'f2_sin_acceso',
      location: '/staff',
      db: await staffDb(),
      session: editorSession(),
    );
  });
}
