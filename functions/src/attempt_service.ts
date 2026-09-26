import type {
  DocumentReference,
  Firestore,
  Timestamp,
  Transaction
} from "firebase-admin/firestore";
import { FieldValue } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import {
  type CandidateQuestion,
  type ExamTemplateRecord,
  type PartContext,
  parseCandidateQuestion,
  parseTemplate
} from "./exam_contracts";
import { failedPrecondition, invalidArgument, notFound, resourceExhausted } from "./errors";
import {
  assessExamApproval,
  assessSectionCompletion,
  readPartProgress,
  type PartProgressAssessment,
  type PartProgressStatus,
  type PartSection,
  type ProgressPartContext
} from "./part_progress";
import {
  bindPartCompletionBlocks,
  chooseQuestions,
  randomStarts,
  requireEnough,
  shuffle,
  type SelectedQuestion
} from "./selection";
import { OperationMetrics } from "./operation_metrics";
import type {
  CreateExamAttemptInput,
  RecordPartSectionCompletionInput,
  SaveExamAnswersInput,
  SubmitExamAttemptInput
} from "./validation";

const defaultAttemptDurationSeconds = 60 * 60;
/** One changed incremental answer payload per second per attempt. */
export const answerSaveIntervalMs = 1_000;

export interface CreateExamAttemptResponse {
  attemptId: string;
  status: AttemptStatus;
  title: string;
  questionCount: number;
  requiredCorrectAnswers: number;
  expiresAt: string;
  questions: AttemptQuestionSnapshot[];
}

export type AttemptStatus = "in_progress" | "submitted" | "expired";

/** Public recovery response. It intentionally has no score, key or explanation. */
export interface ExamAttemptResponse extends CreateExamAttemptResponse {
  answers: Record<string, string>;
}

export interface AttemptQuestionSnapshot {
  questionId: string;
  version: number;
  order: number;
  content: unknown[];
  alternatives: { id: string; label: string; content: unknown[] }[];
  sourceLabel: string;
  alternativeOrder: string[];
}

interface StoredExamResult {
  total: number;
  correct: number;
  passPercentExclusive: number;
  gradedAtMs: number;
}

export interface FrozenAnswerKey {
  questionId: string;
  version: number;
  correctAlternativeId: string;
  explanation: unknown[];
}

export interface SubmittedAttemptResponse {
  attemptId: string;
  status: "submitted";
  title: string;
  questionCount: number;
  correctAnswers: number;
  percentage: number;
  requiredCorrectAnswers: number;
  passed: boolean;
  review: AttemptReview[];
  partCompletion?: PartCompletionResponse;
}

export interface AttemptReview {
  questionId: string;
  version: number;
  order: number;
  selectedAlternativeId: string | null;
  correctAlternativeId: string;
  isCorrect: boolean;
  explanation: unknown[];
}

export interface PartCompletionResponse {
  partId: string;
  status: PartProgressStatus;
  missingSections: PartSection[];
  examAttemptId?: string;
}

export class ExamAttemptService {
  public constructor(
    private readonly db: Firestore,
    private readonly config: BackendConfig
  ) {}

