import { getAuth, type UserRecord } from "firebase-admin/auth";
import { Timestamp } from "firebase-admin/firestore";
import type { CallableRequest } from "firebase-functions/v2/https";

import { db, serverTimestamp } from "./admin";
import type { BackendConfig } from "./config";
import { ExamBackendError, asHttpsError, unauthenticated } from "./errors";
import { safeError, safeLog } from "./logging";

/**
 * Perfiles y permisos del admin (docs/admin_staff_contract.md).
 * Solo esta capa escribe fichas, perfiles e invitaciones, y fija los claims.
 */

export const STAFF_SECTIONS = [
  "questions",
  "courses",
  "universities",
  "students",
  "news",
  "settings",
  "staff",
  "history",
  "production"
] as const;
export type StaffSection = (typeof STAFF_SECTIONS)[number];
export type Perms = Partial<Record<StaffSection, string>>;

const ACTIONS = "vepa";
const MAX_SCOPE_IDS = 20;
const INVITE_DAYS = 14;

export interface StaffRole {
  name: string;
  description: string;
  perms: Perms;
  builtIn: boolean;
}

export interface StaffScope {
  courseIds: string[];
  universityIds: string[];
}

export interface StaffClaims {
  admin: true;
  role: string;
  p: Perms;
  cs?: string[];
  us?: string[];
}

const all = (letters: string): Perms =>
  Object.fromEntries(STAFF_SECTIONS.map((s) => [s, letters])) as Perms;

export const BUILTIN_ROLES: Record<string, StaffRole> = {
  owner: {
    name: "Dueño",
    description: "Todo, incluido perfiles y producción. No se puede borrar.",
    perms: all("vepa"),
    builtIn: true
  },
  editor: {
    name: "Editor de contenido",
    description: "Crea y edita preguntas, cursos y exámenes. Publicar pide revisión.",
    perms: { questions: "ve", courses: "ve", universities: "ve", news: "ve", settings: "v", history: "v" },
    builtIn: true
  },
  reviewer: {
    name: "Revisor",
    description: "Revisa y publica lo que cargan los editores. No borra.",
    perms: { questions: "vep", courses: "vep", universities: "vep", news: "vep", settings: "v", history: "v" },
    builtIn: true
  },
  support: {
    name: "Soporte a alumnos",
    description: "Busca alumnos, ve su ficha y corrige XP con motivo.",
    perms: { students: "ve", questions: "v", courses: "v", history: "v" },
    builtIn: true
  },
  readonly: {
    name: "Solo lectura",
    description: "Ve todo, no cambia nada. Útil para socios o auditoría.",
    perms: {
      questions: "v", courses: "v", universities: "v", students: "v", news: "v", settings: "v", history: "v"
    },
    builtIn: true
  }
};

class StaffError extends ExamBackendError {
  public constructor(code: ConstructorParameters<typeof ExamBackendError>[0], reason: string, message: string) {
    super(code, message, { reason });
  }
}

const forbidden = (reason: string, message: string): StaffError =>
  new StaffError("permission-denied", reason, message);
const invalid = (reason: string, message: string): StaffError =>
  new StaffError("invalid-argument", reason, message);
const precondition = (reason: string, message: string): StaffError =>
  new StaffError("failed-precondition", reason, message);

/** Normaliza letras de permiso: solo `vepa`, sin repetir, en ese orden; `v` va implícita. */
export function normalizeLetters(value: unknown): string {
  if (typeof value !== "string") return "";
  const set = new Set(value.toLowerCase().split("").filter((c) => ACTIONS.includes(c)));
  if (set.size > 0) set.add("v");
  return ACTIONS.split("").filter((c) => set.has(c)).join("");
}

export function normalizePerms(value: unknown): Perms {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw invalid("invalid_permissions", "Permissions must be an object.");
  }
  const out: Perms = {};
  for (const [key, letters] of Object.entries(value as Record<string, unknown>)) {
    if (!(STAFF_SECTIONS as readonly string[]).includes(key)) {
      throw invalid("invalid_permissions", `Unknown section: ${key}`);
    }
    const norm = normalizeLetters(letters);
    if (norm) out[key as StaffSection] = norm;
  }
  return out;
}

