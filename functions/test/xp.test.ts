import assert from "node:assert/strict";
import test from "node:test";

import {
  applyXpGrants,
  defaultXpSettings,
  emptyXpState,
  guideGrants,
  parseRanks,
  parseXpSettings,
  peruDay,
  peruWeek,
  rankStepFor,
  simulatorGrants,
  starsFor,
  type SimulatorXpInput
} from "../src/xp";

const settings = defaultXpSettings;
// Wednesday 2026-10-14 15:00 in Lima (20:00 UTC).
const wednesday = Date.UTC(2026, 9, 14, 20, 0, 0);
const hour = 60 * 60 * 1000;

test("the Peru day and week start at midnight Lima time", () => {
  assert.equal(peruDay(Date.UTC(2026, 9, 15, 4, 59)), "2026-10-14");
  assert.equal(peruDay(Date.UTC(2026, 9, 15, 5, 0)), "2026-10-15");
  assert.equal(peruWeek(wednesday), "2026-10-12");
  assert.equal(peruWeek(Date.UTC(2026, 9, 19, 4, 0)), "2026-10-12"); // Sunday night
  assert.equal(peruWeek(Date.UTC(2026, 9, 19, 6, 0)), "2026-10-19"); // Monday
});

test("ranks come from the ladder; stars after the last one", () => {
  assert.equal(rankStepFor(0, settings.ranks), 0);
  assert.equal(rankStepFor(149, settings.ranks), 0);
  assert.equal(rankStepFor(150, settings.ranks), 1);
  assert.equal(rankStepFor(3450, settings.ranks), 9); // Zafiro I
  assert.equal(settings.ranks[9]?.name, "Zafiro I");
  assert.equal(rankStepFor(50000, settings.ranks), 17);
  assert.equal(starsFor(11999, settings), 0);
  assert.equal(starsFor(14000, settings), 1);
  assert.equal(starsFor(36000, settings), 12);
  assert.equal(starsFor(36000, { ...settings, starsEnabled: false }), 0);
});

test("invalid settings fall back to the factory values", () => {
  assert.equal(parseRanks([{ name: "A", minXp: 10, image: "bronze_1" }]), settings.ranks); // must start at 0
  assert.equal(parseRanks([{ name: "A", minXp: 0, image: "bronze_1" }, { name: "B", minXp: 0, image: "silver_1" }]), settings.ranks);
  assert.equal(parseRanks([{ name: "A", minXp: 0, image: "gold_1" }]), settings.ranks);
  const custom = parseXpSettings({ dailyCap: 100, amounts: { partPassed: 0, diagnostic: -5 }, ranks: [{ name: "Uno", minXp: 0, image: "bronze_1" }, { name: "Dos", minXp: 50, image: "master_12" }] });
  assert.equal(custom.dailyCap, 100);
  assert.equal(custom.amounts.partPassed, 0);
  assert.equal(custom.amounts.diagnostic, 30);
  assert.equal(custom.ranks.length, 2);
});

test("the daily cap limits only repeatable events and resets the next Peru day", () => {
  const capped = { ...settings, dailyCap: 25 };
  const grants = [
    { id: "session_a", type: "simulator_session" as const, xp: 10, atMs: wednesday, source: {} },
    { id: "correct_a", type: "correct_answers" as const, xp: 20, count: 20, atMs: wednesday, source: {} },
    { id: "part_passed_p1", type: "part_passed" as const, xp: 40, atMs: wednesday, source: {} },
    { id: "session_b", type: "simulator_session" as const, xp: 10, atMs: wednesday + 12 * hour, source: {} }
  ];
  const { state, applied } = applyXpGrants(emptyXpState(), grants, capped);
  assert.deepEqual(applied.map((event) => event.xp), [10, 15, 40, 10]);
  assert.equal(applied[1]?.requested, 20);
  assert.equal(state.total, 75);
  assert.equal(state.today.day, "2026-10-15");
  assert.equal(state.today.capped, 10);
  assert.equal(state.week.xp, 75);
  assert.equal(state.week.sessionDays.length, 2);
});

test("the rank never goes down, even if thresholds rise", () => {
  const { state } = applyXpGrants(emptyXpState(), [{ id: "x", type: "subtopic_mastered", xp: 700, atMs: wednesday, source: {} }], settings);
  assert.equal(state.rankStep, 3); // Plata I
  const harder = { ...settings, ranks: settings.ranks.map((rank, index) => ({ ...rank, minXp: index * 1000 })) };
  const after = applyXpGrants(state, [{ id: "y", type: "section_reviewed", xp: 2, atMs: wednesday, source: {} }], harder);
  assert.equal(after.state.rankStep, 3);
});

function simulator(overrides: Partial<SimulatorXpInput> = {}): SimulatorXpInput {
  return { attemptId: "att1", purpose: "practice", total: 20, freshCorrect: 14, score: 70, timeUsedSeconds: 600, atMs: wednesday, ...overrides };
}

test("a Simulator session gives session, answers, streak and weekly goal XP", () => {
  const state = { ...emptyXpState(), week: { key: "2026-10-12", xp: 0, sessionDays: ["2026-10-12", "2026-10-13"] } };
  const grants = simulatorGrants(simulator({ goalSessions: 3 }), state, settings);
  assert.deepEqual(grants.map((grant) => [grant.id, grant.xp]), [
    ["session_att1", 10],
    ["correct_att1", 14],
    ["streak_2026-10-14", 5],
    ["weekly_goal_2026-10-12", 50]
  ]);
  // Short sessions give only the answers; a rushed one gives nothing.
  assert.deepEqual(simulatorGrants(simulator({ total: 5, freshCorrect: 3 }), state, settings).map((grant) => grant.id), ["correct_att1"]);
  assert.deepEqual(simulatorGrants(simulator({ timeUsedSeconds: 60 }), state, settings), []);
});

test("diagnostic, past exam completion every 7 days and improvement", () => {
  assert.ok(simulatorGrants(simulator({ mode: "diagnostic" }), emptyXpState(), settings).some((grant) => grant.id === "diagnostic"));
  const past = simulator({ purpose: "past_exam", examId: "e1", score: 640, previousBestScore: 420 });
  const grants = simulatorGrants(past, emptyXpState(), settings);
  assert.deepEqual(grants.filter((grant) => grant.type.startsWith("past_exam")).map((grant) => [grant.id, grant.xp]), [
    ["past_exam_e1_2026-10-14", 50],
    ["improve_att1", 22]
  ]);
  const recent = { ...emptyXpState(), pastExamDays: { e1: "2026-10-10" } };
  assert.equal(simulatorGrants(past, recent, settings).some((grant) => grant.type === "past_exam_completed"), false);
  const huge = simulatorGrants(simulator({ purpose: "past_exam", examId: "e1", score: 1000, previousBestScore: 0 }), emptyXpState(), settings);
  assert.equal(huge.find((grant) => grant.type === "past_exam_improvement")?.xp, 50);
});

test("guide grants use fixed ids per section, part and subtopic", () => {
  const grants = guideGrants({ partId: "p1", sections: ["lesson", "video"], partPassed: true, subtopicId: "s1", subtopicCompleted: true, subtopicMastered: false, atMs: wednesday }, settings);
  assert.deepEqual(grants.map((grant) => [grant.id, grant.xp]), [
    ["section_p1_lesson", 2],
    ["section_p1_video", 2],
    ["part_passed_p1", 40],
    ["subtopic_completed_s1", 80]
  ]);
});
