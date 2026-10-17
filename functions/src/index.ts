import { setGlobalOptions } from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { config as loadDotenv } from "dotenv";

import "./admin";
import { readBackendConfig } from "./config";
import { createCallableHandlers } from "./handlers";
import { closeLastLeagueWeek } from "./league_job";
import { createStaffHandlers } from "./staff";

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
