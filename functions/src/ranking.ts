/**
 * Usernames (docs/rankings_contract.md §3): every student has one, chosen in
 * the onboarding or generated at random, and may hide from the rankings.
 * The public card `{leaderboard}/{uid}` never carries the name or email; only
 * the server writes it: here when the username or the choice changes, and in
 * `XpService.grant` whenever the XP changes.
 */
import { FieldValue, type Firestore, type Transaction } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import { ExamBackendError, failedPrecondition, invalidArgument } from "./errors";
import type { OperationMetrics } from "./operation_metrics";
import {
  foldAlias,
  leaderboardEntry,
  parseRankingChoice,
  profileFacts,
  publicIdentity,
  record,
  suggestAlias,
  type RankingsSettings
} from "./leaderboard";
import { parseXpState, peruWeek, starsFor, type XpSettings } from "./xp";

// ---------------------------------------------------------------- alias

export const aliasMinLength = 3;
export const aliasMaxLength = 20;
const aliasPattern = /^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9_]+$/;

/** Always rejected, besides the admin's list. Whole words, or inside the alias when long. */
export const factoryBannedWords = [
  "puta", "puto", "putas", "mierda", "verga", "pinga", "pija", "concha", "conchatumadre", "ctm", "csm",
  "huevon", "cojudo", "cojuda", "maricon", "cabro", "pendejo", "pendeja", "idiota", "imbecil",
  "estupido", "estupida", "tarado", "mongol", "carajo", "chucha", "joder", "zorra", "perra",
  "culo", "sexo", "porno", "nazi", "hitler", "violador", "admin", "ingresoya", "moderador"
];

export type AliasProblem = "length" | "characters" | "banned" | "personal";

/** Pieces of an alias: split on `_`, digits and lower→upper changes («BuhoVeloz» → buho, veloz). */
function aliasWords(alias: string): string[] {
  return alias
    .replace(/([a-záéíóúüñ])([A-ZÁÉÍÓÚÜÑ])/g, "$1 $2")
    .split(/[_0-9\s]+/)
    .map(foldAlias)
    .filter((word) => word.length > 0);
}

/**
 * Words of the student's own name and email that the alias may not contain
 * («Sin nombres reales, correos…»). Short pieces are ignored.
 */
