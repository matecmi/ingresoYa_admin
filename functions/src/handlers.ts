import type { CallableRequest } from "firebase-functions/v2/https";

import type { BackendConfig } from "./config";
import type { AchievementSummary } from "./achievement_summary";
import { db } from "./admin";
import {
  ExamAttemptService,
  type CreateExamAttemptResponse,
  type ExamAttemptResponse,
  type PartCompletionResponse,
  type SubmittedAttemptResponse
} from "./attempt_service";
import { asHttpsError, unauthenticated } from "./errors";
import { safeError, safeLog } from "./logging";
import { OperationMetrics } from "./operation_metrics";
import { XpService, type XpAward } from "./xp";
import {
  parseCreateExamAttempt,
  parseGetAchievementSummary,
  parseGetExamAttempt,
  parseReconcileSubtopicAchievement,
  parseRecordPartSectionCompletion,
  parseSaveExamAnswers,
  parseStartExamAttempt,
  parseSubmitExamAttempt
} from "./validation";

export function requireUid(request: CallableRequest<unknown>): string {
  if (request.auth === undefined || request.auth === null) throw unauthenticated();
  return request.auth.uid;
}

/**
 * Callables accept only IDs and answer IDs: question lists, scores, durations,
 * versions and ownership always come from Firestore server state.
 */
