export type DeploymentEnvironment = "test" | "staging" | "production";

export interface BackendCollections {
  questions: string;
  answerKeys: string;
  templates: string;
  attempts: string;
  users: string;
  courses: string;
}

export interface BackendConfig {
  environment: DeploymentEnvironment;
  region: string;
  enforceAppCheck: boolean;
  collections: BackendCollections;
}

const collectionsByEnvironment: Record<DeploymentEnvironment, BackendCollections> = {
  test: {
    questions: "iya-questions-test",
    answerKeys: "iya-question-answer-keys-test",
    templates: "iya-exam-templates-test",
    attempts: "iya-exam-attempts-test",
    users: "iya-profile-test",
    courses: "iya-courses-test"
  },
  staging: {
    questions: "iya-questions-staging",
    answerKeys: "iya-question-answer-keys-staging",
    templates: "iya-exam-templates-staging",
    attempts: "iya-exam-attempts-staging",
    users: "iya-profile-staging",
    courses: "iya-courses-staging"
  },
  production: {
    questions: "iya-questions",
    answerKeys: "iya-question-answer-keys",
    templates: "iya-exam-templates",
    attempts: "iya-exam-attempts",
    users: "iya-profile",
    courses: "iya-courses"
  }
};

const allowedEnvironments = new Set<DeploymentEnvironment>([
  "test",
  "staging",
  "production"
]);

function readOptionalBoolean(value: string | undefined, name: string): boolean | undefined {
  if (value === undefined || value.trim() === "") return undefined;
  if (value.trim().toLowerCase() === "true") return true;
  if (value.trim().toLowerCase() === "false") return false;
  throw new Error(`${name} must be true or false when set.`);
}

/**
 * Production deployments must name their environment explicitly. The local
 * Emulator Suite and unit tests default to `test` so they can never target a
 * production collection by accident.
 */
export function readBackendConfig(
  env: NodeJS.ProcessEnv = process.env
): BackendConfig {
  const requested = env.INGRESOYA_ENV?.trim().toLowerCase();
  const local = env.FUNCTIONS_EMULATOR === "true" || env.NODE_ENV === "test";
  const environment = requested ?? (local ? "test" : undefined);
  if (
    environment === undefined ||
    !allowedEnvironments.has(environment as DeploymentEnvironment)
  ) {
    throw new Error(
      "INGRESOYA_ENV must be one of test, staging or production outside local emulators."
    );
  }
  const region = env.FUNCTIONS_REGION?.trim() || "southamerica-east1";
  if (!/^[a-z]+-[a-z]+\d$/.test(region)) {
    throw new Error("FUNCTIONS_REGION is not a supported region identifier.");
  }
  // The emulator cannot mint production App Check tokens. Production protects
  // every callable by default; non-production must opt in deliberately once
  // its App Check provider is configured.
  const configuredAppCheck = readOptionalBoolean(
    env.FUNCTIONS_ENFORCE_APP_CHECK,
    "FUNCTIONS_ENFORCE_APP_CHECK"
  );
  if (environment === "production" && configuredAppCheck === false) {
    throw new Error("FUNCTIONS_ENFORCE_APP_CHECK cannot be false in production.");
  }
  return {
    environment: environment as DeploymentEnvironment,
    region,
    enforceAppCheck: configuredAppCheck ?? environment === "production",
    collections: collectionsByEnvironment[environment as DeploymentEnvironment]
  };
}
