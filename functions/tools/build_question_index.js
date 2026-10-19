#!/usr/bin/env node
/**
 * Arma desde cero el índice de preguntas por curso (`{questionIndex}/{courseId}`,
 * functions/src/question_index.ts) con las preguntas publicadas que ya existen.
 * Después de esta carga, el disparador `indexQuestions` lo mantiene solo.
 *
 * Usa la sesión de gcloud (no necesita cuenta de servicio):
 *   npm run build
 *   node tools/build_question_index.js --env test --project ingresoya-e5115 [--dry-run]
 * GCLOUD_PATH apunta a gcloud si no está en el PATH.
 *
 * Costo: una lectura por pregunta publicada y una escritura por curso.
 */
const { execFileSync } = require("node:child_process");
const { readBackendConfig } = require("../lib/src/config");
const { indexEntryOf } = require("../lib/src/question_index");

const args = Object.fromEntries(
  process.argv.slice(2).map((arg, i, all) => (arg.startsWith("--") ? [arg.slice(2), all[i + 1]?.startsWith("--") || all[i + 1] === undefined ? true : all[i + 1]] : [])).filter((pair) => pair.length)
);
const env = args.env ?? "test";
const project = args.project ?? "ingresoya-e5115";
const dryRun = args["dry-run"] === true;
const config = readBackendConfig({ INGRESOYA_ENV: env });
const gcloud = process.env.GCLOUD_PATH ?? "gcloud";
// ACCESS_TOKEN evita llamar a gcloud (en Windows su ruta con espacios rompe la llamada).
const token = (process.env.ACCESS_TOKEN ??
  execFileSync(gcloud, ["auth", "print-access-token"], { encoding: "utf8", shell: process.platform === "win32" })).trim();
const base = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;

function decode(value) {
  if (value === undefined || value === null) return undefined;
  if ("stringValue" in value) return value.stringValue;
  if ("integerValue" in value) return Number(value.integerValue);
  if ("doubleValue" in value) return value.doubleValue;
  if ("booleanValue" in value) return value.booleanValue;
  if ("nullValue" in value) return null;
  if ("timestampValue" in value) return value.timestampValue;
  if ("arrayValue" in value) return (value.arrayValue.values ?? []).map(decode);
  if ("mapValue" in value) return Object.fromEntries(Object.entries(value.mapValue.fields ?? {}).map(([k, v]) => [k, decode(v)]));
  return undefined;
}

function encode(value) {
  if (typeof value === "string") return { stringValue: value };
  if (typeof value === "number") return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  if (typeof value === "boolean") return { booleanValue: value };
  if (Array.isArray(value)) return { arrayValue: { values: value.map(encode) } };
  if (value !== null && typeof value === "object") return { mapValue: { fields: Object.fromEntries(Object.entries(value).map(([k, v]) => [k, encode(v)])) } };
  return { nullValue: null };
}

async function request(url, body, method = "POST") {
  const response = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  if (!response.ok) throw new Error(`${response.status} ${await response.text()}`);
  return response.json();
}

async function main() {
  const byCourse = new Map();
  let cursor;
  let read = 0;
  for (;;) {
    const query = {
      structuredQuery: {
        from: [{ collectionId: config.collections.questions }],
        where: { fieldFilter: { field: { fieldPath: "status" }, op: "EQUAL", value: { stringValue: "published" } } },
        orderBy: [{ field: { fieldPath: "__name__" }, direction: "ASCENDING" }],
        limit: 300,
        ...(cursor ? { startAt: { values: [{ referenceValue: cursor }], before: false } } : {})
      }
    };
    const rows = (await request(`${base}:runQuery`, query)).filter((row) => row.document);
    if (rows.length === 0) break;
    for (const { document } of rows) {
      read += 1;
      const id = document.name.split("/").pop();
      const data = decode({ mapValue: { fields: document.fields ?? {} } });
      const entry = indexEntryOf(id, data);
      if (entry === undefined) continue;
      if (!byCourse.has(entry.courseId)) byCourse.set(entry.courseId, {});
      byCourse.get(entry.courseId)[id] = entry.value;
    }
    cursor = rows.at(-1).document.name;
    if (rows.length < 300) break;
  }
  console.log(`Preguntas publicadas leídas: ${read}`);
  for (const [courseId, q] of byCourse) {
    console.log(`  ${courseId}: ${Object.keys(q).length} en el índice`);
    if (dryRun) continue;
    await request(
      `${base}/${config.collections.questionIndex}/${encodeURIComponent(courseId)}`,
      { fields: { schemaVersion: encode(1), updatedAtMs: encode(Date.now()), q: encode(q) } },
      "PATCH"
    );
  }
  console.log(dryRun ? "Sin escribir (--dry-run)." : `Índices escritos: ${byCourse.size}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
