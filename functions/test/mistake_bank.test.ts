import assert from "node:assert/strict";
import test from "node:test";

import {
  applyGraded,
  defaultMistakeSettings,
  emptyMistakeBank,
  parseMistakeBank,
  parseMistakeSettings,
  pickFromBank,
  questionExcerpt,
  type GradedQuestion
} from "../src/mistake_bank";
import { parseCreateExamAttempt } from "../src/validation";
import { mistakeSourceOf } from "../src/simulator_service";

const q = (id: string, correct: boolean, extra: Partial<GradedQuestion> = {}): GradedQuestion => ({
  questionId: id,
  correct,
  blank: false,
  courseId: "ari",
  topicId: "fracciones",
  subtopicId: "s1",
  excerpt: `Pregunta ${id}`,
  ...extra
});

const day = "2026-10-29";
const now = Date.parse("2026-10-29T15:00:00Z");

test("settings parse field by field with factory values", () => {
  assert.deepEqual(parseMistakeSettings(undefined), defaultMistakeSettings);
  const parsed = parseMistakeSettings({ missionSize: 8, exitHits: 2, bankMax: 10, includeGuide: true, fixXp: "x" });
  assert.equal(parsed.missionSize, 8);
  assert.equal(parsed.exitHits, 2);
  assert.equal(parsed.bankMax, defaultMistakeSettings.bankMax, "bankMax below 50 is ignored");
  assert.equal(parsed.includeGuide, true);
  assert.equal(parsed.fixXp, defaultMistakeSettings.fixXp);
});

test("wrong and blank questions enter; a correct one leaves and counts for the mission", () => {
  const first = applyGraded(emptyMistakeBank(), [q("a", false), q("b", false, { blank: true }), q("c", true)],
    defaultMistakeSettings, { now, day, where: "practice" });
  assert.equal(first.added, 2);
  assert.equal(first.fixed, 0);
  assert.deepEqual(Object.keys(first.bank.items).sort(), ["a", "b"]);
  assert.equal(first.bank.items.b!.b, true);

  const again = applyGraded(first.bank, [q("a", false), q("b", true)], defaultMistakeSettings,
    { now: now + 1000, day, where: "mistakes" });
  assert.equal(again.bank.items.a!.n, 2, "failed twice");
  assert.equal(again.bank.items.b, undefined);
  assert.equal(again.fixed, 1);
  assert.equal(again.bank.fixed[0]!.q, "b");
  assert.equal(again.bank.fixed[0]!.w, "mistakes");
  assert.equal(again.bank.mission.done, 1);
  assert.equal(again.fixXp, defaultMistakeSettings.fixXp);
});

test("the mission completes once, grows the streak and the fix XP has a daily cap", () => {
  const settings = { ...defaultMistakeSettings, missionSize: 2, fixXp: 10, fixXpDailyCap: 15 };
  let bank = applyGraded(emptyMistakeBank(), [q("a", false), q("b", false), q("c", false)], settings,
    { now, day: "2026-10-28", where: "practice" }).bank;
  bank = { ...bank, streak: { day: "2026-10-28", days: 3 } };
  const done = applyGraded(bank, [q("a", true), q("b", true)], settings, { now, day, where: "mistakes" });
  assert.equal(done.missionCompleted, true);
  assert.deepEqual(done.bank.streak, { day, days: 4 });
  assert.equal(done.fixXp, 15, "two fixes worth 20, capped at 15");
  const more = applyGraded(done.bank, [q("c", true)], settings, { now, day, where: "mistakes" });
  assert.equal(more.missionCompleted, false, "only once a day");
  assert.equal(more.fixXp, 0, "the daily cap is spent");
  assert.equal(more.bank.mission.done, 3);
});

test("a missed day restarts the streak; a new day restarts the mission", () => {
  const settings = { ...defaultMistakeSettings, missionSize: 1 };
  const base = { ...applyGraded(emptyMistakeBank(), [q("a", false)], settings, { now, day: "2026-10-20", where: "practice" }).bank,
    streak: { day: "2026-10-25", days: 5 }, mission: { day: "2026-10-25", done: 9, completed: true } };
  const update = applyGraded(base, [q("a", true)], settings, { now, day, where: "mistakes" });
  assert.equal(update.missionCompleted, true);
  assert.deepEqual(update.bank.streak, { day, days: 1 });
  assert.deepEqual(update.bank.mission, { day, done: 1, completed: true });
});

