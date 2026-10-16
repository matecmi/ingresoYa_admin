import { db } from "./admin";
import type { BackendConfig } from "./config";
import { leagueRuns, parseRankingsSettings } from "./leaderboard";
import { closeLeagueWeek } from "./league";
import { safeLog } from "./logging";
import { peruWeek } from "./xp";

/** Closes the Peru week that just ended (run on Monday), if the league ran it. */
export async function closeLastLeagueWeek(config: BackendConfig, nowMs: number = Date.now()): Promise<number> {
  const week = peruWeek(nowMs - 24 * 60 * 60 * 1000);
  const settings = parseRankingsSettings((await db.collection(config.collections.config).doc("rankings").get()).data());
  if (!leagueRuns(settings, week)) return 0;
  const closed = await closeLeagueWeek(db, config, week, settings);
  safeLog("league_week_closed", "system", { closed });
  return closed;
}
