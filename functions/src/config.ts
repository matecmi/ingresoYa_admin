export type DeploymentEnvironment = "test" | "staging" | "production";

export interface BackendCollections {
  questions: string;
  answerKeys: string;
  templates: string;
  attempts: string;
  users: string;
}

export interface BackendConfig {
  environment: DeploymentEnvironment;
  region: string;
  collections: BackendCollections;
}

const collectionsByEnvironment: Record<DeploymentEnvironment, BackendCollections> = {
  test: {
    questions: "iya-questions-test",
    answerKeys: "iya-question-answer-keys-test",
    templates: "iya-exam-templates-test",
    attempts: "iya-exam-attempts-test",
    users: "iya-profile-test"
  },
  staging: {
    questions: "iya-questions-staging",
    answerKeys: "iya-question-answer-keys-staging",
    templates: "iya-exam-templates-staging",
    attempts: "iya-exam-attempts-staging",
    users: "iya-profile-staging"
  },
  production: {
    questions: "iya-questions",
    answerKeys: "iya-question-answer-keys",
    templates: "iya-exam-templates",
    attempts: "iya-exam-attempts",
    users: "iya-profile"
  }
};

const allowedEnvironments = new Set<DeploymentEnvironment>([
  "test",
  "staging",
  "production"
]);

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
  return {
    environment: environment as DeploymentEnvironment,
    region,
    collections: collectionsByEnvironment[environment as DeploymentEnvironment]
  };
}
