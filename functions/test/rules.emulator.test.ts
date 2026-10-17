import { readFile } from "node:fs/promises";
import { join } from "node:path";
import assert from "node:assert/strict";
import test, { after, before, beforeEach } from "node:test";

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment
} from "@firebase/rules-unit-testing";
import "firebase/compat/firestore";
import "firebase/compat/storage";

const projectId = "ingresoya-security-rules";
let testEnv: RulesTestEnvironment;

function firestoreFor(uid?: string, admin = false) {
  const context = uid === undefined
    ? testEnv.unauthenticatedContext()
    : testEnv.authenticatedContext(uid, admin ? { admin: true } : {});
  return context.firestore();
}

function staffFor(uid: string, claims: Record<string, unknown>) {
  return testEnv.authenticatedContext(uid, { admin: true, ...claims }).firestore();
}

const EDITOR = {
  role: "editor",
  p: { questions: "ve", courses: "ve", universities: "ve", news: "ve", settings: "v", history: "v" }
};
const REVIEWER = {
  role: "reviewer",
  p: { questions: "vep", courses: "vep", universities: "vep", news: "vep", settings: "v", history: "v" }
};
const SUPPORT = { role: "support", p: { students: "ve", questions: "v", courses: "v", history: "v" } };

function storageFor(uid?: string, admin = false) {
  const context = uid === undefined
    ? testEnv.unauthenticatedContext()
    : testEnv.authenticatedContext(uid, admin ? { admin: true } : {});
  return context.storage();
}

// `emulators:exec` exports where each emulator listens; the defaults match
// firebase.json for direct runs.
function emulatorPort(variable: string, fallback: number): number {
  const port = Number(process.env[variable]?.split(":").at(-1));
  return Number.isInteger(port) && port > 0 ? port : fallback;
}

before(async () => {
  const root = join(process.cwd(), "..");
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: await readFile(join(root, "firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: emulatorPort("FIRESTORE_EMULATOR_HOST", 8080)
    },
    storage: {
      rules: await readFile(join(root, "storage.rules"), "utf8"),
      host: "127.0.0.1",
      port: emulatorPort("FIREBASE_STORAGE_EMULATOR_HOST", 9199)
    }
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("iya-courses-test/course-1").set({ active: true });
    await db.doc("iya-questions-test/published").set({
      questionId: "published",
      version: 1,
      status: "published",
      content: { blocks: [] }
    });
    await db.doc("iya-questions-test/draft").set({
      questionId: "draft",
      version: 1,
      status: "draft"
    });
    await db.doc("iya-question-answer-keys-test/published_1").set({
      questionId: "published",
      version: 1,
      correctAlternativeId: "alternative-a"
    });
    await db.doc("iya-exam-attempts-test/attempt-owned").set({
      userId: "student-1",
      status: "in_progress"
    });
  });
});

after(async () => {
  await testEnv.cleanup();
});

test("learner access is limited to required catalogs and cannot enumerate the bank", async () => {
  const learner = firestoreFor("student-1");
  const anonymous = firestoreFor();

  await assertSucceeds(learner.doc("iya-courses-test/course-1").get());
  await assertFails(learner.doc("iya-questions-test/published").get());
  await assertFails(learner.doc("iya-questions-test/draft").get());
  await assertFails(
    learner.doc("iya-question-answer-keys-test/published_1").get()
  );
  await assertFails(anonymous.doc("iya-courses-test/course-1").get());
  await assertFails(anonymous.doc("iya-questions-test/published").get());
});

test("attempts are readable only by their owner and are server-written", async () => {
  const owner = firestoreFor("student-1");
  const otherLearner = firestoreFor("student-2");

  await assertSucceeds(
    owner.doc("iya-exam-attempts-test/attempt-owned").get()
  );
  await assertFails(
    otherLearner.doc("iya-exam-attempts-test/attempt-owned").get()
  );
  await assertFails(
    owner.doc("iya-exam-attempts-test/attempt-client").set({
      userId: "student-1",
      status: "submitted"
    })
  );
});

