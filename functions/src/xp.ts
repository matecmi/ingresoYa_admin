/**
 * Profile XP and rank, phase 1 (docs/xp_contract.md).
 *
 * XP is granted only here, after the event it rewards was already committed
 * by its own transaction (exam graded, part verified, award written). Every
 * grant has a fixed id, so retrying a callable or re-running the retroactive
 * script never adds the same XP twice.
 */
import { FieldValue, type DocumentReference, type Firestore } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import { readConfigDoc } from "./config_cache";
import type { OperationMetrics } from "./operation_metrics";
import {
  leaderboardEntry,
  leagueRuns,
  parseRankingChoice,
  parseRankingsSettings,
  profileFacts,
  publicIdentity,
  type RankingsSettings
} from "./leaderboard";
import { readLeagueSeat, writeLeagueSeat } from "./league";

// ---------------------------------------------------------------- settings

/** Badge images bundled in the app (`assets/ranks/{key}.png`). */
export const rankImages = [
  "bronze_1", "bronze_6", "bronze_12",
  "silver_1", "silver_6", "silver_12",
  "platinum_1", "platinum_6", "platinum_12",
  "sapphire_1", "sapphire_6", "sapphire_12",
  "amethyst_1", "amethyst_6", "amethyst_12",
  "master_1", "master_6", "master_12"
] as const;

export interface RankStep {
  name: string;
  minXp: number;
  image: string;
}

export interface XpAmounts {
  sectionReviewed: number;
  partPassed: number;
  subtopicCompleted: number;
  subtopicMastered: number;
  simulatorSession: number;
  correctAnswer: number;
  diagnostic: number;
  pastExamCompleted: number;
  improvementPer10: number;
  improvementMax: number;
  weeklyGoal: number;
  streakDay: number;
  /** Explanation of a failed question opened with a rewarded video. */
  explanationVideo: number;
}

export interface XpSettings {
  ranks: RankStep[];
  starsEnabled: boolean;
  xpPerStar: number;
  amounts: XpAmounts;
  /** Max XP per Peru day from repeatable events (sessions, answers, streak). */
  dailyCap: number;
  minQuestionsPerSession: number;
  /** A question seen in this window does not give the correct-answer XP. */
  repeatWindowDays: number;
  /** Sessions answered faster than this (average) give no XP. */
  minSecondsPerQuestion: number;
  pastExamEveryDays: number;
  /** Max XP per Peru day from explanation videos (its own cap). */
  explanationVideoDailyCap: number;
}

const defaultNames = ["Bronce", "Plata", "Platino", "Zafiro", "Amatista", "Maestro"];
const defaultMinXp = [0, 150, 350, 600, 900, 1250, 1650, 2100, 2600, 3200, 3900, 4700, 5600, 6600, 7700, 9000, 10500, 12000];

export const defaultXpSettings: XpSettings = {
  ranks: rankImages.map((image, index) => ({
    name: `${defaultNames[Math.floor(index / 3)]} ${["I", "II", "III"][index % 3]}`,
    minXp: defaultMinXp[index] ?? 0,
    image
  })),
  starsEnabled: true,
  xpPerStar: 2000,
  amounts: {
    sectionReviewed: 2,
    partPassed: 40,
    subtopicCompleted: 80,
    subtopicMastered: 150,
    simulatorSession: 10,
    correctAnswer: 1,
    diagnostic: 30,
    pastExamCompleted: 50,
    improvementPer10: 1,
    improvementMax: 50,
    weeklyGoal: 50,
    streakDay: 5,
    explanationVideo: 5
  },
  dailyCap: 300,
  minQuestionsPerSession: 10,
  repeatWindowDays: 14,
  minSecondsPerQuestion: 5,
  pastExamEveryDays: 7,
  explanationVideoDailyCap: 25
};

function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : undefined;
}

function bounded(value: unknown, fallback: number, min: number, max: number): number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max ? value : fallback;
}