  public async create(
    uid: string,
    input: CreateExamAttemptInput,
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<CreateExamAttemptResponse> {
    const requestRef = this.db
      .collection(this.config.collections.users)
      .doc(uid)
      .collection("examRequestKeys")
      .doc(input.requestId);
    const previous = await requestRef.get();
    metrics.readDocument();
    if (previous.exists) return this.responseForExisting(uid, previous.data(), metrics);

    const [profile, context, template, recentExposure] = await Promise.all([
      this.profileUniversity(uid, metrics),
      this.partContext(uid, input.partId, metrics),
      this.template(input.templateId, metrics),
      this.recentExposure(uid, metrics)
    ]);
    if (template.purpose !== input.purpose || template.mode !== "dynamic") {
      throw failedPrecondition("The template cannot create this type of attempt.");
    }
    const blocks = bindPartCompletionBlocks(template.blocks, context);
    const selected = await this.select(
      template,
      blocks,
      profile,
      recentExposure,
      uid,
      input.requestId,
      metrics
    );
    const ordered = shuffle(selected, `${uid}:${input.requestId}:questions`);
    const attemptRef = this.db.collection(this.config.collections.attempts).doc();
    const now = Date.now();
    const durationSeconds = template.durationSeconds ?? defaultAttemptDurationSeconds;
    const expiresAtMs = now + durationSeconds * 1000;
    const response = this.responseFromSelection(
      attemptRef.id,
      template,
      ordered,
      expiresAtMs
    );

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
        templateId: template.id,
        templateVersion: template.version,
        templateSnapshot: {
          title: template.title,
          purpose: template.purpose,
          selectionPolicy: template.selectionPolicy,
          passPercentExclusive: template.passPercentExclusive,
          durationSeconds
        },
        partId: context.partId,
        status: "in_progress",
        createdAt: FieldValue.serverTimestamp(),
        createdAtMs: now,
        expiresAt: new Date(expiresAtMs),
        questions: response.questions.map((question) => ({
          questionId: question.questionId,
          version: question.version,
          alternativeOrder: question.alternativeOrder
        })),
        questionSnapshots: response.questions,
        answers: {},
        requiredCorrectAnswers: response.requiredCorrectAnswers
      });
      transaction.set(requestRef, {
        attemptId: attemptRef.id,
        createdAt: FieldValue.serverTimestamp()
      });
      for (const question of response.questions) {
        transaction.set(
          this.db
            .collection(this.config.collections.users)
            .doc(uid)
            .collection("recentQuestions")
            .doc(question.questionId),
          {
            exposureCount: FieldValue.increment(1),
            lastSeenAt: FieldValue.serverTimestamp()
          },
          { merge: true }
        );
      }
      return true;
    });
    if (!created) return this.responseForRequest(uid, input.requestId, metrics);
    // Attempt, idempotency key and one recent-question record per selected item.
    metrics.writeDocument(2 + response.questions.length);
    return response;
  }

  /** Returns the immutable server snapshot only to its owner. */
  public async get(
    uid: string,
    attemptId: string,
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<ExamAttemptResponse> {
    const attempt = await this.db.collection(this.config.collections.attempts).doc(attemptId).get();
    metrics.readDocument();
    return this.readAttempt(uid, attemptId, attempt.exists ? attempt.data() : undefined);
  }

  /**
   * Persists a bounded patch of answer IDs. The transaction makes concurrent
   * retries safe and never writes after an attempt has been submitted/expired.
   */
  public async saveAnswers(
    uid: string,
    input: SaveExamAnswersInput,
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<ExamAttemptResponse> {
    const attemptRef = this.db.collection(this.config.collections.attempts).doc(input.attemptId);
    return this.db.runTransaction(async (transaction) => {
      metrics.transactionAttempt();
      const attempt = await transaction.get(attemptRef);
      metrics.readDocument();
      const current = this.readAttempt(uid, input.attemptId, attempt.exists ? attempt.data() : undefined);
      if (current.status !== "in_progress") {
        throw failedPrecondition("The exam attempt is not open.", {
          reason: "attempt_not_open",
          status: current.status
        });
      }
      validateAnswerPatch(current.questions, input.answers);
      const answers = { ...current.answers, ...input.answers };
      const hasChanges = Object.entries(input.answers).some(
        ([questionId, alternativeId]) => current.answers[questionId] !== alternativeId
      );
      if (!hasChanges) return current;

      const lastSaveAtMs = timestampToMs(attempt.data()?.lastAnswerSaveAt);
      const now = Date.now();
      if (lastSaveAtMs !== undefined && now - lastSaveAtMs < answerSaveIntervalMs) {
        throw resourceExhausted("Please wait before saving answers again.", {
          reason: "answer_save_rate_limit",
          retryAfterMs: answerSaveIntervalMs - (now - lastSaveAtMs)
        });
      }
      transaction.update(attemptRef, {
        answers,
        updatedAt: FieldValue.serverTimestamp(),
        lastAnswerSaveAt: FieldValue.serverTimestamp(),
        answerRevision: FieldValue.increment(1)
      });
      metrics.writeDocument();
      return { ...current, answers };
    });
  }

  /**
   * Finalizes exactly once. The answer key is looked up by the question
   * revision frozen in the attempt, never by the mutable public question.
   */
  public async submit(
    uid: string,
    input: SubmitExamAttemptInput,
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<SubmittedAttemptResponse> {
    const attemptRef = this.db.collection(this.config.collections.attempts).doc(input.attemptId);
    return this.db.runTransaction(async (transaction) => {
      metrics.transactionAttempt();
      const attempt = await transaction.get(attemptRef);
      metrics.readDocument();
      const current = this.readAttempt(uid, input.attemptId, attempt.exists ? attempt.data() : undefined);
      validateAnswerPatch(current.questions, input.answers);
      const answerKeys = await this.answerKeys(transaction, current.questions, metrics);

      if (current.status === "submitted") {
        const result = parseStoredResult(attempt.data()?.result, input.attemptId, current.questions.length);
        const purpose = stringField(attempt.data()?.templateSnapshot, "purpose");
        const partCompletion = purpose === "part_completion" && hasPassed(result)
          ? await this.recordExamApproval(transaction, uid, attempt.data(), input.attemptId, metrics)
          : undefined;
        return submittedResponse(current, result, answerKeys, partCompletion);
      }
      if (current.status !== "in_progress") {
        throw failedPrecondition("The exam attempt is not open.", {
          reason: "attempt_not_open",
          status: current.status
        });
      }

      const answers = { ...current.answers, ...input.answers };
      const passPercentExclusive = numberProperty(
        attempt.data()?.templateSnapshot,
        "passPercentExclusive"
      );
      if (passPercentExclusive === undefined) {
        throw failedPrecondition("The stored exam attempt is invalid.");
      }
      const grading = gradeFrozenAttempt(
        current.questions,
        answers,
        answerKeys,
        passPercentExclusive
      );
      const expectedRequired = Math.floor(
        (current.questions.length * passPercentExclusive) / 100
      ) + 1;
      if (current.requiredCorrectAnswers !== expectedRequired) {
        throw failedPrecondition("The stored exam attempt is invalid.");
      }
      const result: StoredExamResult = {
        total: current.questions.length,
        correct: grading.correctAnswers,
        passPercentExclusive,
        gradedAtMs: Date.now()
      };
      const purpose = stringField(attempt.data()?.templateSnapshot, "purpose");
      const partCompletion = grading.passed && purpose === "part_completion"
        ? await this.recordExamApproval(transaction, uid, attempt.data(), input.attemptId, metrics)
        : undefined;
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
          passPercentExclusive: result.passPercentExclusive,
          gradedAtMs: result.gradedAtMs
        }
      });
      metrics.writeDocument();
      return submittedResponse(
        { ...current, status: "submitted", answers },
        result,
        answerKeys,
        partCompletion
      );
    });
  }

  /** Records one server-timestamped section event and reconciles a provisional pass. */
  public async recordPartSectionCompletion(
    uid: string,
    input: RecordPartSectionCompletionInput,
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<PartCompletionResponse> {
    const progressRef = this.progressRef(uid);
    return this.db.runTransaction(async (transaction) => {
      metrics.transactionAttempt();
      const progress = await transaction.get(progressRef);
      metrics.readDocument();
      if (!progress.exists) throw failedPrecondition("Learning progress is unavailable.");
      const context = allowedPartContext(progress.data(), input.partId);
      if (context === undefined) {
        throw failedPrecondition("The requested part is not enabled by learning progress.");
      }
      return this.applyPartProgress(
        transaction,
        progressRef,
        progress.data(),
        context,
        assessSectionCompletion(readPartProgress(partRecord(progress.data(), input.partId), context), input.section),
        input.section,
        metrics
      );
    });
  }

  private async responseForExisting(
    uid: string,
    request: Record<string, unknown> | undefined,
    metrics: OperationMetrics
  ): Promise<CreateExamAttemptResponse> {
    const attemptId = typeof request?.attemptId === "string" ? request.attemptId : "";
    if (attemptId.length === 0) throw failedPrecondition("The idempotency record is invalid.");
    return this.responseForAttempt(uid, attemptId, metrics);
  }

  private async responseForRequest(
    uid: string,
    requestId: string,
    metrics: OperationMetrics
  ): Promise<CreateExamAttemptResponse> {
    const request = await this.db
      .collection(this.config.collections.users)
      .doc(uid)
      .collection("examRequestKeys")
      .doc(requestId)
      .get();
    metrics.readDocument();
    return this.responseForExisting(uid, request.data(), metrics);
  }

  private async responseForAttempt(
    uid: string,
    attemptId: string,
    metrics: OperationMetrics
  ): Promise<CreateExamAttemptResponse> {
    const attempt = await this.db.collection(this.config.collections.attempts).doc(attemptId).get();
    metrics.readDocument();
    const response = this.readAttempt(uid, attemptId, attempt.exists ? attempt.data() : undefined);
    return {
      attemptId: response.attemptId,
      status: response.status,
      title: response.title,
      questionCount: response.questionCount,
      requiredCorrectAnswers: response.requiredCorrectAnswers,
      expiresAt: response.expiresAt,
      questions: response.questions
    };
  }

  private readAttempt(
    uid: string,
    attemptId: string,
    data: Record<string, unknown> | undefined
  ): ExamAttemptResponse {
    if (data?.userId !== uid) throw notFound("Exam attempt not found.");
    return projectAttemptResponse(attemptId, data);
  }

  private async answerKeys(
    transaction: Transaction,
    questions: readonly AttemptQuestionSnapshot[],
    metrics: OperationMetrics
  ): Promise<FrozenAnswerKey[]> {
    // One batched Firestore call avoids an N+1 network pattern. It still reads
    // one answer-key document per frozen question, which the telemetry reports.
    const snapshots = await transaction.getAll(
      ...questions.map((question) =>
        this.db
          .collection(this.config.collections.answerKeys)
          .doc(`${question.questionId}_${question.version}`)
      )
    );
    metrics.readDocument(snapshots.length);
    return snapshots.map((snapshot, index) => {
      const question = questions[index];
      if (question === undefined || !snapshot.exists) {
        throw failedPrecondition("A frozen answer key is unavailable.");
      }
      return parseFrozenAnswerKey(snapshot.data(), question);
    });
  }

  private async recordExamApproval(
    transaction: Transaction,
    uid: string,
    attempt: Record<string, unknown> | undefined,
    attemptId: string,
    metrics: OperationMetrics
  ): Promise<PartCompletionResponse> {
    const partId = stringValue(attempt?.partId);
    if (partId === undefined) throw failedPrecondition("The stored exam attempt is invalid.");
    const progressRef = this.progressRef(uid);
    const progress = await transaction.get(progressRef);
    metrics.readDocument();
    if (!progress.exists) throw failedPrecondition("Learning progress is unavailable.");
    const context = allowedPartContext(progress.data(), partId);
    if (context === undefined) {
      throw failedPrecondition("The attempted part is no longer enabled by learning progress.");
    }
    const state = readPartProgress(partRecord(progress.data(), partId), context);
    return this.applyPartProgress(
      transaction,
      progressRef,
      progress.data(),
      context,
      assessExamApproval(state, attemptId),
      undefined,
      metrics
    );
  }

  private applyPartProgress(
    transaction: Transaction,
    progressRef: DocumentReference,
    progress: Record<string, unknown> | undefined,
    context: ProgressPartContext,
    assessment: PartProgressAssessment,
    newSection?: PartSection,
    metrics?: OperationMetrics
  ): PartCompletionResponse {
    const existing = readPartProgress(partRecord(progress, context.partId), context);
    const sectionIsNew = newSection !== undefined && !existing.completedSections.has(newSection);
    if (existing.completed || (!assessment.shouldRecordApproval && !assessment.shouldMarkCompleted && !sectionIsNew)) {
      return progressResponse(context.partId, assessment);
    }
    const progressMap = objectMap(progress?.partProgress);
    const parts = { ...progressMap };
    const rawPart = objectMap(parts[context.partId]);
    const sections = { ...objectMap(rawPart.sections) };
    if (sectionIsNew && newSection !== undefined) {
      sections[newSection] = { completedAt: FieldValue.serverTimestamp() };
    }
    const next: Record<string, unknown> = {
      ...rawPart,
      schemaVersion: 2,
      partId: context.partId,
      courseId: context.courseId,
      topicId: context.topicId,
      subtopicId: context.subtopicId,
      sections
    };
    if (assessment.shouldRecordApproval && assessment.effectiveExamAttemptId !== undefined) {
      next.approvedExamAttemptId = assessment.effectiveExamAttemptId;
      next.examApprovedAt = FieldValue.serverTimestamp();
    }
    if (assessment.shouldMarkCompleted && assessment.effectiveExamAttemptId !== undefined) {
      next.completed = true;
      next.verificationStatus = "verified";
      next.examAttemptId = assessment.effectiveExamAttemptId;
      next.completedAt = FieldValue.serverTimestamp();
    } else if (assessment.effectiveExamAttemptId !== undefined) {
      next.verificationStatus = "provisional";
    } else {
      next.verificationStatus = "not_approved";
    }
    parts[context.partId] = next;
    transaction.set(
      progressRef,
      { partProgressSchemaVersion: 2, partProgress: parts, updatedAt: FieldValue.serverTimestamp() },
      { merge: true }
    );
    metrics?.writeDocument();
    return progressResponse(context.partId, assessment);
  }

  private progressRef(uid: string) {
    return this.db
      .collection(this.config.collections.users)
      .doc(uid)
      .collection("learningProgress")
      .doc("current");
  }

  private async profileUniversity(uid: string, metrics: OperationMetrics): Promise<string> {
    const profile = await this.db.collection(this.config.collections.users).doc(uid).get();
    metrics.readDocument();
    const universityId = profile.data()?.universityId;
    if (!profile.exists || typeof universityId !== "string" || universityId.trim().length === 0) {
      throw failedPrecondition("The profile needs a selected university.");
    }
    return universityId;
  }

  private async partContext(
    uid: string,
    partId: string,
    metrics: OperationMetrics
  ): Promise<PartContext> {
    const progress = await this.db
      .collection(this.config.collections.users)
      .doc(uid)
      .collection("learningProgress")
      .doc("current")
      .get();
    metrics.readDocument();
    const allowed: unknown[] = Array.isArray(progress.data()?.allowedParts)
      ? (progress.data()!.allowedParts as unknown[])
      : [];
    const raw = allowed.find(
      (entry: unknown) => entry !== null && typeof entry === "object" && (entry as { partId?: unknown }).partId === partId
    ) as Record<string, unknown> | undefined;
    const context = raw === undefined ? undefined : parsePartContext(raw);
    if (context === undefined) {
      throw failedPrecondition("The requested part is not enabled by learning progress.");
    }
    await this.validateCatalogPart(context, metrics);
    return context;
  }

  private async validateCatalogPart(
    context: PartContext,
    metrics: OperationMetrics
  ): Promise<void> {
    const course = this.db.collection(this.config.collections.courses).doc(context.courseId);
    const topic = course.collection("topics").doc(context.topicId);
    const subtopic = topic.collection("subtopics").doc(context.subtopicId);
    const [courseDoc, topicDoc, subtopicDoc] = await Promise.all([course.get(), topic.get(), subtopic.get()]);
    metrics.readDocument(3);
    const parts: unknown[] = Array.isArray(subtopicDoc.data()?.listPart)
      ? (subtopicDoc.data()!.listPart as unknown[])
      : [];
    const part = parts.length > 0
      ? parts.find(
          (entry: unknown) => entry !== null && typeof entry === "object" && (entry as { id?: unknown }).id === context.partId
        ) as Record<string, unknown> | undefined
      : undefined;
    if (
      !courseDoc.exists ||
      !isActive(courseDoc.data()) ||
      !topicDoc.exists ||
      !isActive(topicDoc.data()) ||
      !subtopicDoc.exists ||
      !isActive(subtopicDoc.data()) ||
      part === undefined ||
      !isActive(part)
    ) {
      throw failedPrecondition("The requested academic part is unavailable.");
    }
  }

  private async template(templateId: string, metrics: OperationMetrics): Promise<ExamTemplateRecord> {
    const snapshot = await this.db.collection(this.config.collections.templates).doc(templateId).get();
    metrics.readDocument();
    if (!snapshot.exists) throw notFound("Exam template not found.");
    return parseTemplate(snapshot.data()!, templateId);
  }

  private async recentExposure(uid: string, metrics: OperationMetrics): Promise<Map<string, number>> {
    const snapshots = await this.db
      .collection(this.config.collections.users)
      .doc(uid)
      .collection("recentQuestions")
      .limit(this.config.selection.recentQuestionLimit)
      .get();
    metrics.readQuery(snapshots.size);
    return new Map(
      snapshots.docs.map((document) => [
        document.id,
        typeof document.data().exposureCount === "number" ? document.data().exposureCount : 0
      ])
    );
  }

  private async select(
    template: ExamTemplateRecord,
    blocks: ReturnType<typeof bindPartCompletionBlocks>,
    profileUniversityId: string,
    recentExposure: ReadonlyMap<string, number>,
    uid: string,
    requestId: string,
    metrics: OperationMetrics
  ): Promise<SelectedQuestion[]> {
    const selected: SelectedQuestion[] = [];
    const selectedIds = new Set<string>();
    for (const [index, block] of blocks.entries()) {
      const candidates = await this.candidates(
        block.filter,
        `${uid}:${requestId}:${index}`,
        block.count,
        metrics
      );
      const picked = chooseQuestions({
        candidates,
        selectedIds,
        filter: block.filter,
        count: block.count,
        selectionPolicy: template.selectionPolicy,
        profileUniversityId,
        allowedFallbackSources: template.allowedFallbackSources,
        recentExposure,
        seed: `${uid}:${requestId}:${index}`
      });
      requireEnough(picked, picked.length, block.count, index);
      for (const item of picked) selectedIds.add(item.question.questionId);
      selected.push(...picked);
    }
    return selected;
  }

  private async candidates(
    filter: ReturnType<typeof bindPartCompletionBlocks>[number]["filter"],
    seed: string,
    required: number,
    metrics: OperationMetrics
  ): Promise<CandidateQuestion[]> {
    const limit = Math.min(
      this.config.selection.maxCandidatesPerStart,
      Math.max(20, required * 8)
    );
    const found = new Map<string, CandidateQuestion>();
    for (const start of randomStarts(seed, this.config.selection.candidateStartsPerBlock)) {
      let query = this.db
        .collection(this.config.collections.questions)
        .where("status", "==", "published")
        .where("courseId", "==", filter.courseId)
        .where("topicId", "==", filter.topicId)
        .where("subtopicId", "==", filter.subtopicId)
        .where("partIds", "array-contains", filter.partId)
        .where("randomKey", ">=", start)
        .orderBy("randomKey");
      // Source type is a compact, indexed equality filter. Other optional
      // source metadata remains a bounded in-memory predicate to avoid a
      // combinatorial index matrix.
      if (filter.sourceType !== "any") {
        query = query.where("sourceType", "==", filter.sourceType);
      }
      const snapshot = await query.limit(limit).get();
      metrics.readQuery(snapshot.size);
      for (const document of snapshot.docs) {
        const parsed = parseCandidateQuestion(document.id, document.data());
        if (parsed !== undefined) found.set(parsed.questionId, parsed);
      }
    }
    return [...found.values()];
  }

  private responseFromSelection(
    attemptId: string,
    template: ExamTemplateRecord,
    selected: readonly SelectedQuestion[],
    expiresAtMs: number
  ): CreateExamAttemptResponse {
    const questions = selected.map(({ question, alternativeOrder }, order) => ({
      questionId: question.questionId,
      version: question.version,
      order,
      content: question.content,
      alternatives: question.alternatives.map(({ id, label, content }) => ({ id, label, content })),
      sourceLabel: question.sourceLabel,
      alternativeOrder
    }));
    return {
      attemptId,
      status: "in_progress",
      title: template.title,
      questionCount: questions.length,
      requiredCorrectAnswers: Math.floor((questions.length * template.passPercentExclusive) / 100) + 1,
      expiresAt: new Date(expiresAtMs).toISOString(),
      questions
    };
  }
}

