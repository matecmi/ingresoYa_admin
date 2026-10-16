/**
 * Rankings settings, the student's choice and the public card
 * (docs/rankings_contract.md §2-§4). No runtime dependency on xp.ts, which
 * imports this module.
 */
import type { XpState } from "./xp";

// ---------------------------------------------------------------- settings

export interface LeagueSettings {
  stageNames: string[];
  groupSize: number;
  promotePercent: number;
  demotePercent: number;
  /** Smaller groups demote nobody. */
  minGroupForDemotion: number;
  preferSameUniversity: boolean;
  showWeekPositions: boolean;
  /** Minimum players to show the per-career weekly position/table. */
  minCareerPlayers: number;
}

export interface ChallengeSettings {
  enabled: boolean;
  questionCount: number;
  minutes: number;
  bonusXp: number;
  /** Up to this many from the university's own past exams (at least 1 when there are any). */
  ownPastExamQuestions: number;
  noRepeatDays: number;
  minCareerPlayers: number;
}

/** `{config}/rankings`. */
export interface RankingsSettings {
  /** Master switch: off by default until there are enough students. */
  enabled: boolean;
  /** Monday (`YYYY-MM-DD`) the league starts from; set by the admin when enabling. */
  startWeek: string;
  /** Extra words a username may not contain (the factory list always applies). */
  bannedWords: string[];
  league: LeagueSettings;
  challenge: ChallengeSettings;
}

export const defaultRankingsSettings: RankingsSettings = {
  enabled: false,
  startWeek: "",
  bannedWords: [],
  league: {
    stageNames: ["Aspirante", "Postulante", "Finalista", "Ingresante"],
    groupSize: 30,
    promotePercent: 15,
    demotePercent: 15,
    minGroupForDemotion: 5,
    preferSameUniversity: false,
    showWeekPositions: true,
    minCareerPlayers: 5
  },
  challenge: {
    enabled: true,
    questionCount: 10,
    minutes: 15,
    bonusXp: 20,
    ownPastExamQuestions: 6,
    noRepeatDays: 30,
    minCareerPlayers: 5
  }
};

export function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : undefined;
}

function bounded(value: unknown, fallback: number, min: number, max: number): number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max ? value : fallback;
}

const flag = (value: unknown, fallback: boolean): boolean => typeof value === "boolean" ? value : fallback;

/** Any missing or invalid field keeps its factory value (field by field). */
export function parseRankingsSettings(value: unknown): RankingsSettings {
  const raw = record(value) ?? {};
  const league = record(raw.league) ?? {};
  const challenge = record(raw.challenge) ?? {};
  const d = defaultRankingsSettings;
  const names = Array.isArray(league.stageNames)
    ? league.stageNames.filter((name): name is string => typeof name === "string" && name.trim().length > 0).map((name) => name.trim())
    : [];
  const questionCount = bounded(challenge.questionCount, d.challenge.questionCount, 3, 30);
  return {
    enabled: flag(raw.enabled, d.enabled),
    startWeek: typeof raw.startWeek === "string" && /^\d{4}-\d{2}-\d{2}$/.test(raw.startWeek) ? raw.startWeek : d.startWeek,
    bannedWords: Array.isArray(raw.bannedWords)
      ? raw.bannedWords.filter((word): word is string => typeof word === "string")
        .map(foldAlias).filter((word) => word.length >= 2).slice(0, 500)
      : d.bannedWords,
    league: {
      stageNames: names.length >= 2 && names.length <= 8 ? names : d.league.stageNames,
      groupSize: bounded(league.groupSize, d.league.groupSize, 5, 100),
      promotePercent: bounded(league.promotePercent, d.league.promotePercent, 0, 50),
      demotePercent: bounded(league.demotePercent, d.league.demotePercent, 0, 50),
      minGroupForDemotion: bounded(league.minGroupForDemotion, d.league.minGroupForDemotion, 1, 100),
      preferSameUniversity: flag(league.preferSameUniversity, d.league.preferSameUniversity),
      showWeekPositions: flag(league.showWeekPositions, d.league.showWeekPositions),
      minCareerPlayers: bounded(league.minCareerPlayers, d.league.minCareerPlayers, 1, 1000)
    },
    challenge: {
      enabled: flag(challenge.enabled, d.challenge.enabled),
      questionCount,
      minutes: bounded(challenge.minutes, d.challenge.minutes, 3, 120),
      bonusXp: bounded(challenge.bonusXp, d.challenge.bonusXp, 0, 1000),
      ownPastExamQuestions: Math.min(questionCount, bounded(challenge.ownPastExamQuestions, d.challenge.ownPastExamQuestions, 0, 30)),
      noRepeatDays: bounded(challenge.noRepeatDays, d.challenge.noRepeatDays, 0, 365),
      minCareerPlayers: bounded(challenge.minCareerPlayers, d.challenge.minCareerPlayers, 1, 1000)
    }
  };
}

/** The league runs for [week] when rankings are on and the week reached the start. */
export function leagueRuns(settings: RankingsSettings, week: string): boolean {
  return settings.enabled && week >= settings.startWeek;
}