export function normalizeScope(value: unknown): StaffScope {
  const read = (v: unknown): string[] => {
    if (v === undefined || v === null) return [];
    if (!Array.isArray(v) || v.some((x) => typeof x !== "string" || x.trim() === "")) {
      throw invalid("invalid_scope", "Scope ids must be non-empty strings.");
    }
    const ids = [...new Set((v as string[]).map((x) => x.trim()))];
    if (ids.length > MAX_SCOPE_IDS) throw invalid("invalid_scope", "Too many scope ids.");
    return ids;
  };
  const obj = (value ?? {}) as Record<string, unknown>;
  if (typeof obj !== "object" || Array.isArray(obj)) throw invalid("invalid_scope", "Scope must be an object.");
  return { courseIds: read(obj.courseIds), universityIds: read(obj.universityIds) };
}

/** Une permisos (perfil + excepciones) letra por letra. */
export function mergePerms(base: Perms, extra: Perms): Perms {
  const out: Perms = { ...base };
  for (const [k, letters] of Object.entries(extra)) {
    out[k as StaffSection] = normalizeLetters((out[k as StaffSection] ?? "") + letters);
  }
  return out;
}

export function claimsFor(roleId: string, role: StaffRole, extra: Perms, scope: StaffScope): StaffClaims {
  const claims: StaffClaims = {
    admin: true,
    role: roleId,
    p: roleId === "owner" ? all("vepa") : mergePerms(role.perms, extra)
  };
  if (roleId !== "owner" && scope.courseIds.length > 0) claims.cs = scope.courseIds;
  if (roleId !== "owner" && scope.universityIds.length > 0) claims.us = scope.universityIds;
  return claims;
}

const STAFF_CLAIM_KEYS = ["admin", "role", "p", "cs", "us"];

/** Claims de la cuenta sin los del admin (por si existieran otros). */
function otherClaims(user: UserRecord): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(user.customClaims ?? {})) {
    if (!STAFF_CLAIM_KEYS.includes(k)) out[k] = v;
  }
  return out;
}

function sameClaims(a: Record<string, unknown>, b: Record<string, unknown>): boolean {
  const canon = (o: Record<string, unknown>): string =>
    JSON.stringify(Object.keys(o).sort().map((k) => [k, o[k]]));
  return canon(a) === canon(b);
}

interface StaffDoc {
  uid: string;
  email: string;
  name: string;
  roleId: string;
  extra: Perms;
  scope: StaffScope;
  status: "active" | "revoked";
}

export class StaffService {
  public constructor(private readonly config: BackendConfig) {}

  private get cols() {
    return this.config.collections;
  }

  /** Perfil por id: el guardado en Firestore o el de fábrica. */
  public async role(roleId: string): Promise<StaffRole | null> {
    const snap = await db.collection(this.cols.staffRoles).doc(roleId).get();
    if (snap.exists) {
      const d = snap.data() ?? {};
      return {
        name: String(d.name ?? roleId),
        description: String(d.description ?? ""),
        perms: roleId === "owner" ? all("vepa") : normalizePerms(d.perms ?? {}),
        builtIn: d.builtIn === true
      };
    }
    return BUILTIN_ROLES[roleId] ?? null;
  }

  /** Crea en Firestore los perfiles de fábrica que falten (para que el admin los lea). */
  public async seedBuiltinRoles(): Promise<void> {
    const col = db.collection(this.cols.staffRoles);
    const existing = await col.get();
    const have = new Set(existing.docs.map((d) => d.id));
    const batch = db.batch();
    let writes = 0;
    for (const [id, role] of Object.entries(BUILTIN_ROLES)) {
      if (have.has(id)) continue;
      batch.set(col.doc(id), { ...role, updatedAt: serverTimestamp(), updatedBy: "system" });
      writes++;
    }
    if (writes > 0) await batch.commit();
  }