/** Ranks must start at 0, grow strictly and use a bundled image; otherwise the factory ladder is used. */
export function parseRanks(value: unknown): RankStep[] {
  if (!Array.isArray(value) || value.length === 0 || value.length > 40) return defaultXpSettings.ranks;
  const ranks: RankStep[] = [];
  for (const item of value) {
    const raw = record(item);
    const name = typeof raw?.name === "string" ? raw.name.trim() : "";
    const minXp = raw?.minXp;
    const image = raw?.image;
    if (name.length === 0 || typeof minXp !== "number" || !Number.isInteger(minXp) ||
      typeof image !== "string" || !(rankImages as readonly string[]).includes(image)) {
      return defaultXpSettings.ranks;
    }
    ranks.push({ name, minXp, image });
  }
  if (ranks[0]?.minXp !== 0) return defaultXpSettings.ranks;
  for (let index = 1; index < ranks.length; index++) {
    if (ranks[index]!.minXp <= ranks[index - 1]!.minXp) return defaultXpSettings.ranks;
  }
  return ranks;
}

/** `{config}/xp`; any missing or invalid field keeps its factory value. */
export function parseXpSettings(value: unknown): XpSettings {
  const raw = record(value) ?? {};
  const amounts = record(raw.amounts) ?? {};
  const d = defaultXpSettings;
  const amount = (key: keyof XpAmounts) => bounded(amounts[key], d.amounts[key], 0, 1000);
  return {
    ranks: parseRanks(raw.ranks),
    starsEnabled: typeof raw.starsEnabled === "boolean" ? raw.starsEnabled : d.starsEnabled,
    xpPerStar: bounded(raw.xpPerStar, d.xpPerStar, 100, 100000),
    amounts: {
      sectionReviewed: amount("sectionReviewed"),
      partPassed: amount("partPassed"),
      subtopicCompleted: amount("subtopicCompleted"),
      subtopicMastered: amount("subtopicMastered"),
      simulatorSession: amount("simulatorSession"),
      correctAnswer: amount("correctAnswer"),
      diagnostic: amount("diagnostic"),
      pastExamCompleted: amount("pastExamCompleted"),
      improvementPer10: amount("improvementPer10"),
      improvementMax: amount("improvementMax"),
      weeklyGoal: amount("weeklyGoal"),
      streakDay: amount("streakDay"),
      explanationVideo: amount("explanationVideo")
    },
    dailyCap: bounded(raw.dailyCap, d.dailyCap, 0, 100000),
    minQuestionsPerSession: bounded(raw.minQuestionsPerSession, d.minQuestionsPerSession, 1, 300),
    repeatWindowDays: bounded(raw.repeatWindowDays, d.repeatWindowDays, 0, 365),
    minSecondsPerQuestion: bounded(raw.minSecondsPerQuestion, d.minSecondsPerQuestion, 0, 600),
    pastExamEveryDays: bounded(raw.pastExamEveryDays, d.pastExamEveryDays, 0, 365),
    explanationVideoDailyCap: bounded(raw.explanationVideoDailyCap, d.explanationVideoDailyCap, 0, 1000)
  };
}

/** Index of the highest rank whose threshold is reached. */
export function rankStepFor(total: number, ranks: readonly RankStep[]): number {
  let step = 0;
  for (let index = 0; index < ranks.length; index++) {
    if (total >= ranks[index]!.minXp) step = index;
  }
  return step;
}

/** Stars after the last rank: one per `xpPerStar`. */
export function starsFor(total: number, settings: XpSettings): number {
  if (!settings.starsEnabled || settings.ranks.length === 0) return 0;
  const top = settings.ranks[settings.ranks.length - 1]!.minXp;
  return total < top ? 0 : Math.floor((total - top) / settings.xpPerStar);
}

// ---------------------------------------------------------------- Peru calendar

const peruOffsetMs = -5 * 60 * 60 * 1000;
const dayMs = 24 * 60 * 60 * 1000;

/** `YYYY-MM-DD` of the moment in Peru (UTC−5, no daylight saving). */
export function peruDay(ms: number): string {
  return new Date(ms + peruOffsetMs).toISOString().slice(0, 10);
}

