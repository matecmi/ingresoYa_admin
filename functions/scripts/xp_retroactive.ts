/**
 * Retroactive XP (docs/xp_contract.md §6): gives every student the XP of what
 * the server already verified before XP existed, with the same fixed ids as
 * the live grants, so nothing is ever counted twice.
 *
 * Usage (from functions/):
 *   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> INGRESOYA_ENV=test \
 *     npm run xp:retro -- [--dry-run]
 *
 * Covered: sections recorded, parts passed, subtopics completed and mastered,
 * Simulator sessions, diagnostic, past exam completions and streak days.
 * Not covered (unknown afterwards): correct-answer XP, score improvements and
 * weekly goals.
 */
import { db } from "../src/admin";
import { readBackendConfig } from "../src/config";
import {
  applyXpGrants,
  emptyXpState,
  guideGrants,
  simulatorGrants,
  XpService,
  type XpGrant,
  type XpSettings,
  type XpState
} from "../src/xp";

const dryRun = process.argv.includes("--dry-run");
const config = readBackendConfig();
const xp = new XpService(db, config);
const chunkSize = 150;

const record = (value: unknown): Record<string, unknown> | undefined =>
  value !== null && typeof value === "object" && !Array.isArray(value) ? value as Record<string, unknown> : undefined;
const millis = (value: unknown, fallback: number): number => {
  if (typeof value === "number") return value;
  const maybe = value as { toMillis?: () => number } | undefined;
  return typeof maybe?.toMillis === "function" ? maybe.toMillis() : fallback;
};

async function guideFor(uid: string, settings: XpSettings): Promise<XpGrant[]> {
  const user = db.collection(config.collections.users).doc(uid);
  const [progress, events] = await Promise.all([
    user.collection("learningProgress").doc("current").get(),
    user.collection("learningEvents").get()
  ]);
  const grants: XpGrant[] = [];
  const parts = record(progress.data()?.partProgress) ?? {};
  for (const [partId, value] of Object.entries(parts)) {
    const part = record(value);
    if (part === undefined) continue;
    const required = Array.isArray(part.requiredSections) ? part.requiredSections.filter((s): s is string => typeof s === "string") : [];
    const sections = Object.keys(record(part.sections) ?? {}).filter((s) => required.length === 0 || required.includes(s)).sort();
    const atMs = millis(part.completedAt, millis(part.examApprovedAt, Date.now()));
    grants.push(...guideGrants({
      partId,
      sections,
      partPassed: part.completed === true,
      ...(typeof part.courseId === "string" ? { courseId: part.courseId } : {}),
      ...(typeof part.topicId === "string" ? { topicId: part.topicId } : {}),
      ...(typeof part.subtopicId === "string" ? { subtopicId: part.subtopicId } : {}),
      atMs
    }, settings));
  }
  for (const event of events.docs) {
    const data = event.data();
    const subtopicId = typeof data.subtopicId === "string" ? data.subtopicId : undefined;
    if (subtopicId === undefined) continue;
    const completed = data.type === "subtopic_completed";
    const mastered = data.type === "subtopic_mastered";
    if (!completed && !mastered) continue;
    grants.push(...guideGrants({
      subtopicId,
      subtopicCompleted: completed,
      subtopicMastered: mastered,
      ...(typeof data.courseId === "string" ? { courseId: data.courseId } : {}),
      ...(typeof data.topicId === "string" ? { topicId: data.topicId } : {}),
      atMs: millis(data.occurredAtMs, Date.now())
    }, settings));
  }
  return grants;
}

/** Simulator grants in time order, replaying the state for the 7-day past exam rule. */
async function simulatorFor(uid: string, settings: XpSettings, from: XpState): Promise<XpGrant[]> {
  const results = await db.collection(config.collections.users).doc(uid).collection("simulatorResults").get();
  const ordered = results.docs.map((doc) => ({ id: doc.id, data: doc.data() }))
    .sort((a, b) => millis(a.data.submittedAtMs, 0) - millis(b.data.submittedAtMs, 0));
  let state = from;
  const grants: XpGrant[] = [];
  for (const { id, data } of ordered) {
    const built = simulatorGrants({
      attemptId: id,
      purpose: data.purpose === "past_exam" ? "past_exam" : "practice",
      ...(typeof data.mode === "string" ? { mode: data.mode } : {}),
      ...(typeof data.examId === "string" ? { examId: data.examId } : {}),
      total: typeof data.total === "number" ? data.total : 0,
      freshCorrect: 0,
      score: typeof data.score === "number" ? data.score : 0,
      timeUsedSeconds: typeof data.timeUsedSeconds === "number" ? data.timeUsedSeconds : null,
      atMs: millis(data.submittedAtMs, Date.now())
    }, state, settings);
    state = applyXpGrants(state, built, settings).state;
    grants.push(...built);
  }
  return grants;
}

async function main(): Promise<void> {
  const settings = await xp.settings();
  const users = await db.collection(config.collections.users).get();
  let students = 0;
  let total = 0;
  for (const user of users.docs) {
    const guide = await guideFor(user.id, settings);
    const simulator = await simulatorFor(user.id, settings, emptyXpState());
    const all = [...guide, ...simulator].sort((a, b) => a.atMs - b.atMs);
    if (all.length === 0) continue;
    students += 1;
    if (dryRun) {
      const preview = applyXpGrants(emptyXpState(), all, settings).state;
      console.log(`${user.id}: ${all.length} eventos, hasta ${preview.total} XP (${settings.ranks[preview.rankStep]?.name ?? "-"})`);
      total += preview.total;
      continue;
    }
    let gained = 0;
    for (let index = 0; index < all.length; index += chunkSize) {
      const chunk = all.slice(index, index + chunkSize);
      const award = await xp.grant(user.id, () => chunk, undefined, settings);
      gained += award?.gained ?? 0;
    }
    total += gained;
    console.log(`${user.id}: +${gained} XP`);
  }
  console.log(`${dryRun ? "Simulación" : "Listo"}: ${students} alumnos, ${total} XP${dryRun ? " como máximo (los ya otorgados no se repiten)" : ""}.`);
}

void main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