/** Pure projection used by recovery. Do not add private attempt fields here. */
export function projectAttemptResponse(
  attemptId: string,
  data: Record<string, unknown>
): ExamAttemptResponse {
  const expiresAtMs = timestampToMs(data.expiresAt);
  const expiresAt = timestampToIso(data.expiresAt);
  const questions = sanitizeQuestionSnapshots(data.questionSnapshots);
  const requiredCorrectAnswers = numberField(data.requiredCorrectAnswers);
  const title = stringField(data.templateSnapshot, "title");
  if (
    expiresAtMs === undefined ||
    expiresAt === undefined ||
    questions === undefined ||
    requiredCorrectAnswers === undefined ||
    title === undefined
  ) {
    throw failedPrecondition("The stored exam attempt is invalid.");
  }
  const status = attemptStatus(data.status, expiresAtMs);
  return {
    attemptId,
    status,
    title,
    questionCount: questions.length,
    requiredCorrectAnswers,
    expiresAt,
    questions,
    answers: sanitizeAnswers(data.answers, questions)
  };
}

/**
 * Calculates from immutable question/answer-key revisions. Missing answers are
 * deliberately incorrect, matching the shared v2 contract.
 */
export function gradeFrozenAttempt(
  questions: readonly AttemptQuestionSnapshot[],
  answers: Readonly<Record<string, string>>,
  answerKeys: readonly FrozenAnswerKey[],
  passPercentExclusive: number
): { correctAnswers: number; percentage: number; passed: boolean; review: AttemptReview[] } {
  if (
    !Number.isInteger(passPercentExclusive) ||
    passPercentExclusive < 0 ||
    passPercentExclusive >= 100 ||
    questions.length === 0 ||
    answerKeys.length !== questions.length
  ) {
    throw failedPrecondition("The stored exam attempt is invalid.");
  }
  const keys = new Map(answerKeys.map((key) => [`${key.questionId}_${key.version}`, key]));
  if (keys.size !== questions.length) throw failedPrecondition("The frozen answer keys are invalid.");

  let correctAnswers = 0;
  const review = questions.map((question) => {
    const key = keys.get(`${question.questionId}_${question.version}`);
    if (key === undefined || !question.alternativeOrder.includes(key.correctAlternativeId)) {
      throw failedPrecondition("The frozen answer keys are invalid.");
    }
    const selectedAlternativeId = answers[question.questionId] ?? null;
    const isCorrect = selectedAlternativeId === key.correctAlternativeId;
    if (isCorrect) correctAnswers += 1;
    return {
      questionId: question.questionId,
      version: question.version,
      order: question.order,
      selectedAlternativeId,
      correctAlternativeId: key.correctAlternativeId,
      isCorrect,
      explanation: [...key.explanation]
    };
  });
  return {
    correctAnswers,
    percentage: (correctAnswers * 100) / questions.length,
    passed: correctAnswers * 100 > questions.length * passPercentExclusive,
    review
  };
}