/** Days since the epoch of a `YYYY-MM-DD` key. */
export function dayNumber(day: string): number {
  return Math.round(Date.parse(`${day}T00:00:00Z`) / dayMs);
}

/** Monday (`YYYY-MM-DD`) of the Peru week of the moment. */
export function peruWeek(ms: number): string {
  const day = peruDay(ms);
  const date = new Date(`${day}T00:00:00Z`);
  const fromMonday = (date.getUTCDay() + 6) % 7;
  return new Date(date.getTime() - fromMonday * dayMs).toISOString().slice(0, 10);
}

// ---------------------------------------------------------------- state and grants

export type XpEventType =
  | "section_reviewed"
  | "part_passed"
  | "subtopic_completed"
  | "subtopic_mastered"
  | "simulator_session"
  | "correct_answers"
  | "diagnostic"
  | "past_exam_completed"
  | "past_exam_improvement"
  | "weekly_goal"
  | "streak_day"
  | "daily_challenge"
  | "explanation_video";

/** Repeatable events limited by the daily cap. */
export const cappedTypes: ReadonlySet<XpEventType> = new Set(["simulator_session", "correct_answers", "streak_day"]);

export interface XpGrant {
  /** Fixed id: the same achievement always maps to the same id. */
  id: string;
  type: XpEventType;
  xp: number;
  /** For correct answers: how many. */
  count?: number;
  atMs: number;
  source: Record<string, unknown>;
}

export interface XpState {
  total: number;
  /** Highest rank reached: it never goes down when thresholds change. */
  rankStep: number;
  /** [explained]: XP from explanation videos today (own cap). */
  today: { day: string; capped: number; explained: number };
  week: { key: string; xp: number; sessionDays: string[] };
  /** Last Peru day a past exam gave its completion XP, by exam id. */
  pastExamDays: Record<string, string>;
}

export function emptyXpState(): XpState {
  return { total: 0, rankStep: 0, today: { day: "", capped: 0, explained: 0 }, week: { key: "", xp: 0, sessionDays: [] }, pastExamDays: {} };
}

export function parseXpState(value: unknown): XpState {
  const raw = record(value);
  if (raw === undefined) return emptyXpState();
  const today = record(raw.today);
  const week = record(raw.week);
  const days = record(raw.pastExamDays) ?? {};
  const number = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : 0);
  return {
    total: number(raw.total),
    rankStep: number(raw.rankStep),
    today: { day: typeof today?.day === "string" ? today.day : "", capped: number(today?.capped), explained: number(today?.explained) },
    week: {
      key: typeof week?.key === "string" ? week.key : "",
      xp: number(week?.xp),
      sessionDays: Array.isArray(week?.sessionDays) ? week!.sessionDays.filter((d): d is string => typeof d === "string") : []
    },
    pastExamDays: Object.fromEntries(Object.entries(days).filter((entry): entry is [string, string] => typeof entry[1] === "string"))
  };
}

export interface AppliedXpEvent {
  id: string;
  type: XpEventType;
  /** XP the event asked for before the daily cap. */
  requested: number;
  xp: number;
  count?: number;
  day: string;
  week: string;
  atMs: number;
  source: Record<string, unknown>;
}

/**
 * Applies new grants in order. Pure: the caller removed grants whose id
 * already exists. Events of an older day than the stored one skip the cap
 * (only the retroactive script can produce them, already sorted).
 */
