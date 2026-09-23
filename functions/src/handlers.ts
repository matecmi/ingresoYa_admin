import type { CallableRequest } from "firebase-functions/v2/https";

import type { BackendConfig } from "./config";
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
 * The business workflow is introduced in the next backend tasks. These entry
 * points deliberately accept only IDs and answer IDs: question lists, scores,
 * durations, versions and ownership always come from Firestore server state.
 */
export function createCallableHandlers(config: BackendConfig) {
  return {
    async createExamAttempt(request: CallableRequest<unknown>): Promise<never> {
      try {
        const uid = requireUid(request);
        parseCreateExamAttempt(request.data);
        safeLog("exam_attempt_create_requested", uid);
        void config;
        throw workflowNotReady();
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
