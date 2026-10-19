import assert from "node:assert/strict";
import test from "node:test";

import { db } from "../src/admin";
import { readBackendConfig } from "../src/config";
import { ExamBackendError } from "../src/errors";
import { PremiumService, type PlaySubscription, type PlayVerifier } from "../src/premium";

const config = readBackendConfig({ INGRESOYA_ENV: "test" });
const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 9, 19, 20, 0, 0);
const uid = "premium-fixture-student";

class FakeVerifier implements PlayVerifier {
  public calls: string[] = [];
  public constructor(public subscriptionResult: PlaySubscription) {}
  public async subscription(_packageName: string, purchaseToken: string): Promise<PlaySubscription> {
    this.calls.push(purchaseToken);
    return this.subscriptionResult;
  }
}

const activeMonthly: PlaySubscription = {
  productId: "premium_monthly",
  expiresAtMs: NOW + 30 * DAY,
  state: "SUBSCRIPTION_STATE_ACTIVE",
  orderId: "GPA.fixture",
  autoRenewing: true
};

async function seed(): Promise<void> {
  await db.collection(config.collections.users).doc(uid).set({ profile: { email: "p@test.pe" }, universityIdDoc: "uni" });
}

async function profile(): Promise<Record<string, unknown>> {
  return (await db.collection(config.collections.users).doc(uid).get()).data() ?? {};
}

test("el admin regala días sobre el premium vigente y luego lo corta", async () => {
  await seed();
  const service = new PremiumService(db, config, undefined, () => NOW);
  const first = await service.grant(uid, { days: 7, by: "admin@test.pe", reason: "Beca piloto" });
  assert.equal(first.untilMs, NOW + 7 * DAY);
  assert.equal(first.source, "admin");
  const second = await service.grant(uid, { days: 3, by: "admin@test.pe", reason: "Extensión" });
  assert.equal(second.untilMs, NOW + 10 * DAY);

  const data = await profile();
  const premium = data.premium as Record<string, unknown>;
  assert.equal(premium.productId, "admin_grant");
  assert.equal((premium.until as { toMillis(): number }).toMillis(), NOW + 10 * DAY);
  // Lo demás del perfil sigue ahí (merge).
  assert.equal((data.profile as Record<string, unknown>).email, "p@test.pe");

  const revoked = await service.revoke(uid, { by: "admin@test.pe", reason: "Error de carga" });
  assert.equal(revoked.untilMs, NOW);
  const events = await db.collection(config.collections.users).doc(uid).collection("premiumEvents").get();
  assert.deepEqual(
    events.docs.map((doc) => doc.data().type).sort(),
    ["admin_grant", "admin_grant", "admin_revoke"]
  );

  await assert.rejects(
    service.grant("nobody", { days: 1, by: "a", reason: "Motivo" }),
    (error: unknown) => error instanceof ExamBackendError && error.details?.reason === "student_not_found"
  );
});

test("sin verificador la compra se rechaza; con él se escribe el premium y se indexa el token", async () => {
  await seed();
  const off = new PremiumService(db, config, undefined, () => NOW);
  await assert.rejects(
    off.verifyPurchase(uid, { productId: "premium_monthly", purchaseToken: "token-fixture-0123456789" }),
    (error: unknown) => error instanceof ExamBackendError && error.details?.reason === "purchases_unavailable"
  );

  const verifier = new FakeVerifier(activeMonthly);
  const service = new PremiumService(db, config, verifier, () => NOW);
  const token = "token-fixture-0123456789";
  const state = await service.verifyPurchase(uid, { productId: "premium_monthly", purchaseToken: token });
  assert.deepEqual(state, { productId: "premium_monthly", untilMs: NOW + 30 * DAY, source: "play" });
  assert.deepEqual(verifier.calls, [token]);

  // Otra cuenta no puede reutilizar el mismo token.
  await db.collection(config.collections.users).doc("other-student").set({ universityIdDoc: "uni" });
  await assert.rejects(
    service.verifyPurchase("other-student", { productId: "premium_monthly", purchaseToken: token }),
    (error: unknown) => error instanceof ExamBackendError && error.details?.reason === "purchase_owned_elsewhere"
  );
  // El producto debe coincidir con lo que dice Play.
  await assert.rejects(
    service.verifyPurchase(uid, { productId: "premium_yearly", purchaseToken: token }),
    (error: unknown) => error instanceof ExamBackendError && error.code === "invalid-argument"
  );

  // Notificación de Play: una cancelación aún vigente mantiene la fecha; una
  // retención corta el acceso hoy.
  verifier.subscriptionResult = { ...activeMonthly, state: "SUBSCRIPTION_STATE_CANCELED", autoRenewing: false };
  const canceled = await service.onNotification({
    subscriptionNotification: { notificationType: 3, purchaseToken: token, subscriptionId: "premium_monthly" }
  });
  assert.deepEqual(canceled, { handled: true, reason: "rtdn_3", uid });
  assert.equal(((await profile()).premium as { until: { toMillis(): number } }).until.toMillis(), NOW + 30 * DAY);

  verifier.subscriptionResult = { ...activeMonthly, state: "SUBSCRIPTION_STATE_ON_HOLD" };
  await service.onNotification({ subscriptionNotification: { notificationType: 5, purchaseToken: token } });
  assert.equal(((await profile()).premium as { until: { toMillis(): number } }).until.toMillis(), NOW);

  assert.deepEqual(await service.onNotification({ testNotification: { version: "1.0" } }), {
    handled: false,
    reason: "test_notification"
  });
  assert.deepEqual(await service.onNotification({ subscriptionNotification: { purchaseToken: "unknown-token" } }), {
    handled: false,
    reason: "unknown_token"
  });
});