function submittedResponse(
  attempt: ExamAttemptResponse,
  result: StoredExamResult,
  answerKeys: readonly FrozenAnswerKey[],
  partCompletion?: PartCompletionResponse
): SubmittedAttemptResponse {
  if (result.total !== attempt.questions.length) {
    throw failedPrecondition("The stored exam result is invalid.");
  }
  const expectedRequired = Math.floor(
    (attempt.questions.length * result.passPercentExclusive) / 100
  ) + 1;
  if (attempt.requiredCorrectAnswers !== expectedRequired) {
    throw failedPrecondition("The stored exam result is invalid.");
  }
  const grading = gradeFrozenAttempt(
    attempt.questions,
    attempt.answers,
    answerKeys,
    result.passPercentExclusive
  );
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
    passed: grading.passed,
    review: grading.review,
    ...(partCompletion === undefined ? {} : { partCompletion })
  };
}

function parseFrozenAnswerKey(
  data: Record<string, unknown> | undefined,
  question: AttemptQuestionSnapshot
): FrozenAnswerKey {
  const questionId = stringValue(data?.questionId);
  const version = numberField(data?.version);
  const correctAlternativeId = stringValue(data?.correctAlternativeId);
  const explanation = arrayValue(data?.explanation);
  if (
    data?.schemaVersion !== 2 ||
    questionId !== question.questionId ||
    version !== question.version ||
    correctAlternativeId === undefined ||
    explanation === undefined ||
    !question.alternativeOrder.includes(correctAlternativeId)
  ) {
    throw failedPrecondition("The frozen answer key is invalid.");
  }
  return { questionId, version, correctAlternativeId, explanation: [...explanation] };
}

