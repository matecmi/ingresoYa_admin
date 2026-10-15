import type { DocumentReference, Firestore, Transaction } from "firebase-admin/firestore";
import { FieldValue } from "firebase-admin/firestore";

import {
  gradeFrozenAttempt,
  parseFrozenAnswerKey,
  projectAttemptResponse,
  validateAnswerPatch,
  type AttemptQuestionSnapshot,
  type AttemptReview,
  type CreateExamAttemptResponse,
  type ExamAttemptResponse,
  type FrozenAnswerKey,
  type SubmittedAttemptResponse
} from "./attempt_service";
import type { BackendConfig } from "./config";
import { type CandidateQuestion, parseCandidateQuestion } from "./exam_contracts";
import { failedPrecondition, notFound } from "./errors";
import { OperationMetrics } from "./operation_metrics";
import { randomStarts, shuffle } from "./selection";
import type {
  MistakesAttemptInput,
  PlanAttemptInput,
  PastExamAttemptInput,
  PracticeAttemptInput,
  PracticeDifficulty,
  PracticeSource,
  SubmitExamAttemptInput
} from "./validation";

/** Purposes served by this module; the others belong to the study guide. */
export type SimulatorPurpose = "past_exam" | "practice";

export type SimulatorAttemptInput =
  PastExamAttemptInput | PracticeAttemptInput | MistakesAttemptInput | PlanAttemptInput;

function isPlanInput(input: SimulatorAttemptInput): input is PlanAttemptInput {
  return input.purpose === "practice" && (input.mode === "plan" || input.mode === "diagnostic");
}

export function isSimulatorPurpose(value: unknown): value is SimulatorPurpose {
  return value === "past_exam" || value === "practice";
}

/** Rules of a registered exam, `admissionExams/{examId}.simulator` (contract §1). */
export interface PastExamRules {
  questionCount: number;
  durationMinutes: number;
  maxScore: number;
  correctPoints: number;
  incorrectPoints: number;
  blankPoints: number;
  questionOrder: "original" | "shuffled";
  available: boolean;
  cutoffs: Record<string, number>;
}

export interface PracticeSize {
  key: string;
  label: string;
  questions: number;
  minutes: number;
}

/** `{config}/simulator`; every missing field falls back to the factory value. */
export interface SimulatorSettings {
  practiceSizes: PracticeSize[];
  practicePenalty: boolean;
  repeatWindowDays: number;
  defaultSource: PracticeSource;
  defaultDifficulty: PracticeDifficulty;
  showOtherUniversities: boolean;
  showExplanations: boolean;
  plan: PlanSettings;
}

/** `{config}/simulator.plan` (contract §4), only what Functions uses. */
export interface PlanSettings {
  dailyQuestions: number;
  dailyMinutes: number;
  weakSharePercent: number;
  weakThresholdPercent: number;
  minAnswersToJudge: number;
  diagnosticPerCourse: number;
  diagnosticMinutes: number;
}

export interface TopicStat {
  topicId: string;
  courseId: string;
  answered: number;
  correct: number;
}

/** Weakest first: judged topics below the threshold (contract §4). */
export function weakTopics(stats: readonly TopicStat[], plan: PlanSettings, limit = 3): TopicStat[] {
  return stats
    .filter((stat) => stat.answered >= plan.minAnswersToJudge &&
      stat.correct * 100 < stat.answered * plan.weakThresholdPercent)
    .sort((a, b) => a.correct / a.answered - b.correct / b.answered || b.answered - a.answered)
    .slice(0, limit);
}

export function parsePlanSettings(value: unknown): PlanSettings {
  const raw = record(value) ?? {};
  const bounded = (key: string, fallback: number, min: number, max: number): number => {
    const parsed = integer(raw[key]);
    return parsed !== undefined && parsed >= min && parsed <= max ? parsed : fallback;
  };
  return {
    dailyQuestions: bounded("dailyQuestions", 10, 5, 40),
    dailyMinutes: bounded("dailyMinutes", 15, 5, 120),
    weakSharePercent: bounded("weakSharePercent", 60, 0, 100),
    weakThresholdPercent: bounded("weakThresholdPercent", 50, 1, 99),
    minAnswersToJudge: bounded("minAnswersToJudge", 5, 1, 50),
    diagnosticPerCourse: bounded("diagnosticPerCourse", 4, 1, 10),
    diagnosticMinutes: bounded("diagnosticMinutes", 30, 5, 180)
  };
}

export interface SimulatorScoring {
  questionCount: number;
  maxScore: number;
  correctPoints: number;
  incorrectPoints: number;
  blankPoints: number;
}

export interface GroupResult {
  id: string;
  total: number;
  correct: number;
  incorrect: number;
  blank: number;
}

export interface SimulatorResult {
  purpose: SimulatorPurpose;
  total: number;
  correct: number;
  incorrect: number;
  blank: number;
  rawScore: number;
  /** Official score over `maxScore` (past exam) or 0–100 (practice). */
  score: number;
  maxScore: number;
  percentage: number;
  timeUsedSeconds: number | null;
  byCourse: GroupResult[];
  byTopic: GroupResult[];
  examId?: string;
  cutoffScore?: number;
  reachedCutoff?: boolean;
  /** Past exam: score of the student's previous try at the same exam. */
  previousScore?: number;
  gradedAtMs: number;
}

/** Public context the app needs to draw an attempt; nothing private. */
export interface PublicSimulatorContext {
  purpose: SimulatorPurpose;
  timed: boolean;
  examId?: string;
  examUniversityId?: string;
  mode?: string;
  courseIds: string[];
  size?: string;
  /** Plan session: the weak topics it focuses on. */
  focusTopicIds?: string[];
  /** Course of each question, aligned with `questions` by order. */
  questionCourseIds: string[];
}

interface QuestionMeta {
  questionId: string;
  courseId: string;
  topicId: string;
  subtopicId: string;
  partIds: string[];
}

interface Picked {
  question: CandidateQuestion;
  alternativeOrder: string[];
}

const factorySizes: PracticeSize[] = [
  { key: "short", label: "Corto", questions: 10, minutes: 15 },
  { key: "normal", label: "Normal", questions: 20, minutes: 30 },
  { key: "long", label: "Largo", questions: 40, minutes: 60 }
];

