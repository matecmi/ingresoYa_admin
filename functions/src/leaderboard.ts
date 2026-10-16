/**
 * Public top 100 entries and their settings (docs/xp_contract.md §7).
 * No runtime dependency on xp.ts, which imports this module.
 */
import type { XpState } from "./xp";

// ---------------------------------------------------------------- settings

export interface LeaderboardSettings {
  /** Shows «Los más dedicados» in the app. Entries keep updating either way. */
  enabled: boolean;
  /** How many students the list shows. */
  size: number;
  /** A university gets its own filter once it has this many visible students. */
  universityFilterMin: number;
  /** Extra words an alias may not contain (the factory list always applies). */
  bannedWords: string[];
}

export const defaultLeaderboardSettings: LeaderboardSettings = {
  enabled: true,
  size: 100,
  universityFilterMin: 50,
  bannedWords: []
};

export function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : undefined;
}

function bounded(value: unknown, fallback: number, min: number, max: number): number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max ? value : fallback;
}

/** `{config}/xp.leaderboard`; any missing or invalid field keeps its factory value. */
export function parseLeaderboardSettings(value: unknown): LeaderboardSettings {
  const raw = record(value) ?? {};
  const d = defaultLeaderboardSettings;
  return {
    enabled: typeof raw.enabled === "boolean" ? raw.enabled : d.enabled,
    size: bounded(raw.size, d.size, 10, 500),
    universityFilterMin: bounded(raw.universityFilterMin, d.universityFilterMin, 1, 100000),
    bannedWords: Array.isArray(raw.bannedWords)
      ? raw.bannedWords.filter((word): word is string => typeof word === "string")
        .map(foldAlias).filter((word) => word.length >= 2).slice(0, 500)
      : d.bannedWords
  };
}

/** Lower case without accents: «Búho» and «buho» are the same alias. */
export function foldAlias(value: string): string {
  return value.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().trim();
}

// ---------------------------------------------------------------- entries

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

/** The public document: alias, XP and university/career only. */
export function leaderboardEntry(
  alias: string,
  state: XpState,
  stars: number,
  profile: RankingProfileFacts
): Record<string, unknown> {
  return {
    schemaVersion: 1,
    alias,
    total: state.total,
    rankStep: state.rankStep,
    stars,
    universityId: profile.universityId ?? null,
    universityAcronym: profile.universityAcronym ?? null,
    professionId: profile.professionId ?? null,
    professionName: profile.professionName ?? null,
    updatedAtMs: Date.now()
  };
}

/** `{profile}/{uid}/ranking/current`: the student's choice, written only by the server and the admin. */
export interface RankingChoice {
  alias: string | null;
  visible: boolean;
  /** Set when the admin removed the alias; shown to the student until they pick another. */
  moderatedReason: string | null;
}

export function parseRankingChoice(value: unknown): RankingChoice {
  const raw = record(value);
  return {
    alias: text(raw?.alias) ?? null,
    visible: raw?.visible === true,
    moderatedReason: text(raw?.moderatedReason) ?? null
  };
}