function parseStoredResult(
  value: unknown,
  attemptId: string,
  expectedTotal: number
): StoredExamResult {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw failedPrecondition("The stored exam result is invalid.");
  }
  const data = value as Record<string, unknown>;
  const total = numberField(data.total);
  const correct = numberField(data.correct);
  const passPercentExclusive = numberField(data.passPercentExclusive);
  const gradedAtMs = numberField(data.gradedAtMs);
  if (
    data.schemaVersion !== 2 ||
    data.attemptId !== attemptId ||
    total !== expectedTotal ||
    correct === undefined ||
    !Number.isInteger(correct) ||
    correct < 0 ||
    correct > total ||
    passPercentExclusive === undefined ||
    !Number.isInteger(passPercentExclusive) ||
    passPercentExclusive < 0 ||
    passPercentExclusive >= 100 ||
    gradedAtMs === undefined ||
    !Number.isInteger(gradedAtMs) ||
    gradedAtMs < 1
  ) {
    throw failedPrecondition("The stored exam result is invalid.");
  }
  return { total, correct, passPercentExclusive, gradedAtMs };
}

function hasPassed(result: StoredExamResult): boolean {
  return result.correct * 100 > result.total * result.passPercentExclusive;
}

function parsePartContext(raw: Record<string, unknown>): PartContext | undefined {
  const partId = typeof raw.partId === "string" ? raw.partId : undefined;
  const courseId = typeof raw.courseId === "string" ? raw.courseId : undefined;
  const topicId = typeof raw.topicId === "string" ? raw.topicId : undefined;
  const subtopicId = typeof raw.subtopicId === "string" ? raw.subtopicId : undefined;
  return partId !== undefined && courseId !== undefined && topicId !== undefined && subtopicId !== undefined
    ? { partId, courseId, topicId, subtopicId }
    : undefined;
}

