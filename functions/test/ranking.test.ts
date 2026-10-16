import assert from "node:assert/strict";
import test from "node:test";

import { foldAlias, leaderboardEntry, parseLeaderboardSettings, profileFacts } from "../src/leaderboard";
import { aliasProblem, parseUpdateRankingProfile, personalTokens } from "../src/ranking";
import { emptyXpState, parseXpSettings } from "../src/xp";

test("aliases fold accents and case", () => {
  assert.equal(foldAlias("Búho_Veloz"), "buho_veloz");
  assert.equal(foldAlias("  ÑANDÚ "), "nandu");
});

test("alias rules: length, characters, offensive words and own name", () => {
  const personal = personalTokens("Fútbol En Vivo Mas", "futbolenvivomas@gmail.com");
  assert.deepEqual(personal, ["futbol", "vivo", "futbolenvivomas"]);
  assert.equal(aliasProblem("Búho_Sistemas_27", [], personal), undefined);
  assert.equal(aliasProblem("Pitágoras_Lam", [], personal), undefined);
  assert.equal(aliasProblem("ab", [], personal), "length");
  assert.equal(aliasProblem("a".repeat(21), [], personal), "length");
  assert.equal(aliasProblem("Búho Veloz", [], personal), "characters");
  assert.equal(aliasProblem("correo@x", [], personal), "characters");
  assert.equal(aliasProblem("12345", [], personal), "characters");
  assert.equal(aliasProblem("Puto_Amo", [], personal), "banned");
  assert.equal(aliasProblem("ElImbecil", [], personal), "banned");
  // Short words count only as whole words: «Cálculo» is fine.
  assert.equal(aliasProblem("Rey_del_Cálculo", [], personal), undefined);
  assert.equal(aliasProblem("Gran_Culo", [], personal), "banned");
  assert.equal(aliasProblem("Futbolero_9", [], personal), "personal");
  assert.equal(aliasProblem("Lince_Andino", ["andino"], personal), "banned");
});

test("leaderboard settings fall back to the factory values", () => {
  assert.deepEqual(parseLeaderboardSettings(undefined), { enabled: true, size: 100, universityFilterMin: 50, bannedWords: [] });
  const custom = parseLeaderboardSettings({ enabled: false, size: 5, universityFilterMin: 3, bannedWords: ["Tonto", 3, "x"] });
  assert.deepEqual(custom, { enabled: false, size: 100, universityFilterMin: 3, bannedWords: ["tonto"] });
  assert.equal(parseXpSettings({ leaderboard: { size: 50 } }).leaderboard.size, 50);
});

test("the callable accepts only visible and alias", () => {
  assert.deepEqual(parseUpdateRankingProfile({ visible: true, alias: " Búho_1 " }), { visible: true, alias: "Búho_1" });
  assert.deepEqual(parseUpdateRankingProfile({ visible: false }), { visible: false });
  assert.throws(() => parseUpdateRankingProfile({ alias: "x" }));
  assert.throws(() => parseUpdateRankingProfile({ visible: true, uid: "other" }));
  assert.throws(() => parseUpdateRankingProfile({ visible: true, alias: 3 }));
});

test("the public entry has no name or email", () => {
  const facts = profileFacts({
    universityIdDoc: "root-uni",
    profile: { universityIdDoc: "u1", universityAcronym: "UNPRG", professionId: "p1", professionName: "INGENIERIA CIVIL", userName: "Ana", email: "ana@x.pe" }
  });
  assert.equal(facts.universityId, "u1");
  const entry = leaderboardEntry("Búho_1", { ...emptyXpState(), total: 382, rankStep: 2 }, 0, facts);
  assert.deepEqual(Object.keys(entry).sort(), [
    "alias", "professionId", "professionName", "rankStep", "schemaVersion", "stars", "total",
    "universityAcronym", "universityId", "updatedAtMs"
  ]);
  assert.equal(entry.total, 382);
  assert.equal(JSON.stringify(entry).includes("ana@x.pe"), false);
});
