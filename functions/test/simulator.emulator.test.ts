import assert from "node:assert/strict";
import test from "node:test";
import { Timestamp, type WriteBatch } from "firebase-admin/firestore";

import { db } from "../src/admin";
import { ExamAttemptService, type AttemptQuestionSnapshot } from "../src/attempt_service";
import { readBackendConfig } from "../src/config";
import { ExamBackendError } from "../src/errors";
import { ChallengeService } from "../src/challenge";
import { examMemoryRef, parseExamMemory } from "../src/exam_memory";
import { OperationMetrics } from "../src/operation_metrics";
import { loadQuestionIndex, syncQuestionIndex } from "../src/question_index";
import { peruDay, XpService } from "../src/xp";

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

test("submitting builds topic stats; the plan focuses on the weak topic", async () => {
  await seed();
  const user = db.collection(config.collections.users).doc(uid);
  // Diagnostic: the per-course share of every active course with questions.
  const diagnostic = await service.create(uid, { requestId: "sim-diag", purpose: "practice", mode: "diagnostic", timed: false });
  const perCourse = count(diagnostic.simulator?.questionCourseIds ?? []);
  assert.equal(perCourse.get("sim-course-a"), 4);
  assert.equal(perCourse.get("sim-course-b"), 4);
  assert.equal(diagnostic.simulator?.timed, false);
  await service.submit(uid, { attemptId: diagnostic.attemptId, answers: {} });
  // Fase 4A: un solo documento resumen en vez de una subcolección por tema.
  const summaryRef = user.collection("simulatorSummary").doc("current");
  const topics = (await summaryRef.get()).data()?.topics as Record<string, Record<string, unknown>>;
  const topicA = topics["sim-course-a-topic"];
  assert.equal(topicA?.answered, 4);
  assert.equal(topicA?.correct, 0);
  assert.equal(topicA?.courseId, "sim-course-a");

  // Course B gets right answers so only course A's topic is weak.
  await summaryRef.set({
    topics: {
      "sim-course-b-topic": { topicId: "sim-course-b-topic", courseId: "sim-course-b", answered: 10, correct: 9 },
      "sim-course-a-topic": { topicId: "sim-course-a-topic", courseId: "sim-course-a", answered: 10, correct: 2 }
    }
  }, { merge: true });
  const daily = await service.create(uid, { requestId: "sim-daily", purpose: "practice", mode: "plan", timed: true });
  assert.equal(daily.questions.length, 10);
  assert.equal(daily.durationSeconds, 15 * 60);
  assert.deepEqual(daily.simulator?.focusTopicIds, ["sim-course-a-topic"]);
  assert.ok((count(daily.simulator?.questionCourseIds ?? []).get("sim-course-a") ?? 0) >= 6);
});

test("«Hoy te toca» twice returns the open session; after submitting, a new one", async () => {
  await seed();
  const first = await service.create(uid, { requestId: "plan-tap-1", purpose: "practice", mode: "plan", timed: true });
  // A second tap or a retry after a timeout comes with another request ID.
  const second = await service.create(uid, { requestId: "plan-tap-2", purpose: "practice", mode: "plan", timed: true });
  assert.equal(second.attemptId, first.attemptId);
  assert.deepEqual(second.questions.map((q) => q.questionId), first.questions.map((q) => q.questionId));
  const open = await db.collection(config.collections.attempts).where("userId", "==", uid)
    .where("requestId", "in", ["plan-tap-1", "plan-tap-2"]).get();
  assert.equal(open.size, 1);
  // Other modes are not affected.
  const practice = await service.create(uid, { requestId: "plan-tap-3", purpose: "practice", mode: "random", courseIds: [], topicIds: [], size: "short", timed: false });
  assert.notEqual(practice.attemptId, first.attemptId);
  // «Otra sesión» after submitting creates a new one.
  await service.submit(uid, { attemptId: first.attemptId, answers: {} });
  const next = await service.create(uid, { requestId: "plan-tap-4", purpose: "practice", mode: "plan", timed: true });
  assert.notEqual(next.attemptId, first.attemptId);
});

