import assert from "node:assert/strict";
import test from "node:test";

import {
  BUILTIN_ROLES,
  claimsFor,
  mergePerms,
  normalizeLetters,
  normalizePerms,
  normalizeScope
} from "../src/staff";

test("las letras se normalizan y ver va implícito", () => {
  assert.equal(normalizeLetters("pe"), "vep");
  assert.equal(normalizeLetters("aaxv"), "va");
  assert.equal(normalizeLetters(""), "");
  assert.equal(normalizeLetters(3), "");
});

test("permisos desconocidos se rechazan", () => {
  assert.throws(() => normalizePerms({ hacking: "v" }), /Unknown section/);
  assert.deepEqual(normalizePerms({ questions: "e", courses: "" }), { questions: "ve" });
});

test("el alcance limita y depura ids", () => {
  assert.deepEqual(normalizeScope({ courseIds: [" a ", "a", "b"] }), { courseIds: ["a", "b"], universityIds: [] });
  assert.throws(() => normalizeScope({ courseIds: Array.from({ length: 21 }, (_, i) => `c${i}`) }), /Too many/);
  assert.throws(() => normalizeScope({ courseIds: [""] }), /non-empty/);
});

test("las excepciones se suman al perfil", () => {
  const editor = BUILTIN_ROLES.editor!;
  assert.deepEqual(mergePerms(editor.perms, { questions: "p" }).questions, "vep");
  const claims = claimsFor("editor", editor, { students: "v" }, { courseIds: ["fis"], universityIds: [] });
  assert.equal(claims.admin, true);
  assert.equal(claims.role, "editor");
  assert.equal(claims.p.questions, "ve");
  assert.equal(claims.p.students, "v");
  assert.deepEqual(claims.cs, ["fis"]);
  assert.equal(claims.us, undefined);
});

test("el dueño tiene todo y no lleva alcance", () => {
  const claims = claimsFor("owner", BUILTIN_ROLES.owner!, {}, { courseIds: ["x"], universityIds: ["u"] });
  assert.equal(claims.p.staff, "vepa");
  assert.equal(claims.p.production, "vepa");
  assert.equal(claims.cs, undefined);
});

test("los claims caben holgados en el límite de 1000 bytes", () => {
  const claims = claimsFor("owner", BUILTIN_ROLES.owner!, {}, { courseIds: [], universityIds: [] });
  const scoped = claimsFor("editor", BUILTIN_ROLES.editor!, {}, {
    courseIds: Array.from({ length: 20 }, (_, i) => `qa-course-${i}-xxxxxxxx`),
    universityIds: []
  });
  assert.ok(JSON.stringify(claims).length < 400);
  assert.ok(JSON.stringify(scoped).length < 900);
});