test("two hits to leave when the admin asks for it", () => {
  const settings = { ...defaultMistakeSettings, exitHits: 2 };
  const bank = applyGraded(emptyMistakeBank(), [q("a", false)], settings, { now, day, where: "practice" }).bank;
  const once = applyGraded(bank, [q("a", true)], settings, { now, day, where: "mistakes" });
  assert.equal(once.fixed, 0);
  assert.equal(once.bank.items.a!.h, 1);
  const twice = applyGraded(once.bank, [q("a", true)], settings, { now, day, where: "mistakes" });
  assert.equal(twice.fixed, 1);
  const relapse = applyGraded(once.bank, [q("a", false)], settings, { now, day, where: "practice" });
  assert.equal(relapse.bank.items.a!.h, 0, "a new miss resets the hits");
});

test("the bank keeps the newest misses up to its cap", () => {
  const settings = { ...defaultMistakeSettings, bankMax: 50 };
  const graded = Array.from({ length: 60 }, (_, i) => q(`q${i}`, false));
  let bank = emptyMistakeBank();
  graded.forEach((item, i) => {
    bank = applyGraded(bank, [item], settings, { now: now + i, day, where: "practice" }).bank;
  });
  assert.equal(Object.keys(bank.items).length, 50);
  assert.equal(bank.items.q0, undefined);
  assert.notEqual(bank.items.q59, undefined);
});

test("today's challenge mistakes wait until tomorrow", () => {
  const bank = applyGraded(emptyMistakeBank(), [q("a", false), q("b", false)], defaultMistakeSettings,
    { now, day, where: "challenge", holdUntil: "2026-10-30" }).bank;
  assert.deepEqual(pickFromBank(bank, day, { count: 10, order: "most_missed" }), []);
  assert.equal(pickFromBank(bank, "2026-10-30", { count: 10, order: "most_missed" }).length, 2);
});

test("picking: most missed first, by course or topic, up to the count", () => {
  let bank = emptyMistakeBank();
  bank = applyGraded(bank, [q("a", false), q("b", false), q("g", false, { courseId: "geo", topicId: "relieve" })],
    defaultMistakeSettings, { now, day, where: "practice" }).bank;
  bank = applyGraded(bank, [q("b", false)], defaultMistakeSettings, { now: now + 5, day, where: "practice" }).bank;
  const top = pickFromBank(bank, day, { count: 2, order: "most_missed" });
  assert.equal(top.length, 2);
  assert.equal(top[0], "b", "failed twice goes first");
  assert.deepEqual(pickFromBank(bank, day, { count: 5, courseId: "geo", order: "most_missed" }), ["g"]);
  assert.deepEqual(pickFromBank(bank, day, { count: 5, topicId: "fracciones", order: "most_missed" }).sort(), ["a", "b"]);
});

test("the stored bank parses back to the same thing", () => {
  const bank = applyGraded(emptyMistakeBank(), [q("a", false)], defaultMistakeSettings, { now, day, where: "practice" }).bank;
  assert.deepEqual(parseMistakeBank(JSON.parse(JSON.stringify(bank))), bank);
  assert.deepEqual(parseMistakeBank("nope"), emptyMistakeBank());
});

test("excerpt: text and formulas, never a half formula", () => {
  assert.equal(questionExcerpt([
    { type: "text", text: "Si  3/4 de un número" },
    { type: "paragraph", spans: [{ type: "text", text: "es " }, { type: "formula", latex: "36" }] },
    { type: "image", storagePath: "x" }
  ]), "Si 3/4 de un número es $36$");
  const long = questionExcerpt([{ type: "text", text: `${"a".repeat(130)} $\\frac{1}{2}$ fin` }], 140);
  assert.ok(long.endsWith("…"));
  assert.equal((long.match(/\$/g) ?? []).length % 2, 0);
});

test("the bank practice request is validated", () => {
  assert.deepEqual(parseCreateExamAttempt({
    requestId: "r1", purpose: "practice", mode: "mistake_bank", count: 3, courseId: "ari", order: "most_missed", timed: false
  }), { requestId: "r1", purpose: "practice", mode: "mistake_bank", count: 3, courseId: "ari", order: "most_missed", timed: false });
  assert.throws(() => parseCreateExamAttempt({
    requestId: "r1", purpose: "practice", mode: "mistake_bank", count: 0, order: "most_missed", timed: false
  }));
  assert.throws(() => parseCreateExamAttempt({
    requestId: "r1", purpose: "practice", mode: "mistake_bank", count: 3, order: "random", timed: false
  }));
});

test("where a fix happened", () => {
  assert.equal(mistakeSourceOf("practice", "mistake_bank"), "mistakes");
  assert.equal(mistakeSourceOf("practice", "plan"), "daily");
  assert.equal(mistakeSourceOf("past_exam", undefined), "past_exam");
});
