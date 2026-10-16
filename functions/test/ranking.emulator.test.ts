import assert from "node:assert/strict";
import test from "node:test";

import { db } from "../src/admin";
import { readBackendConfig } from "../src/config";
import { ExamBackendError } from "../src/errors";
import { parseRankingsSettings } from "../src/leaderboard";
import { closeLeagueWeek } from "../src/league";
import { RankingService } from "../src/ranking";
import { defaultXpSettings, peruWeek, XpService } from "../src/xp";

const config = readBackendConfig({ INGRESOYA_ENV: "test" });
const xp = new XpService(db, config);
const users = db.collection(config.collections.users);
const leaderboard = db.collection(config.collections.leaderboard);
const aliases = db.collection(config.collections.aliases);
const members = db.collection(config.collections.leagueMembers);
const rankingsDoc = db.collection(config.collections.config).doc("rankings");
const off = parseRankingsSettings({});
const on = parseRankingsSettings({ enabled: true, startWeek: "2000-01-03", league: { groupSize: 5 } });

async function student(uid: string, name: string, email: string): Promise<void> {
  await users.doc(uid).set({
    profile: { universityIdDoc: "uni-1", universityAcronym: "UNPRG", professionId: "civil", professionName: "INGENIERIA CIVIL", userName: name, email }
  });
}

function hasReason(code: ExamBackendError["code"], reason: string) {
  return (error: unknown): boolean =>
    error instanceof ExamBackendError && error.code === code && error.details?.reason === reason;
}

test("every student gets a username: random when none, own when valid; hiding keeps playing", async () => {
  const ranking = new RankingService(db, config, () => 0.42);
  const uid = "rank-u1";
  await student(uid, "Ana Torres", "ana.torres@example.com");
  // No username yet: the server generates one with the career.
  const generated = await ranking.update(uid, {}, defaultXpSettings, off);
  assert.match(generated.alias, /_Civil_\d{2}$/);
  assert.equal(generated.hidden, false);
  assert.equal((await aliases.doc(generated.alias.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()).get()).data()?.uid, uid);
  // Its own choice replaces it; the name and offensive words are refused.
  await assert.rejects(ranking.update(uid, { alias: "Ana_Torres" }, defaultXpSettings, off), hasReason("failed-precondition", "alias_personal"));
  await assert.rejects(ranking.update(uid, { alias: "Tonto_1" }, defaultXpSettings, parseRankingsSettings({ bannedWords: ["tonto"] })),
    hasReason("failed-precondition", "alias_banned"));
  assert.deepEqual(await ranking.update(uid, { alias: "Cóndor_9" }, defaultXpSettings, off), { alias: "Cóndor_9", hidden: false });
  const card = (await leaderboard.doc(uid).get()).data();
  assert.equal(card?.alias, "Cóndor_9");
  assert.equal(card?.universityId, "uni-1");
  assert.equal(JSON.stringify(card).includes("Ana"), false);
  // «Ocultarme de los rankings»: the card keeps playing without username or badge.
  assert.deepEqual(await ranking.update(uid, { hidden: true }, defaultXpSettings, off), { alias: "Cóndor_9", hidden: true });
  const hiddenCard = (await leaderboard.doc(uid).get()).data();
  assert.equal(hiddenCard?.alias, null);
  assert.equal(hiddenCard?.rankStep, null);
  // Another student cannot take it.
  await student("rank-u2", "Luis", "luis@example.com");
  await assert.rejects(ranking.update("rank-u2", { alias: "condor_9" }, defaultXpSettings, off), hasReason("already-exists", "alias_taken"));
});

test("the league seats students by arrival in groups of their stage and closes the week", async () => {
  await rankingsDoc.set({ enabled: true, startWeek: "2000-01-03", league: { groupSize: 5 } });
  const ranking = new RankingService(db, config, Math.random);
  const week = peruWeek(Date.now());
  const ids = Array.from({ length: 7 }, (_, i) => `league-u${i}`);
  for (const [index, uid] of ids.entries()) {
    await student(uid, `Alumno ${index}`, `alumno${index}@example.com`);
    await members.doc(`${week}_${uid}`).delete();
    await ranking.update(uid, {}, defaultXpSettings, on);
  }
  // No XP, no seat.
  assert.equal((await members.doc(`${week}_${ids[0]}`).get()).exists, false);
  for (const [index, uid] of ids.entries()) {
    await xp.grant(uid, () => [{ id: `part_passed_league_${index}`, type: "part_passed", xp: 10 * (index + 1), atMs: Date.now(), source: {} }]);
  }
  const seats = await Promise.all(ids.map(async (uid) => (await members.doc(`${week}_${uid}`).get()).data()));
  // Five fill the first group; the next two open a second one.
  assert.equal(seats.filter((seat) => seat?.groupId === `${week}_0_1`).length, 5);
  assert.equal(seats.filter((seat) => seat?.groupId === `${week}_0_2`).length, 2);
  assert.equal(seats[6]?.weekXp, 70);
  // More XP in the same week keeps the seat and updates the points.
  await xp.grant(ids[0]!, () => [{ id: "part_passed_league_extra", type: "part_passed", xp: 100, atMs: Date.now(), source: {} }]);
  const first = (await members.doc(`${week}_${ids[0]}`).get()).data();
  assert.equal(first?.groupId, `${week}_0_1`);
  assert.equal(first?.weekXp, 110);
  assert.equal((await leaderboard.doc(ids[0]!).get()).data()?.weekXp, 110);

  // Close: group 1 (5 students, first stage) → the leader moves up, nobody down.
  const closed = await closeLeagueWeek(db, config, week, on);
  assert.equal(closed, 7);
  const choice = async (uid: string) => (await users.doc(uid).collection("ranking").doc("current").get()).data();
  assert.equal((await choice(ids[0]!))?.stage, 1);
  assert.equal((await choice(ids[0]!))?.lastResult?.position, 1);
  assert.equal((await choice(ids[1]!))?.stage, 0);
  // Closing twice does nothing.
  assert.equal(await closeLeagueWeek(db, config, week, on), 0);
  await rankingsDoc.delete();
});