test("XP: a practice gives session, fresh answers and streak once; repeats and rushing give none", async () => {
  await seed();
  const xp = new XpService(db, config);
  const user = db.collection(config.collections.users).doc(uid);
  await user.collection("simulatorPlan").doc("current").set({ sessionsPerWeek: 1, mockDay: 6 });
  const first = await service.create(uid, {
    requestId: "xp-1", purpose: "practice", mode: "course",
    courseIds: ["sim-course-a"], topicIds: [], size: "short", timed: true
  });
  assert.equal(((await db.collection(config.collections.attempts).doc(first.attemptId).get()).data()?.xpFreshQuestionIds as string[]).length, 10);
  await service.start(uid, first.attemptId);
  // Ten minutes used: well above the 5 s per question minimum.
  await db.collection(config.collections.attempts).doc(first.attemptId).update({ startedAtMs: Date.now() - 10 * 60 * 1000 });
  const graded = await service.submit(uid, { attemptId: first.attemptId, answers: answersFor(first.questions, 7) });
  assert.equal(graded.simulator?.correct, 7);
  // Últimos resultados dentro del resumen: la app los lee con una lectura.
  const recent = (await user.collection("simulatorSummary").doc("current").get()).data()?.recentResults as Record<string, unknown>[];
  assert.equal(recent[0]?.attemptId, first.attemptId);
  assert.equal(recent[0]?.correct, 7);
  assert.equal(recent[0]?.universityId, undefined);
  const award = await xp.afterAttempt(uid, first.attemptId);
  assert.deepEqual(award?.items.map((item) => [item.type, item.xp]), [
    ["simulator_session", 10],
    ["correct_answers", 7],
    ["streak_day", 5],
    ["weekly_goal", 50]
  ]);
  assert.equal(award?.total, 72);
  assert.equal(await xp.afterAttempt(uid, first.attemptId), undefined);
  assert.equal((await user.collection("xp").doc("current").get()).data()?.total, 72);
  assert.equal((await user.collection("xpEvents").doc(`session_${first.attemptId}`).get()).data()?.xp, 10);

  // «Mis errores» repeats seen questions and is answered too fast: nothing.
  const rushed = await service.create(uid, { requestId: "xp-2", purpose: "practice", mode: "mistakes", fromAttemptId: first.attemptId, timed: false });
  await service.start(uid, rushed.attemptId);
  await service.submit(uid, { attemptId: rushed.attemptId, answers: answersFor(rushed.questions, 3) });
  assert.equal(await xp.afterAttempt(uid, rushed.attemptId), undefined);
});

test("reto del día: same questions for the university, one attempt, answers hidden, entry and bonus", async () => {
  await seed();
  const rankings = db.collection(config.collections.config).doc("rankings");
  await rankings.set({ enabled: false });
  await assert.rejects(
    service.create(uid, { requestId: "ch-0", purpose: "practice", mode: "daily_challenge", timed: true }),
    hasReason("failed-precondition", "challenge_disabled")
  );
  await rankings.set({ enabled: true, startWeek: "2000-01-03", challenge: { ownPastExamQuestions: 4 } });
  const day = peruDay(Date.now());
  await db.collection(config.collections.dailyChallenges).doc(`${day}_${universityId}`).delete();
  await db.collection(config.collections.challengeEntries).doc(`${day}_${uid}`).delete();

  const first = await service.create(uid, { requestId: "ch-1", purpose: "practice", mode: "daily_challenge", timed: true });
  assert.equal(first.questions.length, 10);
  assert.equal(first.durationSeconds, 15 * 60);
  assert.equal(first.simulator?.mode, "daily_challenge");
  // Another tap (any request ID) is the same attempt: one per day.
  const again = await service.create(uid, { requestId: "ch-2", purpose: "practice", mode: "daily_challenge", timed: true });
  assert.equal(again.attemptId, first.attemptId);
  // Another student of the university gets the same questions, in the same order.
  const other = "simulator-fixture-other";
  await db.collection(config.collections.users).doc(other).set({ profile: { universityIdDoc: universityId, professionId: "sim-profession" } });
  await db.collection(config.collections.users).doc(other).collection("examRequestKeys").doc(`challenge_${day}`).delete();
  const theirs = await service.create(other, { requestId: "ch-x", purpose: "practice", mode: "daily_challenge", timed: true });
  assert.deepEqual(theirs.questions.map((q) => q.questionId), first.questions.map((q) => q.questionId));
  const stored = (await db.collection(config.collections.dailyChallenges).doc(`${day}_${universityId}`).get()).data();
  assert.ok((stored?.ownPastExamCount as number) >= 4);

  await service.start(uid, first.attemptId);
  // Answer at a human pace: the clock is the server's, so move it back.
  await db.collection(config.collections.attempts).doc(first.attemptId).update({ startedAtMs: Date.now() - 5 * 60 * 1000 });
  const result = await service.submit(uid, { attemptId: first.attemptId, answers: answersFor(first.questions, 7) });
  assert.equal(result.correctAnswers, 7);
  // The answers of today's challenge stay hidden until tomorrow.
  assert.deepEqual(result.review, []);
  const xp = new XpService(db, config);
  const award = await xp.afterAttempt(uid, first.attemptId);
  assert.ok(award?.items.some((item) => item.type === "daily_challenge" && item.xp === 20));
  const entry = await new ChallengeService(db, config).recordEntry(uid, first.attemptId, await xp.settings());
  assert.equal(entry?.correct, 7);
  const saved = (await db.collection(config.collections.challengeEntries).doc(`${day}_${uid}`).get()).data();
  assert.equal(saved?.correct, 7);
  assert.equal(saved?.universityId, universityId);
  assert.equal(saved?.professionId, "sim-profession");
  // «Practicar mis errores» of today's challenge would reveal the answers.
  await assert.rejects(
    service.create(uid, { requestId: "ch-mistakes", purpose: "practice", mode: "mistakes", fromAttemptId: first.attemptId, timed: false }),
    hasReason("failed-precondition", "mistakes_unavailable")
  );
  await rankings.delete();
});

