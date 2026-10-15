import assert from "node:assert/strict";
import test from "node:test";
import type { WriteBatch } from "firebase-admin/firestore";

import { db } from "../src/admin";
import { ExamAttemptService, type AttemptQuestionSnapshot } from "../src/attempt_service";
import { readBackendConfig } from "../src/config";
import { ExamBackendError } from "../src/errors";

const config = readBackendConfig({ INGRESOYA_ENV: "test" });
const service = new ExamAttemptService(db, config);
const uid = "simulator-fixture-student";
const universityId = "sim-university";
const examId = "sim-exam";
const exam = () => db.collection(config.collections.universities).doc(universityId)
  .collection("admissionExams").doc(examId);
const rules = {
  questionCount: 4,
  durationMinutes: 10,
  maxScore: 100,
  correctPoints: 2,
  incorrectPoints: -0.5,
  blankPoints: 0,
  questionOrder: "original",
  available: true,
  cutoffs: { "sim-profession": 50 }
};

test("a past exam keeps the original order, official score, best score and event", async () => {
  await seed();
  const created = await service.create(uid, { requestId: "sim-past-1", purpose: "past_exam", universityId, examId });
  // originalNumber runs opposite to the document IDs.
  assert.deepEqual(created.questions.map((question) => question.questionId), ["sim-past-4", "sim-past-3", "sim-past-2", "sim-past-1"]);
  assert.equal(created.durationSeconds, 600);
  assert.equal(created.simulator?.purpose, "past_exam");
  assert.equal(created.simulator?.timed, true);
  for (const question of created.questions) assert.deepEqual(question.alternativeOrder, ["a", "b", "c"]);
  assert.deepEqual(
    (await service.create(uid, { requestId: "sim-past-1", purpose: "past_exam", universityId, examId })).attemptId,
    created.attemptId
  );
  await assert.rejects(
    service.create(uid, { requestId: "sim-past-1", purpose: "practice", mode: "random", courseIds: [], topicIds: [], size: "short", timed: true }),
    hasReason("failed-precondition", "request_id_conflict")
  );

  await service.start(uid, created.attemptId);
  const [q1, q2, q3] = created.questions;
  // Two correct, one incorrect, one blank: 2·2 − 0.5 = 3.5 of 8 → 44 of 100.
  const result = await service.submit(uid, {
    attemptId: created.attemptId,
    answers: { [q1!.questionId]: "a", [q2!.questionId]: "a", [q3!.questionId]: "b" }
  });
  assert.equal(result.simulator?.correct, 2);
  assert.equal(result.simulator?.incorrect, 1);
  assert.equal(result.simulator?.blank, 1);
  assert.equal(result.simulator?.rawScore, 3.5);
  assert.equal(result.simulator?.score, 44);
  assert.equal(result.simulator?.cutoffScore, 50);
  assert.equal(result.simulator?.reachedCutoff, false);
  assert.deepEqual(result.simulator?.byCourse, [{ id: "sim-course-a", total: 4, correct: 2, incorrect: 1, blank: 1 }]);
  assert.equal(result.review[0]?.courseId, "sim-course-a");
  assert.deepEqual(result.review[0]?.partIds, ["sim-part"]);
  assert.deepEqual(await service.submit(uid, { attemptId: created.attemptId, answers: {} }), result);

  const user = db.collection(config.collections.users).doc(uid);
  const best = (await user.collection("pastExamBest").doc(examId).get()).data();
  assert.equal(best?.bestScore, 44);
  assert.equal(best?.attempts, 1);
  const summary = (await user.collection("simulatorResults").doc(created.attemptId).get()).data();
  assert.equal(summary?.score, 44);
  assert.equal(summary?.examId, examId);
  const event = (await user.collection("learningEvents").doc(`past_exam_completed_${created.attemptId}`).get()).data();
  assert.equal(event?.type, "past_exam_completed");

  // A worse second try keeps the best score.
  const second = await service.create(uid, { requestId: "sim-past-2", purpose: "past_exam", universityId, examId });
  const worse = await service.submit(uid, { attemptId: second.attemptId, answers: {} });
  assert.equal(worse.simulator?.score, 0);
  assert.equal(worse.simulator?.previousScore, 44);
  assert.equal(result.simulator?.previousScore, undefined);

  // «Practicar mis errores»: the incorrect and the blank question only.
  const mistakes = await service.create(uid, {
    requestId: "sim-mistakes", purpose: "practice", mode: "mistakes", fromAttemptId: created.attemptId, timed: true
  });
  assert.deepEqual(
    mistakes.questions.map((question) => question.questionId).sort(),
    [q3!.questionId, created.questions[3]!.questionId].sort()
  );
  assert.equal(mistakes.durationSeconds, 2 * 90);
  assert.equal(mistakes.simulator?.mode, "mistakes");
  const retried = await service.submit(uid, {
    attemptId: mistakes.attemptId,
    answers: Object.fromEntries(mistakes.questions.map((question) => [question.questionId, "a"]))
  });
  assert.equal(retried.simulator?.percentage, 100);
  await assert.rejects(
    service.create(uid, { requestId: "sim-mistakes-none", purpose: "practice", mode: "mistakes", fromAttemptId: mistakes.attemptId, timed: false }),
    hasReason("failed-precondition", "no_mistakes")
  );
  await db.collection(config.collections.users).doc("another-student").set({ universityId });
  await assert.rejects(
    service.create("another-student", { requestId: "sim-mistakes-other", purpose: "practice", mode: "mistakes", fromAttemptId: created.attemptId, timed: false }),
    hasReason("failed-precondition", "mistakes_unavailable")
  );
  const after = (await user.collection("pastExamBest").doc(examId).get()).data();
  assert.equal(after?.bestScore, 44);
  assert.equal(after?.lastScore, 0);
  assert.equal(after?.attempts, 2);
});