export function applyXpGrants(
  previous: XpState,
  grants: readonly XpGrant[],
  settings: XpSettings
): { state: XpState; applied: AppliedXpEvent[] } {
  const state: XpState = {
    ...previous,
    today: { ...previous.today },
    week: { ...previous.week, sessionDays: [...previous.week.sessionDays] },
    pastExamDays: { ...previous.pastExamDays }
  };
  const applied: AppliedXpEvent[] = [];
  for (const grant of grants) {
    const day = peruDay(grant.atMs);
    const week = peruWeek(grant.atMs);
    if (day > state.today.day) state.today = { day, capped: 0, explained: 0 };
    if (week > state.week.key) state.week = { key: week, xp: 0, sessionDays: [] };
    let xp = Math.max(0, Math.round(grant.xp));
    if (cappedTypes.has(grant.type) && day === state.today.day) {
      xp = Math.min(xp, Math.max(0, settings.dailyCap - state.today.capped));
      state.today.capped += xp;
    }
    if (grant.type === "explanation_video" && day === state.today.day) {
      xp = Math.min(xp, Math.max(0, settings.explanationVideoDailyCap - state.today.explained));
      state.today.explained += xp;
    }
    state.total += xp;
    if (week === state.week.key) {
      state.week.xp += xp;
      if (grant.type === "simulator_session" && !state.week.sessionDays.includes(day)) state.week.sessionDays.push(day);
    }
    if (grant.type === "past_exam_completed" && typeof grant.source.examId === "string") {
      state.pastExamDays[grant.source.examId] = day;
    }
    state.rankStep = Math.max(state.rankStep, rankStepFor(state.total, settings.ranks));
    applied.push({
      id: grant.id,
      type: grant.type,
      requested: Math.max(0, Math.round(grant.xp)),
      xp,
      ...(grant.count === undefined ? {} : { count: grant.count }),
      day,
      week,
      atMs: grant.atMs,
      source: grant.source
    });
  }
  return { state, applied };
}

/** What a submitted Simulator attempt is worth (before ids are de-duplicated). */
export interface SimulatorXpInput {
  attemptId: string;
  purpose: "past_exam" | "practice";
  mode?: string;
  examId?: string;
  total: number;
  /** Correct answers to questions not seen in the repeat window. */
  freshCorrect: number;
  score: number;
  previousBestScore?: number;
  timeUsedSeconds: number | null;
  atMs: number;
  /** Weekly sessions of the student's goal; undefined = no goal. */
  goalSessions?: number;
}

export function simulatorGrants(input: SimulatorXpInput, state: XpState, settings: XpSettings): XpGrant[] {
  const a = settings.amounts;
  const day = peruDay(input.atMs);
  const week = peruWeek(input.atMs);
  const source = { attemptId: input.attemptId, purpose: input.purpose, ...(input.mode ? { mode: input.mode } : {}), ...(input.examId ? { examId: input.examId } : {}) };
  // Juego limpio: answering faster than the minimum gives nothing.
  if (input.total > 0 && input.timeUsedSeconds !== null &&
    input.timeUsedSeconds / input.total < settings.minSecondsPerQuestion) {
    return [];
  }
  const grants: XpGrant[] = [];
  const counts = input.total >= settings.minQuestionsPerSession;
  if (counts) grants.push({ id: `session_${input.attemptId}`, type: "simulator_session", xp: a.simulatorSession, atMs: input.atMs, source });
  if (input.freshCorrect > 0) {
    grants.push({ id: `correct_${input.attemptId}`, type: "correct_answers", xp: input.freshCorrect * a.correctAnswer, count: input.freshCorrect, atMs: input.atMs, source });
  }
  if (input.mode === "diagnostic") grants.push({ id: "diagnostic", type: "diagnostic", xp: a.diagnostic, atMs: input.atMs, source });
  if (input.purpose === "past_exam" && input.examId !== undefined) {
    const last = state.pastExamDays[input.examId];
    if (last === undefined || dayNumber(day) - dayNumber(last) >= settings.pastExamEveryDays) {
      grants.push({ id: `past_exam_${input.examId}_${day}`, type: "past_exam_completed", xp: a.pastExamCompleted, atMs: input.atMs, source });
    }
    if (input.previousBestScore !== undefined && input.score > input.previousBestScore) {
      const xp = Math.min(a.improvementMax, Math.floor((input.score - input.previousBestScore) / 10) * a.improvementPer10);
      if (xp > 0) grants.push({ id: `improve_${input.attemptId}`, type: "past_exam_improvement", xp, atMs: input.atMs, source: { ...source, from: input.previousBestScore, to: input.score } });
    }
  }
  if (counts) {
    grants.push({ id: `streak_${day}`, type: "streak_day", xp: a.streakDay, atMs: input.atMs, source: { day } });
    if (input.goalSessions !== undefined && input.goalSessions > 0) {
      const days = new Set(state.week.key === week ? state.week.sessionDays : []);
      days.add(day);
      if (days.size >= input.goalSessions) {
        grants.push({ id: `weekly_goal_${week}`, type: "weekly_goal", xp: a.weeklyGoal, atMs: input.atMs, source: { week, sessions: input.goalSessions } });
      }
    }
  }
  return grants;
}

