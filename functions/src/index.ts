import { setGlobalOptions } from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";

import "./admin";
import { readBackendConfig } from "./config";
import { createCallableHandlers } from "./handlers";

const config = readBackendConfig();
const handlers = createCallableHandlers(config);

setGlobalOptions({
  region: config.region,
  maxInstances: 10,
  timeoutSeconds: 30,
  memory: "256MiB"
});

const callableOptions = { enforceAppCheck: config.enforceAppCheck };

export const createExamAttempt = onCall(callableOptions, handlers.createExamAttempt);
export const getExamAttempt = onCall(callableOptions, handlers.getExamAttempt);
export const saveExamAnswers = onCall(callableOptions, handlers.saveExamAnswers);
export const recordPartSectionCompletion = onCall(
  callableOptions,
  handlers.recordPartSectionCompletion
);
export const submitExamAttempt = onCall(callableOptions, handlers.submitExamAttempt);
