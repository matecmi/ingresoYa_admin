import assert from "node:assert/strict";
import test from "node:test";

import { ExamBackendError } from "../src/errors";
import {
  DEFAULT_PREMIUM_SETTINGS,
  GooglePlayVerifier,
  entitlementUntil,
  isPremiumAt,
  parsePlaySubscription,
  parsePremiumSettings,
  parseSetStudentPremium,
  parseVerifyPurchase,
  pastExamGate,
  premiumOf
} from "../src/premium";
import { readBackendConfig } from "../src/config";

const DAY = 24 * 60 * 60 * 1000;
// 2026-10-19 15:00 Lima (20:00 UTC).
const NOW = Date.UTC(2026, 9, 19, 20, 0, 0);

test("la configuración premium cae a fábrica con datos raros", () => {
  assert.deepEqual(parsePremiumSettings(undefined), DEFAULT_PREMIUM_SETTINGS);
  assert.deepEqual(parsePremiumSettings({ enabled: "yes", freePastExamsPerDay: 99 }), {
    enabled: false,
    freePastExamsPerDay: 3
  });
  assert.deepEqual(parsePremiumSettings({ enabled: true, freePastExamsPerDay: 0 }), {
    enabled: true,
    freePastExamsPerDay: 0
  });
});

test("premium del perfil: Timestamp o milisegundos, vigente solo hasta `until`", () => {
  const until = { toMillis: () => NOW + DAY };
  assert.deepEqual(premiumOf({ premium: { until, productId: "premium_monthly", source: "play" } }), {
    productId: "premium_monthly",
    untilMs: NOW + DAY,
    source: "play"
  });
  assert.equal(isPremiumAt({ premium: { until: NOW + 1 } }, NOW), true);
  assert.equal(isPremiumAt({ premium: { until: NOW } }, NOW), false);
  assert.equal(isPremiumAt({ premium: { until: "ayer" } }, NOW), false);
  assert.equal(isPremiumAt(undefined, NOW), false);
});

test("el tope diario de exámenes pasados solo aplica a cuentas gratuitas con premium encendido", () => {
  const on = { enabled: true, freePastExamsPerDay: 2 };
  assert.equal(pastExamGate({ settings: { enabled: false, freePastExamsPerDay: 2 }, profile: {}, nowMs: NOW }), undefined);
  assert.equal(pastExamGate({ settings: { enabled: true, freePastExamsPerDay: 0 }, profile: {}, nowMs: NOW }), undefined);
  assert.equal(pastExamGate({ settings: on, profile: { premium: { until: NOW + DAY } }, nowMs: NOW }), undefined);

  assert.deepEqual(pastExamGate({ settings: on, profile: {}, nowMs: NOW }), {
    pastExamDay: "2026-10-19",
    pastExamStarts: 1
  });
  assert.deepEqual(
    pastExamGate({ settings: on, profile: { usage: { pastExamDay: "2026-10-19", pastExamStarts: 1 } }, nowMs: NOW }),
    { pastExamDay: "2026-10-19", pastExamStarts: 2 }
  );
  // Ayer no cuenta.
  assert.deepEqual(
    pastExamGate({ settings: on, profile: { usage: { pastExamDay: "2026-10-18", pastExamStarts: 9 } }, nowMs: NOW }),
    { pastExamDay: "2026-10-19", pastExamStarts: 1 }
  );
  assert.throws(
    () => pastExamGate({ settings: on, profile: { usage: { pastExamDay: "2026-10-19", pastExamStarts: 2 } }, nowMs: NOW }),
    (error: unknown) =>
      error instanceof ExamBackendError &&
      error.code === "resource-exhausted" &&
      error.details?.reason === "past_exam_daily_limit" &&
      error.details?.limit === 2
  );
});

test("la respuesta de Play se reduce a producto, vencimiento y estado", () => {
  const body = {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    latestOrderId: "GPA.1",
    lineItems: [
      {
        productId: "premium_monthly",
        expiryTime: "2026-11-19T20:00:00Z",
        autoRenewingPlan: { autoRenewEnabled: true }
      }
    ]
  };
  const parsed = parsePlaySubscription(body);
  assert.equal(parsed.productId, "premium_monthly");
  assert.equal(parsed.expiresAtMs, Date.UTC(2026, 10, 19, 20));
  assert.equal(parsed.orderId, "GPA.1");
  assert.equal(parsed.autoRenewing, true);
  assert.equal(entitlementUntil(parsed, NOW), parsed.expiresAtMs);
  assert.equal(entitlementUntil({ ...parsed, state: "SUBSCRIPTION_STATE_CANCELED" }, NOW), parsed.expiresAtMs);
  assert.equal(entitlementUntil({ ...parsed, state: "SUBSCRIPTION_STATE_ON_HOLD" }, NOW), NOW);
  assert.equal(entitlementUntil({ ...parsed, state: "SUBSCRIPTION_STATE_EXPIRED", expiresAtMs: NOW - DAY }, NOW), NOW - DAY);
  assert.throws(() => parsePlaySubscription({ lineItems: [] }), /unexpected subscription/);
});

