/**
 * Documentos de `{config}` leídos una vez por instancia y recordados unos
 * minutos (reestructuración de costos, Fases 3B y 3C). Un cambio del admin
 * tarda a lo sumo CONFIG_CACHE_TTL_MS en llegar a cada instancia caliente;
 * antes cada llamada volvía a leer `xp`, `rankings`, `simulator`, ...
 */
import type { Firestore } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import type { OperationMetrics } from "./operation_metrics";

export type ConfigData = Record<string, unknown> | undefined;

export const CONFIG_CACHE_TTL_MS = 5 * 60 * 1000;

interface Entry {
  data: ConfigData;
  atMs: number;
}

const entries = new Map<string, Entry>();
const inFlight = new Map<string, Promise<ConfigData>>();

/** `{config}/<docId>`; la lectura real cuenta en [metrics] solo cuando ocurre. */
export async function readConfigDoc(
  db: Firestore,
  config: BackendConfig,
  docId: string,
  metrics?: OperationMetrics,
  nowMs: number = Date.now()
): Promise<ConfigData> {
  const key = `${config.collections.config}/${docId}`;
  const hit = entries.get(key);
  if (hit !== undefined && nowMs - hit.atMs < CONFIG_CACHE_TTL_MS) return hit.data;
  let pending = inFlight.get(key);
  if (pending === undefined) {
    pending = db
      .collection(config.collections.config)
      .doc(docId)
      .get()
      .then((snapshot) => {
        metrics?.readDocument();
        const data = snapshot.data() as ConfigData;
        entries.set(key, { data, atMs: nowMs });
        return data;
      })
      .finally(() => inFlight.delete(key));
    inFlight.set(key, pending);
  }
  return pending;
}

/** Para pruebas y para forzar una relectura. */
export function resetConfigCache(): void {
  entries.clear();
  inFlight.clear();
}
