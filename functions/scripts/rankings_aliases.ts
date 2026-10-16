/**
 * Gives every existing student a username (docs/rankings_contract.md §3):
 * a random «Animal_Carrera_NN» for those without one. Students who already
 * have one keep it; running it again changes nothing.
 *
 * Usage (from functions/):
 *   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> INGRESOYA_ENV=test \
 *     npm run rankings:aliases -- [--dry-run]
 */
import { db } from "../src/admin";
import { readBackendConfig } from "../src/config";
import { parseRankingChoice } from "../src/leaderboard";
import { RankingService } from "../src/ranking";
import { XpService } from "../src/xp";

const dryRun = process.argv.includes("--dry-run");
const config = readBackendConfig();

async function main(): Promise<void> {
  const xp = new XpService(db, config);
  const ranking = new RankingService(db, config);
  const [xpSettings, rankings] = await Promise.all([xp.settings(), xp.rankingsSettings()]);
  const users = await db.collection(config.collections.users).get();
  let created = 0;
  for (const user of users.docs) {
    const choice = parseRankingChoice((await user.ref.collection("ranking").doc("current").get()).data());
    if (choice.alias !== null) continue;
    if (dryRun) {
      console.log(`${user.id}: sin nombre de usuario`);
    } else {
      const { alias } = await ranking.update(user.id, {}, xpSettings, rankings);
      console.log(`${user.id}: ${alias}`);
    }
    created += 1;
  }
  console.log(`${dryRun ? "Simulación" : "Listo"}: ${created} de ${users.size} alumnos ${dryRun ? "necesitan" : "recibieron"} nombre de usuario.`);
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
