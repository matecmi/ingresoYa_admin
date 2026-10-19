import { createHash } from "node:crypto";

import { FieldValue, Timestamp, type DocumentReference, type Firestore } from "firebase-admin/firestore";
import type { CloudEvent } from "firebase-functions/v2";
import type { CallableRequest } from "firebase-functions/v2/https";
import type { MessagePublishedData } from "firebase-functions/v2/pubsub";
import { GoogleAuth } from "google-auth-library";

import { db } from "./admin";
import { tokenCan } from "./audit";
import type { BackendConfig } from "./config";
import { readConfigDoc } from "./config_cache";
import {
  ExamBackendError,
  asHttpsError,
  failedPrecondition,
  invalidArgument,
  notFound,
  resourceExhausted,
  unauthenticated
} from "./errors";
import { safeError, safeLog } from "./logging";
import { OperationMetrics } from "./operation_metrics";
import { peruDay } from "./xp";

/**
 * Plan premium (docs/premium_contract.md, Fase 5B de la reestructuración de
 * costos). Solo este módulo escribe `premium` y `usage` en el perfil: el
 * alumno los lee, las reglas le impiden tocarlos. Las compras se verifican con
 * la API de Google Play; sin verificador configurado (`PLAY_VERIFIER=off`)
 * la compra se rechaza y el premium solo llega por regalo del admin.
 */

export const PREMIUM_PRODUCT_IDS = ["premium_monthly", "premium_yearly"] as const;
export const ADMIN_GRANT_PRODUCT_ID = "admin_grant";
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_GRANT_DAYS = 3650;

type Data = Record<string, unknown>;

function record(value: unknown): Data | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value) ? (value as Data) : undefined;
}

function millis(value: unknown): number | undefined {
  if (value instanceof Timestamp) return value.toMillis();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const candidate = value as { toMillis?: unknown } | null;
  if (candidate && typeof candidate.toMillis === "function") return (candidate as Timestamp).toMillis();
  return undefined;
}

const permissionDenied = (): ExamBackendError =>
  new ExamBackendError("permission-denied", "Not allowed.", { reason: "permission_denied" });

// ---------------------------------------------------------------- settings

/** `{config}/premium`, lo que decide el admin. */
export interface PremiumSettings {
  /** Apagado: nadie compra, no hay límites de cuenta gratuita y la app no ofrece Premium. */
  enabled: boolean;
  /** Exámenes pasados por día (hora del Perú) para la cuenta gratuita; 0 = sin límite. */
  freePastExamsPerDay: number;
}

export const DEFAULT_PREMIUM_SETTINGS: PremiumSettings = { enabled: false, freePastExamsPerDay: 3 };
export const MAX_FREE_PAST_EXAMS_PER_DAY = 20;

export function parsePremiumSettings(data: unknown): PremiumSettings {
  const raw = record(data) ?? {};
  const limit = raw.freePastExamsPerDay;
  return {
    enabled: raw.enabled === true,
    freePastExamsPerDay:
      typeof limit === "number" && Number.isInteger(limit) && limit >= 0 && limit <= MAX_FREE_PAST_EXAMS_PER_DAY
        ? limit
        : DEFAULT_PREMIUM_SETTINGS.freePastExamsPerDay
  };
}

// ------------------------------------------------------------------- state

export interface PremiumState {
  productId: string;
  untilMs: number;
  source: "play" | "admin";
}

/** `premium` del perfil, tolerante a datos viejos; undefined si nunca lo tuvo. */
export function premiumOf(profile: Data | undefined): PremiumState | undefined {
  const raw = record(profile?.premium);
  if (raw === undefined) return undefined;
  const untilMs = millis(raw.until);
  if (untilMs === undefined) return undefined;
  return {
    productId: typeof raw.productId === "string" ? raw.productId : "",
    untilMs,
    source: raw.source === "play" ? "play" : "admin"
  };
}