/** Guide grants from server facts: sections recorded and fixed-id learning events. */
export interface GuideFacts {
  partId?: string;
  sections?: readonly string[];
  partPassed?: boolean;
  subtopicId?: string;
  subtopicCompleted?: boolean;
  subtopicMastered?: boolean;
  courseId?: string;
  topicId?: string;
  atMs: number;
}

export function guideGrants(facts: GuideFacts, settings: XpSettings): XpGrant[] {
  const a = settings.amounts;
  const grants: XpGrant[] = [];
  const base = { ...(facts.courseId ? { courseId: facts.courseId } : {}), ...(facts.topicId ? { topicId: facts.topicId } : {}), ...(facts.subtopicId ? { subtopicId: facts.subtopicId } : {}) };
  if (facts.partId !== undefined) {
    for (const section of facts.sections ?? []) {
      grants.push({ id: `section_${facts.partId}_${section}`, type: "section_reviewed", xp: a.sectionReviewed, atMs: facts.atMs, source: { ...base, partId: facts.partId, section } });
    }
    if (facts.partPassed) grants.push({ id: `part_passed_${facts.partId}`, type: "part_passed", xp: a.partPassed, atMs: facts.atMs, source: { ...base, partId: facts.partId } });
  }
  if (facts.subtopicId !== undefined) {
    if (facts.subtopicCompleted) grants.push({ id: `subtopic_completed_${facts.subtopicId}`, type: "subtopic_completed", xp: a.subtopicCompleted, atMs: facts.atMs, source: base });
    if (facts.subtopicMastered) grants.push({ id: `subtopic_mastered_${facts.subtopicId}`, type: "subtopic_mastered", xp: a.subtopicMastered, atMs: facts.atMs, source: base });
  }
  return grants;
}

/**
 * XP for opening the explanation of a failed (or blank) question with a
 * rewarded video: once per attempt and question (fixed id), limited by its
 * own daily cap in [applyXpGrants].
 */
export function explanationGrant(attemptId: string, questionId: string, atMs: number, settings: XpSettings): XpGrant[] {
  const xp = settings.amounts.explanationVideo;
  if (xp <= 0 || settings.explanationVideoDailyCap <= 0) return [];
  return [{ id: `explanation_${attemptId}_${questionId}`, type: "explanation_video", xp, atMs, source: { attemptId, questionId } }];
}

// ---------------------------------------------------------------- award sent to the app

export interface XpAwardItem {
  type: XpEventType;
  xp: number;
  requested: number;
  count?: number;
}

/** «+48 XP» and the rank change, returned by the callables that grant XP. */
export interface XpAward {
  gained: number;
  items: XpAwardItem[];
  totalBefore: number;
  total: number;
  rankStepBefore: number;
  rankStep: number;
  starsBefore: number;
  stars: number;
  todayCapped: number;
  dailyCap: number;
  /** XP from explanation videos today and its cap («te quedan N XP hoy»). */
  todayExplained: number;
  explanationDailyCap: number;
}

function award(before: XpState, after: XpState, applied: readonly AppliedXpEvent[], settings: XpSettings): XpAward {
  return {
    gained: after.total - before.total,
    items: applied.map(({ type, xp, requested, count }) => ({ type, xp, requested, ...(count === undefined ? {} : { count }) })),
    totalBefore: before.total,
    total: after.total,
    rankStepBefore: before.rankStep,
    rankStep: after.rankStep,
    starsBefore: starsFor(before.total, settings),
    stars: starsFor(after.total, settings),
    todayCapped: after.today.day === peruDay(Date.now()) ? after.today.capped : 0,
    dailyCap: settings.dailyCap,
    todayExplained: after.today.day === peruDay(Date.now()) ? after.today.explained : 0,
    explanationDailyCap: settings.explanationVideoDailyCap
  };
}

