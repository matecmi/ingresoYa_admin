export type DeploymentEnvironment = "test" | "staging" | "production";

export interface BackendCollections {
  questions: string;
  answerKeys: string;
  templates: string;
  attempts: string;
  users: string;
  courses: string;
  /** Catalog with `admissionExams` (and their Simulator rules). */
  universities: string;
  /** Admin-edited settings, e.g. `simulator`. */
  config: string;
  /** Public top 100 entries (`{uid}`), only for students who chose to appear. */
  leaderboard: string;
  /** Alias reservations (`{folded alias}` → uid); server-only. */
  aliases: string;
  /** Weekly league seats `{week}_{uid}` (public to students). */
  leagueMembers: string;
  /** League groups and their open pointers (server-only). */
  leagueGroups: string;
  /** Daily challenge per day and university (server-only). */
  dailyChallenges: string;
  /** Daily challenge results `{day}_{uid}` (public to students). */
  challengeEntries: string;
  /** Admin staff, roles and pending invites (docs/admin_staff_contract.md). */
  staff: string;
  staffRoles: string;
  staffInvites: string;
  /** Historial de cambios del admin (docs/admin_audit_contract.md). */
  audit: string;
  professions: string;
  /** Estadísticas por pregunta (docs/question_stats_contract.md). */
  questionStats: string;
  /** Noticias del alumno (docs/news_contract.md). */
  news: string;
}

export interface BackendConfig {
  environment: DeploymentEnvironment;
  region: string;
  enforceAppCheck: boolean;
  /**
   * Warm instances for the callables a student waits on (create, submit,
   * section completion). 0 = cold starts, no idle cost; production defaults
   * to 1. Each warm 256 MiB instance has a small monthly idle cost.
   */
  minInstances: number;
  selection: {
    candidateStartsPerBlock: number;
    maxCandidatesPerStart: number;
    recentQuestionLimit: number;
  };
  collections: BackendCollections;
}

const collectionsByEnvironment: Record<DeploymentEnvironment, BackendCollections> = {
  test: {
    questions: "iya-questions-test",
    answerKeys: "iya-question-answer-keys-test",
    templates: "iya-exam-templates-test",
    attempts: "iya-exam-attempts-test",
    users: "iya-profile-test",
    courses: "iya-courses-test",
    universities: "iya-universities-test",
    config: "iya-config-test",
    leaderboard: "iya-leaderboard-test",
    aliases: "iya-aliases-test",
    leagueMembers: "iya-league-members-test",
    leagueGroups: "iya-league-groups-test",
    dailyChallenges: "iya-daily-challenges-test",
    challengeEntries: "iya-challenge-entries-test",
    staff: "iya-admin-staff-test",
    staffRoles: "iya-admin-roles-test",
    staffInvites: "iya-admin-invites-test",
    audit: "iya-admin-audit-test",
    professions: "iya-professions-test",
    questionStats: "iya-question-stats-test",
    news: "iya-news-test"
  },
  staging: {
    questions: "iya-questions-staging",
    answerKeys: "iya-question-answer-keys-staging",
    templates: "iya-exam-templates-staging",
    attempts: "iya-exam-attempts-staging",
    users: "iya-profile-staging",
    courses: "iya-courses-staging",
    universities: "iya-universities-staging",
    config: "iya-config-staging",
    leaderboard: "iya-leaderboard-staging",
    aliases: "iya-aliases-staging",
    leagueMembers: "iya-league-members-staging",
    leagueGroups: "iya-league-groups-staging",
    dailyChallenges: "iya-daily-challenges-staging",
    challengeEntries: "iya-challenge-entries-staging",
    staff: "iya-admin-staff-staging",
    staffRoles: "iya-admin-roles-staging",
    staffInvites: "iya-admin-invites-staging",
    audit: "iya-admin-audit-staging",
    professions: "iya-professions-staging",
    questionStats: "iya-question-stats-staging",
    news: "iya-news-staging"
  },
  production: {
    questions: "iya-questions",
    answerKeys: "iya-question-answer-keys",
    templates: "iya-exam-templates",
    attempts: "iya-exam-attempts",
    users: "iya-profile",
    courses: "iya-courses",
    universities: "iya-universities",
    config: "iya-config",
    leaderboard: "iya-leaderboard",
    aliases: "iya-aliases",
    leagueMembers: "iya-league-members",
    leagueGroups: "iya-league-groups",
    dailyChallenges: "iya-daily-challenges",
    challengeEntries: "iya-challenge-entries",
    staff: "iya-admin-staff",
    staffRoles: "iya-admin-roles",
    staffInvites: "iya-admin-invites",
    audit: "iya-admin-audit",
    professions: "iya-professions",
    questionStats: "iya-question-stats",
    news: "iya-news"
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

function readBoundedPositiveInteger(
  value: string | undefined,
  name: string,
  fallback: number,
  minimum: number,
  maximum: number
): number {
  if (value === undefined || value.trim() === "") return fallback;
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < minimum || parsed > maximum) {
    throw new Error(`${name} must be an integer between ${minimum} and ${maximum}.`);
  }
  return parsed;
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
    minInstances: readBoundedPositiveInteger(
      env.FUNCTIONS_MIN_INSTANCES,
      "FUNCTIONS_MIN_INSTANCES",
      environment === "production" ? 1 : 0,
      0,
      3
    ),
    selection: {
      candidateStartsPerBlock: readBoundedPositiveInteger(
        env.EXAM_CANDIDATE_STARTS_PER_BLOCK,
        "EXAM_CANDIDATE_STARTS_PER_BLOCK",
        4,
        1,
        8
      ),
      maxCandidatesPerStart: readBoundedPositiveInteger(
        env.EXAM_MAX_CANDIDATES_PER_START,
        "EXAM_MAX_CANDIDATES_PER_START",
        80,
        20,
        80
      ),
      recentQuestionLimit: readBoundedPositiveInteger(
        env.EXAM_RECENT_QUESTION_LIMIT,
        "EXAM_RECENT_QUESTION_LIMIT",
        200,
        1,
        200
      )
    },
    collections: collectionsByEnvironment[environment as DeploymentEnvironment]
  };
}
