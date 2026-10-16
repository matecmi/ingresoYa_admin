import assert from "node:assert/strict";
import test from "node:test";

import type { CandidateQuestion } from "../src/exam_contracts";
import {
  defaultRankingsSettings,
  foldAlias,
  leaderboardEntry,
  leagueRuns,
  parseRankingChoice,
  parseRankingsSettings,
  profileFacts,
  suggestAlias
} from "../src/leaderboard";
import { groupFamily, movesFor, orderGroup } from "../src/league";
import { aliasProblem, parseUpdateRankingProfile, personalTokens } from "../src/ranking";
import { challengeLocked, challengeOwnPick } from "../src/simulator_service";
import { emptyXpState } from "../src/xp";

const settings = defaultRankingsSettings;

test("aliases fold accents and case", () => {
  assert.equal(foldAlias("Búho_Veloz"), "buho_veloz");
  assert.equal(foldAlias("  ÑANDÚ "), "nandu");
});

test("alias rules: length, characters, offensive words and own name", () => {
  const personal = personalTokens("Fútbol En Vivo Mas", "futbolenvivomas@gmail.com");
  assert.deepEqual(personal, ["futbol", "vivo", "futbolenvivomas"]);
  assert.equal(aliasProblem("Búho_Sistemas_27", [], personal), undefined);
  assert.equal(aliasProblem("ab", [], personal), "length");
  assert.equal(aliasProblem("Búho Veloz", [], personal), "characters");
  assert.equal(aliasProblem("12345", [], personal), "characters");
  assert.equal(aliasProblem("Puto_Amo", [], personal), "banned");
  assert.equal(aliasProblem("Rey_del_Cálculo", [], personal), undefined);
  assert.equal(aliasProblem("Futbolero_9", [], personal), "personal");
  assert.equal(aliasProblem("Lince_Andino", ["andino"], personal), "banned");
});

test("random usernames use an animal, the career and a number, and pass the rules", () => {
  let seed = 0.37;
  const random = () => (seed = (seed * 9301 + 0.49297) % 1);
  for (let i = 0; i < 50; i++) {
    const alias = suggestAlias(random, "INGENIERIA DE SISTEMAS");
    assert.match(alias, /^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+_Sistemas_\d{2}$/);
    assert.equal(aliasProblem(alias, [], []), undefined, alias);
  }
  assert.match(suggestAlias(() => 0.1), /_Ingreso_/);
});

test("rankings settings: off by default, field by field fallback", () => {
  assert.equal(settings.enabled, false);
  assert.deepEqual(settings.league.stageNames, ["Aspirante", "Postulante", "Finalista", "Ingresante"]);
  const custom = parseRankingsSettings({
    enabled: true,
    startWeek: "2026-10-19",
    bannedWords: ["Tonto", 3],
    league: { groupSize: 2, promotePercent: 20, stageNames: ["Uno"] },
    challenge: { questionCount: 8, ownPastExamQuestions: 12, bonusXp: -1 }
  });
  assert.equal(custom.enabled, true);
  assert.deepEqual(custom.bannedWords, ["tonto"]);
  assert.equal(custom.league.groupSize, 30);
  assert.equal(custom.league.promotePercent, 20);
  assert.equal(custom.league.stageNames.length, 4);
  assert.equal(custom.challenge.questionCount, 8);
  assert.equal(custom.challenge.ownPastExamQuestions, 8);
  assert.equal(custom.challenge.bonusXp, 20);
  assert.equal(leagueRuns(custom, "2026-10-12"), false);
  assert.equal(leagueRuns(custom, "2026-10-19"), true);
  assert.equal(leagueRuns(settings, "2026-10-19"), false);
});

test("the choice keeps username, hidden, stage and last result", () => {
  const choice = parseRankingChoice({ alias: "Puma_1", hidden: true, stage: 2, lastResult: { week: "2026-10-12", from: 1, to: 2, position: 3, size: 30 } });
  assert.equal(choice.hidden, true);
  assert.equal(choice.stage, 2);
  assert.equal(choice.lastResult?.to, 2);
  assert.equal(choice.lastResult?.seen, false);
  assert.equal(parseRankingChoice(undefined).alias, null);
});

