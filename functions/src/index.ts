import { setGlobalOptions } from "firebase-functions/v2";
import { onCall } from "firebase-functions/v2/https";
import { config as loadDotenv } from "dotenv";

import "./admin";
import { readBackendConfig } from "./config";
import { createCallableHandlers } from "./handlers";

// Firebase CLI discovers the callable manifest before it injects the deployed
// environment variables. Loading the ignored local .env lets that discovery
// use the same non-secret environment selection as the pending deployment;
// dotenv never overwrites values injected by the runtime.
loadDotenv();

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