  private async staffDoc(uid: string): Promise<StaffDoc | null> {
    const snap = await db.collection(this.cols.staff).doc(uid).get();
    if (!snap.exists) return null;
    const d = snap.data() ?? {};
    return {
      uid,
      email: String(d.email ?? ""),
      name: String(d.name ?? ""),
      roleId: String(d.roleId ?? ""),
      extra: normalizePerms(d.extra ?? {}),
      scope: normalizeScope(d.scope ?? {}),
      status: d.status === "revoked" ? "revoked" : "active"
    };
  }

  /** Fija (o quita) los claims del admin según la ficha. Devuelve si cambiaron. */
  public async applyClaims(uid: string, staff: StaffDoc | null): Promise<boolean> {
    const user = await getAuth().getUser(uid);
    let desired: Record<string, unknown> = otherClaims(user);
    if (staff && staff.status === "active") {
      const role = await this.role(staff.roleId);
      if (role) desired = { ...desired, ...claimsFor(staff.roleId, role, staff.extra, staff.scope) };
    }
    if (sameClaims(desired, user.customClaims ?? {})) return false;
    await getAuth().setCustomUserClaims(uid, desired);
    return true;
  }

  public async sync(uid: string, email: string | undefined, name: string | undefined, tokenAdmin: boolean) {
    await this.seedBuiltinRoles();
    const ref = db.collection(this.cols.staff).doc(uid);
    let staff = await this.staffDoc(uid);
    const lowerEmail = (email ?? "").trim().toLowerCase();

    if (!staff && lowerEmail) {
      const inviteRef = db.collection(this.cols.staffInvites).doc(lowerEmail);
      const invite = await inviteRef.get();
      const data = invite.data();
      const expires = data?.expiresAt instanceof Timestamp ? data.expiresAt.toMillis() : 0;
      if (invite.exists && data && expires > Date.now()) {
        staff = {
          uid,
          email: lowerEmail,
          name: name ?? "",
          roleId: String(data.roleId),
          extra: normalizePerms(data.extra ?? {}),
          scope: normalizeScope(data.scope ?? {}),
          status: "active"
        };
        await db.runTransaction(async (tx) => {
          tx.set(ref, {
            ...staff,
            invitedBy: data.invitedBy ?? null,
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
            lastSeenAt: serverTimestamp()
          });
          tx.delete(inviteRef);
        });
      }
    }

    if (!staff && tokenAdmin) {
      // Cuentas que ya eran admin antes de los perfiles: quedan como Dueño.
      staff = {
        uid,
        email: lowerEmail,
        name: name ?? "",
        roleId: "owner",
        extra: {},
        scope: { courseIds: [], universityIds: [] },
        status: "active"
      };
      await ref.set({
        ...staff,
        invitedBy: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        lastSeenAt: serverTimestamp()
      });
    } else if (staff) {
      await ref.set({ lastSeenAt: serverTimestamp(), ...(name && !staff.name ? { name } : {}) }, { merge: true });
    }

    const changed = await this.applyClaims(uid, staff);
    return {
      active: staff?.status === "active",
      roleId: staff?.status === "active" ? staff.roleId : null,
      changed
    };
  }

  /** La ficha de quien llama, verificada en Firestore (no solo en el token). */
  private async requireStaffEditor(uid: string): Promise<StaffDoc> {
    const me = await this.staffDoc(uid);
    if (!me || me.status !== "active") throw forbidden("not_staff", "Not an admin.");
    if (me.roleId === "owner") return me;
    const role = await this.role(me.roleId);
    const perms = role ? mergePerms(role.perms, me.extra) : {};
    if (!(perms.staff ?? "").includes("e")) throw forbidden("staff_forbidden", "Missing staff:e.");
    return me;
  }