export function isPremiumAt(profile: Data | undefined, nowMs: number): boolean {
  const state = premiumOf(profile);
  return state !== undefined && state.untilMs > nowMs;
}

// --------------------------------------------------------- past exam gate

export interface PastExamUsage {
  pastExamDay: string;
  pastExamStarts: number;
}

/**
 * Cuenta gratuita: cuántos exámenes pasados puede empezar hoy. Devuelve el
 * `usage` que hay que guardar al crear el intento, o undefined cuando no
 * aplica (premium apagado, sin límite o alumno premium). Lanza
 * `resource-exhausted` / `past_exam_daily_limit` al llegar al tope.
 */
export function pastExamGate(args: {
  settings: PremiumSettings;
  profile: Data | undefined;
  nowMs: number;
}): PastExamUsage | undefined {
  const { settings, profile, nowMs } = args;
  if (!settings.enabled || settings.freePastExamsPerDay <= 0) return undefined;
  if (isPremiumAt(profile, nowMs)) return undefined;
  const day = peruDay(nowMs);
  const usage = record(profile?.usage);
  const starts =
    usage?.pastExamDay === day && typeof usage.pastExamStarts === "number" && Number.isFinite(usage.pastExamStarts)
      ? Math.max(0, Math.floor(usage.pastExamStarts))
      : 0;
  if (starts >= settings.freePastExamsPerDay) {
    throw resourceExhausted("Daily past exam limit for free accounts.", {
      reason: "past_exam_daily_limit",
      limit: settings.freePastExamsPerDay
    });
  }
  return { pastExamDay: day, pastExamStarts: starts + 1 };
}

// ------------------------------------------------------------ Google Play

export interface PlaySubscription {
  productId: string;
  expiresAtMs: number;
  /** `subscriptionState` de la API (SUBSCRIPTION_STATE_ACTIVE, …). */
  state: string;
  orderId?: string;
  autoRenewing: boolean;
  linkedPurchaseToken?: string;
}

export interface PlayVerifier {
  subscription(packageName: string, purchaseToken: string): Promise<PlaySubscription>;
}

/** Respuesta de `purchases.subscriptionsv2.get` → lo que nos importa. */
export function parsePlaySubscription(body: unknown): PlaySubscription {
  const raw = record(body);
  const items = Array.isArray(raw?.lineItems) ? raw.lineItems : [];
  const item = record(items[0]);
  const productId = typeof item?.productId === "string" ? item.productId : "";
  const expiresAtMs = typeof item?.expiryTime === "string" ? Date.parse(item.expiryTime) : Number.NaN;
  if (productId === "" || !Number.isFinite(expiresAtMs)) {
    throw failedPrecondition("Google Play returned an unexpected subscription.", { reason: "purchase_invalid" });
  }
  const plan = record(item?.autoRenewingPlan);
  return {
    productId,
    expiresAtMs,
    state: typeof raw?.subscriptionState === "string" ? raw.subscriptionState : "",
    ...(typeof raw?.latestOrderId === "string" ? { orderId: raw.latestOrderId } : {}),
    autoRenewing: plan !== undefined && plan.autoRenewEnabled !== false,
    ...(typeof raw?.linkedPurchaseToken === "string" ? { linkedPurchaseToken: raw.linkedPurchaseToken } : {})
  };
}

/** Estados con acceso: activa, en gracia o cancelada pero aún vigente. */
const ENTITLED_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED"
]);

/** Hasta cuándo vale el premium según Play; en pausa o retenida se corta ya. */
export function entitlementUntil(subscription: PlaySubscription, nowMs: number): number {
  return ENTITLED_STATES.has(subscription.state)
    ? subscription.expiresAtMs
    : Math.min(subscription.expiresAtMs, nowMs);
}

/**
 * Verificador real: la cuenta de servicio de Functions (credenciales por
 * defecto) debe tener acceso a la app en Play Console → Usuarios y permisos.
 */
