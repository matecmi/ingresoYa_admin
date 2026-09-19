import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/university_repo.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:ingresoya_admin/src/ui/screens/universities/widgets/mode_form_dialog.dart';

void main() {
  test(
    'Create, update and retry the same modality without duplicates',
    () async {
      final db = FakeFirebaseFirestore();
      await db.collection(AppEnv.universitiesCollection).doc('uni').set({
        'name': 'Universidad',
      });
      final repo = UniversityRepo(db);
      final id = await repo.upsertMode(
        universityId: 'uni',
        name: ' Ordinario ',
        acronym: ' ORD ',
        active: true,
      );
      final first = (await repo.watchModes('uni').first).single;
      expect(first.name, 'Ordinario');
      expect(first.acronym, 'ORD');
      final reference = db
          .collection(AppEnv.universitiesCollection)
          .doc('uni')
          .collection('modes')
          .doc(id);
      final createdAt = (await reference.get()).data()!['createdAt'];
      await repo.upsertMode(
        universityId: 'uni',
        modeId: id,
        name: 'Extraordinario',
        acronym: 'EXT',
        active: false,
      );
      final second = (await repo.watchModes('uni').first).single;
      expect(second.id, id);
      expect(second.name, 'Extraordinario');
      expect(second.active, false);
      expect((await reference.get()).data()!['createdAt'], createdAt);
      await expectLater(
        repo.upsertMode(
          universityId: 'uni',
          name: ' ',
          acronym: '',
          active: true,
        ),
        throwsArgumentError,
      );
    },
  );

  testWidgets('Save error retains inputs; retry closes only the dialog', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    final repo = UniversityRepo(db);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ModeFormDialog(repo: repo, universityId: 'uni'),
              ),
              child: const Text('Abrir modalidad'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir modalidad'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa el nombre de la modalidad'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Ordinario',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Sigla'), 'ORD');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No se pudo guardar la modalidad'),
      findsOneWidget,
    );
    expect(find.text('Ordinario'), findsOneWidget);
    await db.collection(AppEnv.universitiesCollection).doc('uni').set({
      'name': 'Universidad',
    });
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.byType(ModeFormDialog), findsNothing);
    expect(find.text('Abrir modalidad'), findsOneWidget);
    expect((await repo.watchModes('uni').first).single.active, false);
    expect(tester.takeException(), isNull);
  });
}
