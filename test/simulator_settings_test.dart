import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/app_config_repo.dart';
import 'package:ingresoya_admin/src/domain/simulator_settings.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/simulator_settings_card.dart';

void main() {
  test('sin documento o con datos inválidos usa los valores de fábrica', () {
    final defaults = SimulatorSettings.fromMap(null);
    expect(defaults.practiceSizes.map((s) => s.questions), [10, 20, 40]);
    expect(defaults.practiceSizes.singleWhere((s) => s.isDefault).key, 'normal');
    expect(defaults.repeatWindowDays, 14);

    final partial = SimulatorSettings.fromMap({
      'practiceSizes': [
        {'key': 'x'},
      ],
      'defaultSource': 'otra',
      'practicePenalty': true,
      'repeatWindowDays': 7,
    });
    expect(partial.practiceSizes.length, 3);
    expect(partial.defaultSource, 'both');
    expect(partial.practicePenalty, isTrue);
    expect(partial.repeatWindowDays, 7);
  });

  test('valida tamaños, un solo por defecto y días', () {
    expect(SimulatorSettings.defaults.validate(), isNull);
    const short = PracticeSize(
      key: 'a',
      label: 'A',
      questions: 5,
      minutes: 10,
      isDefault: true,
    );
    expect(
      SimulatorSettings.defaults.copyWith(practiceSizes: [short]).validate(),
      contains('entre 10'),
    );
    expect(
      SimulatorSettings.defaults
          .copyWith(
            practiceSizes: [
              short.copyWith(questions: 10),
              short.copyWith(questions: 20),
            ],
          )
          .validate(),
      contains('misma clave'),
    );
    expect(
      SimulatorSettings.defaults
          .copyWith(
            practiceSizes: SimulatorSettings.defaultSizes
                .map((s) => s.copyWith(isDefault: false))
                .toList(),
          )
          .validate(),
      contains('exactamente un'),
    );
    expect(
      SimulatorSettings.defaults.copyWith(repeatWindowDays: 400).validate(),
      isNotNull,
    );
  });

  test('guardar escribe el documento y lo vuelve a leer igual', () async {
    final db = FakeFirebaseFirestore();
    final repo = AppConfigRepo(db);
    final settings = SimulatorSettings.defaults.copyWith(
      repeatWindowDays: 30,
      showOtherUniversities: false,
    );
    await repo.saveSimulatorSettings(settings, editor: 'admin@ingresoya.test');
    final stored = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.simulatorSettingsDocument)
        .get();
    expect(stored.data(), containsPair('repeatWindowDays', 30));
    expect(stored.data(), containsPair('updatedBy', 'admin@ingresoya.test'));
    final read = await repo.watchSimulatorSettings().first;
    expect(read.exists, isTrue);
    expect(read.settings.showOtherUniversities, isFalse);
    expect(read.settings.practiceSizes.length, 3);

    await expectLater(
      repo.saveSimulatorSettings(
        settings.copyWith(repeatWindowDays: -1),
        editor: 'x',
      ),
      throwsStateError,
    );
  });

  testWidgets('la tarjeta guarda un tamaño editado', (tester) async {
    final db = FakeFirebaseFirestore();
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigRepoProvider.overrideWithValue(AppConfigRepo(db))],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: SimulatorSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Usando valores por defecto'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('size-questions-short')),
      '12',
    );
    await tester.tap(find.byKey(const ValueKey('sim-save')));
    await tester.pumpAndSettle();
    final stored = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.simulatorSettingsDocument)
        .get();
    final sizes = stored.data()!['practiceSizes'] as List;
    expect((sizes.first as Map)['questions'], 12);
  });
}
