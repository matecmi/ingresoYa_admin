import assert from "node:assert/strict";
import test from "node:test";

import { db } from "../src/admin";
import { readBackendConfig } from "../src/config";
import { ExamBackendError } from "../src/errors";
import { RankingService } from "../src/ranking";
import { defaultXpSettings, XpService } from "../src/xp";

const config = readBackendConfig({ INGRESOYA_ENV: "test" });
const ranking = new RankingService(db, config);
const xp = new XpService(db, config);
const settings = defaultXpSettings;
const users = db.collection(config.collections.users);
const leaderboard = db.collection(config.collections.leaderboard);
const aliases = db.collection(config.collections.aliases);

async function student(uid: string, name: string, email: string): Promise<void> {
  await users.doc(uid).set({
    profile: { universityIdDoc: "uni-1", universityAcronym: "UNPRG", professionId: "civil", professionName: "INGENIERIA CIVIL", userName: name, email }
  });
}

function hasReason(code: ExamBackendError["code"], reason: string) {
  return (error: unknown): boolean =>
    error instanceof ExamBackendError && error.code === code && error.details?.reason === reason;
}

test("a student picks an alias, appears in the top 100 with their XP and can leave it", async () => {
  const uid = "rank-student-1";
  await student(uid, "Ana Torres", "ana.torres@example.com");
  await xp.grant(uid, () => [{ id: "part_passed_p1", type: "part_passed", xp: 40, atMs: Date.now(), source: {} }]);

  // Hidden by default: XP never creates the public entry on its own.
  assert.equal((await leaderboard.doc(uid).get()).exists, false);
  await assert.rejects(ranking.update(uid, { visible: true }, settings), hasReason("failed-precondition", "alias_required"));
  await assert.rejects(ranking.update(uid, { visible: true, alias: "Ana_Torres" }, settings), hasReason("failed-precondition", "alias_personal"));
  await assert.rejects(ranking.update(uid, { visible: true, alias: "Puto_1" }, settings), hasReason("failed-precondition", "alias_banned"));

  assert.deepEqual(await ranking.update(uid, { visible: true, alias: "Búho_Civil_27" }, settings), { alias: "Búho_Civil_27", visible: true });
  const entry = (await leaderboard.doc(uid).get()).data();
  assert.equal(entry?.alias, "Búho_Civil_27");
  assert.equal(entry?.total, 40);
  assert.equal(entry?.universityId, "uni-1");
  assert.equal(entry?.professionName, "INGENIERIA CIVIL");
  assert.equal(JSON.stringify(entry).includes("Ana"), false);
  assert.equal((await aliases.doc("buho_civil_27").get()).data()?.uid, uid);

  // New XP keeps the entry in step, in the same transaction.
  await xp.grant(uid, () => [{ id: "subtopic_completed_s1", type: "subtopic_completed", xp: 80, atMs: Date.now(), source: {} }]);
  assert.equal((await leaderboard.doc(uid).get()).data()?.total, 120);

  // Another student cannot take the alias, not even with other accents or case.
  const other = "rank-student-2";
  await student(other, "Luis", "luis@example.com");
  await assert.rejects(ranking.update(other, { visible: true, alias: "buho_civil_27" }, settings), hasReason("already-exists", "alias_taken"));

  // Renaming frees the old alias; hiding removes the entry but keeps the alias.
  await ranking.update(uid, { visible: true, alias: "Cóndor_9" }, settings);
  assert.equal((await aliases.doc("buho_civil_27").get()).exists, false);
  assert.equal((await leaderboard.doc(uid).get()).data()?.alias, "Cóndor_9");
  assert.deepEqual(await ranking.update(uid, { visible: false }, settings), { alias: "Cóndor_9", visible: false });
  assert.equal((await leaderboard.doc(uid).get()).exists, false);
  await xp.grant(uid, () => [{ id: "part_passed_p2", type: "part_passed", xp: 40, atMs: Date.now(), source: {} }]);
  assert.equal((await leaderboard.doc(uid).get()).exists, false);
  assert.equal((await users.doc(uid).collection("ranking").doc("current").get()).data()?.alias, "Cóndor_9");

  // The freed alias can now be used by someone else.
  await ranking.update(other, { visible: true, alias: "Búho_Civil_27" }, settings);
  assert.equal((await leaderboard.doc(other).get()).data()?.total, 0);
});
