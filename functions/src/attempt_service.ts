import type { Firestore, Timestamp } from "firebase-admin/firestore";
import { FieldValue } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import {
  type CandidateQuestion,
  type ExamTemplateRecord,
  type PartContext,
  parseCandidateQuestion,
  parseTemplate
} from "./exam_contracts";
import { failedPrecondition, notFound } from "./errors";
import {
  bindPartCompletionBlocks,
  chooseQuestions,
  randomStarts,
  requireEnough,
  shuffle,
  type SelectedQuestion
} from "./selection";
import type { CreateExamAttemptInput } from "./validation";

const candidateStartsPerBlock = 4;
const maxCandidatesPerStart = 80;
const recentQuestionLimit = 200;
const defaultAttemptDurationSeconds = 60 * 60;

export interface CreateExamAttemptResponse {
  attemptId: string;
  status: "in_progress";
  title: string;
  questionCount: number;
  requiredCorrectAnswers: number;
  expiresAt: string;
  questions: AttemptQuestionSnapshot[];
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

export class ExamAttemptService {
  public constructor(
    private readonly db: Firestore,
    private readonly config: BackendConfig
  ) {}

  public async create(
    uid: string,
    input: CreateExamAttemptInput
  ): Promise<CreateExamAttemptResponse> {
    const requestRef = this.db
      .collection(this.config.collections.users)
      .doc(uid)
      .collection("examRequestKeys")
      .doc(input.requestId);
    const previous = await requestRef.get();
    if (previous.exists) return this.responseForExisting(uid, previous.data());

    const [profile, context, template, recentExposure] = await Promise.all([
      this.profileUniversity(uid),
      this.partContext(uid, input.partId),
      this.template(input.templateId),
      this.recentExposure(uid)
    ]);
    if (template.purpose !== input.purpose || template.mode !== "dynamic") {
      throw failedPrecondition("The template cannot create this type of attempt.");
    }
    const blocks = bindPartCompletionBlocks(template.blocks, context);
    const selected = await this.select(template, blocks, profile, recentExposure, uid, input.requestId);
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
      const existing = await transaction.get(requestRef);
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
    if (!created) return this.responseForRequest(uid, input.requestId);
    return response;
  }

  private async responseForExisting(
    uid: string,
    request: Record<string, unknown> | undefined
  ): Promise<CreateExamAttemptResponse> {
    const attemptId = typeof request?.attemptId === "string" ? request.attemptId : "";
    if (attemptId.length === 0) throw failedPrecondition("The idempotency record is invalid.");
    return this.responseForAttempt(uid, attemptId);
  }

  private async responseForRequest(
    uid: string,
    requestId: string
  ): Promise<CreateExamAttemptResponse> {
    const request = await this.db
      .collection(this.config.collections.users)
      .doc(uid)
      .collection("examRequestKeys")
      .doc(requestId)
      .get();
    return this.responseForExisting(uid, request.data());
  }

  private async responseForAttempt(
    uid: string,
    attemptId: string
  ): Promise<CreateExamAttemptResponse> {
    const attempt = await this.db.collection(this.config.collections.attempts).doc(attemptId).get();
    const data = attempt.data();
    if (!attempt.exists || data?.userId !== uid) throw notFound("Exam attempt not found.");
    if (data.status !== "in_progress" || !Array.isArray(data.questionSnapshots)) {
      throw failedPrecondition("The stored exam attempt is invalid.");
    }
    const expiresAt = timestampToIso(data.expiresAt);
    const questions = data.questionSnapshots as AttemptQuestionSnapshot[];
    const requiredCorrectAnswers = numberField(data.requiredCorrectAnswers);
    const title = stringField(data.templateSnapshot, "title");
    if (expiresAt === undefined || requiredCorrectAnswers === undefined || title === undefined) {
      throw failedPrecondition("The stored exam attempt is invalid.");
    }
    return {
      attemptId,
      status: "in_progress",
      title,
      questionCount: questions.length,
      requiredCorrectAnswers,
      expiresAt,
      questions
    };
  }

  private async profileUniversity(uid: string): Promise<string> {
    const profile = await this.db.collection(this.config.collections.users).doc(uid).get();
    const universityId = profile.data()?.universityId;
    if (!profile.exists || typeof universityId !== "string" || universityId.trim().length === 0) {
      throw failedPrecondition("The profile needs a selected university.");
    }
    return universityId;
  }

  private async partContext(uid: string, partId: string): Promise<PartContext> {
    const progress = await this.db
      .collection(this.config.collections.users)
      .doc(uid)
      .collection("learningProgress")
      .doc("current")
      .get();
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
    await this.validateCatalogPart(context);
    return context;
  }

  private async validateCatalogPart(context: PartContext): Promise<void> {
    const course = this.db.collection(this.config.collections.courses).doc(context.courseId);
    const topic = course.collection("topics").doc(context.topicId);
    const subtopic = topic.collection("subtopics").doc(context.subtopicId);
    const [courseDoc, topicDoc, subtopicDoc] = await Promise.all([course.get(), topic.get(), subtopic.get()]);
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

  private async template(templateId: string): Promise<ExamTemplateRecord> {
    const snapshot = await this.db.collection(this.config.collections.templates).doc(templateId).get();
    if (!snapshot.exists) throw notFound("Exam template not found.");
    return parseTemplate(snapshot.data()!, templateId);
  }

  private async recentExposure(uid: string): Promise<Map<string, number>> {
    const snapshots = await this.db
      .collection(this.config.collections.users)
      .doc(uid)
      .collection("recentQuestions")
      .limit(recentQuestionLimit)
      .get();
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
    requestId: string
  ): Promise<SelectedQuestion[]> {
    const selected: SelectedQuestion[] = [];
    const selectedIds = new Set<string>();
    for (const [index, block] of blocks.entries()) {
      const candidates = await this.candidates(block.filter, `${uid}:${requestId}:${index}`, block.count);
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
    required: number
  ): Promise<CandidateQuestion[]> {
    const limit = Math.min(maxCandidatesPerStart, Math.max(20, required * 8));
    const found = new Map<string, CandidateQuestion>();
    for (const start of randomStarts(seed, candidateStartsPerBlock)) {
      const snapshot = await this.db
        .collection(this.config.collections.questions)
        .where("status", "==", "published")
        .where("partIds", "array-contains", filter.partId)
        .where("randomKey", ">=", start)
        .orderBy("randomKey")
        .limit(limit)
        .get();
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

function parsePartContext(raw: Record<string, unknown>): PartContext | undefined {
  const partId = typeof raw.partId === "string" ? raw.partId : undefined;
  const courseId = typeof raw.courseId === "string" ? raw.courseId : undefined;
  const topicId = typeof raw.topicId === "string" ? raw.topicId : undefined;
  const subtopicId = typeof raw.subtopicId === "string" ? raw.subtopicId : undefined;
  return partId !== undefined && courseId !== undefined && topicId !== undefined && subtopicId !== undefined
    ? { partId, courseId, topicId, subtopicId }
    : undefined;
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

function numberField(data: unknown): number | undefined {
  return typeof data === "number" ? data : undefined;
}

function stringField(data: unknown, field: string): string | undefined {
  if (data === null || typeof data !== "object") return undefined;
  const value = (data as Record<string, unknown>)[field];
  return typeof value === "string" ? value : undefined;
}
