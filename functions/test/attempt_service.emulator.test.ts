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
// Content for all five sections, so the fixture parts require all of them.
const fullPart = {
  linkVideo: "https://youtu.be/fixture",
  content: "Lección",
  examples: [{ id: "e1" }],
  flashcards: [{ id: "f1" }],
  linkPdf: "https://example.com/fixture.pdf"
};

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
    listPart: [{ id: partId, active: true, examTemplateId: templateId, ...fullPart }, { id: "part-2", active: true, examTemplateId: templateId, ...fullPart }]
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
    listPart: [{ id: partId, active: true, examTemplateId: templateId, ...fullPart }, { id: "part-2", active: true, examTemplateId: templateId, ...fullPart }, { id: "part-3", active: true, examTemplateId: templateId, ...fullPart }]
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

test("a part exam only uses the template associated with that catalog part", async () => {
  await seed();
  await db.collection(config.collections.templates).doc("other-part-template").set({
    ...(await db.collection(config.collections.templates).doc(templateId).get()).data(),
    id: "other-part-template"
  });
  const request = {
    requestId: "request-part-template",
    purpose: "part_completion" as const,
    partId,
    templateId: "other-part-template"
  };
  await assert.rejects(
    service.create(uid, request),
    hasReason("failed-precondition", "part_template_not_associated")
  );
  await fixtureSubtopicRef().update({ listPart: [{ id: partId, active: true }] });
  await assert.rejects(
    service.create(uid, { ...request, templateId }),
    hasReason("failed-precondition", "part_template_not_associated")
  );
});

