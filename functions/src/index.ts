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

export const createExamAttempt = onCall(handlers.createExamAttempt);
export const getExamAttempt = onCall(handlers.getExamAttempt);

// Answers are deliberately persisted only at submit time. Incremental writes
// would add an attack surface without being required by the current contract.
export const submitExamAttempt = onCall(handlers.submitExamAttempt);
