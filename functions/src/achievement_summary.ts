/** Safe, bounded Profile projection. Award documents remain the source of truth. */
export interface AchievementPreview {
  courseId: string;
  topicId: string;
  subtopicId: string;
  requirementVersion: string;
  awardedAtMs: number;
}

export interface AchievementSummary {
  schemaVersion: 1;
  totalCompletedSubtopics: number;
  completedSubtopicKeys: string[];
  recent: AchievementPreview[];
}

export const emptyAchievementSummary = (): AchievementSummary => ({
  schemaVersion: 1,
  totalCompletedSubtopics: 0,
  completedSubtopicKeys: [],
  recent: []
});

export function subtopicKey(value: Pick<AchievementPreview, "courseId" | "topicId" | "subtopicId">): string {
  return JSON.stringify([value.courseId, value.topicId, value.subtopicId]);
}

/** A new requirement version refreshes recency but never increments the badge count. */
export function includeAchievement(
  summary: AchievementSummary,
  award: AchievementPreview
): AchievementSummary {
  const key = subtopicKey(award);
  const keys = summary.completedSubtopicKeys.includes(key)
    ? summary.completedSubtopicKeys
    : [...summary.completedSubtopicKeys, key];
  const recent = [award, ...summary.recent.filter((item) => subtopicKey(item) !== key)]
    .sort((left, right) => right.awardedAtMs - left.awardedAtMs)
    .slice(0, 5);
  return {
    schemaVersion: 1,
    totalCompletedSubtopics: keys.length,
    completedSubtopicKeys: keys,
    recent
  };
}

export function readAchievementSummary(value: unknown): AchievementSummary | undefined {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return undefined;
  const data = value as Record<string, unknown>;
  if (data.schemaVersion !== 1 || !Array.isArray(data.completedSubtopicKeys) ||
    !data.completedSubtopicKeys.every((key) => typeof key === "string") ||
    !Array.isArray(data.recent)) return undefined;
  const recent = data.recent.map(readPreview);
  if (recent.some((item) => item === undefined)) return undefined;
  const keys = [...new Set(data.completedSubtopicKeys as string[])];
  return {
    schemaVersion: 1,
    totalCompletedSubtopics: keys.length,
    completedSubtopicKeys: keys,
    recent: recent as AchievementPreview[]
  };
}

export function readPreview(value: unknown): AchievementPreview | undefined {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return undefined;
  const item = value as Record<string, unknown>;
  for (const field of ["courseId", "topicId", "subtopicId", "requirementVersion"]) {
    if (typeof item[field] !== "string" || item[field].length === 0) return undefined;
  }
  if (typeof item.awardedAtMs !== "number" || !Number.isFinite(item.awardedAtMs)) return undefined;
  return item as unknown as AchievementPreview;
}

/** Used once for accounts with awards issued before this projection existed. */
export function summaryFromAwards(rows: readonly unknown[]): AchievementSummary {
  const awards = rows.map((row) => {
    if (row === null || typeof row !== "object" || Array.isArray(row)) return undefined;
    const data = row as Record<string, unknown>;
    const timestamp = data.awardedAt as { toMillis?: () => number } | undefined;
    return readPreview({
      courseId: data.courseId,
      topicId: data.topicId,
      subtopicId: data.subtopicId,
      requirementVersion: data.requirementVersion,
      awardedAtMs: timestamp?.toMillis?.()
    });
  }).filter((award): award is AchievementPreview => award !== undefined)
    .sort((left, right) => left.awardedAtMs - right.awardedAtMs);
  return awards.reduce(includeAchievement, emptyAchievementSummary());
}
