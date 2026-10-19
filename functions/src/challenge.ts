/**
 * Reto del día results (docs/rankings_contract.md §6): one public entry per
 * student and day, written after the challenge attempt is graded.
 */
import type { Firestore } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import { parseRankingChoice, profileFacts, publicIdentity, record } from "./leaderboard";
import type { OperationMetrics } from "./operation_metrics";
import { parseXpState, starsFor, type XpSettings } from "./xp";

export interface ChallengeEntrySummary {
  day: string;
  correct: number;
  total: number;
  timeUsedSeconds: number;
}

export class ChallengeService {
  public constructor(
    private readonly db: Firestore,
    private readonly config: BackendConfig
  ) {}

  /** Writes the entry once (fixed id `{day}_{uid}`); undefined when the attempt is not a graded challenge. */
  public async recordEntry(
    uid: string,
    attemptId: string,
    xpSettings: XpSettings,
    metrics?: OperationMetrics,
    known?: Record<string, unknown>
  ): Promise<ChallengeEntrySummary | undefined> {
    let data = known;
    if (data === undefined) {
      const attempt = await this.db.collection(this.config.collections.attempts).doc(attemptId).get();
      metrics?.readDocument();
      data = attempt.data();
    }
    const simulator = record(data?.simulator);
    const result = record(data?.simulatorResult);
    if (data?.userId !== uid || data?.status !== "submitted" || simulator?.mode !== "daily_challenge" ||
      typeof simulator.day !== "string" || result === undefined) {
      return undefined;
    }
    const day = simulator.day;
    const user = this.db.collection(this.config.collections.users).doc(uid);
    const entryRef = this.db.collection(this.config.collections.challengeEntries).doc(`${day}_${uid}`);
    const summary: ChallengeEntrySummary = {
      day,
      correct: typeof result.correct === "number" ? result.correct : 0,
      total: typeof result.total === "number" ? result.total : 0,
      // Unknown time sorts last among equal scores.
      timeUsedSeconds: typeof result.timeUsedSeconds === "number" ? result.timeUsedSeconds : 999999
    };
    await this.db.runTransaction(async (transaction) => {
      metrics?.transactionAttempt();
      const [entry, choiceDoc, stateDoc, profileDoc] = await transaction.getAll(
        entryRef,
        user.collection("ranking").doc("current"),
        user.collection("xp").doc("current"),
        user
      );
      metrics?.readDocument(4);
      if (entry?.exists === true) return;
      const choice = parseRankingChoice(choiceDoc?.data());
      const state = parseXpState(stateDoc?.data());
      // The university of the challenge; the career of the profile now (§6).
      const profile = profileFacts(profileDoc?.data());
      transaction.set(entryRef, {
        schemaVersion: 1,
        ...summary,
        attemptId,
        ...publicIdentity(choice, state, starsFor(state.total, xpSettings)),
        universityId: typeof simulator.challengeUniversityId === "string" ? simulator.challengeUniversityId : profile.universityId ?? null,
        professionId: profile.professionId ?? null,
        submittedAtMs: typeof result.gradedAtMs === "number" ? result.gradedAtMs : Date.now()
      });
      metrics?.writeDocument();
    });
    return summary;
  }
}