test("the public card never has the name; hidden students show no username or badge", () => {
  const facts = profileFacts({ profile: { universityIdDoc: "u1", professionId: "p1", userName: "Ana", email: "ana@x.pe" } });
  const state = { ...emptyXpState(), total: 382, rankStep: 2, week: { key: "2026-10-12", xp: 120, sessionDays: [] } };
  const visible = leaderboardEntry(parseRankingChoice({ alias: "Búho_1" }), state, 0, facts);
  assert.equal(visible.alias, "Búho_1");
  assert.equal(visible.weekXp, 120);
  assert.equal(visible.rankStep, 2);
  assert.equal(JSON.stringify(visible).includes("ana@x.pe"), false);
  const hidden = leaderboardEntry(parseRankingChoice({ alias: "Búho_1", hidden: true }), state, 0, facts);
  assert.equal(hidden.alias, null);
  assert.equal(hidden.rankStep, null);
  assert.equal(hidden.hidden, true);
});

test("the callable accepts only alias and hidden", () => {
  assert.deepEqual(parseUpdateRankingProfile({ alias: " Búho_1 ", hidden: true }), { alias: "Búho_1", hidden: true });
  assert.deepEqual(parseUpdateRankingProfile(undefined), {});
  assert.throws(() => parseUpdateRankingProfile({ visible: true }));
  assert.throws(() => parseUpdateRankingProfile({ hidden: "yes" }));
});

test("league moves: proportional, never overlapping, none past the ends", () => {
  assert.deepEqual(movesFor(30, 1, settings), { up: 5, down: 5 });
  assert.deepEqual(movesFor(15, 1, settings), { up: 2, down: 2 });
  assert.deepEqual(movesFor(4, 1, settings), { up: 1, down: 0 });
  assert.deepEqual(movesFor(30, 0, settings), { up: 5, down: 0 });
  assert.deepEqual(movesFor(30, 3, settings), { up: 0, down: 5 });
  assert.deepEqual(movesFor(1, 1, settings), { up: 1, down: 0 });
  const ordered = orderGroup([
    { uid: "a", weekXp: 50, joinedAtMs: 3 },
    { uid: "b", weekXp: 90, joinedAtMs: 2 },
    { uid: "c", weekXp: 50, joinedAtMs: 1 }
  ]);
  assert.deepEqual(ordered.map((m) => m.uid), ["b", "c", "a"]);
  assert.equal(groupFamily("2026-10-12", 1, settings, "u1"), "2026-10-12_1");
  assert.equal(groupFamily("2026-10-12", 1, { ...settings, league: { ...settings.league, preferSameUniversity: true } }, "u1"), "2026-10-12_1_u1");
});

function question(id: string, courseId: string): CandidateQuestion {
  return {
    questionId: id, version: 1, randomKey: 0.5, sourceLabel: "", universityId: "u1", sourceType: "admission_exam",
    sourceExamId: "e1", modalityId: "", courseId, topicId: "", subtopicId: "", partIds: [], difficulty: "medium",
    content: [], alternatives: []
  };
}

test("the challenge takes own past-exam questions across courses, at least one", () => {
  const own = [question("a1", "A"), question("a2", "A"), question("a3", "A"), question("b1", "B")];
  const picked = challengeOwnPick(own, { ownPastExamQuestions: 2, questionCount: 10 }, "s");
  assert.equal(picked.length, 2);
  assert.deepEqual(new Set(picked.map((q) => q.courseId)), new Set(["A", "B"]));
  assert.equal(challengeOwnPick(own, { ownPastExamQuestions: 0, questionCount: 10 }, "s").length, 1);
  assert.equal(challengeOwnPick(own, { ownPastExamQuestions: 9, questionCount: 10 }, "s").length, 4);
  assert.deepEqual(challengeOwnPick([], { ownPastExamQuestions: 6, questionCount: 10 }, "s"), []);
});

test("a challenge's answers stay hidden until the next Peru day", () => {
  // 2026-10-16 23:00 in Lima = 2026-10-17 04:00 UTC.
  const sameDay = Date.UTC(2026, 9, 17, 4, 0);
  const nextDay = Date.UTC(2026, 9, 17, 5, 30);
  assert.equal(challengeLocked({ mode: "daily_challenge", day: "2026-10-16" }, sameDay), true);
  assert.equal(challengeLocked({ mode: "daily_challenge", day: "2026-10-16" }, nextDay), false);
  assert.equal(challengeLocked({ mode: "plan" }, sameDay), false);
});
