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
import { OperationMetrics } from "../src/operation_metrics";

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
  assert.equal((await db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current").collection("achievements").get()).size, 0);
  assert.equal((await service.getAchievementSummary(uid)).totalCompletedSubtopics, 0);

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
  const awardsRef = db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current").collection("achievements");
  const awarded = await awardsRef.get();
  assert.equal(awarded.size, 1);
  assert.equal(awarded.docs[0]?.data().type, "subtopic_completed");
  assert.deepEqual(awarded.docs[0]?.data().requiredPartIds, [partId]);
  const summaryRef = db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current")
    .collection("achievementSummary").doc("current");
  const summary = await service.getAchievementSummary(uid);
  assert.equal(summary.totalCompletedSubtopics, 1);
  assert.equal(summary.recent[0]?.subtopicId, "subtopic-1");
  assert.equal(summary.completedSubtopicKeys.length, 1);
  const summaryBeforeRetry = (await summaryRef.get()).data();
  const verified = await service.submit(uid, {
    attemptId: passing.attemptId,
    answers: answers(passing.questions, 9)
  });
  assert.deepEqual(verified.progressUpdate, { partId, completed: true });
  const repeatedAward = await awardsRef.get();
  assert.equal(repeatedAward.size, 1);
  assert.deepEqual(repeatedAward.docs[0]?.data(), awarded.docs[0]?.data());
  assert.deepEqual((await summaryRef.get()).data(), summaryBeforeRetry);
  const metrics = new OperationMetrics();
  assert.deepEqual(await service.getAchievementSummary(uid, metrics), summary);
  assert.equal(metrics.logFields().directDocumentReads, 1);
  assert.equal(metrics.logFields().queryCalls, 0);
});

test("an award snapshots all active parts and survives a later catalog expansion", async () => {
  await seed();
  const profile = db.collection(config.collections.users).doc(uid);
  const progressRef = profile.collection("learningProgress").doc("current");
  const awardsRef = progressRef.collection("achievements");
  const subtopicRef = db.collection(config.collections.courses).doc("course-1")
    .collection("topics").doc("topic-1").collection("subtopics").doc("subtopic-1");
  const batch = db.batch();
  batch.update(progressRef, {
    allowedParts: [partId, "part-2", "part-3"].map((id) => ({
      partId: id, courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1"
    }))
  });
  batch.update(subtopicRef, {
    listPart: [{ id: partId, active: true }, { id: "part-2", active: true }]
  });
  batch.update(db.collection(config.collections.templates).doc(templateId), {
    blocks: [{ count: 10, filter: {} }]
  });
  for (let index = 1; index <= 80; index += 1) {
    batch.update(
      db.collection(config.collections.questions).doc(`attempt-fixture-question-${index}`),
      { partIds: [partId, "part-2", "part-3"] }
    );
  }
  await batch.commit();

  for (const id of [partId, "part-2"]) {
    const attempt = await service.create(uid, {
      requestId: `request-achievement-${id}`,
      purpose: "part_completion",
      partId: id,
      templateId
    });
    await service.submit(uid, { attemptId: attempt.attemptId, answers: answers(attempt.questions, 9) });
    await service.recordPartSectionCompletion(uid, {
      partId: id,
      sections: ["video", "lesson", "examples", "review", "resources"]
    });
    assert.equal((await awardsRef.get()).size, id === partId ? 0 : 1);
  }
  const original = (await awardsRef.get()).docs[0];
  assert.ok(original);
  assert.deepEqual(original.data().requiredPartIds, [partId, "part-2"]);
  assert.equal((await service.getAchievementSummary(uid)).totalCompletedSubtopics, 1);

  await subtopicRef.update({
    listPart: [{ id: partId, active: true }, { id: "part-2", active: true }, { id: "part-3", active: true }]
  });
  const attempt = await service.create(uid, {
    requestId: "request-achievement-part-3",
    purpose: "part_completion",
    partId: "part-3",
    templateId
  });
  await service.submit(uid, { attemptId: attempt.attemptId, answers: answers(attempt.questions, 9) });
  await service.recordPartSectionCompletion(uid, {
    partId: "part-3",
    sections: ["video", "lesson", "examples", "review", "resources"]
  });
  const awards = await awardsRef.get();
  assert.equal(awards.size, 2);
  assert.deepEqual((await original.ref.get()).data(), original.data());
  assert.deepEqual(
    awards.docs.map((doc) => doc.data().requiredPartIds.length).sort(),
    [2, 3]
  );
  const summary = await service.getAchievementSummary(uid);
  assert.equal(summary.totalCompletedSubtopics, 1);
  assert.equal(summary.recent.length, 1);
  assert.equal(summary.recent[0]?.requirementVersion, awards.docs.find(
    (doc) => doc.data().requiredPartIds.length === 3
  )?.id);
});

