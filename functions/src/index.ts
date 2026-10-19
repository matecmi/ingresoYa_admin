import { setGlobalOptions } from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { onDocumentWritten, onDocumentWrittenWithAuthContext } from "firebase-functions/v2/firestore";
import { config as loadDotenv } from "dotenv";

import "./admin";
import { readBackendConfig } from "./config";
import { createCallableHandlers } from "./handlers";
import { closeLastLeagueWeek } from "./league_job";
import { prepareDailyChallenges } from "./challenge_job";
import { createStaffHandlers } from "./staff";
import { createPremiumHandlers } from "./premium";
import { createAuditHandlers, onlyMetaChanged, recordWrite } from "./audit";
import { CATALOG_DOC, bumpCatalogVersion, catalogKindOf, courseIdFromParams } from "./catalog_version";
import { APP_CONFIG_DOC, publishAppConfig } from "./app_config";
import { db } from "./admin";
import { syncQuestionIndex } from "./question_index";
import { createQuestionStatsHandlers } from "./question_stats";
import { sendDueNewsPushes, sendNewsPush, shouldSendPush } from "./news_push";

// Firebase CLI discovers the callable manifest before it injects the deployed
// environment variables. Loading the ignored local .env lets that discovery
// use the same non-secret environment selection as the pending deployment;
// dotenv never overwrites values injected by the runtime.
loadDotenv();

const config = readBackendConfig();
const handlers = createCallableHandlers(config);
const staffHandlers = createStaffHandlers(config);

setGlobalOptions({
  region: config.region,
  maxInstances: 10,
  timeoutSeconds: 30,
  memory: "256MiB"
});

const callableOptions = { enforceAppCheck: config.enforceAppCheck };
// The student waits on these three; keep them warm where configured.
const hotCallableOptions = { ...callableOptions, minInstances: config.minInstances };

export const createExamAttempt = onCall(hotCallableOptions, handlers.createExamAttempt);
export const getExamAttempt = onCall(callableOptions, handlers.getExamAttempt);
export const getAchievementSummary = onCall(callableOptions, handlers.getAchievementSummary);
export const startExamAttempt = onCall(callableOptions, handlers.startExamAttempt);
export const saveExamAnswers = onCall(callableOptions, handlers.saveExamAnswers);
export const recordPartSectionCompletion = onCall(
  hotCallableOptions,
  handlers.recordPartSectionCompletion
);
export const submitExamAttempt = onCall(hotCallableOptions, handlers.submitExamAttempt);
export const updateRankingProfile = onCall(callableOptions, handlers.updateRankingProfile);
export const claimExplanationXp = onCall(callableOptions, handlers.claimExplanationXp);
export const reconcileSubtopicAchievement = onCall(
  callableOptions,
  handlers.reconcileSubtopicAchievement
);

// Admin web callables (docs/admin_staff_contract.md). They are protected by
// sign-in and staff claims checked against Firestore; the web admin has no
// App Check provider, so enforcing it would lock the panel out.
const adminCallableOptions = { enforceAppCheck: false };
export const syncAdminAccess = onCall(adminCallableOptions, staffHandlers.syncAdminAccess);
export const manageAdminStaff = onCall(adminCallableOptions, staffHandlers.manageAdminStaff);
const auditHandlers = createAuditHandlers(config);
export const restoreAuditEntry = onCall(adminCallableOptions, auditHandlers.restoreAuditEntry);

// Plan premium (docs/premium_contract.md): la app verifica su compra de Play,
// el admin regala o corta días, y Play avisa renovaciones por Pub/Sub.
const premiumHandlers = createPremiumHandlers(config);
export const verifyPurchase = onCall(callableOptions, premiumHandlers.verifyPurchase);
export const setStudentPremium = onCall(adminCallableOptions, premiumHandlers.setStudentPremium);
export const onPlayNotification = onMessagePublished(
  { topic: config.premium.rtdnTopic, retry: false },
  premiumHandlers.onPlayNotification
);

// Estadísticas por pregunta para «Preguntas a revisar»
// (docs/question_stats_contract.md): cada noche y con «Actualizar ahora».
const questionStats = createQuestionStatsHandlers(db, config);
export const refreshQuestionStats = onCall(
  { ...adminCallableOptions, timeoutSeconds: 300, memory: "512MiB" },
  questionStats.refreshQuestionStats
);
export const nightlyQuestionStats = onSchedule(
  { schedule: "30 3 * * *", timeZone: "America/Lima", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    // Hasta tres pasadas por noche si quedó trabajo pendiente (Fase 4B): con
    // más de ~6.000 alumnos activos al día una sola pasada se atrasaba.
    for (let pass = 0; pass < 3; pass += 1) {
      const { attempts } = await questionStats.service.refresh(20000);
      if (attempts < 20000) break;
    }
  }
);

