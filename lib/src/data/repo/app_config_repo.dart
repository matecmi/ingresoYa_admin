import 'package:ingresoya_admin/src/domain/sound_settings.dart';
import 'package:ingresoya_admin/src/domain/tour_settings.dart';
import 'package:ingresoya_admin/src/domain/mistake_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ingresoya_admin/src/domain/ads_settings.dart';
import 'package:ingresoya_admin/src/domain/exam_settings.dart';
import 'package:ingresoya_admin/src/domain/news.dart';
import 'package:ingresoya_admin/src/domain/quality_settings.dart';
import 'package:ingresoya_admin/src/domain/simulator_settings.dart';
import 'package:ingresoya_admin/src/domain/plan_settings.dart';
import 'package:ingresoya_admin/src/domain/premium_settings.dart';
import 'package:ingresoya_admin/src/domain/stats_settings.dart';
import 'package:ingresoya_admin/src/domain/study_review_rules.dart';
import 'package:ingresoya_admin/src/domain/sync_settings.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';

/// Settings the student app reads from `{config}`; only admins can write.
class AppConfigRepo {
  AppConfigRepo(this.db);

  final FirebaseFirestore db;

  DocumentReference<Map<String, dynamic>> get _sync =>
      db.collection(AppEnv.configCollection).doc(AppEnv.syncSettingsDocument);

  Stream<SyncSettingsRecord> watchSyncSettings() =>
      _sync.snapshots().map((snapshot) {
        final data = snapshot.data();
        final updatedAt = data?['updatedAt'];
        return SyncSettingsRecord(
          settings: SyncSettings.fromMap(data),
          exists: snapshot.exists,
          updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
          updatedBy: (data?['updatedBy'] ?? '').toString(),
        );
      });