test("learner cannot publish questions or complete learning progress directly", async () => {
  const learner = firestoreFor("student-1");

  await assertFails(
    learner.doc("iya-questions-test/client-question").set({
      questionId: "client-question",
      version: 1,
      status: "published"
    })
  );
  await assertFails(
    learner.doc("iya-profile-test/student-1/learningProgress/part-1").set({ completed: true })
  );
  const award = learner.doc(
    "iya-profile-test/student-1/learningProgress/current/achievements/parts-v1-fixture"
  );
  await assertFails(award.get());
  await assertFails(award.set({ type: "subtopic_completed" }));
  const masteryAward = learner.doc(
    "iya-profile-test/student-1/learningProgress/current/achievements/mastery-v1-fixture"
  );
  await assertFails(masteryAward.get());
  await assertFails(masteryAward.set({ type: "subtopic_mastery", subtopicId: "subtopic-1" }));
  const summary = learner.doc(
    "iya-profile-test/student-1/learningProgress/current/achievementSummary/current"
  );
  await assertFails(summary.get());
  await assertFails(summary.set({ totalCompletedSubtopics: 99 }));
  await assertFails(summary.set({ totalMasteredSubtopics: 99 }));
});

test("owner can only read its own server part evidence, never write it", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore()
      .doc("iya-profile-test/student-1/learningProgress/current")
      .set({ partProgress: { "part-1": { schemaVersion: 2, completed: true } } });
  });
  const learner = firestoreFor("student-1");
  const other = firestoreFor("student-2");
  const current = "iya-profile-test/student-1/learningProgress/current";

  await assertSucceeds(learner.doc(current).get());
  await assertFails(other.doc(current).get());
  await assertFails(learner.doc(current).set({ partProgress: {} }));
  await assertFails(learner.doc(current).update({ allowedParts: [] }));
  await assertFails(learner.collection("iya-profile-test/student-1/learningProgress").get());
});

test("simulator results, best scores and learning events are owner-read, server-written", async () => {
  const learner = firestoreFor("student-1");
  const other = firestoreFor("student-2");
  for (const name of ["simulatorResults", "pastExamBest", "learningEvents", "simulatorTopicStats"]) {
    const path = `iya-profile-test/student-1/${name}/doc-1`;
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context.firestore().doc(path).set({ score: 1 });
    });
    await assertSucceeds(learner.doc(path).get());
    await assertSucceeds(learner.collection(`iya-profile-test/student-1/${name}`).get());
    await assertFails(other.doc(path).get());
    await assertFails(learner.doc(path).set({ score: 1000 }));
    await assertFails(learner.doc(`iya-profile-test/student-1/${name}/doc-2`).set({ score: 1000 }));
    await assertFails(learner.doc(path).delete());
  }
});

test("the student writes only their own training plan goal", async () => {
  const learner = firestoreFor("student-1");
  const other = firestoreFor("student-2");
  const path = "iya-profile-test/student-1/simulatorPlan/current";
  await assertSucceeds(learner.doc(path).set({ sessionsPerWeek: 5, mockDay: 6 }));
  await assertSucceeds(learner.doc(path).get());
  await assertFails(other.doc(path).get());
  await assertFails(other.doc(path).set({ sessionsPerWeek: 7 }));
});

test("the top 100 is public to students but written only by the server; aliases stay private", async () => {
  const learner = firestoreFor("student-1");
  const admin = firestoreFor("admin-1", true);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("iya-leaderboard-test/student-2").set({ alias: "Búho_2", total: 500 });
    await db.doc("iya-aliases-test/buho_2").set({ uid: "student-2" });
    await db.doc("iya-profile-test/student-1/ranking/current").set({ alias: "Búho_1", visible: true });
  });
  await assertSucceeds(learner.doc("iya-leaderboard-test/student-2").get());
  await assertSucceeds(learner.collection("iya-leaderboard-test").orderBy("total", "desc").limit(100).get());
  await assertFails(firestoreFor().doc("iya-leaderboard-test/student-2").get());
  await assertFails(learner.doc("iya-leaderboard-test/student-1").set({ alias: "Yo", total: 99999 }));
  await assertFails(learner.doc("iya-leaderboard-test/student-2").update({ total: 0 }));
  await assertFails(learner.doc("iya-aliases-test/buho_2").get());
  await assertFails(learner.doc("iya-aliases-test/nuevo").set({ uid: "student-1" }));
  // The choice is owner-read; only the server (and the admin) change it.
  await assertSucceeds(learner.doc("iya-profile-test/student-1/ranking/current").get());
  await assertFails(learner.doc("iya-profile-test/student-1/ranking/current").set({ alias: "Otro", visible: true }));
  await assertFails(firestoreFor("student-2").doc("iya-profile-test/student-1/ranking/current").get());
  await assertSucceeds(admin.doc("iya-leaderboard-test/student-2").update({ total: 450 }));
  await assertSucceeds(admin.doc("iya-profile-test/student-1/ranking/current").update({ alias: null, visible: false }));
  await assertSucceeds(admin.doc("iya-aliases-test/buho_2").delete());
  await assertSucceeds(admin.doc("iya-leaderboard-test/student-2").delete());
});