test("older awards are projected once without reading exam attempts on Profile", async () => {
  await seed();
  const progressRef = db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current");
  await progressRef.collection("achievements").doc("parts-v1-legacy-fixture").set({
    schemaVersion: 1,
    type: "subtopic_completed",
    courseId: "course-1",
    topicId: "topic-1",
    subtopicId: "subtopic-1",
    requirementVersion: "parts-v1-legacy-fixture",
    awardedAt: FieldValue.serverTimestamp()
  });
  const firstMetrics = new OperationMetrics();
  const first = await service.getAchievementSummary(uid, firstMetrics);
  assert.equal(first.totalCompletedSubtopics, 1);
  assert.equal(firstMetrics.logFields().queryCalls, 1);
  const secondMetrics = new OperationMetrics();
  assert.deepEqual(await service.getAchievementSummary(uid, secondMetrics), first);
  assert.equal(secondMetrics.logFields().directDocumentReads, 1);
  assert.equal(secondMetrics.logFields().queryCalls, 0);
});

test("a new award incorporates earlier awards even before Profile reads the summary", async () => {
  await seed();
  const progressRef = db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current");
  await progressRef.collection("achievements").doc("parts-v1-earlier-subtopic").set({
    schemaVersion: 1,
    type: "subtopic_completed",
    courseId: "course-1",
    topicId: "topic-1",
    subtopicId: "earlier-subtopic",
    requirementVersion: "parts-v1-earlier-subtopic",
    awardedAt: FieldValue.serverTimestamp()
  });
  const attempt = await service.create(uid, {
    requestId: "request-after-older-award", purpose: "part_completion", partId, templateId
  });
  await service.submit(uid, {
    attemptId: attempt.attemptId, answers: answers(attempt.questions, 9)
  });
  await service.recordPartSectionCompletion(uid, {
    partId, sections: ["video", "lesson", "examples", "review", "resources"]
  });
  const summary = await service.getAchievementSummary(uid);
  assert.equal(summary.totalCompletedSubtopics, 2);
  assert.equal(summary.completedSubtopicKeys.length, 2);
});

test("one batch confirms five sections and a repeated batch does not rewrite progress", async () => {
  await seed();
  const attempt = await service.create(uid, {
    requestId: "request-batch-sections",
    purpose: "part_completion",
    partId,
    templateId
  });
  const passed = await service.submit(uid, {
    attemptId: attempt.attemptId,
    answers: answers(attempt.questions, 9)
  });
  assert.equal(passed.partCompletion?.status, "provisional");

  const sections = ["video", "lesson", "examples", "review", "resources"] as const;
  const confirmed = await service.recordPartSectionCompletion(uid, { partId, sections });
  assert.equal(confirmed.status, "verified");
  assert.deepEqual(confirmed.missingSections, []);
  const progressRef = db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current");
  const first = (await progressRef.get()).data()?.partProgress?.[partId];
  assert.equal(first.examAttemptId, attempt.attemptId);

  const repeated = await service.recordPartSectionCompletion(uid, { partId, sections });
  const second = (await progressRef.get()).data()?.partProgress?.[partId];
  assert.deepEqual(repeated, confirmed);
  assert.deepEqual(second, first);
});

test("passing after all sections are reviewed grants the award during submit", async () => {
  await seed();
  await service.recordPartSectionCompletion(uid, {
    partId,
    sections: ["video", "lesson", "examples", "review", "resources"]
  });
  const attempt = await service.create(uid, {
    requestId: "request-award-on-submit",
    purpose: "part_completion",
    partId,
    templateId
  });
  const submitted = await service.submit(uid, {
    attemptId: attempt.attemptId,
    answers: answers(attempt.questions, 9)
  });
  assert.equal(submitted.partCompletion?.status, "verified");
  const awards = await db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current").collection("achievements").get();
  assert.equal(awards.size, 1);
  assert.equal(awards.docs[0]?.data().examAttemptId, attempt.attemptId);
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

test("four published questions shared by multiple parts survive a random-key wrap", async () => {
  await seed();
  const batch = db.batch();
  const users = db.collection(config.collections.users);
  const questions = db.collection(config.collections.questions);
  batch.update(users.doc(uid).collection("learningProgress").doc("current"), {
    allowedParts: [
      { partId, courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1" },
      { partId: "part-2", courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1" }
    ]
  });
  batch.update(
    db.collection(config.collections.courses).doc("course-1")
      .collection("topics").doc("topic-1")
      .collection("subtopics").doc("subtopic-1"),
    { listPart: [{ id: partId, active: true }, { id: "part-2", active: true }] }
  );
  batch.update(db.collection(config.collections.templates).doc(templateId), {
    questionCount: 4,
    blocks: [{ count: 4, filter: {} }]
  });
  for (let index = 1; index <= 80; index += 1) {
    batch.update(questions.doc(`attempt-fixture-question-${index}`), index <= 4
      ? { randomKey: 0, partIds: [partId, "part-2"] }
      : { status: "retired" });
  }
  await batch.commit();

  for (const linkedPartId of [partId, "part-2"]) {
    const attempt = await service.create(uid, {
      requestId: `request-four-${linkedPartId}`,
      purpose: "part_completion",
      partId: linkedPartId,
      templateId
    });
    assert.equal(attempt.questionCount, 4);
    assert.deepEqual(
      new Set(attempt.questions.map((question) => question.questionId)),
      new Set([1, 2, 3, 4].map((index) => `attempt-fixture-question-${index}`))
    );
  }
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
  const awards = await db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current").collection("achievements").get();
  const batch = db.batch();
  for (const award of awards.docs) batch.delete(award.ref);
  batch.delete(db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current")
    .collection("achievementSummary").doc("current"));
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