function allowedPartContext(
  progress: Record<string, unknown> | undefined,
  partId: string
): PartContext | undefined {
  const allowed: unknown[] = Array.isArray(progress?.allowedParts)
    ? (progress!.allowedParts as unknown[])
    : [];
  const raw = allowed.find(
    (entry: unknown) => entry !== null && typeof entry === "object" && (entry as { partId?: unknown }).partId === partId
  ) as Record<string, unknown> | undefined;
  return raw === undefined ? undefined : parsePartContext(raw);
}

function partRecord(
  progress: Record<string, unknown> | undefined,
  partId: string
): Record<string, unknown> | undefined {
  const parts = objectMap(progress?.partProgress);
  const candidate = parts[partId];
  return candidate !== null && typeof candidate === "object" && !Array.isArray(candidate)
    ? candidate as Record<string, unknown>
    : undefined;
}

function objectMap(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function progressResponse(
  partId: string,
  assessment: PartProgressAssessment
): PartCompletionResponse {
  return {
    partId,
    status: assessment.status,
    missingSections: [...assessment.missingSections],
    ...(assessment.effectiveExamAttemptId === undefined
      ? {}
      : { examAttemptId: assessment.effectiveExamAttemptId })
  };
}

function isActive(data: Record<string, unknown> | undefined): boolean {
  const value = data?.active;
  return value !== false && value !== "N" && value !== "false" && value !== 0;
}

function timestampToIso(value: unknown): string | undefined {
  if (value instanceof Date) return value.toISOString();
  if (value !== null && typeof value === "object" && "toDate" in value) {
    return (value as Timestamp).toDate().toISOString();
  }
  return undefined;
}

function timestampToMs(value: unknown): number | undefined {
  if (value instanceof Date) return value.getTime();
  if (value !== null && typeof value === "object" && "toDate" in value) {
    return (value as Timestamp).toDate().getTime();
  }
  return undefined;
}

function attemptStatus(value: unknown, expiresAtMs: number): AttemptStatus {
  if (value === "submitted" || value === "graded") return "submitted";
  if (value === "in_progress") {
    return expiresAtMs <= Date.now() ? "expired" : "in_progress";
  }
  if (value === "expired" || value === "abandoned") return "expired";
  throw failedPrecondition("The stored exam attempt is invalid.");
}

/**
 * Projects persisted snapshots into the client contract. This defensive copy
 * keeps a malformed legacy value from accidentally exposing a future private
 * field (for example a correct alternative ID) through recovery.
 */
function sanitizeQuestionSnapshots(value: unknown): AttemptQuestionSnapshot[] | undefined {
  if (!Array.isArray(value)) return undefined;
  const result: AttemptQuestionSnapshot[] = [];
  for (const raw of value) {
    if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return undefined;
    const item = raw as Record<string, unknown>;
    const questionId = stringValue(item.questionId);
    const version = numberField(item.version);
    const order = numberField(item.order);
    const content = arrayValue(item.content);
    const sourceLabel = stringValue(item.sourceLabel);
    const alternatives = sanitizeAlternatives(item.alternatives);
    if (
      questionId === undefined ||
      version === undefined ||
      order === undefined ||
      content === undefined ||
      sourceLabel === undefined ||
      alternatives === undefined
    ) {
      return undefined;
    }
    const availableIds = new Set(alternatives.map((alternative) => alternative.id));
    const alternativeOrder = sanitizeAlternativeOrder(item.alternativeOrder, availableIds);
    if (alternativeOrder === undefined) return undefined;
    result.push({
      questionId,
      version,
      order,
      content,
      alternatives,
      sourceLabel,
      alternativeOrder
    });
  }
  const uniqueIds = new Set(result.map((question) => question.questionId));
  const uniqueOrders = new Set(result.map((question) => question.order));
  if (uniqueIds.size !== result.length || uniqueOrders.size !== result.length) return undefined;
  return result.sort((left, right) => left.order - right.order);
}

function sanitizeAlternatives(
  value: unknown
): { id: string; label: string; content: unknown[] }[] | undefined {
  if (!Array.isArray(value) || value.length < 2) return undefined;
  const result: { id: string; label: string; content: unknown[] }[] = [];
  for (const raw of value) {
    if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return undefined;
    const item = raw as Record<string, unknown>;
    const id = stringValue(item.id);
    const label = stringValue(item.label);
    const content = arrayValue(item.content);
    if (id === undefined || label === undefined || content === undefined) return undefined;
    result.push({ id, label, content });
  }
  return new Set(result.map((alternative) => alternative.id)).size === result.length ? result : undefined;
}

function sanitizeAlternativeOrder(
  value: unknown,
  availableIds: ReadonlySet<string>
): string[] | undefined {
  if (!Array.isArray(value) || value.length !== availableIds.size) return undefined;
  const order = value.every((entry) => typeof entry === "string") ? [...value] as string[] : undefined;
  if (order === undefined || new Set(order).size !== order.length || !order.every((id) => availableIds.has(id))) {
    return undefined;
  }
  return order;
}

function sanitizeAnswers(
  value: unknown,
  questions: readonly AttemptQuestionSnapshot[]
): Record<string, string> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return {};
  const allowed = new Map(
    questions.map((question) => [question.questionId, new Set(question.alternativeOrder)])
  );
  const answers: Record<string, string> = {};
  for (const [questionId, alternativeId] of Object.entries(value)) {
    if (typeof alternativeId === "string" && allowed.get(questionId)?.has(alternativeId)) {
      answers[questionId] = alternativeId;
    }
  }
  return answers;
}

