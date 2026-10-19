/**
 * Reto del día generado de noche (docs/exam_config_contract.md, Fase 3C):
 * antes lo armaba el primer alumno que lo pedía, con hasta ~1.400 lecturas, y
 * lo pagaban todos los que llegaban a la vez.
 */
import { db } from "./admin";
import type { BackendConfig } from "./config";
import { safeError, safeLog } from "./logging";
import { OperationMetrics } from "./operation_metrics";
import { SimulatorService } from "./simulator_service";
import { peruDay } from "./xp";

function isActive(data: Record<string, unknown> | undefined): boolean {
  const value = data?.active;
  return value !== false && value !== "N" && value !== "false" && value !== 0;
}

/** Arma el reto de hoy (hora de Lima) para cada universidad activa que aún no lo tenga. */
export async function prepareDailyChallenges(config: BackendConfig): Promise<void> {
  const metrics = new OperationMetrics();
  const simulator = new SimulatorService(db, config);
  const day = peruDay(Date.now());
  const universities = await db.collection(config.collections.universities).get();
  metrics.readQuery(universities.size);
  let prepared = 0;
  let skipped = 0;
  let failed = 0;
  for (const university of universities.docs) {
    if (!isActive(university.data())) {
      skipped += 1;
      continue;
    }
    try {
      const done = await simulator.prepareDailyChallenge(university.id, day, metrics);
      if (done) prepared += 1;
      else skipped += 1;
    } catch (error) {
      // Una universidad sin banco suficiente no debe frenar a las demás.
      failed += 1;
      safeError("daily_challenge_prepare_failed", error, metrics.logFields(), {
        environment: config.environment
      });
    }
  }
  safeLog("daily_challenges_prepared", "system", { ...metrics.logFields(), prepared, skipped, failed });
}
