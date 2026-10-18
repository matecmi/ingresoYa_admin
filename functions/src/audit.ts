import { FieldValue, Timestamp } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";

import { db, serverTimestamp } from "./admin";
import type { BackendConfig } from "./config";
import { ExamBackendError, asHttpsError, unauthenticated } from "./errors";
import { safeError, safeLog } from "./logging";

/**
 * Historial de cambios del admin (rediseño, fase 6). Un disparador por
 * colección del admin anota antes/después de cada escritura; la callable
 * `restoreAuditEntry` deshace un cambio. Contrato: docs/admin_audit_contract.md.
 */

export type AuditSection =
  | "questions"
  | "courses"
  | "universities"
  | "news"
  | "settings"
  | "staff";

export type AuditKind = "create" | "update" | "delete" | "restore";

export interface AuditChange {
  field: string;
  before: string;
  after: string;
}

type Data = Record<string, unknown>;

/** Campos que cambian solos y no interesan al historial. */
const META = new Set([
  "updatedAt",
  "createdAt",
  "updatedBy",
  "searchTokens",
  "partSearchTokens",
  "randomKey",
  "lastSeenAt",
  "auditRestoredBy",
  "publishedAt"
]);

const MAX_SNAPSHOT_CHARS = 180_000;
const MAX_VALUE_CHARS = 140;
const MAX_CHANGES = 40;

function isPlainObject(v: unknown): v is Data {
  return v !== null && typeof v === "object" && !Array.isArray(v) && !(v instanceof Timestamp);
}

