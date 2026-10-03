import assert from "node:assert/strict";
import test from "node:test";
import { FieldValue } from "firebase-admin/firestore";

import { db } from "../src/admin";
import {
  ExamAttemptService,
  type AttemptQuestionSnapshot
} from "../src/attempt_service";
import { readBackendConfig } from "../src/config";
import { ExamBackendError } from "../src/errors";

const config = readBackendConfig({ INGRESOYA_ENV: "test" });
const service = new ExamAttemptService(db, config);
const uid = "attempt-fixture-student";
const partId = "part-1";
const templateId = "attempt-fixture-template";

test("frozen attempts preserve ownership, order, grading and verified progress", async () => {
  await seed();
  const request = { requestId: "request-frozen", purpose: "part_completion" as const, partId, templateId };
  const [first, repeated] = await Promise.all([
    service.create(uid, request),
    service.create(uid, request)
  ]);

  assert.equal(first.attemptId, repeated.attemptId);
  assert.equal(first.questions.length, 10);
  assert.equal(new Set(first.questions.map((question) => question.questionId)).size, 10);
  assert.equal(JSON.stringify(first.questions).includes("correctAlternativeId"), false);
  assert.equal(JSON.stringify(first.questions).includes("explanation"), false);

  const recovered = await service.get(uid, first.attemptId);
  assert.deepEqual(
    recovered.questions.map((question) => question.questionId),
    first.questions.map((question) => question.questionId)
  );
  await assert.rejects(
    service.get("another-student", first.attemptId),
    hasReason("not-found", "attempt_not_found")
  );
  await assert.rejects(
    service.saveAnswers(uid, { attemptId: first.attemptId, answers: { missing: "a" } }),
    isCode("invalid-argument")
  );

  const eight = answers(first.questions, 8);
  const failed = await service.submit(uid, { attemptId: first.attemptId, answers: eight });
  assert.equal(failed.correctAnswers, 8);
  assert.equal(failed.requiredCorrectAnswers, 9);
  assert.equal(failed.passed, false);

  const passing = await service.create(uid, { ...request, requestId: "request-passing" });
  const passed = await service.submit(uid, {
    attemptId: passing.attemptId,
    answers: answers(passing.questions, 9)
  });
  assert.equal(passed.correctAnswers, 9);
  assert.equal(passed.passed, true);
  assert.equal(passed.partCompletion?.status, "provisional");
  assert.deepEqual(passed.progressUpdate, { partId, completed: false });
  const repeatedSubmit = await service.submit(uid, {
    attemptId: passing.attemptId,
    answers: answers(passing.questions, 9)
  });
  assert.deepEqual(repeatedSubmit, passed);

  for (const section of ["video", "lesson", "examples", "review", "resources"] as const) {
    await service.recordPartSectionCompletion(uid, { partId, section });
  }
  const progress = await db
    .collection(config.collections.users)
    .doc(uid)
    .collection("learningProgress")
    .doc("current")
    .get();
  const stored = progress.data()?.partProgress?.[partId] as Record<string, unknown>;
  assert.equal(stored.completed, true);
  assert.equal(stored.verificationStatus, "verified");
  assert.equal(stored.examAttemptId, passing.attemptId);
  const verified = await service.submit(uid, {
    attemptId: passing.attemptId,
    answers: answers(passing.questions, 9)
  });
  assert.deepEqual(verified.progressUpdate, { partId, completed: true });
});

test("create distinguishes a missing template from an orphaned request key", async () => {
  await seed();
  const request = {
    requestId: "request-error-diagnostics",
    purpose: "part_completion" as const,
    partId,
    templateId
  };
  await assert.rejects(
    service.create(uid, { ...request, templateId: "missing-template" }),
    hasReason("not-found", "template_not_found")
  );
  const created = await service.create(uid, request);
  await db.collection(config.collections.attempts).doc(created.attemptId).delete();
  await assert.rejects(
    service.create(uid, request),
    hasReason("failed-precondition", "request_key_orphaned")
  );
});