  private async ownerCount(): Promise<number> {
    const snap = await db.collection(this.cols.staff)
      .where("roleId", "==", "owner")
      .where("status", "==", "active")
      .get();
    return snap.size;
  }

  private async requireRole(roleId: unknown): Promise<string> {
    if (typeof roleId !== "string" || roleId.trim() === "") throw invalid("role_not_found", "roleId is required.");
    const role = await this.role(roleId);
    if (!role) throw precondition("role_not_found", "Role not found.");
    return roleId;
  }

  public async manage(callerUid: string, input: Record<string, unknown>): Promise<Record<string, unknown>> {
    await this.seedBuiltinRoles();
    const me = await this.requireStaffEditor(callerUid);
    const action = input.action;
    const ownerOnly = (roleId: string): void => {
      if (roleId === "owner" && me.roleId !== "owner") {
        throw forbidden("owner_only", "Only an owner can assign the owner role.");
      }
    };

    switch (action) {
      case "invite": {
        const email = typeof input.email === "string" ? input.email.trim().toLowerCase() : "";
        if (!email.includes("@")) throw invalid("invalid_email", "A valid email is required.");
        const roleId = await this.requireRole(input.roleId);
        ownerOnly(roleId);
        const extra = normalizePerms(input.extra ?? {});
        const scope = normalizeScope(input.scope ?? {});
        let user: UserRecord | null = null;
        try {
          user = await getAuth().getUserByEmail(email);
        } catch {
          user = null;
        }
        if (user) {
          const ref = db.collection(this.cols.staff).doc(user.uid);
          const before = await ref.get();
          const doc: StaffDoc = {
            uid: user.uid, email, name: user.displayName ?? "", roleId, extra, scope, status: "active"
          };
          await ref.set({
            ...doc,
            invitedBy: callerUid,
            updatedAt: serverTimestamp(),
            ...(before.exists ? {} : { createdAt: serverTimestamp() })
          }, { merge: true });
          await this.applyClaims(user.uid, doc);
          return { status: "active", uid: user.uid };
        }
        await db.collection(this.cols.staffInvites).doc(email).set({
          email,
          roleId,
          extra,
          scope,
          invitedBy: callerUid,
          createdAt: serverTimestamp(),
          expiresAt: Timestamp.fromMillis(Date.now() + INVITE_DAYS * 86_400_000)
        });
        return { status: "invited", email };
      }
      case "update": {
        const uid = typeof input.uid === "string" ? input.uid : "";
        const current = await this.staffDoc(uid);
        if (!current) throw precondition("not_staff", "Staff member not found.");
        const roleId = input.roleId === undefined ? current.roleId : await this.requireRole(input.roleId);
        ownerOnly(roleId);
        if (current.roleId === "owner" && roleId !== "owner") {
          ownerOnly("owner");
          if ((await this.ownerCount()) <= 1) throw precondition("last_owner", "At least one owner must remain.");
        }
        const next: StaffDoc = {
          ...current,
          roleId,
          extra: input.extra === undefined ? current.extra : normalizePerms(input.extra),
          scope: input.scope === undefined ? current.scope : normalizeScope(input.scope),
          status: "active"
        };
        await db.collection(this.cols.staff).doc(uid).set({
          roleId: next.roleId, extra: next.extra, scope: next.scope, status: "active",
          updatedAt: serverTimestamp()
        }, { merge: true });
        await this.applyClaims(uid, next);
        return { status: "active", uid };
      }
      case "revoke": {
        const uid = typeof input.uid === "string" ? input.uid : "";
        if (uid === callerUid) throw precondition("self_revoke", "You cannot remove your own access.");
        const current = await this.staffDoc(uid);
        if (!current) throw precondition("not_staff", "Staff member not found.");
        if (current.roleId === "owner") {
          ownerOnly("owner");
          if ((await this.ownerCount()) <= 1) throw precondition("last_owner", "At least one owner must remain.");
        }
        await db.collection(this.cols.staff).doc(uid).set(
          { status: "revoked", updatedAt: serverTimestamp(), revokedBy: callerUid },
          { merge: true }
        );
        await this.applyClaims(uid, { ...current, status: "revoked" });
        await getAuth().revokeRefreshTokens(uid);
        return { status: "revoked", uid };
      }
      case "cancelInvite": {
        const email = typeof input.email === "string" ? input.email.trim().toLowerCase() : "";
        await db.collection(this.cols.staffInvites).doc(email).delete();
        return { status: "cancelled", email };
      }
      case "saveRole": {
        const name = typeof input.name === "string" ? input.name.trim() : "";
        if (name.length < 2 || name.length > 40) throw invalid("invalid_role", "Name must have 2–40 characters.");
        const description = typeof input.description === "string" ? input.description.trim().slice(0, 160) : "";
        const perms = normalizePerms(input.perms ?? {});
        let roleId = typeof input.roleId === "string" && input.roleId ? input.roleId : "";
        if (roleId === "owner") throw precondition("builtin_role", "The owner role cannot be changed.");
        if (!roleId) {
          roleId = name.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
            .replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 30) || "perfil";
          const taken = await db.collection(this.cols.staffRoles).doc(roleId).get();
          if (taken.exists || BUILTIN_ROLES[roleId]) roleId = `${roleId}-${Date.now().toString(36)}`;
        }
        const builtIn = Boolean(BUILTIN_ROLES[roleId]);
        await db.collection(this.cols.staffRoles).doc(roleId).set({
          name, description, perms, builtIn, updatedAt: serverTimestamp(), updatedBy: callerUid
        });
        const members = await db.collection(this.cols.staff).where("roleId", "==", roleId).get();
        for (const m of members.docs) {
          const doc = await this.staffDoc(m.id);
          if (doc) await this.applyClaims(m.id, doc);
        }
        return { roleId, members: members.size };
      }
      case "deleteRole": {
        const roleId = typeof input.roleId === "string" ? input.roleId : "";
        if (BUILTIN_ROLES[roleId]) throw precondition("builtin_role", "Built-in roles cannot be deleted.");
        const members = await db.collection(this.cols.staff)
          .where("roleId", "==", roleId).where("status", "==", "active").limit(1).get();
        if (!members.empty) throw precondition("role_in_use", "The role still has members.");
        await db.collection(this.cols.staffRoles).doc(roleId).delete();
        return { roleId, deleted: true };
      }
      default:
        throw invalid("invalid_action", "Unknown action.");
    }
  }
}

