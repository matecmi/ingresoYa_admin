import assert from "node:assert/strict";
import test from "node:test";

import type { Firestore } from "firebase-admin/firestore";

import { CONFIG_CACHE_TTL_MS, readConfigDoc, resetConfigCache } from "../src/config_cache";
import { parseExamSelection } from "../src/exam_config";
import { readBackendConfig } from "../src/config";
import { OperationMetrics } from "../src/operation_metrics";

const env = { candidateStartsPerBlock: 2, maxCandidatesPerStart: 40, recentQuestionLimit: 60 };

test("los límites de {config}/exam reemplazan al entorno solo dentro de rango", () => {
  const parsed = parseExamSelection(
    { candidateStartsPerBlock: 3, maxCandidatesPerStart: 80, recentQuestionLimit: 150, simulatorSeenLimit: 200, attemptRetentionDays: 365 },
    env
  );
  assert.deepEqual(parsed, {
    candidateStartsPerBlock: 3,
    maxCandidatesPerStart: 80,
    recentQuestionLimit: 150,
    simulatorSeenLimit: 200,
    attemptRetentionDays: 365
  });
  const outOfRange = parseExamSelection(
    { candidateStartsPerBlock: 0, maxCandidatesPerStart: 500, recentQuestionLimit: 2.5, simulatorSeenLimit: 5, attemptRetentionDays: 10 },
    env
  );
  assert.deepEqual(outOfRange, { ...env, simulatorSeenLimit: 100, attemptRetentionDays: 180 });
  assert.deepEqual(parseExamSelection(undefined, env), { ...env, simulatorSeenLimit: 100, attemptRetentionDays: 180 });
});

test("la caché de configuración lee una vez por instancia y relee tras el plazo", async () => {
  resetConfigCache();
  let reads = 0;
  const payload: Record<string, unknown> = { recentQuestionLimit: 30 };
  const fakeDb = {
    collection: () => ({
      doc: () => ({
        get: async () => {
          reads += 1;
          return { data: () => payload };
        }
      })
    })
  } as unknown as Firestore;
  const config = readBackendConfig({ INGRESOYA_ENV: "test" });
  const metrics = new OperationMetrics();

  const first = await readConfigDoc(fakeDb, config, "exam", metrics, 1_000);
  assert.deepEqual(first, { recentQuestionLimit: 30 });
  await readConfigDoc(fakeDb, config, "exam", metrics, 1_000 + CONFIG_CACHE_TTL_MS - 1);
  assert.equal(reads, 1, "dentro del plazo no vuelve a Firestore");
  assert.equal(metrics.logFields().observedDocumentReads, 1);

  await readConfigDoc(fakeDb, config, "exam", metrics, 1_000 + CONFIG_CACHE_TTL_MS + 1);
  assert.equal(reads, 2, "vencido el plazo relee");

  // Dos llamadas simultáneas comparten la misma lectura.
  resetConfigCache();
  reads = 0;
  await Promise.all([
    readConfigDoc(fakeDb, config, "exam", undefined, 5_000),
    readConfigDoc(fakeDb, config, "exam", undefined, 5_000)
  ]);
  assert.equal(reads, 1);
  resetConfigCache();
});