test("league seats and challenge results are public; groups and challenges are server-only", async () => {
  const learner = firestoreFor("student-1");
  const admin = firestoreFor("admin-1", true);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("iya-league-members-test/2026-10-12_student-2").set({ alias: "Puma_1", weekXp: 40, groupId: "g1" });
    await db.doc("iya-challenge-entries-test/2026-10-16_student-2").set({ alias: "Puma_1", correct: 7 });
    await db.doc("iya-league-groups-test/2026-10-12_0_1").set({ size: 1 });
    await db.doc("iya-daily-challenges-test/2026-10-16_u1").set({ questionIds: ["q1"] });
  });
  await assertSucceeds(learner.doc("iya-league-members-test/2026-10-12_student-2").get());
  await assertSucceeds(learner.collection("iya-challenge-entries-test").where("day", "==", "2026-10-16").get());
  await assertFails(firestoreFor().doc("iya-league-members-test/2026-10-12_student-2").get());
  await assertFails(learner.doc("iya-league-members-test/2026-10-12_student-1").set({ weekXp: 9999 }));
  await assertFails(learner.doc("iya-challenge-entries-test/2026-10-16_student-1").set({ correct: 10 }));
  await assertFails(learner.doc("iya-league-groups-test/2026-10-12_0_1").get());
  await assertFails(learner.doc("iya-daily-challenges-test/2026-10-16_u1").get());
  await assertSucceeds(admin.doc("iya-daily-challenges-test/2026-10-16_u1").get());
  await assertSucceeds(admin.doc("iya-daily-challenges-test/2026-10-16_u1").update({ questionIds: ["q2"] }));
  await assertFails(admin.doc("iya-league-groups-test/2026-10-12_0_1").update({ size: 9 }));
});

test("admin claim can administer the bank while answer keys remain student-private", async () => {
  const admin = firestoreFor("editor-1", true);
  const learner = firestoreFor("student-1");

  await assertSucceeds(
    admin.doc("iya-questions-test/admin-draft").set({
      questionId: "admin-draft",
      version: 1,
      status: "draft"
    })
  );
  await assertSucceeds(
    admin.doc("iya-exam-templates-test/template-1").set({
      id: "template-1",
      status: "published",
      active: true
    })
  );
  await assertSucceeds(
    admin.doc("iya-question-answer-keys-test/published_1").get()
  );
  await assertFails(
    learner.doc("iya-exam-templates-test/template-1").get()
  );
  await assertFails(
    learner.doc("iya-question-answer-keys-test/published_1").get()
  );
});

test("Storage permits only valid admin uploads and authenticated public reads", async () => {
  const suffix = `${Date.now()}-${Math.floor(Math.random() * 1_000_000)}`;
  const adminStorage = storageFor("editor-1", true);
  const learnerStorage = storageFor("student-1");
  const anonymousStorage = storageFor();
  const imagePath = `question-public/rules/${suffix}.png`;
  const privatePath = `question-editor/${suffix}.png`;
  const pngBytes = new Uint8Array([137, 80, 78, 71]);

  await assertSucceeds(
    adminStorage.ref(imagePath).put(pngBytes, { contentType: "image/png" }).then(() => undefined)
  );
  await assertSucceeds(learnerStorage.ref(imagePath).getDownloadURL());
  await assertFails(anonymousStorage.ref(imagePath).getDownloadURL());
  await assertFails(
    learnerStorage.ref(`question-public/rules/${suffix}-student.png`).put(pngBytes, {
      contentType: "image/png"
    }).then(() => undefined)
  );
  await assertFails(
    adminStorage.ref(`question-public/rules/${suffix}.txt`).put(pngBytes, {
      contentType: "text/plain"
    }).then(() => undefined)
  );
  await assertSucceeds(
    adminStorage.ref(privatePath).put(pngBytes, { contentType: "image/png" }).then(() => undefined)
  );
  await assertFails(learnerStorage.ref(privatePath).getDownloadURL());
});

