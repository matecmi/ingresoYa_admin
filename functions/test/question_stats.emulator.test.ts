import assert from "node:assert/strict";
import test from "node:test";

import { Timestamp } from "firebase-admin/firestore";

import { db } from "../src/admin";
import { readBackendConfig } from "../src/config";
import { QuestionStatsService } from "../src/question_stats";

const config = readBackendConfig({ INGRESOYA_ENV: "test" });

test("las estadísticas se acumulan sin contar dos veces el mismo intento", async () => {
  const attempts = db.collection(config.collections.attempts);
  await db.collection(config.collections.answerKeys).doc("qs1_1").set({ correctAlternativeId: "c" });
  const question = { questionId: "qs1", version: 1, alternatives: [{ id: "a", label: "A" }, { id: "c", label: "C" }] };
  for (let i = 0; i < 5; i++) {
    await attempts.doc(`qs-att-${i}`).set({
      status: "submitted",
      submittedAt: Timestamp.fromMillis(1_000_000 + i),
      questions: [question],
      answers: { qs1: i < 4 ? "a" : "c" }
    });
  }
  const service = new QuestionStatsService(db, config);
  const first = await service.refresh();
  assert.equal(first.attempts, 5);
  const again = await service.refresh();
  assert.equal(again.attempts, 0);
  const stats = (await db.collection(config.collections.questionStats).doc("qs1_1").get()).data()!;
  assert.equal(stats.answered, 5);
  assert.equal(stats.correct, 1);
  assert.deepEqual(stats.byAlternative, { a: 4, c: 1 });

  await attempts.doc("qs-att-new").set({
    status: "submitted", submittedAt: Timestamp.fromMillis(2_000_000), questions: [question], answers: { qs1: "c" }
  });
  assert.equal((await service.refresh()).attempts, 1);
  const after = (await db.collection(config.collections.questionStats).doc("qs1_1").get()).data()!;
  assert.equal(after.answered, 6);
  assert.equal(after.correct, 2);
});
