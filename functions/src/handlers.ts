import type { CallableRequest } from "firebase-functions/v2/https";

import type { BackendConfig } from "./config";
import { db } from "./admin";
import { ExamAttemptService, type CreateExamAttemptResponse } from "./attempt_service";
import { asHttpsError, unauthenticated, workflowNotReady } from "./errors";
import { safeError, safeLog } from "./logging";
import {
  parseCreateExamAttempt,
  parseGetExamAttempt,
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
      try {
        const uid = requireUid(request);
        const input = parseCreateExamAttempt(request.data);
        safeLog("exam_attempt_create_requested", uid);
        return attempts.create(uid, input);
      } catch (error) {
        safeError("exam_attempt_create_rejected", error);
        throw asHttpsError(error);
      }
    },
    async getExamAttempt(request: CallableRequest<unknown>): Promise<never> {
      try {
        const uid = requireUid(request);
        parseGetExamAttempt(request.data);
        safeLog("exam_attempt_get_requested", uid);
        void config;
        throw workflowNotReady();
      } catch (error) {
        safeError("exam_attempt_get_rejected", error);
        throw asHttpsError(error);
      }
    },
    async submitExamAttempt(request: CallableRequest<unknown>): Promise<never> {
      try {
        const uid = requireUid(request);
        parseSubmitExamAttempt(request.data);
        safeLog("exam_attempt_submit_requested", uid);
        void config;
        throw workflowNotReady();
      } catch (error) {
        safeError("exam_attempt_submit_rejected", error);
        throw asHttpsError(error);
      }
    }
  };
}