// ---------------------------------------------------------------- service

const stringList = (value: unknown): string[] =>
  Array.isArray(value) ? value.filter((item): item is string => typeof item === "string") : [];

export class XpService {
  public constructor(
    private readonly db: Firestore,
    private readonly config: BackendConfig
  ) {}

  /** `{config}/xp`, en caché por instancia (config_cache.ts, Fase 3B). */
  public async settings(metrics?: OperationMetrics): Promise<XpSettings> {
    return parseXpSettings(await readConfigDoc(this.db, this.config, "xp", metrics));
  }

  /** `{config}/rankings` (docs/rankings_contract.md §2), en caché por instancia. */
  public async rankingsSettings(metrics?: OperationMetrics): Promise<RankingsSettings> {
    return parseRankingsSettings(await readConfigDoc(this.db, this.config, "rankings", metrics));
  }

  private userRef(uid: string): DocumentReference {
    return this.db.collection(this.config.collections.users).doc(uid);
  }

  /**
   * Applies the grants built from the current state, skipping ids already in
   * the ledger, in one transaction. Returns undefined when nothing new.
   */
  public async grant(
    uid: string,
    build: (state: XpState, settings: XpSettings) => XpGrant[],
    metrics?: OperationMetrics,
    preloaded?: XpSettings,
    preloadedRankings?: RankingsSettings
  ): Promise<XpAward | undefined> {
    const settings = preloaded ?? await this.settings(metrics);
    const rankings = preloadedRankings ?? await this.rankingsSettings(metrics);
    const stateRef = this.userRef(uid).collection("xp").doc("current");
    const events = this.userRef(uid).collection("xpEvents");
    const choiceRef = this.userRef(uid).collection("ranking").doc("current");
    const entryRef = this.db.collection(this.config.collections.leaderboard).doc(uid);
    return this.db.runTransaction(async (transaction) => {
      metrics?.transactionAttempt();
      const snapshot = await transaction.get(stateRef);
      const before = parseXpState(snapshot.data());
      const candidates = build(before, settings);
      if (candidates.length === 0) return undefined;
      const existing = await transaction.getAll(...candidates.map((grant) => events.doc(grant.id)));
      metrics?.readDocument(1 + candidates.length);
      const fresh = candidates.filter((_, index) => existing[index]?.exists !== true);
      if (fresh.length === 0) return undefined;
      // Rankings (docs/rankings_contract.md): the public card and the league
      // seat move in the same transaction (reads must precede the writes).
      const [choiceDoc, profileDoc] = await transaction.getAll(choiceRef, this.userRef(uid));
      metrics?.readDocument(2);
      const choice = parseRankingChoice(choiceDoc?.data());
      const profile = profileFacts(profileDoc?.data());
      const { state, applied } = applyXpGrants(before, fresh, settings);
      const week = peruWeek(Date.now());
      const seat = choice.alias !== null && state.week.key === week && state.week.xp > 0 && leagueRuns(rankings, week)
        ? await readLeagueSeat(transaction, this.db, this.config, uid, week, choice.stage, rankings, profile.universityId)
        : undefined;
      const stars = starsFor(state.total, settings);
      // The public card only matters while rankings are on (Fase 3B): with
      // them off nobody reads it, and the next grant after turning them on
      // rewrites it.
      if (choice.alias !== null && rankings.enabled) {
        transaction.set(entryRef, leaderboardEntry(choice, state, stars, profile));
        metrics?.writeDocument();
      }
      if (seat !== undefined) {
        writeLeagueSeat(transaction, this.db, this.config, seat, {
          week,
          stage: choice.stage,
          weekXp: state.week.xp,
          identity: publicIdentity(choice, state, stars),
          universityId: profile.universityId ?? null,
          professionId: profile.professionId ?? null
        }, rankings);
        metrics?.writeDocument(seat.member.exists ? 1 : 3);
      }
      for (const event of applied) {
        transaction.set(events.doc(event.id), {
          schemaVersion: 1,
          ...event,
          createdAt: FieldValue.serverTimestamp()
        });
      }
      transaction.set(stateRef, { schemaVersion: 1, ...state, updatedAt: FieldValue.serverTimestamp(), updatedAtMs: Date.now() });
      metrics?.writeDocument(applied.length + 1);
      return award(before, state, applied, settings);
    });
  }

