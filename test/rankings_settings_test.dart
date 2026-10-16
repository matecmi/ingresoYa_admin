import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/rankings_repo.dart';
import 'package:ingresoya_admin/src/data/repo/xp_repo.dart';
import 'package:ingresoya_admin/src/domain/rankings_settings.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/rankings_settings_card.dart';

// Thursday 2026-10-15, 10:00 in Lima.
final _now = DateTime.utc(2026, 10, 15, 15);

void main() {
  test('rankings settings: off by default, parse, validate, round-trip', () {
    expect(RankingsSettings.defaults.enabled, isFalse);
    expect(RankingsSettings.defaults.stageNames.last, 'Ingresante');
    final parsed = RankingsSettings.fromMap({
      'enabled': true,
      'startWeek': '2026-10-19',
      'bannedWords': ['Tonto', 3, 'x'],
      'league': {'groupSize': 2, 'promotePercent': 20},
      'challenge': {'questionCount': 8, 'ownPastExamQuestions': 12},
    });
    expect(parsed.groupSize, 30);
    expect(parsed.promotePercent, 20);
    expect(parsed.bannedWords, ['tonto']);
    expect(parsed.ownPastExamQuestions, 8);
    expect(RankingsSettings.fromMap(parsed.toMap()).toMap(), parsed.toMap());
    expect(
      const RankingsSettings(stageNames: ['Uno']).validate(),
      contains('etapas'),
    );
    expect(
      const RankingsSettings(
        questionCount: 5,
        ownPastExamQuestions: 6,
      ).validate(),
      contains('exámenes pasados'),
    );
    expect(nextPeruMonday(_now), '2026-10-19');
    expect(currentPeruMonday(_now), '2026-10-12');
    expect(foldAlias('Búho_Ñandú'), 'buho_nandu');
  });

  test('turning rankings on starts the league next Monday', () async {
    final db = FakeFirebaseFirestore();
    final repo = RankingsRepo(db);
    await repo.saveSettings(
      const RankingsSettings(enabled: true),
      editor: 'a',
      now: _now,
    );
    final doc = db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.rankingsSettingsDocument);
    expect((await doc.get()).data()!['startWeek'], '2026-10-19');
    // Saving again keeps the start week.
    await repo.saveSettings(
      const RankingsSettings(enabled: true, groupSize: 20),
      editor: 'a',
      now: _now.add(const Duration(days: 10)),
    );
    expect((await doc.get()).data()!['startWeek'], '2026-10-19');
    expect(((await doc.get()).data()!['league'] as Map)['groupSize'], 20);
  });

  test(
    'reverting XP keeps the week card and the league seat in step',
    () async {
      final db = FakeFirebaseFirestore();
      final user = db.collection(AppEnv.usersCollection).doc('u1');
      await user.collection('xp').doc('current').set({
        'total': 400,
        'rankStep': 2,
        'week': {'key': '2026-10-12', 'xp': 120},
      });
      await user.collection('xpEvents').doc('part_passed_p1').set({
        'type': 'part_passed',
        'xp': 40,
        'day': '2026-10-15',
        'week': '2026-10-12',
        'atMs': 1,
      });
      final card = db.collection(AppEnv.leaderboardCollection).doc('u1');
      await card.set({
        'alias': 'Búho_9',
        'weekKey': '2026-10-12',
        'weekXp': 120,
        'rankStep': 2,
      });
      final seat = db
          .collection(AppEnv.leagueMembersCollection)
          .doc('2026-10-12_u1');
      await seat.set({'alias': 'Búho_9', 'weekXp': 120, 'groupId': 'g1'});
      await XpRepo(
        db,
      ).revert('u1', 'part_passed_p1', reason: 'Prueba', editor: 'a');
      expect((await card.get()).data()!['weekXp'], 80);
      expect((await seat.get()).data()!['weekXp'], 80);
    },
  );

  test('removing a username frees it and leaves a note for the app', () async {
    final db = FakeFirebaseFirestore();
    final repo = RankingsRepo(db);
    final user = db.collection(AppEnv.usersCollection).doc('u1');
    await user.collection('ranking').doc('current').set({'alias': 'Búho_9'});
    await db.collection(AppEnv.aliasesCollection).doc('buho_9').set({
      'uid': 'u1',
    });
    await db.collection(AppEnv.leaderboardCollection).doc('u1').set({
      'alias': 'Búho_9',
      'weekXp': 30,
      'universityAcronym': 'UNPRG',
    });
    final found = await repo.findUsername('BUHO_9');
    expect(found?.uid, 'u1');
    expect(found?.career, 'UNPRG');
    await expectLater(
      repo.removeUsername('u1', 'Búho_9', reason: '', editor: 'a'),
      throwsStateError,
    );
    await repo.removeUsername(
      'u1',
      'Búho_9',
      reason: 'parece un nombre',
      editor: 'a',
    );
    expect(
      (await db.collection(AppEnv.aliasesCollection).doc('buho_9').get())
          .exists,
      isFalse,
    );
    final choice = (await user.collection('ranking').doc('current').get())
        .data()!;
    expect(choice['alias'], isNull);
    expect(choice['moderatedReason'], 'parece un nombre');
    expect(
      (await db.collection(AppEnv.leaderboardCollection).doc('u1').get())
          .data()!['alias'],
      isNull,
    );
  });

  test(
    'a challenge question can be swapped only before anyone submits',
    () async {
      final db = FakeFirebaseFirestore();
      final repo = RankingsRepo(db);
      await db
          .collection(AppEnv.dailyChallengesCollection)
          .doc('2026-10-15_u1')
          .set({
            'day': '2026-10-15',
            'universityId': 'u1',
            'questionIds': ['q1', 'q2'],
            'ownPastExamCount': 1,
          });
      await db.collection(AppEnv.questionsCollection).doc('q9').set({
        'status': 'published',
      });
      await db.collection(AppEnv.questionsCollection).doc('q8').set({
        'status': 'draft',
      });
      final challenge = (await repo.challenges('2026-10-15')).single;
      expect(challenge.ownPastExamCount, 1);
      await expectLater(
        repo.swapChallengeQuestion(challenge, 'q1', 'q8'),
        throwsStateError,
      );
      await repo.swapChallengeQuestion(challenge, 'q1', 'q9');
      final updated = (await repo.challenges('2026-10-15')).single;
      expect(updated.questionIds, ['q9', 'q2']);
      await db
          .collection(AppEnv.challengeEntriesCollection)
          .doc('2026-10-15_s1')
          .set({'day': '2026-10-15', 'universityId': 'u1'});
      await expectLater(
        repo.swapChallengeQuestion(updated, 'q2', 'q1'),
        throwsStateError,
      );
    },
  );

  testWidgets('the card turns rankings on and saves the rules', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    tester.view.physicalSize = const Size(1200, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [rankingsRepoProvider.overrideWithValue(RankingsRepo(db))],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RankingsSettingsCard(
                settings: RankingsSettings.defaults,
                now: _now,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alumnos que ganaron XP esta semana: 0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rankings-enabled')));
    await tester.pump();
    expect(find.textContaining('2026-10-19'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('rankings-bonusXp')),
        matching: find.byType(TextField),
      ),
      '25',
    );
    await tester.tap(find.byKey(const ValueKey('rankings-save')));
    await tester.pumpAndSettle();
    final doc = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.rankingsSettingsDocument)
        .get();
    expect(doc.data()!['enabled'], isTrue);
    expect(doc.data()!['startWeek'], '2026-10-19');
    expect((doc.data()!['challenge'] as Map)['bonusXp'], 25);
  });
}