/** Practice without a clock still needs an end: the attempt closes after this. */
export const untimedPracticeSeconds = 4 * 60 * 60;
/** «Practicar mis errores»: at most this many questions, 90 s each. */
export const maxMistakes = 100;
export const mistakeSecondsPerQuestion = 90;
/** Late submissions within this window still count the answers they carry. */
export const submitGraceMs = 2 * 60 * 1000;
/** Penalty per wrong answer when `practicePenalty` is on (contract §2). */
export const practicePenaltyPoints = -0.25;
const realSources = new Set(["admission_exam", "official_practice"]);
const requestKeyRetentionMs = 30 * 24 * 60 * 60 * 1000;
const recentQuestionRetentionMs = 120 * 24 * 60 * 60 * 1000;
const dayMs = 24 * 60 * 60 * 1000;

export function parsePastExamRules(value: unknown): PastExamRules | undefined {
  const raw = record(value);
  if (raw === undefined) return undefined;
  const questionCount = integer(raw.questionCount);
  const durationMinutes = integer(raw.durationMinutes);
  const maxScore = integer(raw.maxScore);
  const correctPoints = finite(raw.correctPoints);
  const incorrectPoints = finite(raw.incorrectPoints);
  const blankPoints = finite(raw.blankPoints) ?? 0;
  if (
    questionCount === undefined || questionCount < 1 || questionCount > 300 ||
    durationMinutes === undefined || durationMinutes < 1 || durationMinutes > 600 ||
    maxScore === undefined || maxScore < 1 ||
    correctPoints === undefined || correctPoints <= 0 ||
    incorrectPoints === undefined || incorrectPoints > 0 ||
    blankPoints < incorrectPoints || blankPoints > correctPoints
  ) {
    return undefined;
  }
  const cutoffs: Record<string, number> = {};
  for (const [professionId, cutoff] of Object.entries(record(raw.cutoffs) ?? {})) {
    if (typeof cutoff === "number" && Number.isFinite(cutoff) && cutoff >= 0) {
      cutoffs[professionId] = Math.round(cutoff);
    }
  }
  return {
    questionCount,
    durationMinutes,
    maxScore,
    correctPoints,
    incorrectPoints,
    blankPoints,
    questionOrder: raw.questionOrder === "original" ? "original" : "shuffled",
    available: raw.available === true,
    cutoffs
  };
}

export function parseSimulatorSettings(value: unknown): SimulatorSettings {
  const raw = record(value) ?? {};
  const sizes = Array.isArray(raw.practiceSizes)
    ? raw.practiceSizes.flatMap((entry): PracticeSize[] => {
        const size = record(entry);
        const key = typeof size?.key === "string" ? size.key.trim() : "";
        const label = typeof size?.label === "string" ? size.label.trim() : "";
        const questions = integer(size?.questions);
        const minutes = integer(size?.minutes);
        return key.length > 0 && label.length > 0 &&
          questions !== undefined && questions >= 10 && questions <= 100 &&
          minutes !== undefined && minutes >= 1 && minutes <= 300
          ? [{ key, label, questions, minutes }]
          : [];
      })
    : [];
  const repeat = integer(raw.repeatWindowDays);
  return {
    practiceSizes: sizes.length > 0 ? sizes : factorySizes,
    practicePenalty: raw.practicePenalty === true,
    repeatWindowDays: repeat !== undefined && repeat >= 0 && repeat <= 365 ? repeat : 14,
    defaultSource: raw.defaultSource === "real" || raw.defaultSource === "original"
      ? raw.defaultSource
      : "both",
    defaultDifficulty: raw.defaultDifficulty === "easy" || raw.defaultDifficulty === "medium" ||
      raw.defaultDifficulty === "hard"
      ? raw.defaultDifficulty
      : "mixed",
    showOtherUniversities: raw.showOtherUniversities !== false,
    showExplanations: raw.showExplanations !== false,
    plan: parsePlanSettings(raw.plan)
  };
}

/** Contract §1: all correct = `maxScore`; never below zero. */
export function officialScore(
  scoring: SimulatorScoring,
  counts: { correct: number; incorrect: number; blank: number }
): { rawScore: number; score: number } {
  const rawScore = counts.correct * scoring.correctPoints +
    counts.incorrect * scoring.incorrectPoints +
    counts.blank * scoring.blankPoints;
  const best = scoring.questionCount * scoring.correctPoints;
  return {
    rawScore: Math.round(rawScore * 1000) / 1000,
    score: best > 0 ? Math.round((Math.max(0, rawScore) * scoring.maxScore) / best) : 0
  };
}

/** Splits [total] among [ids] as evenly as possible; earlier ids get the rest. */
export function splitEvenly(ids: readonly string[], total: number): Map<string, number> {
  const result = new Map<string, number>();
  if (ids.length === 0) return result;
  const base = Math.floor(total / ids.length);
  ids.forEach((id, index) => result.set(id, base + (index < total % ids.length ? 1 : 0)));
  return result;
}

/** Correct/incorrect/blank per course and per topic, from the frozen metadata. */
export function groupResults(
  review: readonly Pick<AttemptReview, "questionId" | "selectedAlternativeId" | "isCorrect">[],
  meta: ReadonlyMap<string, QuestionMeta>
): { byCourse: GroupResult[]; byTopic: GroupResult[] } {
  const courses = new Map<string, GroupResult>();
  const topics = new Map<string, GroupResult>();
  const add = (groups: Map<string, GroupResult>, id: string, item: (typeof review)[number]) => {
    if (id.length === 0) return;
    const group = groups.get(id) ?? { id, total: 0, correct: 0, incorrect: 0, blank: 0 };
    group.total += 1;
    if (item.isCorrect) group.correct += 1;
    else if (item.selectedAlternativeId === null) group.blank += 1;
    else group.incorrect += 1;
    groups.set(id, group);
  };
  for (const item of review) {
    const info = meta.get(item.questionId);
    add(courses, info?.courseId ?? "", item);
    add(topics, info?.topicId ?? "", item);
  }
  return { byCourse: [...courses.values()], byTopic: [...topics.values()] };
}

/** Whether a candidate matches the practice's source and difficulty choice. */
export function matchesPractice(
  question: Pick<CandidateQuestion, "sourceType" | "difficulty">,
  source: PracticeSource,
  difficulty: PracticeDifficulty
): boolean {
  const real = realSources.has(question.sourceType);
  if (source === "real" && !real) return false;
  if (source === "original" && real) return false;
  return difficulty === "mixed" || question.difficulty === difficulty;
}

/**
 * Takes [count] questions, unseen first (by the seeded order). Seen questions
 * fill the gap only when the bank is too small to avoid repeats.
 */
export function pickFresh(
  pool: readonly CandidateQuestion[],
  count: number,
  seen: ReadonlySet<string>,
  taken: ReadonlySet<string>,
  seed: string
): CandidateQuestion[] {
  const available = shuffle(pool.filter((question) => !taken.has(question.questionId)), seed);
  const fresh = available.filter((question) => !seen.has(question.questionId));
  const repeated = available.filter((question) => seen.has(question.questionId));
  return [...fresh, ...repeated].slice(0, count);
}