export class GooglePlayVerifier implements PlayVerifier {
  public constructor(
    private readonly auth: GoogleAuth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"]
    }),
    private readonly fetchFn: typeof fetch = fetch
  ) {}

  public async subscription(packageName: string, purchaseToken: string): Promise<PlaySubscription> {
    const client = await this.auth.getClient();
    const { token } = await client.getAccessToken();
    const url =
      "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/" +
      `${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;
    const response = await this.fetchFn(url, { headers: { Authorization: `Bearer ${token ?? ""}` } });
    if (response.status === 400 || response.status === 404) {
      throw failedPrecondition("Google Play does not know this purchase.", { reason: "purchase_not_found" });
    }
    if (!response.ok) {
      throw new ExamBackendError("internal", "Google Play could not be reached.", {
        reason: "play_unavailable",
        status: response.status
      });
    }
    return parsePlaySubscription(await response.json());
  }
}

// ----------------------------------------------------------------- inputs

export interface VerifyPurchaseInput {
  productId: (typeof PREMIUM_PRODUCT_IDS)[number];
  purchaseToken: string;
}

export function parseVerifyPurchase(data: unknown): VerifyPurchaseInput {
  const raw = record(data ?? {});
  if (raw === undefined) throw invalidArgument("The request must be an object.");
  const productId = raw.productId;
  if (typeof productId !== "string" || !(PREMIUM_PRODUCT_IDS as readonly string[]).includes(productId)) {
    throw invalidArgument("productId must be a known subscription.");
  }
  const token = raw.purchaseToken;
  if (typeof token !== "string" || token.trim().length < 20 || token.length > 4096) {
    throw invalidArgument("purchaseToken is required.");
  }
  return { productId: productId as VerifyPurchaseInput["productId"], purchaseToken: token.trim() };
}

export type SetStudentPremiumInput =
  | { uid: string; action: "grant"; days: number; reason: string }
  | { uid: string; action: "revoke"; reason: string };

export function parseSetStudentPremium(data: unknown): SetStudentPremiumInput {
  const raw = record(data ?? {});
  if (raw === undefined) throw invalidArgument("The request must be an object.");
  const uid = typeof raw.uid === "string" ? raw.uid.trim() : "";
  if (uid === "" || uid.length > 128) throw invalidArgument("uid is required.");
  const reason = typeof raw.reason === "string" ? raw.reason.trim() : "";
  if (reason.length < 3 || reason.length > 200) throw invalidArgument("reason must have 3 to 200 characters.");
  if (raw.action === "revoke") return { uid, action: "revoke", reason };
  if (raw.action !== "grant") throw invalidArgument("action must be grant or revoke.");
  const days = raw.days;
  if (typeof days !== "number" || !Number.isInteger(days) || days < 1 || days > MAX_GRANT_DAYS) {
    throw invalidArgument(`days must be an integer between 1 and ${MAX_GRANT_DAYS}.`);
  }
  return { uid, action: "grant", days, reason };
}

// ---------------------------------------------------------------- service

export class PremiumService {
  public constructor(
    private readonly db: Firestore,
    private readonly config: BackendConfig,
    private readonly verifier: PlayVerifier | undefined,
    private readonly now: () => number = Date.now
  ) {}

  public get purchasesEnabled(): boolean {
    return this.verifier !== undefined;
  }

  public async settings(metrics?: OperationMetrics): Promise<PremiumSettings> {
    return parsePremiumSettings(await readConfigDoc(this.db, this.config, "premium", metrics));
  }

  /** Regalo del admin: suma días al premium vigente o empieza hoy. */
  public async grant(
    uid: string,
    input: { days: number; by: string; reason: string },
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<PremiumState> {
    const ref = this.userRef(uid);
    const snapshot = await ref.get();
    metrics.readDocument();
    if (!snapshot.exists) throw notFound("Student not found.", "student_not_found");
    const nowMs = this.now();
    const current = premiumOf(snapshot.data() as Data | undefined);
    const base = current !== undefined && current.untilMs > nowMs ? current.untilMs : nowMs;
    const state: PremiumState = {
      productId: ADMIN_GRANT_PRODUCT_ID,
      untilMs: base + input.days * DAY_MS,
      source: "admin"
    };
    await this.write(ref, state, { type: "admin_grant", by: input.by, reason: input.reason, days: input.days }, metrics);
    return state;
  }

  /** Corta el premium ahora. Una suscripción de Play vuelve con su próxima renovación. */
  public async revoke(
    uid: string,
    input: { by: string; reason: string },
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<PremiumState> {
    const ref = this.userRef(uid);
    const snapshot = await ref.get();
    metrics.readDocument();
    if (!snapshot.exists) throw notFound("Student not found.", "student_not_found");
    const current = premiumOf(snapshot.data() as Data | undefined);
    const state: PremiumState = {
      productId: current?.productId ?? ADMIN_GRANT_PRODUCT_ID,
      untilMs: this.now(),
      source: current?.source ?? "admin"
    };
    await this.write(ref, state, { type: "admin_revoke", by: input.by, reason: input.reason }, metrics);
    return state;
  }

  /** La app manda el token de Play tras comprar o restaurar; aquí se comprueba y se escribe. */
  public async verifyPurchase(
    uid: string,
    input: VerifyPurchaseInput,
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<PremiumState> {
    if (this.verifier === undefined) {
      throw failedPrecondition("Purchases are not enabled in this environment.", { reason: "purchases_unavailable" });
    }
    const subscription = await this.verifier.subscription(this.config.premium.packageName, input.purchaseToken);
    if (subscription.productId !== input.productId) {
      throw invalidArgument("The purchase does not match the product.");
    }
    const tokenRef = this.tokenRef(input.purchaseToken);
    const owner = await tokenRef.get();
    metrics.readDocument();
    const ownerUid = owner.data()?.uid;
    if (owner.exists && ownerUid !== uid) {
      throw failedPrecondition("This purchase belongs to another account.", { reason: "purchase_owned_elsewhere" });
    }
    const state: PremiumState = {
      productId: subscription.productId,
      untilMs: entitlementUntil(subscription, this.now()),
      source: "play"
    };
    if (!owner.exists) {
      await tokenRef.set({ uid, productId: subscription.productId, createdAt: FieldValue.serverTimestamp() });
      metrics.writeDocument();
    }
    await this.write(
      this.userRef(uid),
      state,
      {
        type: "purchase",
        orderId: subscription.orderId ?? null,
        state: subscription.state,
        autoRenewing: subscription.autoRenewing
      },
      metrics
    );
    return state;
  }

  /**
   * Notificación en tiempo real de Play (renovación, cancelación, pausa…):
   * se vuelve a consultar la suscripción y se escribe lo que diga Play.
   */
  public async onNotification(
    payload: unknown,
    metrics: OperationMetrics = new OperationMetrics()
  ): Promise<{ handled: boolean; reason: string; uid?: string }> {
    const raw = record(payload);
    const notification = record(raw?.subscriptionNotification);
    if (notification === undefined) {
      return { handled: false, reason: raw?.testNotification !== undefined ? "test_notification" : "not_subscription" };
    }
    const token = typeof notification.purchaseToken === "string" ? notification.purchaseToken : "";
    if (token === "") return { handled: false, reason: "missing_token" };
    const owner = await this.tokenRef(token).get();
    metrics.readDocument();
    const uid = owner.data()?.uid;
    if (typeof uid !== "string") return { handled: false, reason: "unknown_token" };
    if (this.verifier === undefined) return { handled: false, reason: "verifier_off", uid };
    const subscription = await this.verifier.subscription(this.config.premium.packageName, token);
    const state: PremiumState = {
      productId: subscription.productId,
      untilMs: entitlementUntil(subscription, this.now()),
      source: "play"
    };
    const type = typeof notification.notificationType === "number" ? notification.notificationType : 0;
    await this.write(
      this.userRef(uid),
      state,
      { type: `rtdn_${type}`, state: subscription.state, autoRenewing: subscription.autoRenewing },
      metrics
    );
    return { handled: true, reason: `rtdn_${type}`, uid };
  }

  private async write(ref: DocumentReference, state: PremiumState, event: Data, metrics: OperationMetrics): Promise<void> {
    const batch = this.db.batch();
    batch.set(
      ref,
      {
        premium: {
          productId: state.productId,
          until: Timestamp.fromMillis(state.untilMs),
          source: state.source,
          updatedAt: FieldValue.serverTimestamp()
        }
      },
      { merge: true }
    );
    batch.set(ref.collection("premiumEvents").doc(), {
      ...event,
      productId: state.productId,
      untilMs: state.untilMs,
      atMs: this.now(),
      createdAt: FieldValue.serverTimestamp()
    });
    await batch.commit();
    metrics.writeDocument(2);
  }

  private userRef(uid: string): DocumentReference {
    return this.db.collection(this.config.collections.users).doc(uid);
  }

  private tokenRef(purchaseToken: string): DocumentReference {
    const id = createHash("sha256").update(purchaseToken).digest("hex");
    return this.db.collection(this.config.collections.purchaseTokens).doc(id);
  }
}

// --------------------------------------------------------------- handlers

export function createPremiumHandlers(
  config: BackendConfig,
  service: PremiumService = new PremiumService(
    db,
    config,
    config.premium.verifier === "google" ? new GooglePlayVerifier() : undefined
  )
) {
  return {
    async verifyPurchase(request: CallableRequest<unknown>): Promise<PremiumState> {
      const metrics = new OperationMetrics();
      try {
        const uid = request.auth?.uid;
        if (!uid) throw unauthenticated();
        const input = parseVerifyPurchase(request.data);
        const state = await service.verifyPurchase(uid, input, metrics);
        safeLog("premium_purchase_verified", uid, { ...metrics.logFields(), untilMs: state.untilMs });
        return state;
      } catch (error) {
        safeError("premium_purchase_rejected", error, metrics.logFields(), {
          environment: config.environment,
          uid: request.auth?.uid
        });
        throw asHttpsError(error);
      }
    },

    /** Admin con `students:e`: regalar días o cortar el premium, con motivo. */
    async setStudentPremium(request: CallableRequest<unknown>): Promise<PremiumState> {
      const metrics = new OperationMetrics();
      try {
        const uid = request.auth?.uid;
        if (!uid) throw unauthenticated();
        const token = request.auth?.token as Record<string, unknown> | undefined;
        if (!tokenCan(token, "students", "e")) throw permissionDenied();
        const input = parseSetStudentPremium(request.data);
        const by = typeof token?.email === "string" ? token.email : uid;
        const state =
          input.action === "grant"
            ? await service.grant(input.uid, { days: input.days, by, reason: input.reason }, metrics)
            : await service.revoke(input.uid, { by, reason: input.reason }, metrics);
        safeLog(`premium_admin_${input.action}`, uid, { ...metrics.logFields(), untilMs: state.untilMs });
        return state;
      } catch (error) {
        safeError("premium_admin_rejected", error, metrics.logFields(), {
          environment: config.environment,
          uid: request.auth?.uid
        });
        throw asHttpsError(error);
      }
    },

    /** Pub/Sub de Play. Nunca lanza: un error se anota y Play no reintenta en bucle. */
    async onPlayNotification(event: CloudEvent<MessagePublishedData>): Promise<void> {
      const metrics = new OperationMetrics();
      try {
        const result = await service.onNotification(event.data.message.json, metrics);
        safeLog(`premium_rtdn_${result.reason}`, result.uid ?? "-", {
          ...metrics.logFields(),
          handled: result.handled
        });
      } catch (error) {
        safeError("premium_rtdn_failed", error, metrics.logFields(), { environment: config.environment });
      }
    }
  };
}
