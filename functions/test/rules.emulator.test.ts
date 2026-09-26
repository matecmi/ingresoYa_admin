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

function storageFor(uid?: string, admin = false) {
  const context = uid === undefined
    ? testEnv.unauthenticatedContext()
    : testEnv.authenticatedContext(uid, admin ? { admin: true } : {});
  return context.storage();
}

before(async () => {
  const root = join(process.cwd(), "..");
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: await readFile(join(root, "firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080
    },
    storage: {
      rules: await readFile(join(root, "storage.rules"), "utf8"),
      host: "127.0.0.1",
      port: 9199
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

test("rule test environment is initialized", () => {
  assert.ok(testEnv);
});