test("a part with no published questions records sections from its catalog location", async () => {
  await seed();
  await db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current").delete();
  await fixtureSubtopicRef().update({
    listPart: [
      { id: partId, active: true, examTemplateId: templateId, ...fullPart },
      { id: "part-empty-bank", active: true, examTemplateId: templateId, ...fullPart }
    ]
  });
  const catalog = { courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1" };

  // Without the location, the old path finds no published question.
  await assert.rejects(
    service.recordPartSectionCompletion(uid, { partId: "part-empty-bank", section: "lesson" }),
    hasReason("failed-precondition", "part_not_available")
  );
  const recorded = await service.recordPartSectionCompletion(uid, {
    partId: "part-empty-bank", section: "lesson", catalog
  });
  assert.deepEqual(recorded.missingSections, ["video", "examples", "review", "resources"]);

  // A location the catalog does not confirm is rejected.
  await assert.rejects(
    service.recordPartSectionCompletion(uid, {
      partId: "part-empty-bank", section: "lesson", catalog: { ...catalog, subtopicId: "other" }
    }),
    hasReason("failed-precondition", "part_not_available")
  );
});

test("a part without a video is verified by its own sections and the exam", async () => {
  await seed();
  const noVideo = { ...fullPart, linkVideo: "" };
  await fixtureSubtopicRef().update({
    listPart: [{ id: partId, active: true, examTemplateId: templateId, ...noVideo }]
  });
  const catalog = { courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1" };
  const sections = await service.recordPartSectionCompletion(uid, {
    partId, sections: ["lesson", "examples", "review", "resources"], catalog
  });
  assert.deepEqual(sections.missingSections, []);

  const attempt = await service.create(uid, {
    requestId: "request-no-video", purpose: "part_completion", partId, templateId, catalog
  });
  const result = await service.submit(uid, {
    attemptId: attempt.attemptId,
    answers: answers(attempt.questions, 9)
  });
  assert.deepEqual(result.progressUpdate, { partId, completed: true });
  const stored = await db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current").get();
  const part = stored.data()?.partProgress?.[partId];
  assert.equal(part.completed, true);
  assert.deepEqual(part.requiredSections, ["lesson", "examples", "review", "resources"]);
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
    { listPart: [{ id: partId, active: true, examTemplateId: templateId, ...fullPart }, { id: "part-2", active: true, examTemplateId: templateId, ...fullPart }] }
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

test("mastery requires a verified completion and an active published association", async () => {
  await seed();
  await seedMastery();
  const request = masteryRequest("mastery-gate");
  await assert.rejects(
    service.create(uid, request),
    hasReason("failed-precondition", "mastery_prerequisite_missing")
  );
  // Historic/local progress is not a verified server award.
  await db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current")
    .update({ legacyCompletedSubtopics: ["subtopic-1"] });
  await assert.rejects(
    service.create(uid, request),
    hasReason("failed-precondition", "mastery_prerequisite_missing")
  );

  await completeFixtureSubtopic();
  const templates = db.collection(config.collections.templates);
  await templates.doc("mastery-fixture-template").update({ active: false });
  await assert.rejects(
    service.create(uid, request),
    hasReason("failed-precondition", "template_not_published")
  );
  await templates.doc("mastery-fixture-template").update({ active: true });
  const subtopic = fixtureSubtopicRef();
  await subtopic.update({ masteryTemplateId: "another-template" });
  await assert.rejects(
    service.create(uid, request),
    hasReason("failed-precondition", "mastery_template_not_associated")
  );
});

test("mastery freezes versions, is idempotent, and grants one badge only after passing", async () => {
  await seed();
  await seedMastery();
  await completeFixtureSubtopic();
  // A later catalog expansion must not revoke the already verified prerequisite.
  await fixtureSubtopicRef().update({
    listPart: [{ id: partId, active: true, examTemplateId: templateId, ...fullPart }, { id: "part-2", active: true, examTemplateId: templateId, ...fullPart }]
  });
  const request = masteryRequest("mastery-idempotent");
  const [first, repeated] = await Promise.all([
    service.create(uid, request),
    service.create(uid, request)
  ]);
  assert.equal(first.attemptId, repeated.attemptId);
  assert.deepEqual(first.questions, repeated.questions);
  assert.equal(first.courseId, "course-1");
  assert.equal(JSON.stringify(first).includes("correctAlternativeId"), false);
  assert.equal(JSON.stringify(first).includes("explanation"), false);
  await assert.rejects(
    service.create(uid, { ...request, subtopicId: "other-subtopic" }),
    hasReason("failed-precondition", "request_id_conflict")
  );
  await assert.rejects(
    service.get("another-student", first.attemptId),
    hasReason("not-found", "attempt_not_found")
  );
  await assert.rejects(
    service.saveAnswers("another-student", { attemptId: first.attemptId, answers: {} }),
    hasReason("not-found", "attempt_not_found")
  );
  await assert.rejects(
    service.submit("another-student", { attemptId: first.attemptId, answers: {} }),
    hasReason("not-found", "attempt_not_found")
  );

  const templateRef = db.collection(config.collections.templates).doc("mastery-fixture-template");
  await templateRef.update({ version: 2, title: "Dominio renovado" });
  await db.collection(config.collections.questions)
    .doc(first.questions[0]!.questionId).update({ version: 2, status: "retired" });
  const recovered = await service.get(uid, first.attemptId);
  assert.equal(recovered.templateVersion, 1);
  assert.deepEqual(recovered.questions, first.questions);
  assert.equal((await service.create(uid, request)).attemptId, first.attemptId);
  await service.saveAnswers(uid, {
    attemptId: first.attemptId,
    answers: { [first.questions[0]!.questionId]: "a" }
  });
  const failed = await service.submit(uid, {
    attemptId: first.attemptId,
    answers: answers(first.questions, 8)
  });
  assert.equal(failed.passed, false);
  assert.equal(failed.masteryUpdate, undefined);
  const afterFail = await service.getAchievementSummary(uid);
  assert.equal(afterFail.totalCompletedSubtopics, 1);
  assert.equal(afterFail.totalMasteredSubtopics, 0);

  const second = await service.create(uid, masteryRequest("mastery-after-fail"));
  assert.notEqual(second.attemptId, first.attemptId);
  assert.equal((await service.get(uid, second.attemptId)).templateVersion, 2);
  const passed = await service.submit(uid, {
    attemptId: second.attemptId,
    answers: answers(second.questions, 9)
  });
  assert.equal(passed.passed, true);
  assert.deepEqual(passed.masteryUpdate, {
    courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1", mastered: true
  });
  const awards = await db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current").collection("achievements").get();
  assert.equal(awards.size, 2);
  const mastery = awards.docs.find((award) => award.data().type === "subtopic_mastery");
  assert.ok(mastery);
  assert.equal(mastery.data().templateVersion, 2);
  assert.equal(mastery.data().examAttemptId, second.attemptId);
  const summaryBeforeRetry = await service.getAchievementSummary(uid);
  assert.equal(summaryBeforeRetry.totalCompletedSubtopics, 1);
  assert.equal(summaryBeforeRetry.totalMasteredSubtopics, 1);
  assert.equal(summaryBeforeRetry.recentMastery[0]?.subtopicId, "subtopic-1");
  assert.deepEqual(await service.submit(uid, {
    attemptId: second.attemptId,
    answers: answers(second.questions, 9)
  }), passed);
  assert.deepEqual((await mastery.ref.get()).data(), mastery.data());
  assert.deepEqual(await service.getAchievementSummary(uid), summaryBeforeRetry);
  const another = await service.create(uid, masteryRequest("mastery-after-success"));
  await service.submit(uid, {
    attemptId: another.attemptId,
    answers: answers(another.questions, 9)
  });
  assert.deepEqual((await mastery.ref.get()).data(), mastery.data());
  assert.deepEqual(await service.getAchievementSummary(uid), summaryBeforeRetry);

  const summaryRef = db.collection(config.collections.users).doc(uid)
    .collection("learningProgress").doc("current")
    .collection("achievementSummary").doc("current");
  await summaryRef.delete();
  const rebuilt = await service.getAchievementSummary(uid);
  assert.equal(rebuilt.totalCompletedSubtopics, 1);
  assert.equal(rebuilt.totalMasteredSubtopics, 1);
  assert.equal(rebuilt.recentMastery[0]?.examAttemptId, second.attemptId);
});

test("a grading failure leaves mastery open and awards nothing until a successful retry", async () => {
  await seed();
  await seedMastery();
  await completeFixtureSubtopic();
  const created = await service.create(uid, masteryRequest("mastery-atomic"));
  const question = created.questions[0]!;
  const keyRef = db.collection(config.collections.answerKeys).doc(`${question.questionId}_${question.version}`);
  const originalKey = (await keyRef.get()).data();
  assert.ok(originalKey);
  await keyRef.delete();
  await assert.rejects(
    service.submit(uid, { attemptId: created.attemptId, answers: answers(created.questions, 9) }),
    hasReason("failed-precondition", "answer_key_unavailable")
  );
  assert.equal((await service.get(uid, created.attemptId)).status, "in_progress");
  assert.equal((await service.getAchievementSummary(uid)).totalMasteredSubtopics, 0);
  await keyRef.set(originalKey);
  const passed = await service.submit(uid, {
    attemptId: created.attemptId,
    answers: answers(created.questions, 9)
  });
  assert.equal(passed.passed, true);
  assert.equal((await service.getAchievementSummary(uid)).totalMasteredSubtopics, 1);
});

test("a published mastery block may reuse an active part filter from the same subtopic", async () => {
  await seed();
  await seedMastery();
  await completeFixtureSubtopic();
  await db.collection(config.collections.templates).doc("mastery-fixture-template")
    .update({ blocks: [{ count: 10, filter: { partId } }] });
  const attempt = await service.create(uid, masteryRequest("mastery-editorial-part-block"));
  assert.equal(attempt.questionCount, 10);
});

function masteryRequest(requestId: string) {
  return {
    requestId,
    purpose: "subtopic_mastery" as const,
    courseId: "course-1",
    topicId: "topic-1",
    subtopicId: "subtopic-1",
    templateId: "mastery-fixture-template"
  };
}

function fixtureSubtopicRef() {
  return db.collection(config.collections.courses).doc("course-1")
    .collection("topics").doc("topic-1")
    .collection("subtopics").doc("subtopic-1");
}

async function seedMastery(): Promise<void> {
  await fixtureSubtopicRef().update({ masteryTemplateId: "mastery-fixture-template" });
  await db.collection(config.collections.templates).doc("mastery-fixture-template").set({
    schemaVersion: 2,
    id: "mastery-fixture-template",
    version: 1,
    title: "Dominio del subtema",
    status: "published",
    active: true,
    purpose: "subtopic_mastery",
    mode: "dynamic",
    selectionPolicy: "strict",
    allowedFallbackSources: [],
    questionCount: 10,
    passPercentExclusive: 80,
    blocks: [{ count: 10, filter: {} }]
  });
}

async function completeFixtureSubtopic(): Promise<void> {
  await service.recordPartSectionCompletion(uid, {
    partId,
    sections: ["video", "lesson", "examples", "review", "resources"]
  });
  const attempt = await service.create(uid, {
    requestId: `prerequisite-${Date.now()}`,
    purpose: "part_completion",
    partId,
    templateId
  });
  await service.submit(uid, {
    attemptId: attempt.attemptId,
    answers: answers(attempt.questions, 9)
  });
}

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
    { active: true, listPart: [{ id: partId, active: true, examTemplateId: templateId, ...fullPart }] }
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
