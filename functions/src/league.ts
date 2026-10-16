/**
 * Weekly league (docs/rankings_contract.md §5): a student joins a group of
 * their stage when they earn their first XP of the week, and the week closes
 * on Monday moving the top of each group up and the bottom down.
 */
import { FieldValue, type DocumentReference, type DocumentSnapshot, type Firestore, type Transaction } from "firebase-admin/firestore";

import type { BackendConfig } from "./config";
import type { PublicIdentity, RankingsSettings } from "./leaderboard";

/** Group family: per week and stage (and university when preferred). */
export function groupFamily(week: string, stage: number, settings: RankingsSettings, universityId?: string): string {
  return settings.league.preferSameUniversity && universityId !== undefined
    ? `${week}_${stage}_${universityId}`
    : `${week}_${stage}`;
}

export interface LeagueSeat {
  memberRef: DocumentReference;
  member: DocumentSnapshot;
  pointerRef?: DocumentReference;
  pointer?: DocumentSnapshot;
  family: string;
}

/** Reads (inside the XP transaction, before any write) the student's seat for [week]. */
export async function readLeagueSeat(
  transaction: Transaction,
  db: Firestore,
  config: BackendConfig,
  uid: string,
  week: string,
  stage: number,
  settings: RankingsSettings,
  universityId?: string
): Promise<LeagueSeat> {
  const memberRef = db.collection(config.collections.leagueMembers).doc(`${week}_${uid}`);
  const member = await transaction.get(memberRef);
  const family = groupFamily(week, stage, settings, universityId);
  if (member.exists) return { memberRef, member, family };
  const pointerRef = db.collection(config.collections.leagueGroups).doc(`${family}_open`);
  const pointer = await transaction.get(pointerRef);
  return { memberRef, member, pointerRef, pointer, family };
}

export interface SeatFacts {
  week: string;
  stage: number;
  weekXp: number;
  identity: PublicIdentity;
  universityId: string | null;
  professionId: string | null;
}

/** Writes the seat: updates the member, or joins the open group (a new one when full). */
export function writeLeagueSeat(
  transaction: Transaction,
  db: Firestore,
  config: BackendConfig,
  seat: LeagueSeat,
  facts: SeatFacts,
  settings: RankingsSettings,
  nowMs: number = Date.now()
): void {
  const common = {
    ...facts.identity,
    weekXp: facts.weekXp,
    universityId: facts.universityId,
    professionId: facts.professionId,
    updatedAtMs: nowMs
  };
  if (seat.member.exists) {
    transaction.set(seat.memberRef, common, { merge: true });
    return;
  }
  const groups = db.collection(config.collections.leagueGroups);
  const open = seat.pointer?.data();
  const openSize = typeof open?.size === "number" ? open.size : 0;
  const openN = typeof open?.n === "number" ? open.n : 0;
  let groupId: string;
  if (typeof open?.groupId === "string" && openSize < settings.league.groupSize) {
    groupId = open.groupId;
    transaction.set(seat.pointerRef!, { size: openSize + 1 }, { merge: true });
    transaction.set(groups.doc(groupId), { size: FieldValue.increment(1) }, { merge: true });
  } else {
    const n = openN + 1;
    groupId = `${seat.family}_${n}`;
    transaction.set(groups.doc(groupId), {
      week: facts.week,
      stage: facts.stage,
      ...(settings.league.preferSameUniversity && facts.universityId !== null ? { universityId: facts.universityId } : {}),
      n,
      size: 1,
      createdAtMs: nowMs
    });
    transaction.set(seat.pointerRef!, { groupId, n, size: 1 });
  }
  transaction.set(seat.memberRef, {
    schemaVersion: 1,
    week: facts.week,
    groupId,
    stage: facts.stage,
    joinedAtMs: nowMs,
    ...common
  });
}

// ---------------------------------------------------------------- weekly close

export interface MemberStanding {
  uid: string;
  weekXp: number;
  joinedAtMs: number;
}

/** How many move up and down in a group of [size] at [stage]. They never overlap. */
export function movesFor(size: number, stage: number, settings: RankingsSettings): { up: number; down: number } {
  const last = settings.league.stageNames.length - 1;
  const up = stage >= last || size === 0 ? 0 : Math.max(1, Math.round(size * settings.league.promotePercent / 100));
  const rawDown = stage <= 0 || size < settings.league.minGroupForDemotion
    ? 0
    : Math.round(size * settings.league.demotePercent / 100);
  return { up, down: Math.max(0, Math.min(rawDown, size - up)) };
}

/** Order of a group: more XP first; on a tie, who joined earlier. */
export function orderGroup(members: readonly MemberStanding[]): MemberStanding[] {
  return [...members].sort((a, b) => b.weekXp - a.weekXp || a.joinedAtMs - b.joinedAtMs);
}

/** Closes [week] once: new stage and result for every member. Returns the members closed. */
export async function closeLeagueWeek(
  db: Firestore,
  config: BackendConfig,
  week: string,
  settings: RankingsSettings
): Promise<number> {
  const marker = db.collection(config.collections.leagueGroups).doc(`${week}_closed`);
  if ((await marker.get()).exists) return 0;
  const members = await db.collection(config.collections.leagueMembers).where("week", "==", week).get();
  const byGroup = new Map<string, { stage: number; standings: MemberStanding[] }>();
  for (const doc of members.docs) {
    const data = doc.data();
    if (typeof data.groupId !== "string") continue;
    const uid = doc.id.slice(week.length + 1);
    const group = byGroup.get(data.groupId) ?? { stage: typeof data.stage === "number" ? data.stage : 0, standings: [] };
    group.standings.push({
      uid,
      weekXp: typeof data.weekXp === "number" ? data.weekXp : 0,
      joinedAtMs: typeof data.joinedAtMs === "number" ? data.joinedAtMs : 0
    });
    byGroup.set(data.groupId, group);
  }
  let writer = db.batch();
  let pending = 0;
  let closed = 0;
  const flush = async () => {
    if (pending > 0) await writer.commit();
    writer = db.batch();
    pending = 0;
  };
  for (const { stage, standings } of byGroup.values()) {
    const ordered = orderGroup(standings);
    const { up, down } = movesFor(ordered.length, stage, settings);
    for (const [index, member] of ordered.entries()) {
      const to = index < up ? stage + 1 : index >= ordered.length - down ? stage - 1 : stage;
      writer.set(db.collection(config.collections.users).doc(member.uid).collection("ranking").doc("current"), {
        stage: to,
        lastResult: { week, from: stage, to, position: index + 1, size: ordered.length, seen: false }
      }, { merge: true });
      pending += 1;
      closed += 1;
      if (pending >= 400) await flush();
    }
  }
  writer.set(marker, { closedAtMs: Date.now(), members: closed });
  pending += 1;
  await flush();
  return closed;
}
