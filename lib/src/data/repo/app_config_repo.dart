import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ingresoya_admin/src/domain/quality_settings.dart';
import 'package:ingresoya_admin/src/domain/simulator_settings.dart';
import 'package:ingresoya_admin/src/domain/plan_settings.dart';
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
}