/** Texto corto de un valor para mostrar «antes → ahora». */
export function summarize(value: unknown): string {
  if (value === undefined || value === null) return "—";
  if (typeof value === "boolean") return value ? "Sí" : "No";
  if (typeof value === "number") return String(value);
  if (typeof value === "string") {
    const plain = value.replace(/\[@\][A-Z]+/g, "").replace(/\[[#%]\]/g, " ").trim();
    return plain.length > MAX_VALUE_CHARS ? `${plain.slice(0, MAX_VALUE_CHARS)}…` : plain || "(vacío)";
  }
  if (value instanceof Timestamp) return value.toDate().toISOString().slice(0, 16).replace("T", " ");
  if (Array.isArray(value)) {
    if (value.every((v) => typeof v === "string" || typeof v === "number")) {
      const s = value.join(", ");
      return s.length > MAX_VALUE_CHARS ? `${value.length} elementos` : `[${s}]`;
    }
    return `${value.length} elemento(s)`;
  }
  const json = JSON.stringify(value);
  return json.length > MAX_VALUE_CHARS ? `${json.slice(0, MAX_VALUE_CHARS)}…` : json;
}

function same(a: unknown, b: unknown): boolean {
  return JSON.stringify(normalize(a)) === JSON.stringify(normalize(b));
}

function normalize(v: unknown): unknown {
  if (v instanceof Timestamp) return v.toMillis();
  if (Array.isArray(v)) return v.map(normalize);
  if (isPlainObject(v)) {
    return Object.fromEntries(Object.keys(v).sort().map((k) => [k, normalize(v[k])]));
  }
  return v;
}

function labelOf(item: Data): string {
  const name = item.name ?? item.title ?? item.label ?? item.id;
  return typeof name === "string" && name.trim() ? name.trim() : "sin nombre";
}

/** Diferencias legibles entre dos versiones de un documento. */
export function diffFields(before: Data | null, after: Data | null): AuditChange[] {
  const out: AuditChange[] = [];
  const push = (field: string, b: unknown, a: unknown): void => {
    if (out.length < MAX_CHANGES) out.push({ field, before: summarize(b), after: summarize(a) });
  };
  const keys = new Set([...Object.keys(before ?? {}), ...Object.keys(after ?? {})]);
  for (const key of [...keys].sort()) {
    if (META.has(key)) continue;
    const b = before?.[key];
    const a = after?.[key];
    if (same(b, a)) continue;
    if (isPlainObject(b) || isPlainObject(a)) {
      const bo = isPlainObject(b) ? b : {};
      const ao = isPlainObject(a) ? a : {};
      for (const sub of [...new Set([...Object.keys(bo), ...Object.keys(ao)])].sort()) {
        if (!same(bo[sub], ao[sub])) push(`${key}.${sub}`, bo[sub], ao[sub]);
      }
      continue;
    }
    if (Array.isArray(b) && Array.isArray(a) &&
        [...b, ...a].every((x) => isPlainObject(x) && typeof x.id === "string")) {
      const bm = new Map((b as Data[]).map((x) => [x.id as string, x]));
      const am = new Map((a as Data[]).map((x) => [x.id as string, x]));
      for (const [id, item] of am) {
        const old = bm.get(id);
        if (!old) {
          push(`${key} «${labelOf(item)}»`, null, "agregado");
          continue;
        }
        for (const f of [...new Set([...Object.keys(old), ...Object.keys(item)])].sort()) {
          if (!same(old[f], item[f])) push(`${key} «${labelOf(item)}».${f}`, old[f], item[f]);
        }
      }
      for (const [id, item] of bm) {
        if (!am.has(id)) push(`${key} «${labelOf(item)}»`, "estaba", "eliminado");
      }
      continue;
    }
    push(key, b, a);
  }
  return out;
}

/** Solo cambió lo automático (fechas, tokens): no vale la pena anotarlo. */
export function onlyMetaChanged(before: Data | null, after: Data | null): boolean {
  if (!before || !after) return false;
  return diffFields(before, after).length === 0;
}

const KIND_LABEL: Record<string, string> = {
  questions: "Pregunta",
  courses: "Curso",
  topics: "Tema",
  subtopics: "Subtema",
  templates: "Plantilla",
  universities: "Universidad",
  universityChild: "Elemento de universidad",
  professions: "Carrera",
  news: "Noticia",
  config: "Configuración",
  staff: "Personal",
  staffRoles: "Perfil"
};

const CONFIG_LABEL: Record<string, string> = {
  rankings: "Rankings y reto del día",
  xp: "XP y rangos",
  simulator: "Simulador y plan",
  study: "Guía de estudio",
  sync: "Sincronización",
  news: "Noticias",
  quality: "Preguntas a revisar"
};

/** «Pregunta «Simplifica (2/3)…»», «Configuración · Rankings…». */
export function auditTitle(kind: string, docId: string, data: Data | null): string {
  const base = KIND_LABEL[kind] ?? "Documento";
  if (kind === "config") return `${base} · ${CONFIG_LABEL[docId] ?? docId}`;
  const d = data ?? {};
  const raw = d.name ?? d.title ?? d.email ?? d.statementText ?? d.label ?? docId;
  const text = summarize(typeof raw === "string" ? raw : docId);
  return `${base} «${text.length > 70 ? `${text.slice(0, 70)}…` : text}»`;
}

export function sectionOf(kind: string): AuditSection {
  switch (kind) {
    case "questions": return "questions";
    case "courses":
    case "topics":
    case "subtopics":
    case "templates": return "courses";
    case "universities":
    case "universityChild":
    case "professions": return "universities";
    case "news": return "news";
    case "config": return "settings";
    default: return "staff";
  }
}

export interface AuditActor {
  uid: string | null;
  email: string;
  type: "user" | "system";
}

export function auditCollection(config: BackendConfig): string {
  return config.collections.audit;
}

const emailCache = new Map<string, string>();

async function actorFor(config: BackendConfig, authType: string | undefined, authId: string | undefined): Promise<AuditActor> {
  if (authType === "app_user" && authId) {
    let email = emailCache.get(authId);
    if (email === undefined) {
      const staff = await db.collection(config.collections.staff).doc(authId).get();
      email = String(staff.data()?.email ?? "");
      emailCache.set(authId, email);
    }
    return { uid: authId, email, type: "user" };
  }
  return { uid: null, email: "", type: "system" };
}

function snapshot(data: Data | null): { value: Data | null; tooLarge: boolean } {
  if (!data) return { value: null, tooLarge: false };
  const size = JSON.stringify(normalize(data)).length;
  return size > MAX_SNAPSHOT_CHARS ? { value: null, tooLarge: true } : { value: data, tooLarge: false };
}

export interface WriteEvent {
  path: string;
  docId: string;
  kindKey: string;
  before: Data | null;
  after: Data | null;
  authType?: string;
  authId?: string;
}

/** Anota una escritura (lo llama cada disparador). */
export async function recordWrite(config: BackendConfig, e: WriteEvent): Promise<void> {
  if (!e.before && !e.after) return;
  if (onlyMetaChanged(e.before, e.after)) return;
  const restored = isPlainObject(e.after?.auditRestoredBy) &&
    !same(e.after?.auditRestoredBy, e.before?.auditRestoredBy)
    ? (e.after?.auditRestoredBy as Data)
    : null;
  let actor = await actorFor(config, e.authType, e.authId);
  let kind: AuditKind = !e.before ? "create" : !e.after ? "delete" : "update";
  if (restored) {
    actor = { uid: String(restored.uid ?? ""), email: String(restored.email ?? ""), type: "user" };
    kind = "restore";
  }
  const before = snapshot(e.before);
  const after = snapshot(e.after);
  const status = (d: Data | null): string => (typeof d?.status === "string" ? d.status : "");
  await db.collection(auditCollection(config)).add({
    at: serverTimestamp(),
    actor,
    path: e.path,
    docId: e.docId,
    kindKey: e.kindKey,
    section: sectionOf(e.kindKey),
    kind,
    title: auditTitle(e.kindKey, e.docId, e.after ?? e.before),
    changes: diffFields(e.before, e.after),
    statusBefore: status(e.before),
    statusAfter: status(e.after),
    before: before.value,
    after: after.value,
    tooLarge: before.tooLarge || after.tooLarge,
    ...(restored ? { restoredEntryId: String(restored.entryId ?? "") } : {})
  });
}

// ---------------------------------------------------------------- restaurar

class AuditError extends ExamBackendError {
  public constructor(code: ConstructorParameters<typeof ExamBackendError>[0], reason: string, message: string) {
    super(code, message, { reason });
  }
}

/** Mismo criterio que `can()` de las reglas, con los claims del token. */
export function tokenCan(token: Record<string, unknown> | undefined, section: string, letter: string): boolean {
  if (!token || token.admin !== true) return false;
  const role = typeof token.role === "string" ? token.role : "owner";
  if (role === "owner") return true;
  const p = isPlainObject(token.p) ? token.p : {};
  const letters = p[section];
  return typeof letters === "string" && letters.includes(letter);
}

export interface RestorePlan {
  action: "set" | "recreate" | "unretire";
  data: Data | null;
}

/**
 * Qué hacer para deshacer una entrada. Las preguntas publicadas son
 * inmutables por versión: solo se recupera una retirada o se deshace un
 * cambio entre borradores.
 */
export function planRestore(entry: Data, current: Data | null, force: boolean): RestorePlan {
  const before = isPlainObject(entry.before) ? entry.before : null;
  const after = isPlainObject(entry.after) ? entry.after : null;
  if (entry.tooLarge === true) {
    throw new AuditError("failed-precondition", "too_large", "This change is too large to restore.");
  }
  if (!before) {
    throw new AuditError("failed-precondition", "creation_restore_unsupported", "Undo a creation from its section.");
  }
  if (entry.kindKey === "questions") {
    if (entry.statusBefore === "published" && entry.statusAfter === "retired") {
      if (current?.status !== "retired") {
        throw new AuditError("failed-precondition", "changed_since", "The question changed afterwards.");
      }
      return { action: "unretire", data: null };
    }
    if (!(entry.statusBefore === "draft" && (entry.statusAfter === "draft" || entry.statusAfter === ""))) {
      throw new AuditError("failed-precondition", "question_restore_unsupported", "Published questions are restored by publishing a new version.");
    }
  }
  if (!after) {
    if (current) throw new AuditError("failed-precondition", "changed_since", "It exists again.");
    return { action: "recreate", data: before };
  }
  if (!force && !same(stripMeta(current), stripMeta(after))) {
    throw new AuditError("failed-precondition", "changed_since", "It changed after this entry.");
  }
  return { action: "set", data: before };
}

function stripMeta(d: Data | null): Data | null {
  if (!d) return null;
  return Object.fromEntries(Object.entries(d).filter(([k]) => !META.has(k)));
}

export function createAuditHandlers(config: BackendConfig) {
  return {
    async restoreAuditEntry(request: CallableRequest<unknown>) {
      try {
        const uid = request.auth?.uid;
        if (!uid) throw unauthenticated();
        const data = (request.data ?? {}) as Data;
        const entryId = typeof data.entryId === "string" ? data.entryId : "";
        if (!entryId) throw new AuditError("invalid-argument", "invalid_request", "entryId is required.");
        const entrySnap = await db.collection(auditCollection(config)).doc(entryId).get();
        const entry = entrySnap.data();
        if (!entry) throw new AuditError("not-found", "entry_not_found", "Entry not found.");
        const token = request.auth?.token as Record<string, unknown> | undefined;
        if (!tokenCan(token, "history", "v") || !tokenCan(token, String(entry.section), "e")) {
          throw new AuditError("permission-denied", "staff_forbidden", "Missing permission.");
        }
        if (entry.kindKey === "questions" && entry.statusBefore === "published" &&
            !tokenCan(token, "questions", "p")) {
          throw new AuditError("permission-denied", "staff_forbidden", "Missing questions:p.");
        }
        const ref = db.doc(String(entry.path));
        const currentSnap = await ref.get();
        const plan = planRestore(entry, currentSnap.exists ? (currentSnap.data() as Data) : null, data.force === true);
        const email = typeof token?.email === "string" ? token.email : "";
        const marker = { uid, email, entryId, at: Timestamp.now() };
        if (plan.action === "unretire") {
          await ref.update({ status: "published", auditRestoredBy: marker, updatedAt: FieldValue.serverTimestamp() });
        } else {
          await ref.set({ ...plan.data, auditRestoredBy: marker });
        }
        safeLog("audit_entry_restored", uid, {});
        return { restored: true, action: plan.action };
      } catch (error) {
        safeError("audit_restore_rejected", error, {}, { environment: config.environment, uid: request.auth?.uid });
        throw asHttpsError(error);
      }
    }
  };
}