/** Validates against the frozen snapshot rather than the mutable question bank. */
export function validateAnswerPatch(
  questions: readonly AttemptQuestionSnapshot[],
  answers: Readonly<Record<string, string>>
): void {
  const alternativesByQuestion = new Map(
    questions.map((question) => [question.questionId, new Set(question.alternativeOrder)])
  );
  for (const [questionId, alternativeId] of Object.entries(answers)) {
    if (!alternativesByQuestion.get(questionId)?.has(alternativeId)) {
      throw invalidArgument("An answer does not belong to this exam attempt.");
    }
  }
}

function stringValue(value: unknown): string | undefined {
  return typeof value === "string" ? value : undefined;
}

function arrayValue(value: unknown): unknown[] | undefined {
  return Array.isArray(value) ? value : undefined;
}

function numberField(data: unknown): number | undefined {
  return typeof data === "number" ? data : undefined;
}

function numberProperty(data: unknown, field: string): number | undefined {
  if (data === null || typeof data !== "object") return undefined;
  return numberField((data as Record<string, unknown>)[field]);
}

function stringField(data: unknown, field: string): string | undefined {
  if (data === null || typeof data !== "object") return undefined;
  const value = (data as Record<string, unknown>)[field];
  return typeof value === "string" ? value : undefined;
}
