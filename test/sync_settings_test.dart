import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ingresoya_admin/src/data/repo/app_config_repo.dart';
import 'package:ingresoya_admin/src/domain/sync_settings.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

void main() {
  test('missing or partial documents fall back to the defaults', () {
    expect(SyncSettings.fromMap(null), SyncSettings.defaults);
    final partial = SyncSettings.fromMap({'debounceSeconds': 30});
    expect(partial.debounceSeconds, 30);
    expect(partial.maxWaitSeconds, 180);
    expect(partial.refreshEveryHours, 12);
    expect(partial.autoSyncEnabled, isTrue);
  });

  test('limits keep the app from uploading too often or never', () {
    expect(SyncSettings.defaults.validate(), isNull);
    expect(const SyncSettings(debounceSeconds: 2).validate(), isNotNull);
    expect(const SyncSettings(debounceSeconds: 900).validate(), isNotNull);
    expect(
      const SyncSettings(debounceSeconds: 60, maxWaitSeconds: 30).validate(),
      isNotNull,
      reason: 'the maximum wait cannot be shorter than the normal wait',
    );
    expect(const SyncSettings(maxWaitSeconds: 7200).validate(), isNotNull);
    expect(const SyncSettings(refreshEveryHours: 0).validate(), isNotNull);
    expect(const SyncSettings(refreshEveryHours: 200).validate(), isNotNull);
  });

  test('saving writes the config document the app reads', () async {
    final db = FakeFirebaseFirestore();
    final repo = AppConfigRepo(db);

    final before = await repo.watchSyncSettings().first;
    expect(before.exists, isFalse);
    expect(before.settings, SyncSettings.defaults);

    await repo.saveSyncSettings(
      const SyncSettings(
        autoSyncEnabled: false,
        debounceSeconds: 30,
        maxWaitSeconds: 120,
        refreshEveryHours: 6,
      ),
      editor: 'admin@ingresoya.test',
    );

    final stored = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.syncSettingsDocument)
        .get();
    expect(stored.data(), containsPair('schemaVersion', 1));
    expect(stored.data(), containsPair('autoSyncEnabled', false));
    expect(stored.data(), containsPair('debounceSeconds', 30));
    expect(stored.data(), containsPair('updatedBy', 'admin@ingresoya.test'));

    final after = await repo.watchSyncSettings().first;
    expect(after.exists, isTrue);
    expect(after.settings.refreshEveryHours, 6);
  });

  test('invalid values are rejected before writing', () async {
    final db = FakeFirebaseFirestore();
    await expectLater(
      AppConfigRepo(
        db,
      ).saveSyncSettings(const SyncSettings(debounceSeconds: 1), editor: 'x'),
      throwsStateError,
    );
    final stored = await db
        .collection(AppEnv.configCollection)
        .doc(AppEnv.syncSettingsDocument)
        .get();
    expect(stored.exists, isFalse);
  });
}
