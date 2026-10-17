import 'package:ingresoya_admin/src/data/repo/rankings_repo.dart';
import 'package:ingresoya_admin/src/data/repo/xp_repo.dart';
import 'package:ingresoya_admin/src/data/repo/app_config_repo.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:ingresoya_admin/src/data/repo/staff_repo.dart';
import 'package:ingresoya_admin/src/data/repo/content_health_repo.dart';
import 'package:ingresoya_admin/src/data/repo/course_structure_repo.dart';
import 'package:ingresoya_admin/src/data/repo/settings_store.dart';
import 'package:ingresoya_admin/src/data/repo/audit_repo.dart';
import 'package:ingresoya_admin/src/data/repo/quality_repo.dart';
import 'package:ingresoya_admin/src/data/repo/student_repo.dart';
import 'package:ingresoya_admin/src/domain/content_health.dart';
import 'package:ingresoya_admin/src/domain/staff.dart';
import 'package:ingresoya_admin/src/env/app_env.dart';
import '../data/repo/admission_exam_repo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingresoya_admin/src/data/repo/course_repo.dart';
import 'package:ingresoya_admin/src/data/repo/exam_template_repo.dart';
import 'package:ingresoya_admin/src/data/repo/profession_repo.dart';
import 'package:ingresoya_admin/src/data/repo/question_repo.dart';
import 'package:ingresoya_admin/src/data/repo/publishable_question_repo.dart';
import 'package:ingresoya_admin/src/data/repo/university_repo.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final professionRepoProvider = Provider<ProfessionRepo>((ref) {
  return ProfessionRepo(ref.watch(firestoreProvider));
});

final universityRepoProvider = Provider<UniversityRepo>((ref) {
  return UniversityRepo(ref.watch(firestoreProvider));
});

final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final courseRepoProvider = Provider<CourseRepo>((ref) {
  return CourseRepo(ref.read(firebaseFirestoreProvider));
});

final questionRepoProvider = Provider<QuestionRepo>((ref) {
  return QuestionRepo(ref.watch(firestoreProvider));
});

final publishableQuestionRepoProvider = Provider<PublishableQuestionRepo>((
  ref,
) {
  return PublishableQuestionRepo(ref.watch(firestoreProvider));
});

final admissionExamRepoProvider = Provider<AdmissionExamRepo>(
  (ref) => AdmissionExamRepo(ref.watch(firestoreProvider)),
);

final examTemplateRepoProvider = Provider<ExamTemplateRepo>(
  (ref) => ExamTemplateRepo(ref.watch(firestoreProvider)),
);

final appConfigRepoProvider = Provider<AppConfigRepo>(
  (ref) => AppConfigRepo(ref.watch(firestoreProvider)),
);

final xpRepoProvider = Provider<XpRepo>(
  (ref) => XpRepo(ref.watch(firestoreProvider)),
);

final rankingsRepoProvider = Provider<RankingsRepo>(
  (ref) => RankingsRepo(ref.watch(firestoreProvider)),
);

/// Callables (región de las Functions). `null` en pruebas sin Firebase.
final functionsProvider = Provider<FirebaseFunctions?>((ref) {
  if (Firebase.apps.isEmpty) return null;
  return FirebaseFunctions.instanceFor(region: AppEnv.functionsRegion);
});

final staffRepoProvider = Provider<StaffRepo>(
  (ref) =>
      StaffRepo(ref.watch(firestoreProvider), ref.watch(functionsProvider)),
);

/// Quién usa el admin y qué puede hacer (lo fija el control de acceso con los
/// claims del token). En pruebas, Dueño.
class AdminSessionNotifier extends Notifier<AdminSession> {
  @override
  AdminSession build() => const AdminSession.owner();

  void set(AdminSession session) => state = session;
}

final adminSessionProvider =
    NotifierProvider<AdminSessionNotifier, AdminSession>(
      AdminSessionNotifier.new,
    );

/// «Ver el admin como este perfil»: perfil en vista previa o `null`.
class StaffPreviewNotifier extends Notifier<StaffRole?> {
  @override
  StaffRole? build() => null;

  void preview(StaffRole? role) => state = role;
}

final staffPreviewProvider = NotifierProvider<StaffPreviewNotifier, StaffRole?>(
  StaffPreviewNotifier.new,
);

/// La sesión que manda en la interfaz: la vista previa si hay una.
final effectiveSessionProvider = Provider<AdminSession>((ref) {
  final session = ref.watch(adminSessionProvider);
  final preview = ref.watch(staffPreviewProvider);
  if (preview == null) return session;
  return AdminSession(
    uid: session.uid,
    email: session.email,
    roleId: preview.id,
    perms: preview.perms,
  );
});

final contentHealthRepoProvider = Provider<ContentHealthRepo>(
  (ref) => ContentHealthRepo(ref.watch(firestoreProvider)),
);

/// Salud del contenido (se calcula al entrar y con «Revisar ahora»:
/// `ref.invalidate(contentHealthProvider)`).
final contentHealthProvider = FutureProvider<ContentHealthReport>(
  (ref) => ref.watch(contentHealthRepoProvider).load(),
);

final courseStructureRepoProvider = Provider<CourseStructureRepo>(
  (ref) => CourseStructureRepo(ref.watch(firestoreProvider)),
);

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore(
    ref.watch(appConfigRepoProvider),
    ref.watch(xpRepoProvider),
    ref.watch(rankingsRepoProvider),
  ),
);

final auditRepoProvider = Provider<AuditRepo>(
  (ref) =>
      AuditRepo(ref.watch(firestoreProvider), ref.watch(functionsProvider)),
);

final qualityRepoProvider = Provider<QualityRepo>(
  (ref) => QualityRepo(ref.watch(firestoreProvider), ref.watch(functionsProvider)),
);

final studentRepoProvider = Provider<StudentRepo>(
  (ref) => StudentRepo(
    ref.watch(firestoreProvider),
    ref.watch(xpRepoProvider),
    ref.watch(rankingsRepoProvider),
  ),
);
