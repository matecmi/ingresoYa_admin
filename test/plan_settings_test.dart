import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/app_config_repo.dart';
import 'package:ingresoya_admin/src/domain/plan_settings.dart';
import 'package:ingresoya_admin/src/domain/simulator_settings.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/plan_settings_card.dart';

void main() {
  test('missing or invalid fields use the factory plan', () {
    final plan = PlanSettings.fromMap({
      'dailyQuestions': 12,
      'sessionOptions': ['x'],
      'defaultReminderTime': '7pm',
    });
    expect(plan.dailyQuestions, 12);
    expect(plan.sessionOptions, [3, 5, 7]);
    expect(plan.defaultReminderTime, '19:00');
    expect(PlanSettings.fromMap(null).weakSharePercent, 60);
    expect(PlanSettings.defaults.validate(), isNull);
  });

  test('validation explains each wrong value', () {
    expect(
      const PlanSettings(recommendedSessions: 4).validate(),
      contains('recomendadas'),
    );
    expect(
      const PlanSettings(sessionOptions: [3, 3]).validate(),
      contains('sin repetir'),
    );
    expect(const PlanSettings(dailyQuestions: 2).validate(), isNotNull);
    expect(const PlanSettings(weakSharePercent: 120).validate(), isNotNull);
    expect(const PlanSettings(defaultMockDay: 9).validate(), isNotNull);
    expect(
      const PlanSettings(defaultReminderTime: '25:00').validate(),
      contains('HH:mm'),
    );
  });

  test('the plan and the simulator settings never erase each other', () async {
    final db = FakeFirebaseFirestore();
    final repo = AppConfigRepo(db);
    await repo.savePlanSettings(
      const PlanSettings(dailyQuestions: 15),
      editor: 'a',
    );
    await repo.saveSimulatorSettings(
      SimulatorSettings.defaults.copyWith(repeatWindowDays: 7),
      editor: 'a',
    );
    final doc = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.simulatorSettingsDocument)
        .get();
    expect((doc.data()!['plan'] as Map)['dailyQuestions'], 15);
    expect(doc.data()!['repeatWindowDays'], 7);
    expect((await repo.watchPlanSettings().first).dailyQuestions, 15);
    await expectLater(
      repo.savePlanSettings(const PlanSettings(dailyQuestions: 1), editor: 'a'),
      throwsStateError,
    );
  });

  testWidgets('the card saves an edited value', (tester) async {
    final db = FakeFirebaseFirestore();
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigRepoProvider.overrideWithValue(AppConfigRepo(db))],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: PlanSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('plan-dailyQuestions')),
        matching: find.byType(TextField),
      ),
      '12',
    );
    await tester.tap(find.byKey(const ValueKey('plan-save')));
    await tester.pumpAndSettle();
    final doc = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.simulatorSettingsDocument)
        .get();
    expect((doc.data()!['plan'] as Map)['dailyQuestions'], 12);
  });
}
