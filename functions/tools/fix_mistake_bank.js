/* eslint-disable */
// Una sola vez (2026-10-29): antes del arreglo `bankWrite`, el envío guardaba
// el banco con merge y las preguntas corregidas seguían en `items`. Este
// script las quita (las que están en `fixed` y no se fallaron después).
// Uso: node tools/fix_mistake_bank.js --env test --project ingresoya-e5115 [--dry-run]
const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { readBackendConfig } = require("../lib/src/config");

const arg = (name) => { const i = process.argv.indexOf(name); return i < 0 ? undefined : process.argv[i + 1]; };
const env = arg("--env") ?? "test";
const projectId = arg("--project") ?? "ingresoya-e5115";
const dryRun = process.argv.includes("--dry-run");

initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const config = readBackendConfig({ INGRESOYA_ENV: env });

(async () => {
  const snap = await db.collectionGroup("simulatorSummary").get();
  let fixedDocs = 0;
  for (const doc of snap.docs) {
    if (doc.id !== "current" || !doc.ref.path.startsWith(config.collections.users + "/")) continue;
    const bank = doc.data().mistakes;
    if (!bank || typeof bank.items !== "object" || !Array.isArray(bank.fixed)) continue;
    const stale = bank.fixed.filter((f) => bank.items[f.q] && bank.items[f.q].at <= f.at).map((f) => f.q);
    if (stale.length === 0) continue;
    fixedDocs += 1;
    console.log(doc.ref.path, "quita", stale.length);
    if (!dryRun) {
      await doc.ref.update(Object.fromEntries(stale.map((q) => [`mistakes.items.${q}`, FieldValue.delete()])));
    }
  }
  console.log(dryRun ? "(simulación)" : "listo", fixedDocs, "documentos");
})();