export class SimulatorService {
  public constructor(
    private readonly db: Firestore,
    private readonly config: BackendConfig
  ) {}

  public async create(
    uid: string,
    input: SimulatorAttemptInput,
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<CreateExamAttemptResponse> {
    const requestRef = this.userRef(uid).collection("examRequestKeys").doc(input.requestId);
    const previous = await requestRef.get();
    metrics.readDocument();
    if (previous.exists) return this.existing(uid, previous.data()?.attemptId, input, metrics);

    const [profile, settings] = await Promise.all([
      this.profile(uid, metrics),
      this.settings(metrics)
    ]);
    const plan = input.purpose === "past_exam"
      ? await this.pastExamPlan(uid, input, profile, settings, metrics)
      : input.mode === "mistakes"
        ? await this.mistakesPlan(uid, input, settings, metrics)
        : isPlanInput(input)
          ? input.mode === "plan"
            ? await this.dailyPlan(uid, input, settings, metrics)
            : await this.diagnosticPlan(uid, input, settings, metrics)
          : await this.practicePlan(uid, input, settings, metrics);

    const attemptRef = this.db.collection(this.config.collections.attempts).doc();
    const now = Date.now();
    const expiresAtMs = now + plan.durationSeconds * 1000;
    const questions: AttemptQuestionSnapshot[] = plan.picked.map(({ question, alternativeOrder }, order) => ({
      questionId: question.questionId,
      version: question.version,
      order,
      content: question.content,
      alternatives: question.alternatives.map(({ id, label, content }) => ({ id, label, content })),
      sourceLabel: question.sourceLabel,
      alternativeOrder
    }));
    const simulator = {
      ...plan.context,
      purpose: input.purpose,
      universityId: profile.universityId,
      professionId: profile.professionId ?? null,
      scoring: plan.scoring,
      ...(plan.cutoffScore === undefined ? {} : { cutoffScore: plan.cutoffScore })
    };
    const publicContext = publicSimulatorContext(simulator, plan.picked.map(({ question }) => question.courseId));
    const created = await this.db.runTransaction(async (transaction) => {
      metrics.transactionAttempt();
      const existing = await transaction.get(requestRef);
      metrics.readDocument();
      if (existing.exists) return false;
      transaction.set(attemptRef, {
        schemaVersion: 2,
        id: attemptRef.id,
        userId: uid,
        requestId: input.requestId,
        templateId: `simulator_${input.purpose}`,
        templateVersion: 1,
        templateSnapshot: {
          title: plan.title,
          purpose: input.purpose,
          selectionPolicy: "simulator",
          passPercentExclusive: 0,
          durationSeconds: plan.durationSeconds
        },
        partId: "",
        simulator,
        questionMeta: plan.picked.map(({ question }) => ({
          questionId: question.questionId,
          courseId: question.courseId,
          topicId: question.topicId,
          subtopicId: question.subtopicId,
          partIds: question.partIds
        })),
        status: "in_progress",
        createdAt: FieldValue.serverTimestamp(),
        createdAtMs: now,
        expiresAt: new Date(expiresAtMs),
        questions: questions.map(({ questionId, version, alternativeOrder }) => ({
          questionId,
          version,
          alternativeOrder
        })),
        questionSnapshots: questions,
        answers: {},
        // Simulator attempts are scored, not passed/failed (contract §3).
        requiredCorrectAnswers: 1
      });
      transaction.set(requestRef, {
        attemptId: attemptRef.id,
        createdAt: FieldValue.serverTimestamp(),
        expireAt: new Date(now + requestKeyRetentionMs)
      });
      for (const question of questions) {
        transaction.set(
          this.userRef(uid).collection("recentQuestions").doc(question.questionId),
          {
            exposureCount: FieldValue.increment(1),
            lastSeenAt: FieldValue.serverTimestamp(),
            expireAt: new Date(now + recentQuestionRetentionMs)
          },
          { merge: true }
        );
      }
      return true;
    });
    if (!created) {
      const request = await requestRef.get();
      metrics.readDocument();
      return this.existing(uid, request.data()?.attemptId, input, metrics);
    }
    metrics.writeDocument(2 + questions.length);
    return {
      attemptId: attemptRef.id,
      status: "in_progress",
      title: plan.title,
      questionCount: questions.length,
      requiredCorrectAnswers: 1,
      expiresAt: new Date(expiresAtMs).toISOString(),
      durationSeconds: plan.durationSeconds,
      questions,
      simulator: publicContext
    };
  }

  /**
   * Grades once with the exam's frozen scoring. A timed attempt is still
   * graded after its clock ran out: answers saved before then count, and the
   * final patch counts only inside [submitGraceMs].
   */
  public async submit(
    uid: string,
    input: SubmitExamAttemptInput,
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<SubmittedAttemptResponse> {
    const attemptRef = this.db.collection(this.config.collections.attempts).doc(input.attemptId);
    const settings = await this.settings(metrics);
    return this.db.runTransaction(async (transaction) => {
      metrics.transactionAttempt();
      const snapshot = await transaction.get(attemptRef);
      metrics.readDocument();
      const data = snapshot.data();
      if (!snapshot.exists || data?.userId !== uid) {
        throw notFound("Exam attempt not found.", "attempt_not_found");
      }
      const attempt = projectAttemptResponse(input.attemptId, data);
      const simulator = record(data.simulator);
      const purpose = simulator?.purpose;
      const scoring = parseScoring(simulator?.scoring);
      if (!isSimulatorPurpose(purpose) || scoring === undefined) {
        throw failedPrecondition("The stored exam attempt is invalid.", {
          reason: "attempt_data_invalid"
        });
      }
      const meta = parseQuestionMeta(data.questionMeta);
      const keys = await this.answerKeys(transaction, attempt.questions, metrics);
      if (attempt.status === "submitted") {
        const stored = parseStoredSimulatorResult(data.simulatorResult);
        if (stored === undefined) {
          throw failedPrecondition("The stored exam result is invalid.", {
            reason: "attempt_data_invalid"
          });
        }
        return simulatorResponse(attempt, attempt.answers, keys, meta, stored, settings);
      }
      const now = Date.now();
      const expiresAtMs = Date.parse(attempt.expiresAt);
      const acceptsPatch = attempt.status === "in_progress" || now <= expiresAtMs + submitGraceMs;
      if (acceptsPatch) validateAnswerPatch(attempt.questions, input.answers);
      const answers = acceptsPatch ? { ...attempt.answers, ...input.answers } : attempt.answers;
      const grading = gradeFrozenAttempt(attempt.questions, answers, keys, 0);
      const blank = grading.review.filter((item) => item.selectedAlternativeId === null).length;
      const counts = {
        correct: grading.correctAnswers,
        incorrect: attempt.questions.length - grading.correctAnswers - blank,
        blank
      };
      const { rawScore, score } = officialScore(scoring, counts);
      const groups = groupResults(grading.review, meta);
      const examId = typeof simulator?.examId === "string" ? simulator.examId : undefined;
      const cutoffScore = typeof simulator?.cutoffScore === "number" ? simulator.cutoffScore : undefined;
      const result: SimulatorResult = {
        purpose,
        total: attempt.questions.length,
        ...counts,
        rawScore,
        score,
        maxScore: scoring.maxScore,
        percentage: Math.round((counts.correct * 1000) / attempt.questions.length) / 10,
        timeUsedSeconds: attempt.startedAtMs === undefined
          ? null
          : Math.min(attempt.durationSeconds, Math.max(0, Math.round((Math.min(now, expiresAtMs) - attempt.startedAtMs) / 1000))),
        ...groups,
        ...(examId === undefined ? {} : { examId }),
        ...(cutoffScore === undefined ? {} : { cutoffScore, reachedCutoff: score >= cutoffScore }),
        gradedAtMs: now
      };

      const bestRef = examId === undefined ? undefined : this.userRef(uid).collection("pastExamBest").doc(examId);
      const best = bestRef === undefined ? undefined : await transaction.get(bestRef);
      if (bestRef !== undefined) metrics.readDocument();
      // «+N vs. anterior»: the score of the previous try at the same exam.
      const previousScore = best?.data()?.lastScore;
      if (typeof previousScore === "number") result.previousScore = previousScore;

      transaction.update(attemptRef, {
        answers,
        status: "submitted",
        submittedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        result: {
          schemaVersion: 2,
          attemptId: input.attemptId,
          total: result.total,
          correct: result.correct,
          passPercentExclusive: 0,
          gradedAtMs: now
        },
        simulatorResult: result
      });
      const summary = {
        attemptId: input.attemptId,
        purpose,
        title: attempt.title,
        examId: examId ?? null,
        mode: typeof simulator?.mode === "string" ? simulator.mode : null,
        courseIds: stringList(simulator?.courseIds),
        universityId: typeof simulator?.universityId === "string" ? simulator.universityId : null,
        professionId: typeof simulator?.professionId === "string" ? simulator.professionId : null,
        total: result.total,
        correct: result.correct,
        incorrect: result.incorrect,
        blank: result.blank,
        score: result.score,
        maxScore: result.maxScore,
        percentage: result.percentage,
        timeUsedSeconds: result.timeUsedSeconds,
        byCourse: result.byCourse,
        ...(cutoffScore === undefined ? {} : { cutoffScore, reachedCutoff: result.reachedCutoff }),
        submittedAtMs: now,
        submittedAt: FieldValue.serverTimestamp()
      };
      transaction.set(this.userRef(uid).collection("simulatorResults").doc(input.attemptId), summary);
      if (bestRef !== undefined) {
        const previousBest = typeof best?.data()?.bestScore === "number" ? best.data()!.bestScore as number : undefined;
        const improved = previousBest === undefined || score > previousBest;
        transaction.set(bestRef, {
          examId,
          attempts: FieldValue.increment(1),
          lastScore: score,
          lastAttemptId: input.attemptId,
          lastAtMs: now,
          maxScore: scoring.maxScore,
          ...(improved ? { bestScore: score, bestAttemptId: input.attemptId, bestAtMs: now } : {}),
          updatedAt: FieldValue.serverTimestamp()
        }, { merge: true });
      }
      // Per-topic accuracy for the training plan (contract §4).
      const topicCourses = new Map<string, string>();
      for (const info of meta.values()) {
        if (info.topicId.length > 0) topicCourses.set(info.topicId, info.courseId);
      }
      for (const topic of result.byTopic) {
        transaction.set(this.userRef(uid).collection("simulatorTopicStats").doc(topic.id), {
          topicId: topic.id,
          courseId: topicCourses.get(topic.id) ?? "",
          answered: FieldValue.increment(topic.total),
          correct: FieldValue.increment(topic.correct),
          updatedAtMs: now
        }, { merge: true });
      }
      metrics.writeDocument(result.byTopic.length);
      transaction.set(
        this.userRef(uid).collection("learningEvents").doc(`${purpose}_completed_${input.attemptId}`),
        learningEvent(`${purpose}_completed`, {
          attemptId: input.attemptId,
          ...(examId === undefined ? {} : { examId }),
          total: result.total,
          correct: result.correct,
          score
        })
      );
      metrics.writeDocument(bestRef === undefined ? 3 : 4);
      return simulatorResponse({ ...attempt, status: "submitted", answers }, answers, keys, meta, result, settings);
    });
  }

  private async pastExamPlan(
    uid: string,
    input: PastExamAttemptInput,
    profile: { universityId: string; professionId?: string },
    settings: SimulatorSettings,
    metrics: OperationMetrics
  ) {
    const universityRef = this.db.collection(this.config.collections.universities).doc(input.universityId);
    const [university, exam, questions] = await Promise.all([
      universityRef.get(),
      universityRef.collection("admissionExams").doc(input.examId).get(),
      this.db.collection(this.config.collections.questions).where("examId", "==", input.examId).get()
    ]);
    metrics.readDocument(2);
    metrics.readQuery(questions.size);
    const rules = parsePastExamRules(exam.data()?.simulator);
    if (
      !university.exists || university.data()?.active === false ||
      university.data()?.simulatorVisible === false ||
      (input.universityId !== profile.universityId && !settings.showOtherUniversities) ||
      !exam.exists || exam.data()?.active === false ||
      rules === undefined || !rules.available
    ) {
      throw failedPrecondition("This past exam is not offered in the Simulator.", {
        reason: "past_exam_unavailable"
      });
    }
    const loaded = questions.docs.flatMap((document) => {
      const data = document.data();
      if (data.universityId !== input.universityId) return [];
      const question = parseCandidateQuestion(document.id, data);
      if (question === undefined) return [];
      const number = integer(data.originalNumber);
      return [{ question, number: number !== undefined && number > 0 ? number : undefined }];
    });
    const numbers = loaded.map((item) => item.number).filter((value): value is number => value !== undefined);
    if (
      loaded.length !== rules.questionCount ||
      (rules.questionOrder === "original" &&
        (numbers.length !== loaded.length || new Set(numbers).size !== numbers.length))
    ) {
      throw failedPrecondition("This past exam is incomplete.", {
        reason: "past_exam_incomplete",
        published: loaded.length,
        required: rules.questionCount
      });
    }
    const seed = `${uid}:${input.requestId}`;
    const ordered = rules.questionOrder === "original"
      ? [...loaded].sort((left, right) => left.number! - right.number!)
      : shuffle(loaded, `${seed}:questions`);
    const picked: Picked[] = ordered.map(({ question }) => ({
      question,
      // The original exam keeps its letters; a shuffled one mixes them too.
      alternativeOrder: rules.questionOrder === "original"
        ? question.alternatives.map((alternative) => alternative.id)
        : shuffle(question.alternatives.map((alternative) => alternative.id), `${seed}:${question.questionId}`)
    }));
    const examData = exam.data()!;
    const professionId = profile.professionId;
    const cutoffScore = input.universityId === profile.universityId && professionId !== undefined
      ? rules.cutoffs[professionId]
      : undefined;
    return {
      title: typeof examData.name === "string" && examData.name.trim().length > 0
        ? examData.name.trim()
        : "Examen pasado",
      durationSeconds: rules.durationMinutes * 60,
      picked,
      scoring: {
        questionCount: rules.questionCount,
        maxScore: rules.maxScore,
        correctPoints: rules.correctPoints,
        incorrectPoints: rules.incorrectPoints,
        blankPoints: rules.blankPoints
      },
      cutoffScore,
      context: {
        timed: true,
        examId: input.examId,
        examUniversityId: input.universityId,
        questionOrder: rules.questionOrder,
        courseIds: [] as string[]
      }
    };
  }

  /**
   * The questions the student got wrong or left blank in one of their own
   * submitted Simulador attempts, with the same frozen revisions.
   */
  private async mistakesPlan(
    uid: string,
    input: MistakesAttemptInput,
    settings: SimulatorSettings,
    metrics: OperationMetrics
  ) {
    const source = await this.db.collection(this.config.collections.attempts).doc(input.fromAttemptId).get();
    metrics.readDocument();
    const data = source.data();
    const simulator = record(data?.simulator);
    if (!source.exists || data?.userId !== uid || !isSimulatorPurpose(simulator?.purpose) ||
      data?.status !== "submitted") {
      throw failedPrecondition("That attempt cannot be practiced again.", { reason: "mistakes_unavailable" });
    }
    const attempt = projectAttemptResponse(input.fromAttemptId, data);
    const keys = await this.db.getAll(
      ...attempt.questions.map((question) =>
        this.db.collection(this.config.collections.answerKeys).doc(`${question.questionId}_${question.version}`)
      )
    );
    metrics.readDocument(keys.length);
    const meta = parseQuestionMeta(data.questionMeta);
    const missed = attempt.questions.filter((question, index) => {
      const key = keys[index]?.data();
      return key === undefined || attempt.answers[question.questionId] !== key.correctAlternativeId;
    }).slice(0, maxMistakes);
    if (missed.length === 0) {
      throw failedPrecondition("There are no mistakes to practice.", { reason: "no_mistakes" });
    }
    const seed = `${uid}:${input.requestId}`;
    const picked: Picked[] = shuffle(missed, `${seed}:questions`).map((question) => {
      const info = meta.get(question.questionId);
      return {
        question: {
          questionId: question.questionId,
          version: question.version,
          randomKey: 0,
          sourceLabel: question.sourceLabel,
          universityId: "",
          sourceType: "other",
          sourceExamId: "",
          modalityId: "",
          courseId: info?.courseId ?? "",
          topicId: info?.topicId ?? "",
          subtopicId: info?.subtopicId ?? "",
          partIds: info?.partIds ?? [],
          difficulty: "medium",
          content: question.content,
          alternatives: question.alternatives
        },
        alternativeOrder: shuffle(question.alternativeOrder, `${seed}:${question.questionId}`)
      };
    });
    return {
      title: "Mis errores",
      durationSeconds: input.timed ? picked.length * mistakeSecondsPerQuestion : untimedPracticeSeconds,
      picked,
      scoring: {
        questionCount: picked.length,
        maxScore: 100,
        correctPoints: 1,
        incorrectPoints: settings.practicePenalty ? practicePenaltyPoints : 0,
        blankPoints: 0
      },
      cutoffScore: undefined,
      context: {
        timed: input.timed,
        mode: "mistakes",
        fromAttemptId: input.fromAttemptId,
        courseIds: [...new Set(picked.map(({ question }) => question.courseId).filter((id) => id.length > 0))]
      }
    };
  }

  /**
   * «Hoy te toca»: a share of the session from the weakest topics, the rest
   * from all active courses; without weak topics everything is mixed.
   */
  private async dailyPlan(
    uid: string,
    input: PlanAttemptInput,
    settings: SimulatorSettings,
    metrics: OperationMetrics
  ) {
    const plan = settings.plan;
    const [stats, seen] = await Promise.all([
      this.topicStats(uid, metrics),
      this.seenSince(uid, settings.repeatWindowDays, metrics)
    ]);
    const focus = weakTopics(stats, plan);
    const seed = `${uid}:${input.requestId}`;
    const taken = new Set<string>();
    const picked: CandidateQuestion[] = [];
    const weakWanted = focus.length === 0 ? 0 : Math.round(plan.dailyQuestions * plan.weakSharePercent / 100);
    const perTopic = splitEvenly(focus.map((topic) => topic.topicId), weakWanted);
    for (const topic of focus) {
      const pool = await this.coursePool(topic.courseId, [topic.topicId], (perTopic.get(topic.topicId) ?? 0) * 3,
        `${seed}:${topic.topicId}`, metrics);
      const chosen = pickFresh(pool, perTopic.get(topic.topicId) ?? 0, seen, taken, `${seed}:${topic.topicId}:pick`);
      chosen.forEach((question) => taken.add(question.questionId));
      picked.push(...chosen);
    }
    const courseIds = await this.randomCourses(uid, input.requestId, metrics);
    let missing = plan.dailyQuestions - picked.length;
    const want = splitEvenly(courseIds, missing);
    const pools = new Map<string, CandidateQuestion[]>();
    for (const courseId of courseIds) {
      pools.set(courseId, await this.coursePool(courseId, [], (want.get(courseId) ?? 0) * 3, `${seed}:${courseId}`, metrics));
    }
    for (const courseId of courseIds) {
      const chosen = pickFresh(pools.get(courseId) ?? [], want.get(courseId) ?? 0, seen, taken, `${seed}:${courseId}:pick`);
      chosen.forEach((question) => taken.add(question.questionId));
      picked.push(...chosen);
    }
    missing = plan.dailyQuestions - picked.length;
    for (const courseId of courseIds) {
      if (missing <= 0) break;
      const extra = pickFresh(pools.get(courseId) ?? [], missing, seen, taken, `${seed}:${courseId}:extra`);
      extra.forEach((question) => taken.add(question.questionId));
      picked.push(...extra);
      missing -= extra.length;
    }
    if (missing > 0) {
      throw failedPrecondition("There are not enough questions for this session.", {
        reason: "insufficient_questions",
        available: picked.length,
        required: plan.dailyQuestions
      });
    }
    return {
      title: "Hoy te toca",
      durationSeconds: input.timed ? plan.dailyMinutes * 60 : untimedPracticeSeconds,
      picked: this.shuffled(picked, seed),
      scoring: practiceScoring(picked.length, settings),
      cutoffScore: undefined,
      context: {
        timed: input.timed,
        mode: "plan",
        courseIds: [...new Set(picked.map((question) => question.courseId))],
        focusTopicIds: focus.map((topic) => topic.topicId)
      }
    };
  }

  /** First session without history: a few questions of every active course. */
  private async diagnosticPlan(
    uid: string,
    input: PlanAttemptInput,
    settings: SimulatorSettings,
    metrics: OperationMetrics
  ) {
    const plan = settings.plan;
    const courses = await this.db.collection(this.config.collections.courses).get();
    metrics.readQuery(courses.size);
    const seed = `${uid}:${input.requestId}`;
    const taken = new Set<string>();
    const picked: CandidateQuestion[] = [];
    const courseIds: string[] = [];
    for (const course of courses.docs) {
      if (!isActive(course.data())) continue;
      const pool = await this.coursePool(course.id, [], plan.diagnosticPerCourse * 3, `${seed}:${course.id}`, metrics);
      // Only courses with enough questions (contract §4).
      if (pool.length < plan.diagnosticPerCourse) continue;
      const chosen = pickFresh(pool, plan.diagnosticPerCourse, new Set(), taken, `${seed}:${course.id}:pick`);
      chosen.forEach((question) => taken.add(question.questionId));
      picked.push(...chosen);
      courseIds.push(course.id);
    }
    if (picked.length === 0) {
      throw failedPrecondition("There are no questions for a diagnostic yet.", {
        reason: "insufficient_questions",
        available: 0,
        required: plan.diagnosticPerCourse
      });
    }
    return {
      title: "Diagnóstico inicial",
      durationSeconds: untimedPracticeSeconds,
      picked: this.shuffled(picked, seed),
      scoring: practiceScoring(picked.length, settings),
      cutoffScore: undefined,
      context: { timed: false, mode: "diagnostic", courseIds }
    };
  }

  private shuffled(questions: readonly CandidateQuestion[], seed: string): Picked[] {
    return shuffle(questions, `${seed}:questions`).map((question) => ({
      question,
      alternativeOrder: shuffle(question.alternatives.map((alternative) => alternative.id), `${seed}:${question.questionId}`)
    }));
  }

  private async topicStats(uid: string, metrics: OperationMetrics): Promise<TopicStat[]> {
    const snapshot = await this.userRef(uid).collection("simulatorTopicStats").get();
    metrics.readQuery(snapshot.size);
    return snapshot.docs.flatMap((doc) => {
      const data = doc.data();
      const answered = integer(data.answered) ?? 0;
      const correct = integer(data.correct) ?? 0;
      const courseId = typeof data.courseId === "string" ? data.courseId : "";
      return answered > 0 && courseId.length > 0 ? [{ topicId: doc.id, courseId, answered, correct }] : [];
    });
  }

  private async practicePlan(
    uid: string,
    input: PracticeAttemptInput,
    settings: SimulatorSettings,
    metrics: OperationMetrics
  ) {
    const size = settings.practiceSizes.find((entry) => entry.key === input.size);
    if (size === undefined) {
      throw failedPrecondition("The practice size is not offered.", { reason: "practice_size_unavailable" });
    }
    const courseIds = input.mode === "random"
      ? await this.randomCourses(uid, input.requestId, metrics)
      : await this.activeCourses(input.courseIds, metrics);
    const topicIds = input.topicIds.length > 0
      ? await this.activeTopics(courseIds[0]!, input.topicIds, metrics)
      : [];
    const source = input.source ?? settings.defaultSource;
    const difficulty = input.difficulty ?? settings.defaultDifficulty;
    const seen = await this.seenSince(uid, settings.repeatWindowDays, metrics);
    const seed = `${uid}:${input.requestId}`;

    // Gather a bounded pool per course, then share out the questions; a course
    // with too few questions hands its remainder to the others.
    const pools = new Map<string, CandidateQuestion[]>();
    const want = splitEvenly(courseIds, size.questions);
    for (const courseId of courseIds) {
      const pool = await this.coursePool(courseId, topicIds, (want.get(courseId) ?? 0) * 3, `${seed}:${courseId}`, metrics);
      pools.set(courseId, pool.filter((question) => matchesPractice(question, source, difficulty)));
    }
    const taken = new Set<string>();
    const picked: CandidateQuestion[] = [];
    let missing = 0;
    for (const courseId of courseIds) {
      const chosen = pickFresh(pools.get(courseId) ?? [], want.get(courseId) ?? 0, seen, taken, `${seed}:${courseId}:pick`);
      chosen.forEach((question) => taken.add(question.questionId));
      picked.push(...chosen);
      missing += (want.get(courseId) ?? 0) - chosen.length;
    }
    for (const courseId of courseIds) {
      if (missing === 0) break;
      const extra = pickFresh(pools.get(courseId) ?? [], missing, seen, taken, `${seed}:${courseId}:extra`);
      extra.forEach((question) => taken.add(question.questionId));
      picked.push(...extra);
      missing -= extra.length;
    }
    if (missing > 0) {
      throw failedPrecondition("There are not enough questions for this practice.", {
        reason: "insufficient_questions",
        available: picked.length,
        required: size.questions
      });
    }
    const ordered = shuffle(picked, `${seed}:questions`).map((question) => ({
      question,
      alternativeOrder: shuffle(question.alternatives.map((alternative) => alternative.id), `${seed}:${question.questionId}`)
    }));
    return {
      title: `Práctica · ${size.label}`,
      durationSeconds: input.timed ? size.minutes * 60 : untimedPracticeSeconds,
      picked: ordered,
      scoring: {
        questionCount: size.questions,
        maxScore: 100,
        correctPoints: 1,
        incorrectPoints: settings.practicePenalty ? practicePenaltyPoints : 0,
        blankPoints: 0
      },
      cutoffScore: undefined,
      context: {
        timed: input.timed,
        mode: input.mode,
        courseIds,
        topicIds,
        size: size.key,
        source,
        difficulty
      }
    };
  }

  private async coursePool(
    courseId: string,
    topicIds: readonly string[],
    wanted: number,
    seed: string,
    metrics: OperationMetrics
  ): Promise<CandidateQuestion[]> {
    const limit = Math.min(this.config.selection.maxCandidatesPerStart, Math.max(20, wanted));
    const found = new Map<string, CandidateQuestion>();
    const scopes = topicIds.length > 0 ? topicIds : [undefined];
    for (const [index, topicId] of scopes.entries()) {
      for (const start of randomStarts(`${seed}:${index}`, 2)) {
        let query = this.db
          .collection(this.config.collections.questions)
          .where("status", "==", "published")
          .where("courseId", "==", courseId);
        if (topicId !== undefined) query = query.where("topicId", "==", topicId);
        const head = await query.where("randomKey", ">=", start).orderBy("randomKey").limit(limit).get();
        metrics.readQuery(head.size);
        const docs = [...head.docs];
        if (head.size < limit) {
          const tail = await query.where("randomKey", "<", start).orderBy("randomKey").limit(limit - head.size).get();
          metrics.readQuery(tail.size);
          docs.push(...tail.docs);
        }
        for (const document of docs) {
          const parsed = parseCandidateQuestion(document.id, document.data());
          if (parsed !== undefined && parsed.courseId === courseId) found.set(parsed.questionId, parsed);
        }
        if (docs.length < limit) break;
      }
    }
    return [...found.values()];
  }

  private async activeCourses(courseIds: readonly string[], metrics: OperationMetrics): Promise<string[]> {
    const refs = courseIds.map((id) => this.db.collection(this.config.collections.courses).doc(id));
    const courses = await this.db.getAll(...refs);
    metrics.readDocument(courses.length);
    if (courses.some((course) => !course.exists || !isActive(course.data()))) {
      throw failedPrecondition("A selected course is unavailable.", { reason: "course_not_available" });
    }
    return [...courseIds];
  }

  private async randomCourses(uid: string, requestId: string, metrics: OperationMetrics): Promise<string[]> {
    const courses = await this.db.collection(this.config.collections.courses).get();
    metrics.readQuery(courses.size);
    const active = courses.docs.filter((course) => isActive(course.data())).map((course) => course.id);
    if (active.length === 0) {
      throw failedPrecondition("There are no courses to practice.", { reason: "course_not_available" });
    }
    // Up to three random courses keep the mix varied without thin slices.
    return shuffle(active, `${uid}:${requestId}:courses`).slice(0, 3);
  }

  private async activeTopics(courseId: string, topicIds: readonly string[], metrics: OperationMetrics): Promise<string[]> {
    const course = this.db.collection(this.config.collections.courses).doc(courseId);
    const topics = await this.db.getAll(...topicIds.map((id) => course.collection("topics").doc(id)));
    metrics.readDocument(topics.length);
    if (topics.some((topic) => !topic.exists || !isActive(topic.data()))) {
      throw failedPrecondition("A selected topic is unavailable.", { reason: "topic_not_available" });
    }
    return [...topicIds];
  }

  private async seenSince(uid: string, days: number, metrics: OperationMetrics): Promise<Set<string>> {
    if (days === 0) return new Set();
    const recent = await this.userRef(uid)
      .collection("recentQuestions")
      .where("lastSeenAt", ">=", new Date(Date.now() - days * dayMs))
      .orderBy("lastSeenAt", "desc")
      .limit(500)
      .get();
    metrics.readQuery(recent.size);
    return new Set(recent.docs.map((document) => document.id));
  }

  private async profile(
    uid: string,
    metrics: OperationMetrics
  ): Promise<{ universityId: string; professionId?: string }> {
    const profile = await this.userRef(uid).get();
    metrics.readDocument();
    const data = profile.data();
    const nested = record(data?.profile);
    const universityId = firstId(data?.universityIdDoc, data?.universityId, nested?.universityIdDoc, nested?.universityId);
    if (!profile.exists || universityId === undefined) {
      throw failedPrecondition("The profile needs a selected university.", { reason: "profile_incomplete" });
    }
    const professionId = firstId(data?.professionIdDoc, data?.professionId, nested?.professionIdDoc, nested?.professionId);
    return { universityId, ...(professionId === undefined ? {} : { professionId }) };
  }

  private async settings(metrics: OperationMetrics): Promise<SimulatorSettings> {
    const snapshot = await this.db.collection(this.config.collections.config).doc("simulator").get();
    metrics.readDocument();
    return parseSimulatorSettings(snapshot.data());
  }

  private async existing(
    uid: string,
    attemptId: unknown,
    input: SimulatorAttemptInput,
    metrics: OperationMetrics
  ): Promise<CreateExamAttemptResponse> {
    if (typeof attemptId !== "string" || attemptId.length === 0) {
      throw failedPrecondition("The idempotency record is invalid.", { reason: "request_key_invalid" });
    }
    const snapshot = await this.db.collection(this.config.collections.attempts).doc(attemptId).get();
    metrics.readDocument();
    const data = snapshot.data();
    if (!snapshot.exists || data?.userId !== uid) {
      throw failedPrecondition("The idempotency record points to an unavailable attempt.", {
        reason: "request_key_orphaned"
      });
    }
    const simulator = record(data.simulator);
    const sameRequest = data.requestId === input.requestId && simulator?.purpose === input.purpose &&
      (input.purpose === "past_exam"
        ? simulator?.examId === input.examId && simulator?.examUniversityId === input.universityId
        : input.mode === "mistakes"
          ? simulator?.mode === "mistakes" && simulator?.fromAttemptId === input.fromAttemptId
          : isPlanInput(input)
            ? simulator?.mode === input.mode
            : simulator?.mode === input.mode && simulator?.size === input.size);
    if (!sameRequest) {
      throw failedPrecondition("The request ID belongs to another exam request.", { reason: "request_id_conflict" });
    }
    const response: ExamAttemptResponse = projectAttemptResponse(attemptId, data);
    return {
      attemptId,
      status: response.status,
      title: response.title,
      questionCount: response.questionCount,
      requiredCorrectAnswers: response.requiredCorrectAnswers,
      expiresAt: response.expiresAt,
      durationSeconds: response.durationSeconds,
      ...(response.startedAtMs === undefined ? {} : { startedAtMs: response.startedAtMs }),
      questions: response.questions,
      ...(response.simulator === undefined ? {} : { simulator: response.simulator })
    };
  }

  private async answerKeys(
    transaction: Transaction,
    questions: readonly AttemptQuestionSnapshot[],
    metrics: OperationMetrics
  ): Promise<FrozenAnswerKey[]> {
    const snapshots = await transaction.getAll(
      ...questions.map((question) =>
        this.db.collection(this.config.collections.answerKeys).doc(`${question.questionId}_${question.version}`)
      )
    );
    metrics.readDocument(snapshots.length);
    return snapshots.map((snapshot, index) => {
      const question = questions[index];
      if (question === undefined || !snapshot.exists) {
        throw failedPrecondition("A frozen answer key is unavailable.", { reason: "answer_key_unavailable" });
      }
      return parseFrozenAnswerKey(snapshot.data(), question);
    });
  }

  private userRef(uid: string): DocumentReference {
    return this.db.collection(this.config.collections.users).doc(uid);
  }
}

/** Fixed-id, server-written learning event (base of the future XP). */
export function learningEvent(type: string, data: Record<string, unknown>): Record<string, unknown> {
  return { schemaVersion: 1, type, ...data, occurredAt: FieldValue.serverTimestamp(), occurredAtMs: Date.now() };
}

/** The public part of a stored `simulator` field (see [PublicSimulatorContext]). */
export function publicSimulatorContext(
  value: unknown,
  questionCourseIds?: readonly string[]
): PublicSimulatorContext | undefined {
  const raw = record(value);
  if (raw === undefined || !isSimulatorPurpose(raw.purpose)) return undefined;
  return {
    purpose: raw.purpose,
    timed: raw.timed !== false,
    ...(typeof raw.examId === "string" ? { examId: raw.examId } : {}),
    ...(typeof raw.examUniversityId === "string" ? { examUniversityId: raw.examUniversityId } : {}),
    ...(typeof raw.mode === "string" ? { mode: raw.mode } : {}),
    courseIds: stringList(raw.courseIds),
    ...(typeof raw.size === "string" ? { size: raw.size } : {}),
    ...(Array.isArray(raw.focusTopicIds) ? { focusTopicIds: stringList(raw.focusTopicIds) } : {}),
    questionCourseIds: [...(questionCourseIds ?? [])]
  };
}

/** Course of each question by order, from the private metadata. */
export function questionCourseIds(data: Record<string, unknown>, questions: readonly AttemptQuestionSnapshot[]): string[] {
  const meta = parseQuestionMeta(data.questionMeta);
  return questions.map((question) => meta.get(question.questionId)?.courseId ?? "");
}

function simulatorResponse(
  attempt: ExamAttemptResponse,
  answers: Readonly<Record<string, string>>,
  keys: readonly FrozenAnswerKey[],
  meta: ReadonlyMap<string, QuestionMeta>,
  result: SimulatorResult,
  settings: SimulatorSettings
): SubmittedAttemptResponse {
  const grading = gradeFrozenAttempt(attempt.questions, answers, keys, 0);
  if (grading.correctAnswers !== result.correct) {
    throw failedPrecondition("The stored exam result is invalid.");
  }
  return {
    attemptId: attempt.attemptId,
    status: "submitted",
    title: attempt.title,
    questionCount: attempt.questions.length,
    correctAnswers: result.correct,
    percentage: grading.percentage,
    requiredCorrectAnswers: attempt.requiredCorrectAnswers,
    passed: result.reachedCutoff ?? false,
    review: grading.review.map((item) => {
      const info = meta.get(item.questionId);
      return {
        ...item,
        explanation: settings.showExplanations ? item.explanation : [],
        courseId: info?.courseId ?? "",
        topicId: info?.topicId ?? "",
        subtopicId: info?.subtopicId ?? "",
        partIds: info?.partIds ?? []
      };
    }),
    simulator: result
  };
}

function parseScoring(value: unknown): SimulatorScoring | undefined {
  const raw = record(value);
  const questionCount = integer(raw?.questionCount);
  const maxScore = integer(raw?.maxScore);
  const correctPoints = finite(raw?.correctPoints);
  const incorrectPoints = finite(raw?.incorrectPoints);
  const blankPoints = finite(raw?.blankPoints);
  return questionCount === undefined || maxScore === undefined || correctPoints === undefined ||
    incorrectPoints === undefined || blankPoints === undefined
    ? undefined
    : { questionCount, maxScore, correctPoints, incorrectPoints, blankPoints };
}

function parseQuestionMeta(value: unknown): Map<string, QuestionMeta> {
  const result = new Map<string, QuestionMeta>();
  if (!Array.isArray(value)) return result;
  for (const entry of value) {
    const raw = record(entry);
    if (raw === undefined || typeof raw.questionId !== "string") continue;
    result.set(raw.questionId, {
      questionId: raw.questionId,
      courseId: typeof raw.courseId === "string" ? raw.courseId : "",
      topicId: typeof raw.topicId === "string" ? raw.topicId : "",
      subtopicId: typeof raw.subtopicId === "string" ? raw.subtopicId : "",
      partIds: stringList(raw.partIds)
    });
  }
  return result;
}

function parseStoredSimulatorResult(value: unknown): SimulatorResult | undefined {
  const raw = record(value);
  if (raw === undefined || !isSimulatorPurpose(raw.purpose)) return undefined;
  const numbers = ["total", "correct", "incorrect", "blank", "rawScore", "score", "maxScore", "percentage", "gradedAtMs"] as const;
  if (!numbers.every((field) => typeof raw[field] === "number")) return undefined;
  return raw as unknown as SimulatorResult;
}

function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : undefined;
}

function integer(value: unknown): number | undefined {
  return typeof value === "number" && Number.isInteger(value) ? value : undefined;
}

function finite(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function stringList(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === "string") : [];
}

function firstId(...values: unknown[]): string | undefined {
  for (const value of values) {
    if (typeof value === "string" && value.trim().length > 0) return value.trim();
  }
  return undefined;
}

function isActive(data: Record<string, unknown> | undefined): boolean {
  const value = data?.active;
  return value !== false && value !== "N" && value !== "false" && value !== 0;
}

/** Practice scoring: over 100, penalty only with `practicePenalty`. */
function practiceScoring(questionCount: number, settings: SimulatorSettings): SimulatorScoring {
  return {
    questionCount,
    maxScore: 100,
    correctPoints: 1,
    incorrectPoints: settings.practicePenalty ? practicePenaltyPoints : 0,
    blankPoints: 0
  };
}