test("an editor works on drafts but cannot publish, retire or delete", async () => {
  const editor = staffFor("editor-2", EDITOR);
  await assertSucceeds(editor.doc("iya-questions-test/new-draft").set({
    questionId: "new-draft", version: 1, status: "draft", courseId: "course-1"
  }));
  await assertSucceeds(editor.doc("iya-questions-test/draft").update({
    review: { status: "pending", requestedBy: "editor-2" }
  }));
  await assertFails(editor.doc("iya-questions-test/draft").update({ status: "published" }));
  await assertFails(editor.doc("iya-questions-test/published").update({ status: "draft", version: 2 }));
  await assertFails(editor.doc("iya-questions-test/draft/versions/1").set({ status: "published" }));
  await assertFails(editor.doc("iya-questions-test/draft").delete());
  await assertSucceeds(editor.doc("iya-questions-test/published").get());
  await assertSucceeds(editor.doc("iya-courses-test/course-1").update({ name: "Física" }));
  await assertFails(editor.doc("iya-config-test/xp").set({ dailyCap: 1 }));
  await assertSucceeds(editor.doc("iya-config-test/xp").get());
  await assertFails(editor.doc("iya-profile-test/student-1").get());
});

test("a reviewer publishes; only archive permission retires or deletes", async () => {
  const reviewer = staffFor("reviewer-1", REVIEWER);
  await assertSucceeds(reviewer.doc("iya-questions-test/draft").update({ status: "published" }));
  await assertSucceeds(reviewer.doc("iya-questions-test/draft/versions/1").set({ status: "published" }));
  await assertFails(reviewer.doc("iya-questions-test/published").update({ status: "retired" }));
  const owner = staffFor("owner-1", { role: "owner", p: {} });
  await assertSucceeds(owner.doc("iya-questions-test/published").update({ status: "retired" }));
});

test("course scope limits which courses and questions an editor can change", async () => {
  const scoped = staffFor("editor-3", { ...EDITOR, cs: ["course-1"] });
  await assertSucceeds(scoped.doc("iya-courses-test/course-1/topics/t1").set({ name: "Cinemática" }));
  await assertFails(scoped.doc("iya-courses-test/course-2").set({ name: "Química" }));
  await assertSucceeds(scoped.doc("iya-questions-test/q-in").set({
    questionId: "q-in", version: 1, status: "draft", courseId: "course-1"
  }));
  await assertFails(scoped.doc("iya-questions-test/q-out").set({
    questionId: "q-out", version: 1, status: "draft", courseId: "course-2"
  }));
});

test("support sees students and fixes XP but cannot edit content", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("iya-profile-test/student-1/xp/current").set({ total: 10 });
  });
  const support = staffFor("support-1", SUPPORT);
  await assertSucceeds(support.doc("iya-profile-test/student-1").get());
  await assertSucceeds(support.doc("iya-profile-test/student-1/xp/current").update({ total: 5 }));
  await assertFails(support.doc("iya-questions-test/draft").update({ review: null }));
  await assertFails(support.doc("iya-courses-test/course-1").update({ name: "X" }));
});

test("a legacy admin token without role still works as owner", async () => {
  const legacy = firestoreFor("admin-legacy", true);
  await assertSucceeds(legacy.doc("iya-config-test/xp").set({ dailyCap: 300 }));
  await assertSucceeds(legacy.doc("iya-questions-test/draft").update({ status: "published" }));
});

test("staff records are readable as described and written only by Functions", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("iya-admin-staff-test/editor-2").set({ roleId: "editor", status: "active" });
    await db.doc("iya-admin-staff-test/owner-1").set({ roleId: "owner", status: "active" });
    await db.doc("iya-admin-roles-test/editor").set({ name: "Editor de contenido" });
  });
  const editor = staffFor("editor-2", EDITOR);
  const owner = staffFor("owner-1", { role: "owner", p: {} });
  await assertSucceeds(editor.doc("iya-admin-staff-test/editor-2").get());
  await assertFails(editor.doc("iya-admin-staff-test/owner-1").get());
  await assertSucceeds(editor.doc("iya-admin-roles-test/editor").get());
  await assertSucceeds(owner.collection("iya-admin-staff-test").get());
  await assertFails(owner.doc("iya-admin-staff-test/editor-2").update({ roleId: "owner" }));
  await assertFails(editor.doc("iya-admin-staff-test/editor-2").update({ roleId: "owner" }));
  await assertFails(firestoreFor("student-1").doc("iya-admin-roles-test/editor").get());
});