  /** After a graded Simulator attempt. [known] = the attempt as the submit left it (saves a read). */
  public async afterSimulatorAttempt(
    uid: string,
    attemptId: string,
    metrics?: OperationMetrics,
    known?: Record<string, unknown>
  ): Promise<XpAward | undefined> {
    const [data, goal, settings] = await Promise.all([
      known === undefined
        ? this.db.collection(this.config.collections.attempts).doc(attemptId).get().then((snapshot) => {
          metrics?.readDocument();
          return snapshot.data();
        })
        : Promise.resolve(known),
      this.userRef(uid).collection("simulatorPlan").doc("current").get(),
      this.settings(metrics)
    ]);
    metrics?.readDocument();
    const simulator = record(data?.simulator);
    const result = record(data?.simulatorResult);
    if (data?.userId !== uid || data?.status !== "submitted" || simulator === undefined || result === undefined) return undefined;
    const purpose = simulator.purpose === "past_exam" ? "past_exam" : "practice";
    const basis = record(data.xpBasis);
    const sessions = goal.data()?.sessionsPerWeek;
    const input: SimulatorXpInput = {
      attemptId,
      purpose,
      ...(typeof simulator.mode === "string" ? { mode: simulator.mode } : {}),
      ...(typeof simulator.examId === "string" ? { examId: simulator.examId } : {}),
      total: typeof result.total === "number" ? result.total : 0,
      freshCorrect: typeof basis?.freshCorrect === "number" ? basis.freshCorrect : 0,
      score: typeof result.score === "number" ? result.score : 0,
      ...(typeof basis?.previousBestScore === "number" ? { previousBestScore: basis.previousBestScore } : {}),
      timeUsedSeconds: typeof result.timeUsedSeconds === "number" ? result.timeUsedSeconds : null,
      atMs: typeof result.gradedAtMs === "number" ? result.gradedAtMs : Date.now(),
      ...(typeof sessions === "number" ? { goalSessions: sessions } : {})
    };
    // Reto del día: a bonus on top of the normal session XP (docs/rankings_contract.md §6).
    const challengeDay = simulator.mode === "daily_challenge" && typeof simulator.day === "string" ? simulator.day : undefined;
    const rankings = await this.rankingsSettings(metrics);
    const bonus = challengeDay === undefined ? 0 : rankings.challenge.bonusXp;
    return this.grant(uid, (state, current) => [
      ...simulatorGrants(input, state, current),
      ...(challengeDay !== undefined && bonus > 0
        ? [{ id: `daily_challenge_${challengeDay}`, type: "daily_challenge" as const, xp: bonus, atMs: input.atMs, source: { attemptId, day: challengeDay } }]
        : [])
    ], metrics, settings, rankings);
  }