export function createStaffHandlers(config: BackendConfig) {
  const service = new StaffService(config);
  return {
    async syncAdminAccess(request: CallableRequest<unknown>) {
      try {
        const uid = request.auth?.uid;
        if (!uid) throw unauthenticated();
        const token: Record<string, unknown> = request.auth?.token ?? {};
        const result = await service.sync(
          uid,
          typeof token.email === "string" && token.email_verified === true ? token.email : undefined,
          typeof token.name === "string" ? token.name : undefined,
          token.admin === true
        );
        safeLog("admin_access_synced", uid, { changed: result.changed, active: result.active });
        return result;
      } catch (error) {
        safeError("admin_access_sync_rejected", error, {}, { environment: config.environment, uid: request.auth?.uid });
        throw asHttpsError(error);
      }
    },
    async manageAdminStaff(request: CallableRequest<unknown>) {
      try {
        const uid = request.auth?.uid;
        if (!uid) throw unauthenticated();
        const data = (request.data ?? {}) as Record<string, unknown>;
        if (typeof data !== "object" || Array.isArray(data)) throw invalid("invalid_action", "Invalid request.");
        const result = await service.manage(uid, data);
        safeLog(`admin_staff_${String(data.action).replace(/[^a-zA-Z]/g, "").slice(0, 20)}`, uid);
        return result;
      } catch (error) {
        safeError("admin_staff_manage_rejected", error, {}, { environment: config.environment, uid: request.auth?.uid });
        throw asHttpsError(error);
      }
    }
  };
}