test("el verificador llama a subscriptionsv2 con el token de la cuenta de servicio", async () => {
  const calls: { url: string; auth: string }[] = [];
  const auth = {
    getClient: async () => ({ getAccessToken: async () => ({ token: "ya29.fixture" }) })
  } as unknown as ConstructorParameters<typeof GooglePlayVerifier>[0];
  const fetchFn = (async (url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), auth: String((init?.headers as Record<string, string>).Authorization) });
    return new Response(
      JSON.stringify({
        subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
        lineItems: [{ productId: "premium_yearly", expiryTime: "2027-10-19T20:00:00Z" }]
      }),
      { status: 200 }
    );
  }) as typeof fetch;
  const verifier = new GooglePlayVerifier(auth, fetchFn);
  const subscription = await verifier.subscription("com.ingresoya.app", "tok/en+1");
  assert.equal(subscription.productId, "premium_yearly");
  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.auth, "Bearer ya29.fixture");
  assert.match(calls[0]?.url ?? "", /applications\/com\.ingresoya\.app\/purchases\/subscriptionsv2\/tokens\/tok%2Fen%2B1$/);

  const missing = new GooglePlayVerifier(auth, (async () => new Response("{}", { status: 404 })) as typeof fetch);
  await assert.rejects(missing.subscription("com.ingresoya.app", "x"), (error: unknown) =>
    error instanceof ExamBackendError && error.details?.reason === "purchase_not_found"
  );
});

test("las entradas de las callables se validan", () => {
  assert.deepEqual(parseVerifyPurchase({ productId: "premium_monthly", purchaseToken: " abcdefghijklmnopqrstuvwxyz " }), {
    productId: "premium_monthly",
    purchaseToken: "abcdefghijklmnopqrstuvwxyz"
  });
  assert.throws(() => parseVerifyPurchase({ productId: "gold", purchaseToken: "abcdefghijklmnopqrstuvwxyz" }), /known subscription/);
  assert.throws(() => parseVerifyPurchase({ productId: "premium_monthly", purchaseToken: "short" }), /purchaseToken/);

  assert.deepEqual(parseSetStudentPremium({ uid: "u1", action: "grant", days: 30, reason: "Beca piloto" }), {
    uid: "u1",
    action: "grant",
    days: 30,
    reason: "Beca piloto"
  });
  assert.deepEqual(parseSetStudentPremium({ uid: "u1", action: "revoke", reason: "Reembolso" }), {
    uid: "u1",
    action: "revoke",
    reason: "Reembolso"
  });
  assert.throws(() => parseSetStudentPremium({ uid: "u1", action: "grant", days: 0, reason: "Beca" }), /days/);
  assert.throws(() => parseSetStudentPremium({ uid: "u1", action: "grant", days: 5, reason: "ok" }), /reason/);
  assert.throws(() => parseSetStudentPremium({ uid: "", action: "revoke", reason: "Motivo" }), /uid/);
});

test("la configuración del backend lee el verificador y el tema de Play", () => {
  const off = readBackendConfig({ INGRESOYA_ENV: "test" });
  assert.deepEqual(off.premium, { packageName: "com.ingresoya.app", verifier: "off", rtdnTopic: "play-rtdn-test" });
  assert.equal(off.collections.purchaseTokens, "iya-purchase-tokens-test");
  const on = readBackendConfig({
    INGRESOYA_ENV: "staging",
    PLAY_VERIFIER: "google",
    PLAY_PACKAGE_NAME: "com.ingresoya.app.staging",
    PLAY_RTDN_TOPIC: "rtdn"
  });
  assert.deepEqual(on.premium, { packageName: "com.ingresoya.app.staging", verifier: "google", rtdnTopic: "rtdn" });
  assert.throws(() => readBackendConfig({ INGRESOYA_ENV: "test", PLAY_VERIFIER: "maybe" }), /PLAY_VERIFIER/);
});