test("con el índice del curso la práctica lee solo lo que usa y recuerda lo visto en un documento", async () => {
  await seed();
  const user = db.collection(config.collections.users).doc(uid);
  // Alumno de antes del cambio: su historial está en recentQuestions.
  await user.collection("recentQuestions").doc("sim-course-b-1").set({ lastSeenAt: Timestamp.now(), exposureCount: 2 });
  const bank = await db.collection(config.collections.questions).where("courseId", "==", "sim-course-b").get();
  await db.collection(config.collections.questionIndex).doc("sim-course-b").delete();
  for (const document of bank.docs) await syncQuestionIndex(db, config, document.id, undefined, document.data());
  assert.equal((await loadQuestionIndex(db, config, "sim-course-b"))?.length, 30);

  const metrics = new OperationMetrics();
  const input = (requestId: string) => ({
    requestId, purpose: "practice" as const, mode: "course" as const, courseIds: ["sim-course-b"], topicIds: [] as string[], size: "short" as const, timed: true
  });
  const first = await service.create(uid, input("idx-1"), metrics);
  assert.equal(first.questions.length, 10);
  const fields = metrics.logFields();
  // Antes: hasta 100 vistas + 80 candidatas + 10 de XP. Ahora: el índice y las 12 que se leen.
  assert.ok(fields.observedDocumentReads! <= 25, `lecturas: ${fields.observedDocumentReads}`);
  assert.equal(fields.plannedDocumentWrites, 3);
  assert.equal(first.questions.some((question) => question.questionId === "sim-course-b-1"), false);
  const memory = parseExamMemory((await examMemoryRef(db, config, uid).get()).data());
  assert.equal(memory.size, 11);
  assert.equal(memory.get("sim-course-b-1")?.n, 2);

  // La segunda práctica ya no repite las vistas y sigue leyendo poco.
  const again = new OperationMetrics();
  const second = await service.create(uid, input("idx-2"), again);
  const firstIds = new Set(first.questions.map((question) => question.questionId));
  assert.equal(second.questions.some((question) => firstIds.has(question.questionId)), false);
  assert.ok(again.logFields().observedDocumentReads! <= 25);
  assert.equal(parseExamMemory((await examMemoryRef(db, config, uid).get()).data()).size, 21);

  // Retirar una pregunta la saca del índice.
  const retired = bank.docs[1]!;
  await syncQuestionIndex(db, config, retired.id, retired.data(), { ...retired.data(), status: "retired" });
  assert.equal((await loadQuestionIndex(db, config, "sim-course-b"))?.some((entry) => entry.id === retired.id), false);
  await db.collection(config.collections.questionIndex).doc("sim-course-b").delete();
});

async function seed(): Promise<void> {
  const user = db.collection(config.collections.users).doc(uid);
  for (const name of ["recentQuestions", "examMemory", "examRequestKeys", "pastExamBest", "simulatorResults", "learningEvents", "simulatorTopicStats", "simulatorSummary", "xp", "xpEvents", "simulatorPlan"]) {
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
