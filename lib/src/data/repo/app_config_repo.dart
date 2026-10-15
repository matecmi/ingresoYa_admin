import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ingresoya_admin/src/domain/simulator_settings.dart';
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
    await _simulator.set({
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': editor,
    });
  }
}
