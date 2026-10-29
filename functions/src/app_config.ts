/**
 * `{config}/app`: todos los documentos de configuración que lee la app,
 * fundidos en uno (docs/app_config_contract.md, Fase 2B de costos). La app
 * los obtiene con una lectura por sesión en vez de una por documento. Lo
 * reescribe el disparador `auditConfig` tras cada cambio del admin (y cada
 * subida de `catalog`).
 */
import { FieldValue } from "firebase-admin/firestore";

import { db } from "./admin";
import type { BackendConfig } from "./config";

export const APP_CONFIG_DOC = "app";

/** Documentos que viajan dentro de `{config}/app`, en este orden. */
export const APP_CONFIG_SECTIONS = [
  "xp",
  "rankings",
  "news",
  "simulator",
  "sync",
  "study",
  "exam",
  "ads",
  "premium",
  "stats",
  "tours",
  "catalog"
] as const;

export type AppConfigSection = (typeof APP_CONFIG_SECTIONS)[number];

type Data = Record<string, unknown>;

/** Campos de auditoría que no hace falta repetir en cada sección. */
const META_FIELDS = new Set(["updatedAt", "updatedBy", "schemaVersion"]);

/** El documento fundido a partir de lo leído; secciones ausentes van vacías. */
export function mergeAppConfig(sections: Partial<Record<AppConfigSection, Data | undefined>>): Data {
  const merged: Data = {};
  for (const name of APP_CONFIG_SECTIONS) {
    const data = sections[name] ?? {};
    merged[name] = Object.fromEntries(Object.entries(data).filter(([key]) => !META_FIELDS.has(key)));
  }
  return merged;
}

/** Lee las secciones y reescribe `{config}/app` (sube `version`). */
export async function publishAppConfig(config: BackendConfig): Promise<void> {
  const collection = db.collection(config.collections.config);
  const snapshots = await db.getAll(...APP_CONFIG_SECTIONS.map((name) => collection.doc(name)));
  const sections: Partial<Record<AppConfigSection, Data | undefined>> = {};
  snapshots.forEach((snapshot, index) => {
    sections[APP_CONFIG_SECTIONS[index]!] = snapshot.data() as Data | undefined;
  });
  await collection.doc(APP_CONFIG_DOC).set(
    {
      ...mergeAppConfig(sections),
      version: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp()
    },
    { merge: true }
  );
}
