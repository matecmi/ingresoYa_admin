import assert from "node:assert/strict";
import test from "node:test";

import { APP_CONFIG_SECTIONS, mergeAppConfig } from "../src/app_config";

test("el documento fundido trae cada sección sin metadatos y vacía si falta", () => {
  const merged = mergeAppConfig({
    xp: { perCorrect: 10, updatedAt: "x", updatedBy: "admin", schemaVersion: 1 },
    rankings: { enabled: true, league: { groupSize: 30 } },
    catalog: { coursesVersion: 3, courseVersions: { alg: 1 } }
  });
  assert.deepEqual(Object.keys(merged), [...APP_CONFIG_SECTIONS]);
  assert.deepEqual(merged.xp, { perCorrect: 10 });
  assert.deepEqual(merged.rankings, { enabled: true, league: { groupSize: 30 } });
  assert.deepEqual(merged.catalog, { coursesVersion: 3, courseVersions: { alg: 1 } });
  assert.deepEqual(merged.news, {});
  assert.deepEqual(merged.exam, {});
});