test("legacy app profiles derive a safe part context from published questions", async () => {
  await seed();
  const users = db.collection(config.collections.users);
  await users.doc(uid).set({ profile: { universityIdDoc: "university-1" } });
  await users.doc(uid).collection("learningProgress").doc("current").delete();

  const attempt = await service.create(uid, {
    requestId: "request-legacy-profile",
    purpose: "part_completion",
    partId,
    templateId
  });

  // Simulate an attempt created before partContext was frozen in the snapshot.
  await db.collection(config.collections.attempts).doc(attempt.attemptId).update({
    partContext: FieldValue.delete()
  });

  assert.equal(attempt.questions.length, 10);
  assert.equal(attempt.questions.every((question) => question.questionId.startsWith("attempt-fixture-question-")), true);
  const passed = await service.submit(uid, {
    attemptId: attempt.attemptId,
    answers: answers(attempt.questions, 9)
  });
  assert.equal(passed.passed, true);
  assert.deepEqual(passed.progressUpdate, { partId, completed: false });
  for (const section of ["video", "lesson", "examples", "review", "resources"] as const) {
    await service.recordPartSectionCompletion(uid, { partId, section });
  }
  const verified = await service.submit(uid, {
    attemptId: attempt.attemptId,
    answers: answers(attempt.questions, 9)
  });
  assert.deepEqual(verified.progressUpdate, { partId, completed: true });
  const stored = await users.doc(uid).collection("learningProgress").doc("current").get();
  assert.equal(stored.data()?.partProgress?.[partId]?.examAttemptId, attempt.attemptId);
});

async function seed(): Promise<void> {
  const batch = db.batch();
  const users = db.collection(config.collections.users);
  const courses = db.collection(config.collections.courses);
  const questions = db.collection(config.collections.questions);
  const answerKeys = db.collection(config.collections.answerKeys);
  const templates = db.collection(config.collections.templates);
  batch.set(users.doc(uid), { universityId: "university-1" });
  batch.set(users.doc(uid).collection("learningProgress").doc("current"), {
    allowedParts: [{ partId, courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1" }]
  });
  batch.set(courses.doc("course-1"), { active: true });
  batch.set(courses.doc("course-1").collection("topics").doc("topic-1"), { active: true });
  batch.set(
    courses.doc("course-1").collection("topics").doc("topic-1").collection("subtopics").doc("subtopic-1"),
    { active: true, listPart: [{ id: partId, active: true }] }
  );
  batch.set(templates.doc(templateId), {
    schemaVersion: 2,
    id: templateId,
    version: 1,
    title: "Fixture",
    status: "published",
    active: true,
    purpose: "part_completion",
    mode: "dynamic",
    selectionPolicy: "strict",
    allowedFallbackSources: [],
    questionCount: 10,
    passPercentExclusive: 80,
    blocks: [{ count: 10, filter: { partId } }]
  });
  for (let index = 1; index <= 80; index += 1) {
    const questionId = `attempt-fixture-question-${index}`;
    batch.set(questions.doc(questionId), {
      schemaVersion: 2,
      questionId,
      version: 1,
      status: "published",
      randomKey: index / 81,
      sourceLabel: "Fixture",
      universityId: "university-1",
      sourceType: "original",
      sourceExamId: "",
      modalityId: "",
      courseId: "course-1",
      topicId: "topic-1",
      subtopicId: "subtopic-1",
      partIds: [partId],
      difficulty: "medium",
      content: [],
      alternatives: [
        { id: "a", label: "A", content: [] },
        { id: "b", label: "B", content: [] }
      ]
    });
    batch.set(answerKeys.doc(`${questionId}_1`), {
      schemaVersion: 2,
      questionId,
      version: 1,
      correctAlternativeId: "a",
      explanation: []
    });
  }
  await batch.commit();
}

function answers(
  questions: readonly AttemptQuestionSnapshot[],
  correctCount: number
): Record<string, string> {
  return Object.fromEntries(
    questions.map((question, index) => [question.questionId, index < correctCount ? "a" : "b"])
  );
}

function isCode(code: ExamBackendError["code"]) {
  return (error: unknown): boolean => error instanceof ExamBackendError && error.code === code;
}

function hasReason(code: ExamBackendError["code"], reason: string) {
  return (error: unknown): boolean =>
    error instanceof ExamBackendError && error.code === code && error.details?.reason === reason;
}