test("an expired timed exam is graded with saved answers; late patches are ignored", async () => {
  await seed();
  const created = await service.create(uid, { requestId: "sim-past-late", purpose: "past_exam", universityId, examId });
  await service.start(uid, created.attemptId);
  const first = created.questions[0]!.questionId;
  await service.saveAnswers(uid, { attemptId: created.attemptId, answers: { [first]: "a" } });
  await db.collection(config.collections.attempts).doc(created.attemptId)
    .update({ expiresAt: new Date(Date.now() - 10 * 60 * 1000) });
  const result = await service.submit(uid, {
    attemptId: created.attemptId,
    answers: Object.fromEntries(created.questions.map((question) => [question.questionId, "a"]))
  });
  assert.equal(result.simulator?.correct, 1);
  assert.equal(result.simulator?.blank, 3);
});

test("a past exam is refused when unavailable or incomplete", async () => {
  await seed();
  await exam().update({ "simulator.available": false });
  await assert.rejects(
    service.create(uid, { requestId: "sim-off", purpose: "past_exam", universityId, examId }),
    hasReason("failed-precondition", "past_exam_unavailable")
  );
  await exam().update({ "simulator.available": true, "simulator.questionCount": 5 });
  await assert.rejects(
    service.create(uid, { requestId: "sim-incomplete", purpose: "past_exam", universityId, examId }),
    hasReason("failed-precondition", "past_exam_incomplete")
  );
});

test("a practice shares questions among courses, avoids repeats and checks the bank", async () => {
  await seed();
  const mix = await service.create(uid, {
    requestId: "sim-mix", purpose: "practice", mode: "mix",
    courseIds: ["sim-course-a", "sim-course-b"], topicIds: [], size: "short", timed: false
  });
  assert.equal(mix.questions.length, 10);
  assert.equal(mix.simulator?.timed, false);
  assert.equal(mix.durationSeconds, 4 * 60 * 60);
  const perCourse = count(mix.simulator?.questionCourseIds ?? []);
  assert.equal(perCourse.get("sim-course-a"), 5);
  assert.equal(perCourse.get("sim-course-b"), 5);

  const single = await service.create(uid, {
    requestId: "sim-single", purpose: "practice", mode: "course",
    courseIds: ["sim-course-b"], topicIds: [], size: "short", timed: true
  });
  const seen = new Set(mix.questions.map((question) => question.questionId));
  assert.equal(single.questions.some((question) => seen.has(question.questionId)), false);
  assert.equal(single.durationSeconds, 15 * 60);

  const graded = await service.submit(uid, { attemptId: single.attemptId, answers: answersFor(single.questions, 7) });
  assert.equal(graded.simulator?.score, 70);
  assert.equal(graded.simulator?.percentage, 70);
  assert.equal(graded.passed, false);

  const realOnly = await service.create(uid, {
    requestId: "sim-real", purpose: "practice", mode: "course",
    courseIds: ["sim-course-b"], topicIds: [], size: "short", timed: true, source: "real"
  });
  for (const question of realOnly.questions) assert.equal(Number(question.questionId.split("-").at(-1)) % 2, 0);

  await assert.rejects(
    service.create(uid, {
      requestId: "sim-long", purpose: "practice", mode: "course",
      courseIds: ["sim-course-b"], topicIds: [], size: "long", timed: true
    }),
    hasReason("failed-precondition", "insufficient_questions")
  );
  await assert.rejects(
    service.create(uid, {
      requestId: "sim-size", purpose: "practice", mode: "course",
      courseIds: ["sim-course-b"], topicIds: [], size: "huge", timed: true
    }),
    hasReason("failed-precondition", "practice_size_unavailable")
  );
});

