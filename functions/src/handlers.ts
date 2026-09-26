import type { CallableRequest } from "firebase-functions/v2/https";

import type { BackendConfig } from "./config";
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
import {
  parseCreateExamAttempt,
  parseGetExamAttempt,
  parseRecordPartSectionCompletion,
  parseSaveExamAnswers,
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
  return {
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
        safeError("exam_attempt_create_rejected", error, metrics.logFields());
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
        safeError("exam_attempt_get_rejected", error, metrics.logFields());
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
        safeError("exam_attempt_answers_save_rejected", error, metrics.logFields());
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
        return response;
      } catch (error) {
        safeError("part_section_completion_rejected", error, metrics.logFields());
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
        return response;
      } catch (error) {
        safeError("exam_attempt_submit_rejected", error, metrics.logFields());
        throw asHttpsError(error);
      }
    }
  };
}
