import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/xp_repo.dart';
import 'package:ingresoya_admin/src/domain/xp_settings.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import 'package:ingresoya_admin/src/providers/providers.dart';
import 'package:ingresoya_admin/src/ui/screens/settings/xp_settings_card.dart';

void main() {
  test('factory ladder: 18 steps from 0 to 12 000 with bundled images', () {
    final settings = XpSettings.defaults;
    expect(settings.ranks.length, 18);
    expect(settings.ranks.first.minXp, 0);
    expect(settings.ranks[9].name, 'Zafiro I');
    expect(settings.ranks.last.minXp, 12000);
    expect(settings.validate(), isNull);
    expect(settings.rankStepFor(3450), 9);
  });

  test('invalid fields fall back to factory values', () {
    final parsed = XpSettings.fromMap({
      'dailyCap': 150,
      'amounts': {'partPassed': 0, 'diagnostic': -1},
      'ranks': [
        {'name': 'A', 'minXp': 10, 'image': 'bronze_1'},
      ],
    });
    expect(parsed.dailyCap, 150);
    expect(parsed.amounts['partPassed'], 0);
    expect(parsed.amounts['diagnostic'], 30);
    expect(parsed.ranks.length, 18);
    expect(
      XpSettings.validateRanks(const [
        RankStep(name: 'A', minXp: 0, image: 'bronze_1'),
        RankStep(name: 'B', minXp: 0, image: 'silver_1'),
      ]),
      contains('creciente'),
    );
  });

  test(
    'reverting an event takes its XP back once and recalculates the rank',
    () async {
      final db = FakeFirebaseFirestore();
      final user = db.collection(AppEnv.usersCollection).doc('u1');
      await user.set({
        'profile': {'email': 'alumno@test.com', 'userName': 'Ana'},
      });
      await user.collection('xp').doc('current').set({
        'total': 620,
        'rankStep': 3,
        'week': {'key': '2026-10-12', 'xp': 620},
        'today': {'day': '2026-10-15', 'capped': 10},
      });
      await user.collection('xpEvents').doc('subtopic_mastered_s1').set({
        'type': 'subtopic_mastered',
        'xp': 150,
        'requested': 150,
        'day': '2026-10-15',
        'week': '2026-10-12',
        'atMs': 1,
      });
      final repo = XpRepo(db);
      expect((await repo.findStudents('alumno@test.com')).single.uid, 'u1');
      expect((await repo.findStudents('u1')).single.name, 'Ana');
      await expectLater(
        repo.revert('u1', 'subtopic_mastered_s1', reason: '', editor: 'a'),
        throwsStateError,
      );
      await repo.revert(
        'u1',
        'subtopic_mastered_s1',
        reason: 'Prueba',
        editor: 'a',
      );
      final state = (await user.collection('xp').doc('current').get()).data()!;
      expect(state['total'], 470);
      expect(state['rankStep'], 2);
      expect((state['week'] as Map)['xp'], 470);
      expect((state['today'] as Map)['capped'], 10);
      final event =
          (await user.collection('xpEvents').doc('subtopic_mastered_s1').get())
              .data()!;
      expect(event['reverted'], isTrue);
      expect(event['revertReason'], 'Prueba');
      await expectLater(
        repo.revert(
          'u1',
          'subtopic_mastered_s1',
          reason: 'Otra vez',
          editor: 'a',
        ),
        throwsStateError,
      );
    },
  );

  testWidgets('the card saves an edited amount', (tester) async {
    final db = FakeFirebaseFirestore();
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [xpRepoProvider.overrideWithValue(XpRepo(db))],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: XpSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('xp-amount-partPassed')),
      '45',
    );
    await tester.tap(find.byKey(const ValueKey('xp-save')));
    await tester.pumpAndSettle();
    final doc = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.xpSettingsDocument)
        .get();
    expect((doc.data()!['amounts'] as Map)['partPassed'], 45);
    expect((doc.data()!['ranks'] as List).length, 18);
  });

  test('top 100 settings parse, validate and round-trip', () {
    final parsed = XpSettings.fromMap({
      'leaderboard': {
        'enabled': false,
        'size': 5,
        'universityFilterMin': 3,
        'bannedWords': ['Tonto', 3, 'x'],
      },
    });
    expect(parsed.leaderboard.enabled, isFalse);
    expect(parsed.leaderboard.size, 100);
    expect(parsed.leaderboard.universityFilterMin, 3);
    expect(parsed.leaderboard.bannedWords, ['tonto']);
    expect(
      XpSettings.fromMap(parsed.toMap()).leaderboard.universityFilterMin,
      3,
    );
    expect(
      const LeaderboardSettings(size: 5).validate(),
      contains('Tamaño del top'),
    );
    expect(XpSettings.defaults.starsFor(12000), 0);
    expect(XpSettings.defaults.starsFor(16000), 2);
    expect(foldAlias('Búho_Ñandú'), 'buho_nandu');
  });

  test('reverting keeps the top in step; removing an alias frees it', () async {
    final db = FakeFirebaseFirestore();
    final user = db.collection(AppEnv.usersCollection).doc('u1');
    await user.collection('xp').doc('current').set({
      'total': 400,
      'rankStep': 2,
    });
    await user.collection('xpEvents').doc('part_passed_p1').set({
      'type': 'part_passed',
      'xp': 40,
      'day': '2026-10-15',
      'week': '2026-10-12',
      'atMs': 1,
    });
    await user.collection('ranking').doc('current').set({
      'alias': 'Búho_9',
      'visible': true,
    });
    final top = db.collection(AppEnv.leaderboardCollection);
    await top.doc('u1').set({'alias': 'Búho_9', 'total': 400, 'rankStep': 2});
    await db.collection(AppEnv.aliasesCollection).doc('buho_9').set({
      'uid': 'u1',
    });
    final repo = XpRepo(db);

    await repo.revert('u1', 'part_passed_p1', reason: 'Prueba', editor: 'a');
    expect((await top.doc('u1').get()).data()!['total'], 360);
    expect((await top.doc('u1').get()).data()!['rankStep'], 2);
    expect((await repo.watchTop().first).single.alias, 'Búho_9');

    await repo.removeAlias(
      'u1',
      'Búho_9',
      reason: 'parece un nombre',
      editor: 'a',
    );
    expect((await top.doc('u1').get()).exists, isFalse);
    expect(
      (await db.collection(AppEnv.aliasesCollection).doc('buho_9').get())
          .exists,
      isFalse,
    );
    final choice = (await user.collection('ranking').doc('current').get())
        .data()!;
    expect(choice['alias'], isNull);
    expect(choice['visible'], isFalse);
    expect(choice['moderatedReason'], 'parece un nombre');
  });

  testWidgets('the card saves the top 100 settings', (tester) async {
    final db = FakeFirebaseFirestore();
    tester.view.physicalSize = const Size(1200, 7000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [xpRepoProvider.overrideWithValue(XpRepo(db))],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: XpSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('xp-banned-words')),
      'Tonto, feo',
    );
    await tester.tap(find.byKey(const ValueKey('xp-top-enabled')));
    await tester.tap(find.byKey(const ValueKey('xp-save')));
    await tester.pumpAndSettle();
    final doc = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.xpSettingsDocument)
        .get();
    final board = doc.data()!['leaderboard'] as Map;
    expect(board['enabled'], isFalse);
    expect(board['bannedWords'], ['tonto', 'feo']);
    expect(board['size'], 100);
  });
}