  Future<void> saveSyncSettings(
    SyncSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _sync.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  DocumentReference<Map<String, dynamic>> get _study => db
      .collection(AppEnv.configCollection)
      .doc(AppEnv.studyReviewRulesDocument);

  /// `{config}/exam` (docs/exam_config_contract.md): guardado de respuestas
  /// en la app y, desde la Fase 3C, límites de selección de preguntas.
  DocumentReference<Map<String, dynamic>> get _exam =>
      db.collection(AppEnv.configCollection).doc('exam');

  Stream<ExamSettings> watchExamSettings() => _exam.snapshots().map(
    (snapshot) => ExamSettings.fromMap(snapshot.data()),
  );

  Future<void> saveExamSettings(
    ExamSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _exam.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  /// Recorridos del búho (docs/tours_contract.md).
  DocumentReference<Map<String, dynamic>> get _tours =>
      db.collection(AppEnv.configCollection).doc('tours');

  Stream<TourSettings> watchTourSettings() => _tours.snapshots().map(
    (snapshot) => TourSettings.fromMap(snapshot.data()),
  );

  Future<void> saveTourSettings(
    TourSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _tours.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  /// Sonidos de logros (docs/sounds_contract.md).
  DocumentReference<Map<String, dynamic>> get _sounds =>
      db.collection(AppEnv.configCollection).doc('sounds');

  Stream<SoundSettings> watchSoundSettings() => _sounds.snapshots().map(
    (snapshot) => SoundSettings.fromMap(snapshot.data()),
  );

  Future<void> saveSoundSettings(
    SoundSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _sounds.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  /// `{config}/stats` (docs/stats_contract.md): umbrales de la pestaña
  /// Estadísticas de la app.
  DocumentReference<Map<String, dynamic>> get _stats =>
      db.collection(AppEnv.configCollection).doc('stats');

  Stream<StatsSettings> watchStatsSettings() => _stats.snapshots().map(
    (snapshot) => StatsSettings.fromMap(snapshot.data()),
  );

  Future<void> saveStatsSettings(
    StatsSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _stats.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  Stream<StudyReviewRulesRecord> watchStudyReviewRules() =>
      _study.snapshots().map((snapshot) {
        final data = snapshot.data();
        final updatedAt = data?['updatedAt'];
        return StudyReviewRulesRecord(
          rules: StudyReviewRules.fromMap(data),
          exists: snapshot.exists,
          updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
          updatedBy: (data?['updatedBy'] ?? '').toString(),
        );
      });

  Future<void> saveStudyReviewRules(
    StudyReviewRules rules, {
    required String editor,
  }) async {
    final problem = rules.validate();
    if (problem != null) throw StateError(problem);
    await _study.set({
      ...rules.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  DocumentReference<Map<String, dynamic>> get _simulator => db
      .collection(AppEnv.configCollection)
      .doc(AppEnv.simulatorSettingsDocument);

  Stream<SimulatorSettingsRecord> watchSimulatorSettings() =>
      _simulator.snapshots().map((snapshot) {
        final data = snapshot.data();
        final updatedAt = data?['updatedAt'];
        return SimulatorSettingsRecord(
          settings: SimulatorSettings.fromMap(data),
          exists: snapshot.exists,
          updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
          updatedBy: (data?['updatedBy'] ?? '').toString(),
        );
      });

  Future<void> saveSimulatorSettings(
    SimulatorSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    // Merge: the training plan (`plan`) is saved by its own card.
    await _simulator.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    }, SetOptions(merge: true));
  }

  /// The training plan (`plan` of `{config}/simulator`).
  Stream<PlanSettings> watchPlanSettings() => _simulator.snapshots().map(
    (snapshot) => PlanSettings.fromMap(snapshot.data()?['plan']),
  );

  Future<void> savePlanSettings(
    PlanSettings plan, {
    required String editor,
  }) async {
    final problem = plan.validate();
    if (problem != null) throw StateError(problem);
    await _simulator.set({
      'plan': plan.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    }, SetOptions(merge: true));
  }

  /// «Mis errores» (`mistakes` of `{config}/simulator`).
  Stream<MistakeSettings> watchMistakeSettings() => _simulator.snapshots().map(
    (snapshot) => MistakeSettings.fromMap(snapshot.data()?['mistakes']),
  );

  Future<void> saveMistakeSettings(
    MistakeSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _simulator.set({
      'mistakes': settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    }, SetOptions(merge: true));
  }

  DocumentReference<Map<String, dynamic>> get _quality => db
      .collection(AppEnv.configCollection)
      .doc(AppEnv.qualitySettingsDocument);

  /// Umbrales de «Preguntas a revisar» (`{config}/quality`).
  Stream<QualitySettings> watchQualitySettings() => _quality.snapshots().map(
    (snapshot) => QualitySettings.fromMap(snapshot.data()),
  );

  Future<void> saveQualitySettings(
    QualitySettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _quality.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  DocumentReference<Map<String, dynamic>> get _ads =>
      db.collection(AppEnv.configCollection).doc(AppEnv.adsSettingsDocument);

  Stream<AdsSettings> watchAdsSettings() =>
      _ads.snapshots().map((s) => AdsSettings.fromMap(s.data()));

  Future<void> saveAdsSettings(
    AdsSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _ads.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  DocumentReference<Map<String, dynamic>> get _premium => db
      .collection(AppEnv.configCollection)
      .doc(AppEnv.premiumSettingsDocument);

  Stream<PremiumSettings> watchPremiumSettings() =>
      _premium.snapshots().map((s) => PremiumSettings.fromMap(s.data()));

  Future<void> savePremiumSettings(
    PremiumSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _premium.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }

  DocumentReference<Map<String, dynamic>> get _news =>
      db.collection(AppEnv.configCollection).doc(AppEnv.newsSettingsDocument);

  Stream<NewsSettings> watchNewsSettings() =>
      _news.snapshots().map((s) => NewsSettings.fromMap(s.data()));

  Future<void> saveNewsSettings(
    NewsSettings settings, {
    required String editor,
  }) async {
    final problem = settings.validate();
    if (problem != null) throw StateError(problem);
    await _news.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }
}