// Historial de cambios del admin (docs/admin_audit_contract.md). La base de
// Firestore está en nam5, así que los disparadores van en us-central1.
const col = config.collections;
function auditTrigger(document: string, kindKey: string) {
  return onDocumentWrittenWithAuthContext(
    { document, region: "us-central1", timeoutSeconds: 30, memory: "256MiB" },
    async (event) => {
      const before = event.data?.before;
      const after = event.data?.after;
      const docId = (after?.id ?? before?.id) ?? "";
      const path = (after?.ref.path ?? before?.ref.path) ?? "";
      // {config}/app y {config}/catalog los escribe el servidor: no son
      // cambios del equipo ni generan entradas del historial. Cualquier otro
      // cambio de configuración (y cada subida del catálogo) refunde
      // {config}/app (docs/app_config_contract.md).
      if (kindKey === "config" && docId === APP_CONFIG_DOC) return;
      if (kindKey === "config" && docId === CATALOG_DOC) {
        await publishAppConfig(config);
        return;
      }
      const beforeData = before?.exists ? (before.data() as Record<string, unknown>) : null;
      const afterData = after?.exists ? (after.data() as Record<string, unknown>) : null;
      await recordWrite(config, {
        path,
        docId,
        kindKey,
        before: beforeData,
        after: afterData,
        authType: event.authType,
        authId: event.authId
      });
      // Versión del catálogo (docs/catalog_version_contract.md): la app baja
      // cursos y universidades solo cuando este contador cambia.
      const catalogKind = catalogKindOf(kindKey);
      if (catalogKind && !onlyMetaChanged(beforeData, afterData)) {
        await bumpCatalogVersion(config, catalogKind, courseIdFromParams(kindKey, event.params as Record<string, string>));
      }
      if (kindKey === "config" && !onlyMetaChanged(beforeData, afterData)) {
        await publishAppConfig(config);
      }
    }
  );
}
export const auditQuestions = auditTrigger(`${col.questions}/{id}`, "questions");
// Índice de preguntas por curso para el Simulador (question_index.ts).
export const indexQuestions = onDocumentWritten(
  { document: `${col.questions}/{id}`, region: "us-central1", timeoutSeconds: 30, memory: "256MiB" },
  async (event) => {
    const before = event.data?.before;
    const after = event.data?.after;
    await syncQuestionIndex(
      db,
      config,
      event.params.id,
      before?.exists ? (before.data() as Record<string, unknown>) : undefined,
      after?.exists ? (after.data() as Record<string, unknown>) : undefined
    );
  }
);
export const auditCourses = auditTrigger(`${col.courses}/{id}`, "courses");
export const auditTopics = auditTrigger(`${col.courses}/{c}/topics/{id}`, "topics");
export const auditSubtopics = auditTrigger(`${col.courses}/{c}/topics/{t}/subtopics/{id}`, "subtopics");
export const auditTemplates = auditTrigger(`${col.templates}/{id}`, "templates");
export const auditUniversities = auditTrigger(`${col.universities}/{id}`, "universities");
export const auditUniversityChildren = auditTrigger(`${col.universities}/{u}/{sub}/{id}`, "universityChild");
export const auditProfessions = auditTrigger(`${col.professions}/{id}`, "professions");
export const auditNews = auditTrigger(`${col.news}/{id}`, "news");
export const auditConfig = auditTrigger(`${col.config}/{id}`, "config");
export const auditStaff = auditTrigger(`${col.staff}/{id}`, "staff");
export const auditStaffRoles = auditTrigger(`${col.staffRoles}/{id}`, "staffRoles");

// Notificaciones de noticias (docs/news_contract.md §6): al publicarse y,
// para las programadas, cada 15 minutos.
export const sendNewsPushOnWrite = onDocumentWritten(
  { document: `${col.news}/{id}`, region: "us-central1", timeoutSeconds: 60, memory: "256MiB" },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists || !shouldSendPush(after.data(), Date.now())) return;
    await sendNewsPush(config, after.id);
  }
);
export const sendScheduledNewsPush = onSchedule(
  { schedule: "*/15 * * * *", timeZone: "America/Lima", timeoutSeconds: 120 },
  async () => {
    await sendDueNewsPushes(config);
  }
);

/**
 * Reto del día armado de noche (docs/exam_config_contract.md, Fase 3C):
 * 00:05 en Lima para cada universidad activa, así ningún alumno paga las
 * lecturas de construirlo al pedirlo.
 */
export const generateDailyChallenges = onSchedule(
  { schedule: "5 0 * * *", timeZone: "America/Lima", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    await prepareDailyChallenges(config);
  }
);

/**
 * Weekly league close (docs/rankings_contract.md §5): Monday 00:10 in Lima,
 * only while rankings are enabled.
 */
export const closeLeagueWeek = onSchedule(
  { schedule: "10 0 * * 1", timeZone: "America/Lima", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    await closeLastLeagueWeek(config);
  }
);
