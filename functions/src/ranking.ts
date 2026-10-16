/**
 * Profile XP phase 2 (docs/xp_contract.md §7): alias, «Aparecer en rankings»
 * and the public top 100 «Los más dedicados».
 *
 * The public entry `{leaderboard}/{uid}` exists only while the student chose
 * to appear. It carries the alias, XP, rank and university/career, never the
 * name or email. Only the server writes it: here when the student changes the
 * choice, and in `XpService.grant` whenever the XP changes.
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
  record
} from "./leaderboard";
import { parseXpState, starsFor, type XpSettings } from "./xp";

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
  visible: boolean;
  alias?: string;
}

export function parseUpdateRankingProfile(data: unknown): UpdateRankingProfileInput {
  const raw = record(data);
  if (raw === undefined || typeof raw.visible !== "boolean") throw invalidArgument("visible must be a boolean.");
  const keys = Object.keys(raw);
  if (keys.some((key) => key !== "visible" && key !== "alias")) throw invalidArgument("Unexpected fields.");
  if (raw.alias !== undefined && typeof raw.alias !== "string") throw invalidArgument("alias must be a string.");
  return typeof raw.alias === "string" ? { visible: raw.visible, alias: raw.alias.trim() } : { visible: raw.visible };
}

export interface RankingProfileResponse {
  alias: string | null;
  visible: boolean;
}

export class RankingService {
  public constructor(
    private readonly db: Firestore,
    private readonly config: BackendConfig
  ) {}

  /** Saves the alias and the «Aparecer en rankings» choice, and creates or removes the public entry. */
  public async update(
    uid: string,
    input: UpdateRankingProfileInput,
    settings: XpSettings,
    metrics?: OperationMetrics
  ): Promise<RankingProfileResponse> {
    const users = this.db.collection(this.config.collections.users);
    const userRef = users.doc(uid);
    const choiceRef = userRef.collection("ranking").doc("current");
    const stateRef = userRef.collection("xp").doc("current");
    const entryRef = this.db.collection(this.config.collections.leaderboard).doc(uid);
    const aliases = this.db.collection(this.config.collections.aliases);
    return this.db.runTransaction(async (transaction: Transaction) => {
      metrics?.transactionAttempt();
      const [choiceDoc, profileDoc, stateDoc] = await transaction.getAll(choiceRef, userRef, stateRef);
      metrics?.readDocument(3);
      const previous = parseRankingChoice(choiceDoc?.data());
      const profile = profileFacts(profileDoc?.data());
      let alias = previous.alias;
      let aliasDocToDelete: string | undefined;
      const changing = input.alias !== undefined && input.alias !== previous.alias;
      if (changing) {
        const requested = input.alias!;
        const problem = aliasProblem(requested, settings.leaderboard.bannedWords, personalTokens(profile.name, profile.email));
        if (problem !== undefined) throw failedPrecondition("The alias is not allowed.", { reason: `alias_${problem}` });
        const key = foldAlias(requested);
        const owner = await transaction.get(aliases.doc(key));
        metrics?.readDocument();
        if (owner.exists && owner.data()?.uid !== uid) {
          throw new ExamBackendError("already-exists", "The alias is taken.", { reason: "alias_taken" });
        }
        if (previous.alias !== null && foldAlias(previous.alias) !== key) aliasDocToDelete = foldAlias(previous.alias);
        transaction.set(aliases.doc(key), { uid, alias: requested, updatedAtMs: Date.now() });
        alias = requested;
      }
      if (input.visible && alias === null) throw failedPrecondition("An alias is required to appear.", { reason: "alias_required" });
      if (aliasDocToDelete !== undefined) transaction.delete(aliases.doc(aliasDocToDelete));
      transaction.set(choiceRef, {
        schemaVersion: 1,
        alias,
        visible: input.visible,
        moderatedReason: changing ? null : previous.moderatedReason,
        updatedAt: FieldValue.serverTimestamp(),
        updatedAtMs: Date.now()
      });
      if (input.visible && alias !== null) {
        const state = parseXpState(stateDoc?.data());
        transaction.set(entryRef, leaderboardEntry(alias, state, starsFor(state.total, settings), profile));
      } else {
        transaction.delete(entryRef);
      }
      metrics?.writeDocument(3);
      return { alias, visible: input.visible };
    });
  }
}