export function createCallableHandlers(config: BackendConfig) {
  const attempts = new ExamAttemptService(db, config);
  const xp = new XpService(db, config);
  /** XP never breaks the operation it rewards: a failure is logged and retried by the next call. */
  async function grantXp(
    uid: string,
    run: () => Promise<XpAward | undefined>,
    metrics: OperationMetrics
  ): Promise<{ xp?: XpAward }> {
    try {
      const award = await run();
      if (award !== undefined) safeLog("xp_granted", uid, { ...metrics.logFields(), gained: award.gained });
      return award === undefined ? {} : { xp: award };
    } catch (error) {
      safeError("xp_grant_failed", error, metrics.logFields(), { environment: config.environment, uid });
      return {};
    }
  }
  return {
    async reconcileSubtopicAchievement(
      request: CallableRequest<unknown>
    ): Promise<{ complete: boolean; awarded: boolean; missingPartIds: string[]; xp?: XpAward }> {
      const metrics = new OperationMetrics();
      try {
        const uid = requireUid(request);
        const input = parseReconcileSubtopicAchievement(request.data);
        const response = await attempts.reconcileSubtopicAchievement(uid, input, metrics);
        safeLog("subtopic_achievement_reconciled", uid, {
          ...metrics.logFields(),
          awarded: response.awarded
        });
        return { ...response, ...await grantXp(uid, () => xp.afterGuide(uid, { subtopicId: input.subtopicId }, metrics), metrics) };
      } catch (error) {
        safeError("subtopic_achievement_reconcile_rejected", error, metrics.logFields(), {
          environment: config.environment,
          uid: request.auth?.uid
        });
        throw asHttpsError(error);
      }
    },
    async getAchievementSummary(request: CallableRequest<unknown>): Promise<AchievementSummary> {
      const metrics = new OperationMetrics();
      try {
        const uid = requireUid(request);
        parseGetAchievementSummary(request.data);
        const response = await attempts.getAchievementSummary(uid, metrics);
        safeLog("achievement_summary_get_completed", uid, metrics.logFields());
        return response;
      } catch (error) {
        safeError("achievement_summary_get_rejected", error, metrics.logFields(), {
          environment: config.environment,
          uid: request.auth?.uid
        });
        throw asHttpsError(error);
      }
    },
    async createExamAttempt(
      request: CallableRequest<unknown>
    ): Promise<CreateExamAttemptResponse> {
      const metrics = new OperationMetrics();
      try {
        const uid = requireUid(request);
        const input = parseCreateExamAttempt(request.data);
        safeLog("exam_attempt_create_requested", uid);
        const response = await attempts.create(uid, input, metrics);
        safeLog("exam_attempt_create_completed", uid, metrics.logFields());
        return response;
      } catch (error) {
        safeError("exam_attempt_create_rejected", error, metrics.logFields(), {
          environment: config.environment,
          uid: request.auth?.uid
        });
        throw asHttpsError(error);
      }
    },
    async getExamAttempt(request: CallableRequest<unknown>): Promise<ExamAttemptResponse> {
      const metrics = new OperationMetrics();
      try {
        const uid = requireUid(request);
        const input = parseGetExamAttempt(request.data);
        safeLog("exam_attempt_get_requested", uid);
        const response = await attempts.get(uid, input.attemptId, metrics);
        safeLog("exam_attempt_get_completed", uid, metrics.logFields());
        return response;
      } catch (error) {
        safeError("exam_attempt_get_rejected", error, metrics.logFields(), {
          environment: config.environment,
          uid: request.auth?.uid
        });
        throw asHttpsError(error);
      }
    },
    async startExamAttempt(request: CallableRequest<unknown>): Promise<ExamAttemptResponse> {
      const metrics = new OperationMetrics();
      try {
        const uid = requireUid(request);
        const input = parseStartExamAttempt(request.data);
        safeLog("exam_attempt_start_requested", uid);
        const response = await attempts.start(uid, input.attemptId, metrics);
        safeLog("exam_attempt_start_completed", uid, metrics.logFields());
        return response;
      } catch (error) {
        safeError("exam_attempt_start_rejected", error, metrics.logFields(), {
          environment: config.environment,
          uid: request.auth?.uid
        });
        throw asHttpsError(error);
      }
    },
    async saveExamAnswers(request: CallableRequest<unknown>): Promise<ExamAttemptResponse> {
      const metrics = new OperationMetrics();
      try {
        const uid = requireUid(request);
        const input = parseSaveExamAnswers(request.data);
        safeLog("exam_attempt_answers_save_requested", uid);
        const response = await attempts.saveAnswers(uid, input, metrics);
        safeLog("exam_attempt_answers_save_completed", uid, metrics.logFields());
        return response;
      } catch (error) {
        safeError("exam_attempt_answers_save_rejected", error, metrics.logFields(), {
          environment: config.environment,
          uid: request.auth?.uid
        });
        throw asHttpsError(error);
      }
    },
    async recordPartSectionCompletion(
      request: CallableRequest<unknown>
    ): Promise<PartCompletionResponse> {
      const metrics = new OperationMetrics();
      try {
        const uid = requireUid(request);
        const input = parseRecordPartSectionCompletion(request.data);
        safeLog("part_section_completion_requested", uid);
        const response = await attempts.recordPartSectionCompletion(uid, input, metrics);
        safeLog("part_section_completion_completed", uid, metrics.logFields());
        return { ...response, ...await grantXp(uid, () => xp.afterGuide(uid, { partId: input.partId }, metrics), metrics) };
      } catch (error) {
        safeError("part_section_completion_rejected", error, metrics.logFields(), {
          environment: config.environment,
          uid: request.auth?.uid
        });
        throw asHttpsError(error);
      }
    },
    async submitExamAttempt(
      request: CallableRequest<unknown>
    ): Promise<SubmittedAttemptResponse> {
      const metrics = new OperationMetrics();
      try {
        const uid = requireUid(request);
        const input = parseSubmitExamAttempt(request.data);
        safeLog("exam_attempt_submit_requested", uid);
        const response = await attempts.submit(uid, input, metrics);
        safeLog("exam_attempt_submit_completed", uid, metrics.logFields());
        return { ...response, ...await grantXp(uid, () => xp.afterAttempt(uid, input.attemptId, metrics), metrics) };
      } catch (error) {
        safeError("exam_attempt_submit_rejected", error, metrics.logFields(), {
          environment: config.environment,
          uid: request.auth?.uid
        });
        throw asHttpsError(error);
      }
    }
  };
}
