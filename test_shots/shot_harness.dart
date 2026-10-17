import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/domain/staff.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/admin_router.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

/// Arnés de capturas del admin: pinta una ruta con datos falsos y la guarda
/// en `test_shots/out/<name>.png`. No forma parte de `flutter test`; se corre
/// con `flutter test test_shots --update-goldens`.
Future<void> loadShotFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await family(AppTheme.fontFamily, [
    for (final w in [400, 500, 600, 700, 800])
      'assets/fonts/PlusJakartaSans-$w.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter';
  await family('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ]);
  await family('Roboto', [
    for (final w in [400, 500, 700, 900]) 'assets/fonts/Roboto-$w.ttf',
  ]);
}

Future<void> shot(
  WidgetTester tester, {
  required String name,
  required String location,
  required FakeFirebaseFirestore db,
  Size size = const Size(1440, 1000),
  Future<void> Function(WidgetTester tester)? act,
  AdminSession? session,
  StaffRole? preview,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = buildAdminRouter(
    initialLocation: location,
    userLabel: 'kevin@ingresoya.test',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseFirestoreProvider.overrideWithValue(db),
        functionsProvider.overrideWithValue(null),
        if (session != null)
          adminSessionProvider.overrideWith(() => _FixedSession(session)),
        if (preview != null)
          staffPreviewProvider.overrideWith(() => _FixedPreview(preview)),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  if (act != null) {
    await act(tester);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }
  await _precacheImages(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

/// Las imágenes de assets se decodifican fuera del reloj falso del test.
Future<void> _precacheImages(WidgetTester tester) async {
  final elements = find.byType(Image).evaluate().toList();
  if (elements.isEmpty) return;
  await tester.runAsync(() async {
    for (final el in elements) {
      await precacheImage((el.widget as Image).image, el);
    }
  });
  await tester.pump(const Duration(milliseconds: 100));
}

Object? _decode(Object? v, FakeFirebaseFirestore db) {
  if (v is Map) {
    if (v.containsKey('__ts')) {
      return Timestamp.fromMillisecondsSinceEpoch(v['__ts'] as int);
    }
    if (v.containsKey('__ref')) return db.doc(v['__ref'] as String);
    return v.map((k, x) => MapEntry(k as String, _decode(x, db)));
  }
  if (v is List) return v.map((x) => _decode(x, db)).toList();
  return v;
}

/// Muestra de TEST leída con la cuenta de servicio (no va al repo):
/// `test_shots/fixtures/test_sample.json`. Si falta, devuelve una base vacía.
Future<FakeFirebaseFirestore> sampleDb() async {
  final db = FakeFirebaseFirestore();
  final file = File('test_shots/fixtures/test_sample.json');
  if (!file.existsSync()) return db;
  final docs = jsonDecode(file.readAsStringSync()) as List;
  for (final raw in docs) {
    final m = raw as Map<String, dynamic>;
    await db
        .doc(m['path'] as String)
        .set(_decode(m['data'], db) as Map<String, dynamic>);
  }
  return db;
}

class _FixedSession extends AdminSessionNotifier {
  _FixedSession(this.value);
  final AdminSession value;
  @override
  AdminSession build() => value;
}

class _FixedPreview extends StaffPreviewNotifier {
  _FixedPreview(this.value);
  final StaffRole value;
  @override
  StaffRole? build() => value;
}

/// Sesión de un Editor de contenido (perfil de fábrica).
AdminSession editorSession() => AdminSession(
  uid: 'editor-lucia',
  email: 'lucia@ingresoya.test',
  roleId: 'editor',
  perms: builtinStaffRoles.firstWhere((r) => r.id == 'editor').perms,
);

/// Captura de un widget suelto (sin el marco del admin).
Future<void> shotWidget(
  WidgetTester tester, {
  required String name,
  required Widget child,
  Size size = const Size(420, 880),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}
