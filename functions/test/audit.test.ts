import assert from "node:assert/strict";
import test from "node:test";

import { Timestamp } from "firebase-admin/firestore";

import { auditTitle, diffFields, onlyMetaChanged, planRestore, summarize, tokenCan } from "../src/audit";

test("diferencias legibles: campos, mapas anidados y partes por id", () => {
  const before = {
    league: { promotePercent: 15, groupSize: 30 },
    name: "MRUV",
    listPart: [{ id: "p1", name: "Aceleración", active: true }, { id: "p2", name: "Caída" }],
    updatedAt: Timestamp.fromMillis(1)
  };
  const after = {
    league: { promotePercent: 20, groupSize: 30 },
    name: "MRUV",
    listPart: [{ id: "p1", name: "Aceleración", active: false }, { id: "p3", name: "Tiro" }],
    updatedAt: Timestamp.fromMillis(2)
  };
  const changes = diffFields(before, after);
  assert.deepEqual(changes.map((c) => c.field), [
    "league.promotePercent",
    "listPart «Aceleración».active",
    "listPart «Tiro»",
    "listPart «Caída»"
  ]);
  assert.equal(changes[0]!.before, "15");
  assert.equal(changes[0]!.after, "20");
  assert.equal(changes[1]!.after, "No");
});

test("solo fechas o tokens no se anotan", () => {
  assert.equal(onlyMetaChanged({ a: 1, updatedAt: 1 }, { a: 1, updatedAt: 2, searchTokens: ["x"] }), true);
  assert.equal(onlyMetaChanged({ a: 1 }, { a: 2 }), false);
});

test("resúmenes y títulos", () => {
  assert.equal(summarize("Halla[@]TEXT[#]x^2[@]MATH"), "Halla x^2");
  assert.equal(summarize(true), "Sí");
  assert.equal(auditTitle("config", "rankings", {}), "Configuración · Rankings y reto del día");
  assert.equal(auditTitle("courses", "c", { name: "Física" }), "Curso «Física»");
});

test("restaurar: cambios simples, recuperar lo borrado y preguntas", () => {
  const current = { name: "B" };
  assert.deepEqual(
    planRestore({ before: { name: "A" }, after: { name: "B" }, kindKey: "courses" }, current, false),
    { action: "set", data: { name: "A" } }
  );
  assert.throws(
    () => planRestore({ before: { name: "A" }, after: { name: "B" }, kindKey: "courses" }, { name: "C" }, false),
    /changed after/
  );
  assert.equal(
    planRestore({ before: { name: "A" }, after: { name: "B" }, kindKey: "courses" }, { name: "C" }, true).action,
    "set"
  );
  assert.equal(planRestore({ before: { name: "A" }, after: null, kindKey: "topics" }, null, false).action, "recreate");
  assert.throws(() => planRestore({ before: null, after: { name: "A" }, kindKey: "topics" }, null, false), /creation/);
  assert.equal(
    planRestore({ before: { status: "published" }, after: { status: "retired" }, kindKey: "questions",
      statusBefore: "published", statusAfter: "retired" }, { status: "retired" }, false).action,
    "unretire"
  );
  assert.throws(
    () => planRestore({ before: { status: "published" }, after: { status: "draft" }, kindKey: "questions",
      statusBefore: "published", statusAfter: "draft" }, { status: "draft" }, false),
    /new version/
  );
});

test("permisos del token como en las reglas", () => {
  assert.equal(tokenCan({ admin: true }, "settings", "e"), true);
  assert.equal(tokenCan({ admin: true, role: "editor", p: { history: "v", courses: "ve" } }, "courses", "e"), true);
  assert.equal(tokenCan({ admin: true, role: "editor", p: { history: "v" } }, "settings", "e"), false);
  assert.equal(tokenCan({}, "settings", "v"), false);
});
