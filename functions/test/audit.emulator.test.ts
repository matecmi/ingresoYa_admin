import assert from "node:assert/strict";
import test from "node:test";

import { db } from "../src/admin";
import { auditCollection, planRestore, recordWrite } from "../src/audit";
import { readBackendConfig } from "../src/config";

const config = readBackendConfig({ INGRESOYA_ENV: "test" });

test("un cambio de configuración queda en el historial y se puede restaurar", async () => {
  const path = `${config.collections.config}/rankings`;
  const ref = db.doc(path);
  await db.collection(config.collections.staff).doc("kevin-uid").set({ email: "kevin@ingresoya.test" });
  const before = { enabled: true, league: { promotePercent: 15, groupSize: 30 } };
  const after = { enabled: true, league: { promotePercent: 20, groupSize: 30 } };
  await ref.set(after);
  await recordWrite(config, {
    path, docId: "rankings", kindKey: "config", before, after, authType: "app_user", authId: "kevin-uid"
  });
  const entries = await db.collection(auditCollection(config)).where("path", "==", path).get();
  assert.equal(entries.size, 1);
  const entry = entries.docs[0]!.data();
  assert.equal(entry.actor.email, "kevin@ingresoya.test");
  assert.equal(entry.kind, "update");
  assert.equal(entry.section, "settings");
  assert.deepEqual(entry.changes, [{ field: "league.promotePercent", before: "15", after: "20" }]);

  const plan = planRestore(entry, (await ref.get()).data() ?? null, false);
  await ref.set({ ...plan.data, auditRestoredBy: { uid: "kevin-uid", email: "kevin@ingresoya.test", entryId: entries.docs[0]!.id } });
  const restoredData = (await ref.get()).data()!;
  assert.equal((restoredData.league as { promotePercent: number }).promotePercent, 15);

  // El disparador ve la restauración y la anota como «restore» de Kevin.
  await recordWrite(config, {
    path, docId: "rankings", kindKey: "config", before: after, after: restoredData, authType: "service_account"
  });
  const all = await db.collection(auditCollection(config)).where("path", "==", path).get();
  const restore = all.docs.map((d) => d.data()).find((d) => d.kind === "restore");
  assert.ok(restore);
  assert.equal(restore.actor.email, "kevin@ingresoya.test");
});

test("escrituras sin cambios reales no ensucian el historial", async () => {
  const path = `${config.collections.courses}/c-meta`;
  await recordWrite(config, {
    path, docId: "c-meta", kindKey: "courses",
    before: { name: "Física", updatedAt: 1 }, after: { name: "Física", updatedAt: 2 }
  });
  const entries = await db.collection(auditCollection(config)).where("path", "==", path).get();
  assert.equal(entries.size, 0);
});