export function personalTokens(name: string | undefined, email: string | undefined): string[] {
  const local = (email ?? "").split("@")[0] ?? "";
  const pieces = [...(name ?? "").split(/[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+/), ...local.split(/[^A-Za-z]+/)];
  return [...new Set(pieces.map(foldAlias).filter((piece) => piece.length >= 4))];
}

export function aliasProblem(alias: string, bannedWords: readonly string[], personal: readonly string[]): AliasProblem | undefined {
  if (alias.length < aliasMinLength || alias.length > aliasMaxLength) return "length";
  if (!aliasPattern.test(alias) || !/[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]/.test(alias)) return "characters";
  const folded = foldAlias(alias);
  const words = aliasWords(alias);
  for (const banned of [...factoryBannedWords, ...bannedWords]) {
    if (words.includes(banned) || (banned.length >= 6 && folded.includes(banned))) return "banned";
  }
  if (personal.some((token) => folded.includes(token))) return "personal";
  return undefined;
}

// ---------------------------------------------------------------- callable

export interface UpdateRankingProfileInput {
  /** A new username; absent keeps the current one (or generates one when there is none). */
  alias?: string;
  /** «Ocultarme de los rankings»; absent keeps the current choice. */
  hidden?: boolean;
}

export function parseUpdateRankingProfile(data: unknown): UpdateRankingProfileInput {
  const raw = record(data ?? {});
  if (raw === undefined) throw invalidArgument("The request must be an object.");
  if (Object.keys(raw).some((key) => key !== "alias" && key !== "hidden")) throw invalidArgument("Unexpected fields.");
  if (raw.alias !== undefined && typeof raw.alias !== "string") throw invalidArgument("alias must be a string.");
  if (raw.hidden !== undefined && typeof raw.hidden !== "boolean") throw invalidArgument("hidden must be a boolean.");
  return {
    ...(typeof raw.alias === "string" ? { alias: raw.alias.trim() } : {}),
    ...(typeof raw.hidden === "boolean" ? { hidden: raw.hidden } : {})
  };
}

export interface RankingProfileResponse {
  alias: string;
  hidden: boolean;
}

export class RankingService {
  public constructor(
    private readonly db: Firestore,
    private readonly config: BackendConfig,
    private readonly random: () => number = Math.random
  ) {}

  /**
   * Saves the username and «Ocultarme de los rankings», generating a random
   * username when the student has none, and refreshes the public card and
   * this week's league seat.
   */
  public async update(
    uid: string,
    input: UpdateRankingProfileInput,
    xpSettings: XpSettings,
    rankings: RankingsSettings,
    metrics?: OperationMetrics,
    account: { name?: string; email?: string } = {}
  ): Promise<RankingProfileResponse> {
    const userRef = this.db.collection(this.config.collections.users).doc(uid);
    const choiceRef = userRef.collection("ranking").doc("current");
    const stateRef = userRef.collection("xp").doc("current");
    const entryRef = this.db.collection(this.config.collections.leaderboard).doc(uid);
    const memberRef = this.db.collection(this.config.collections.leagueMembers).doc(`${peruWeek(Date.now())}_${uid}`);
    const aliases = this.db.collection(this.config.collections.aliases);
    return this.db.runTransaction(async (transaction: Transaction) => {
      metrics?.transactionAttempt();
      const [choiceDoc, profileDoc, stateDoc, memberDoc] = await transaction.getAll(choiceRef, userRef, stateRef, memberRef);
      metrics?.readDocument(4);
      const previous = parseRankingChoice(choiceDoc?.data());
      const profile = profileFacts(profileDoc?.data());
      let alias = previous.alias;
      let changed = false;
      if (input.alias !== undefined && input.alias !== previous.alias) {
        const problem = aliasProblem(input.alias, rankings.bannedWords, [
          ...personalTokens(profile.name, profile.email),
          ...personalTokens(account.name, account.email)
        ]);
        if (problem !== undefined) throw failedPrecondition("The alias is not allowed.", { reason: `alias_${problem}` });
        const owner = await transaction.get(aliases.doc(foldAlias(input.alias)));
        metrics?.readDocument();
        if (owner.exists && owner.data()?.uid !== uid) {
          throw new ExamBackendError("already-exists", "The alias is taken.", { reason: "alias_taken" });
        }
        alias = input.alias;
        changed = true;
      } else if (alias === null) {
        // No username yet (skipped in the onboarding, or removed by the
        // admin): a random one that is free.
        for (let attempt = 0; attempt < 6 && alias === null; attempt++) {
          const candidate = suggestAlias(this.random, profile.professionName);
          const owner = await transaction.get(aliases.doc(foldAlias(candidate)));
          metrics?.readDocument();
          if (!owner.exists) alias = candidate;
        }
        if (alias === null) throw failedPrecondition("No free random alias.", { reason: "alias_taken" });
        changed = true;
      }
      const hidden = input.hidden ?? previous.hidden;
      if (changed) {
        if (previous.alias !== null && foldAlias(previous.alias) !== foldAlias(alias)) {
          transaction.delete(aliases.doc(foldAlias(previous.alias)));
        }
        transaction.set(aliases.doc(foldAlias(alias)), { uid, alias, updatedAtMs: Date.now() });
      }
      transaction.set(choiceRef, {
        schemaVersion: 2,
        alias,
        hidden,
        moderatedReason: input.alias !== undefined && changed ? null : previous.moderatedReason,
        updatedAt: FieldValue.serverTimestamp(),
        updatedAtMs: Date.now()
      }, { merge: true });
      const choice = { ...previous, alias, hidden };
      const state = parseXpState(stateDoc?.data());
      const stars = starsFor(state.total, xpSettings);
      transaction.set(entryRef, leaderboardEntry(choice, state, stars, profile));
      if (memberDoc?.exists === true) {
        transaction.set(memberRef, { ...publicIdentity(choice, state, stars), updatedAtMs: Date.now() }, { merge: true });
      }
      metrics?.writeDocument(4);
      return { alias, hidden };
    });
  }
}