/** Lower case without accents: «Búho» and «buho» are the same alias. */
export function foldAlias(value: string): string {
  return value.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim();
}

// ---------------------------------------------------------------- random usernames

const animals = ["Búho", "Cóndor", "Puma", "Colibrí", "Zorro", "Halcón", "Jaguar", "Vicuña", "Tucán", "Lince", "Delfín", "Llama", "Gallito", "Oso"];
const skipWords = new Set(["ingenieria", "ing", "licenciatura", "lic", "de", "del", "la", "las", "los", "y", "e", "en", "el"]);

/** «Puma_Civil_42»: animal, a word of the career and a number; never the student's name. */
export function suggestAlias(random: () => number, professionName?: string): string {
  const animal = animals[Math.floor(random() * animals.length)]!;
  const word = (professionName ?? "").split(/[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+/)
    .find((part) => part.length >= 3 && !skipWords.has(foldAlias(part))) ?? "";
  const career = word.length === 0 ? "Ingreso" : word[0]!.toUpperCase() + word.slice(1, 9).toLowerCase();
  return `${animal}_${career}_${10 + Math.floor(random() * 90)}`;
}

// ---------------------------------------------------------------- profile facts

export interface RankingProfileFacts {
  universityId?: string;
  universityAcronym?: string;
  professionId?: string;
  professionName?: string;
  name?: string;
  email?: string;
}

const text = (value: unknown): string | undefined =>
  typeof value === "string" && value.trim().length > 0 ? value.trim() : undefined;

/** The app keeps its editable profile inside `profile`; older documents use the root. */
export function profileFacts(data: Record<string, unknown> | undefined): RankingProfileFacts {
  const nested = record(data?.profile) ?? {};
  const pick = (...keys: string[]): string | undefined => {
    for (const key of keys) {
      const value = text(nested[key]) ?? text(data?.[key]);
      if (value !== undefined) return value;
    }
    return undefined;
  };
  const facts: RankingProfileFacts = {};
  const universityId = pick("universityIdDoc", "universityId");
  const universityAcronym = pick("universityAcronym");
  const professionId = pick("professionId");
  const professionName = pick("professionName");
  const name = pick("userName");
  const email = pick("email");
  if (universityId !== undefined) facts.universityId = universityId;
  if (universityAcronym !== undefined) facts.universityAcronym = universityAcronym;
  if (professionId !== undefined) facts.professionId = professionId;
  if (professionName !== undefined) facts.professionName = professionName;
  if (name !== undefined) facts.name = name;
  if (email !== undefined) facts.email = email;
  return facts;
}

// ---------------------------------------------------------------- the student's choice

export interface LeagueResult {
  week: string;
  from: number;
  to: number;
  position: number;
  size: number;
  seen: boolean;
}

/** `{profile}/{uid}/ranking/current`: written only by the server and the admin. */
export interface RankingChoice {
  alias: string | null;
  hidden: boolean;
  /** Set when the admin removed the alias; shown until the student picks another. */
  moderatedReason: string | null;
  /** League stage (0 = first). */
  stage: number;
  lastResult: LeagueResult | null;
}

export function parseRankingChoice(value: unknown): RankingChoice {
  const raw = record(value);
  const result = record(raw?.lastResult);
  const int = (v: unknown) => (typeof v === "number" && Number.isInteger(v) && v >= 0 ? v : 0);
  return {
    alias: text(raw?.alias) ?? null,
    hidden: raw?.hidden === true,
    moderatedReason: text(raw?.moderatedReason) ?? null,
    stage: int(raw?.stage),
    lastResult: result !== undefined && typeof result.week === "string"
      ? { week: result.week, from: int(result.from), to: int(result.to), position: int(result.position), size: int(result.size), seen: result.seen === true }
      : null
  };
}

// ---------------------------------------------------------------- public card

/** What others may see of a student: never the name or email. */
export interface PublicIdentity {
  alias: string | null;
  hidden: boolean;
  rankStep: number | null;
  stars: number | null;
}

export function publicIdentity(choice: RankingChoice, state: XpState, stars: number): PublicIdentity {
  return choice.hidden
    ? { alias: null, hidden: true, rankStep: null, stars: null }
    : { alias: choice.alias, hidden: false, rankStep: state.rankStep, stars };
}

/** `{leaderboard}/{uid}`: the public card with the week's XP for «Esta semana». */
export function leaderboardEntry(
  choice: RankingChoice,
  state: XpState,
  stars: number,
  profile: RankingProfileFacts
): Record<string, unknown> {
  return {
    schemaVersion: 2,
    ...publicIdentity(choice, state, stars),
    stage: choice.stage,
    weekKey: state.week.key,
    weekXp: state.week.xp,
    universityId: profile.universityId ?? null,
    universityAcronym: profile.universityAcronym ?? null,
    professionId: profile.professionId ?? null,
    professionName: profile.professionName ?? null,
    updatedAtMs: Date.now()
  };
}