  /**
   * After guide activity on a part (sections, part exam) or a subtopic
   * (mastery, reconcile): grants what the server already recorded.
   */
  public async afterGuide(
    uid: string,
    scope: { partId?: string; subtopicId?: string },
    metrics?: OperationMetrics
  ): Promise<XpAward | undefined> {
    const progress = await this.userRef(uid).collection("learningProgress").doc("current").get();
    metrics?.readDocument();
    const partProgress = scope.partId === undefined ? undefined : record(record(progress.data()?.partProgress)?.[scope.partId]);
    const subtopicId = scope.subtopicId ?? (typeof partProgress?.subtopicId === "string" ? partProgress.subtopicId : undefined);
    const learning = this.userRef(uid).collection("learningEvents");
    const ids = [
      ...(scope.partId === undefined ? [] : [`part_passed_${scope.partId}`]),
      ...(subtopicId === undefined ? [] : [`subtopic_completed_${subtopicId}`, `subtopic_mastered_${subtopicId}`])
    ];
    const docs = ids.length === 0 ? [] : await this.db.getAll(...ids.map((id) => learning.doc(id)));
    metrics?.readDocument(docs.length);
    const has = (id: string) => docs.some((doc) => doc.id === id && doc.exists);
    const event = docs.find((doc) => doc.exists)?.data();
    const required = stringList(partProgress?.requiredSections);
    const recorded = Object.keys(record(partProgress?.sections) ?? {});
    const facts: GuideFacts = {
      ...(scope.partId === undefined ? {} : {
        partId: scope.partId,
        sections: recorded.filter((section) => required.length === 0 || required.includes(section)).sort(),
        partPassed: has(`part_passed_${scope.partId}`)
      }),
      ...(subtopicId === undefined ? {} : {
        subtopicId,
        subtopicCompleted: has(`subtopic_completed_${subtopicId}`),
        subtopicMastered: has(`subtopic_mastered_${subtopicId}`)
      }),
      ...(typeof partProgress?.courseId === "string" ? { courseId: partProgress.courseId } : typeof event?.courseId === "string" ? { courseId: event.courseId } : {}),
      ...(typeof partProgress?.topicId === "string" ? { topicId: partProgress.topicId } : typeof event?.topicId === "string" ? { topicId: event.topicId } : {}),
      atMs: Date.now()
    };
    return this.grant(uid, (_, settings) => guideGrants(facts, settings), metrics);
  }

  /**
   * The student watched the rewarded video of a failed question
   * (docs/xp_contract.md, «Explicación con video»). Only the owner of a
   * submitted attempt, only for a question it got wrong or left blank;
   * repeated calls give nothing (fixed event id).
   */
  public async afterExplanationVideo(
    uid: string,
    attemptId: string,
    questionId: string,
    metrics?: OperationMetrics
  ): Promise<XpAward | undefined> {
    const attempt = await this.db.collection(this.config.collections.attempts).doc(attemptId).get();
    metrics?.readDocument();
    const data = attempt.data();
    if (data?.userId !== uid || data?.status !== "submitted") return undefined;
    // The review is not stored with the attempt: correctness comes from the
    // frozen answer key of that question (one more read, once per question).
    const snapshots = Array.isArray(data.questionSnapshots) ? data.questionSnapshots.map(record) : [];
    const version = snapshots.find((question) => question?.questionId === questionId)?.version;
    if (typeof version !== "number") return undefined;
    const key = await this.db.collection(this.config.collections.answerKeys).doc(`${questionId}_${version}`).get();
    metrics?.readDocument();
    const correct = key.data()?.correctAlternativeId;
    if (typeof correct !== "string" || record(data.answers)?.[questionId] === correct) return undefined;
    const atMs = Date.now();
    return this.grant(uid, (_, settings) => explanationGrant(attemptId, questionId, atMs, settings), metrics);
  }

  /**
   * After any submitted attempt: Simulator or guide (part exam / mastery).
   * [known] = the attempt as the submit left it, so it is not read again.
   */
  public async afterAttempt(
    uid: string,
    attemptId: string,
    metrics?: OperationMetrics,
    known?: Record<string, unknown>
  ): Promise<XpAward | undefined> {
    let data = known;
    if (data === undefined) {
      const attempt = await this.db.collection(this.config.collections.attempts).doc(attemptId).get();
      metrics?.readDocument();
      data = attempt.data();
    }
    if (data?.userId !== uid) return undefined;
    if (record(data.simulator) !== undefined) return this.afterSimulatorAttempt(uid, attemptId, metrics, data);
    const partContext = record(data.partContext);
    const partId = typeof data.partId === "string" && data.partId.length > 0 ? data.partId : undefined;
    const subtopicId = typeof partContext?.subtopicId === "string"
      ? partContext.subtopicId
      : typeof data.subtopicId === "string" ? data.subtopicId : undefined;
    return this.afterGuide(uid, { ...(partId ? { partId } : {}), ...(subtopicId ? { subtopicId } : {}) }, metrics);
  }
}
