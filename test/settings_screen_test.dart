import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/admin_router.dart';
import 'package:ingresoya_admin/src/ui/theme/app_theme.dart';

void main() {
  testWidgets('cambiar «Suben de liga» y guardar escribe el documento', (
    t,
  ) async {
    t.view.physicalSize = const Size(1440, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final db = FakeFirebaseFirestore();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          firebaseFirestoreProvider.overrideWithValue(db),
          functionsProvider.overrideWithValue(null),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: buildAdminRouter(
            initialLocation: '/settings',
            userLabel: 'kevin@ingresoya.test',
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(
      find.text('¿Qué porcentaje del grupo sube de etapa?'),
      findsOneWidget,
    );

    final field = find.descendant(
      of: find
          .ancestor(
            of: find.text('¿Qué porcentaje del grupo sube de etapa?'),
            matching: find.byType(Container),
          )
          .first,
      matching: find.byType(TextField),
    );
    await t.enterText(field, '20');
    await t.pump();
    expect(find.text('1 cambio sin guardar'), findsOneWidget);
    expect(
      find.textContaining('En un grupo de 30, los 6 primeros suben'),
      findsWidgets,
    );

    await t.tap(find.text('Guardar en TEST'));
    await t.pumpAndSettle();
    final doc = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.rankingsSettingsDocument)
        .get();
    expect((doc.data()!['league'] as Map)['promotePercent'], 20);
    expect(find.text('1 cambio sin guardar'), findsNothing);
  });
}