test("the change history is read with history:v and written only by the server", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("iya-admin-audit-test/e1").set({ kind: "update" });
  });
  await assertSucceeds(staffFor("editor-2", EDITOR).doc("iya-admin-audit-test/e1").get());
  await assertFails(staffFor("x", { role: "custom", p: { questions: "v" } }).doc("iya-admin-audit-test/e1").get());
  await assertFails(firestoreFor("student-1").doc("iya-admin-audit-test/e1").get());
  await assertFails(firestoreFor("admin-1", true).doc("iya-admin-audit-test/e2").set({ kind: "fake" }));
});

test("support reads a student's study data; question stats only mark review", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("iya-profile-test/student-1/simulatorResults/r1").set({ percent: 40 });
    await db.doc("iya-profile-test/student-1/learningProgress/current").set({ partProgress: {} });
    await db.doc("iya-question-stats-test/q1_1").set({ answered: 30, correct: 2 });
  });
  const support = staffFor("support-1", SUPPORT);
  await assertSucceeds(support.doc("iya-profile-test/student-1/simulatorResults/r1").get());
  await assertSucceeds(support.doc("iya-profile-test/student-1/learningProgress/current").get());
  await assertFails(staffFor("editor-2", EDITOR).doc("iya-profile-test/student-1/simulatorResults/r1").get());
  const editor = staffFor("editor-2", EDITOR);
  await assertSucceeds(editor.doc("iya-question-stats-test/q1_1").get());
  await assertSucceeds(editor.doc("iya-question-stats-test/q1_1").update({ review: { ok: true } }));
  await assertFails(editor.doc("iya-question-stats-test/q1_1").update({ answered: 999 }));
  await assertFails(support.doc("iya-question-stats-test/q1_1").update({ review: { ok: true } }));
});

test("students read only published news; publishing needs news:p and pushSentAt is server-only", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("iya-news-test/live").set({ status: "published", title: "Aviso", pushSentAt: null });
    await db.doc("iya-news-test/draft").set({ status: "draft", title: "Borrador" });
  });
  const student = firestoreFor("student-1");
  await assertSucceeds(student.doc("iya-news-test/live").get());
  await assertFails(student.doc("iya-news-test/draft").get());
  await assertSucceeds(student.collection("iya-news-test").where("status", "==", "published").get());
  await assertFails(student.collection("iya-news-test").get());
  await assertFails(student.doc("iya-news-test/mine").set({ status: "draft" }));

  const editor = staffFor("editor-2", EDITOR);
  await assertSucceeds(editor.doc("iya-news-test/draft").get());
  await assertSucceeds(editor.doc("iya-news-test/new").set({ status: "draft", title: "Nuevo" }));
  await assertFails(editor.doc("iya-news-test/draft").update({ status: "published" }));
  await assertFails(editor.doc("iya-news-test/live").update({ title: "Cambio" }));
  await assertFails(editor.doc("iya-news-test/draft").delete());

  const reviewer = staffFor("reviewer-1", REVIEWER);
  await assertSucceeds(reviewer.doc("iya-news-test/draft").update({ status: "published" }));
  await assertSucceeds(reviewer.doc("iya-news-test/live").update({ title: "Cambio" }));
  await assertFails(reviewer.doc("iya-news-test/live").update({ pushSentAt: new Date() }));
  await assertFails(reviewer.doc("iya-news-test/live").delete());
  // «draft» ya la publicó el revisor; «new» sigue en borrador.
  await assertFails(staffFor("support-1", SUPPORT).doc("iya-news-test/new").get());
});

test("news images: admins upload small images, students read them", async () => {
  const image = new Uint8Array([137, 80, 78, 71]);
  const path = `news-public/${Date.now()}.png`;
  await assertSucceeds(
    storageFor("admin-1", true).ref(path).put(image, { contentType: "image/png" }).then(() => undefined)
  );
  await assertSucceeds(storageFor("student-1").ref(path).getDownloadURL());
  await assertFails(
    storageFor("student-1").ref(`${path}.2.png`).put(image, { contentType: "image/png" }).then(() => undefined)
  );
  await assertFails(
    storageFor("admin-1", true).ref("news-public/c.pdf").put(image, { contentType: "application/pdf" }).then(() => undefined)
  );
});

test("rule test environment is initialized", () => {
  assert.ok(testEnv);
});