async function seed(): Promise<void> {
  const user = db.collection(config.collections.users).doc(uid);
  for (const name of ["recentQuestions", "examRequestKeys", "pastExamBest", "simulatorResults", "learningEvents"]) {
    const docs = await user.collection(name).get();
    const cleanup = db.batch();
    docs.docs.forEach((doc) => cleanup.delete(doc.ref));
    await cleanup.commit();
  }
  const batch = db.batch();
  batch.set(user, { profile: { universityIdDoc: universityId, professionId: "sim-profession" } });
  batch.set(db.collection(config.collections.config).doc("simulator"), {});
  batch.set(db.collection(config.collections.universities).doc(universityId), { name: "Sim", active: true });
  batch.set(exam(), { name: "Examen Sim 2026-I", active: true, simulator: rules });
  const courses = db.collection(config.collections.courses);
  batch.set(courses.doc("sim-course-a"), { active: true });
  batch.set(courses.doc("sim-course-b"), { active: true });
  for (let index = 1; index <= 4; index += 1) {
    question(batch, `sim-past-${index}`, "sim-course-a", "admission_exam", {
      examId,
      originalNumber: 5 - index,
      randomKey: index / 10
    });
  }
  for (const course of ["sim-course-a", "sim-course-b"]) {
    for (let index = 1; index <= 30; index += 1) {
      question(batch, `${course}-${index}`, course, index % 2 === 0 ? "admission_exam" : "original", {
        randomKey: index / 31
      });
    }
  }
  await batch.commit();
}

function question(
  batch: WriteBatch,
  questionId: string,
  courseId: string,
  sourceType: string,
  extra: Record<string, unknown>
): void {
  batch.set(db.collection(config.collections.questions).doc(questionId), {
    schemaVersion: 2,
    questionId,
    version: 1,
    status: "published",
    sourceLabel: "Sim",
    universityId,
    sourceType,
    sourceExamId: "",
    modalityId: "",
    courseId,
    topicId: `${courseId}-topic`,
    subtopicId: `${courseId}-subtopic`,
    partIds: ["sim-part"],
    difficulty: "medium",
    content: [],
    alternatives: [
      { id: "a", label: "A", content: [] },
      { id: "b", label: "B", content: [] },
      { id: "c", label: "C", content: [] }
    ],
    ...extra
  });
  batch.set(db.collection(config.collections.answerKeys).doc(`${questionId}_1`), {
    schemaVersion: 2,
    questionId,
    version: 1,
    correctAlternativeId: "a",
    explanation: [{ type: "text", value: "porque sí" }]
  });
}

function answersFor(questions: readonly AttemptQuestionSnapshot[], correct: number): Record<string, string> {
  return Object.fromEntries(questions.map((question, index) => [question.questionId, index < correct ? "a" : "b"]));
}

function count(values: readonly string[]): Map<string, number> {
  const result = new Map<string, number>();
  for (const value of values) result.set(value, (result.get(value) ?? 0) + 1);
  return result;
}

function hasReason(code: ExamBackendError["code"], reason: string) {
  return (error: unknown): boolean =>
    error instanceof ExamBackendError && error.code === code && error.details?.reason === reason;
}
