import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/app_config_repo.dart';
import 'package:ingresoya_admin/src/domain/study_review_rules.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/study_review_rules_card.dart';

void main() {
  test('missing or partial documents fall back to the current rules', () {
    expect(StudyReviewRules.fromMap(null), StudyReviewRules.defaults);
    expect(StudyReviewRules.defaults.videoMinPercent, 60);
    expect(StudyReviewRules.defaults.sectionMinSeconds, 5);
    final partial = StudyReviewRules.fromMap({'strict': false});
    expect(partial.strict, isFalse);
    expect(partial.videoMinPercent, 60);
  });

  test('limits', () {
    expect(StudyReviewRules.defaults.validate(), isNull);
    expect(const StudyReviewRules(sectionMinSeconds: 0).validate(), isNull);
    expect(const StudyReviewRules(videoMinPercent: 0).validate(), isNotNull);
    expect(const StudyReviewRules(videoMinPercent: 101).validate(), isNotNull);
    expect(
      const StudyReviewRules(sectionMinSeconds: 301).validate(),
      isNotNull,
    );
  });

  test('saving writes the config document the app reads', () async {
    final db = FakeFirebaseFirestore();
    final repo = AppConfigRepo(db);

    final before = await repo.watchStudyReviewRules().first;
    expect(before.exists, isFalse);
    expect(before.rules, StudyReviewRules.defaults);

    await repo.saveStudyReviewRules(
      const StudyReviewRules(
        strict: false,
        videoMinPercent: 80,
        sectionMinSeconds: 10,
      ),
      editor: 'admin@ingresoya.test',
    );

    final stored = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.studyReviewRulesDocument)
        .get();
    expect(stored.data(), containsPair('schemaVersion', 1));
    expect(stored.data(), containsPair('strict', false));
    expect(stored.data(), containsPair('videoMinPercent', 80));
    expect(stored.data(), containsPair('sectionMinSeconds', 10));
    expect(stored.data(), containsPair('updatedBy', 'admin@ingresoya.test'));

    final after = await repo.watchStudyReviewRules().first;
    expect(after.exists, isTrue);
    expect(after.rules.strict, isFalse);
  });

  test('invalid values are rejected before writing', () async {
    final db = FakeFirebaseFirestore();
    await expectLater(
      AppConfigRepo(db).saveStudyReviewRules(
        const StudyReviewRules(videoMinPercent: 0),
        editor: 'x',
      ),
      throwsStateError,
    );
    final stored = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.studyReviewRulesDocument)
        .get();
    expect(stored.exists, isFalse);
  });

  testWidgets('turning the rules off locks the minimums', (tester) async {
    final db = FakeFirebaseFirestore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigRepoProvider.overrideWithValue(AppConfigRepo(db))],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: StudyReviewRulesSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Usando valores por defecto'), findsOneWidget);

    TextField field(String key) => tester.widget<TextField>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(TextField),
      ),
    );
    expect(field('study-video-percent').enabled, isTrue);

    await tester.tap(find.byKey(const ValueKey('study-strict')));
    await tester.pump();
    expect(field('study-video-percent').enabled, isFalse);
    expect(field('study-section-seconds').enabled, isFalse);
    expect(find.textContaining('basta con entrar'), findsOneWidget);
  });
}
