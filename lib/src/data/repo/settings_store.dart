import 'dart:async';

import '../../domain/news.dart';
import '../../domain/plan_settings.dart';
import '../../domain/quality_settings.dart';
import '../../domain/rankings_settings.dart';
import '../../domain/settings_catalog.dart';
import '../../domain/simulator_settings.dart';
import '../../domain/study_review_rules.dart';
import '../../domain/sync_settings.dart';
import '../../domain/xp_settings.dart';
import 'app_config_repo.dart';
import 'rankings_repo.dart';
import 'xp_repo.dart';

/// Lee y guarda los documentos de `{config}` como mapas normalizados por el
/// dominio, para la Configuración en lenguaje simple. Guarda por los mismos
/// métodos que las tarjetas anteriores (misma validación).
class SettingsStore {
  SettingsStore(this._config, this._xp, this._rankings);

  final AppConfigRepo _config;
  final XpRepo _xp;
  final RankingsRepo _rankings;

  Stream<Map<String, dynamic>> watch(SettingsDoc doc) => switch (doc) {
    SettingsDoc.rankings => _rankings.watchSettings().map((s) => s.toMap()),
    SettingsDoc.xp => _xp.watchSettings().map((s) => s.toMap()),
    SettingsDoc.simulator => _config.watchSimulatorSettings().map(
      (r) => r.settings.toMap(),
    ),
    SettingsDoc.plan => _config.watchPlanSettings().map((p) => p.toMap()),
    SettingsDoc.study => _config.watchStudyReviewRules().map(
      (r) => r.rules.toMap(),
    ),
    SettingsDoc.sync => _config.watchSyncSettings().map(
      (r) => r.settings.toMap(),
    ),
    SettingsDoc.quality => _config.watchQualitySettings().map((s) => s.toMap()),
    SettingsDoc.news => _config.watchNewsSettings().map((s) => s.toMap()),
  };

  /// Todos los documentos juntos; emite cuando cualquiera cambia.
  Stream<SettingsValues> watchAll() {
    late StreamController<SettingsValues> controller;
    final current = <SettingsDoc, Map<String, dynamic>>{};
    final subs = <StreamSubscription<Map<String, dynamic>>>[];
    controller = StreamController<SettingsValues>(
      onListen: () {
        for (final doc in SettingsDoc.values) {
          subs.add(
            watch(doc).listen((map) {
              current[doc] = map;
              if (current.length == SettingsDoc.values.length) {
                controller.add(Map.of(current));
              }
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<void> save(
    SettingsDoc doc,
    Map<String, dynamic> map, {
    required String editor,
  }) => switch (doc) {
    SettingsDoc.rankings => _rankings.saveSettings(
      RankingsSettings.fromMap(map),
      editor: editor,
    ),
    SettingsDoc.xp => _xp.saveSettings(XpSettings.fromMap(map), editor: editor),
    SettingsDoc.simulator => _config.saveSimulatorSettings(
      SimulatorSettings.fromMap(map),
      editor: editor,
    ),
    SettingsDoc.plan => _config.savePlanSettings(
      PlanSettings.fromMap(map),
      editor: editor,
    ),
    SettingsDoc.study => _config.saveStudyReviewRules(
      StudyReviewRules.fromMap(map),
      editor: editor,
    ),
    SettingsDoc.sync => _config.saveSyncSettings(
      SyncSettings.fromMap(map),
      editor: editor,
    ),
    SettingsDoc.quality => _config.saveQualitySettings(
      QualitySettings.fromMap(map),
      editor: editor,
    ),
    SettingsDoc.news => _config.saveNewsSettings(
      NewsSettings.fromMap(map),
      editor: editor,
    ),
  };
}
