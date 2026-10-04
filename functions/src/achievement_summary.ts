/** Safe, bounded Profile projection. Award documents remain the source of truth. */
export interface AchievementPreview {
  courseId: string;
  topicId: string;
  subtopicId: string;
  requirementVersion: string;
  awardedAtMs: number;
}

export interface MasteryPreview {
  courseId: string;
  topicId: string;
  subtopicId: string;
  templateId: string;
  templateVersion: number;
  examAttemptId: string;
  awardedAtMs: number;
}

export interface AchievementSummary {
  schemaVersion: 1;
  totalCompletedSubtopics: number;
  completedSubtopicKeys: string[];
  recent: AchievementPreview[];
  totalMasteredSubtopics: number;
  masteredSubtopicKeys: string[];
  recentMastery: MasteryPreview[];
}

export const emptyAchievementSummary = (): AchievementSummary => ({
  schemaVersion: 1,
  totalCompletedSubtopics: 0,
  completedSubtopicKeys: [],
  recent: [],
  totalMasteredSubtopics: 0,
  masteredSubtopicKeys: [],
  recentMastery: []
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
    recent,
    totalMasteredSubtopics: summary.totalMasteredSubtopics,
    masteredSubtopicKeys: summary.masteredSubtopicKeys,
    recentMastery: summary.recentMastery
  };
}

/** Repeated passing attempts and template updates never mint a second badge. */
export function includeMastery(
  summary: AchievementSummary,
  award: MasteryPreview
): AchievementSummary {
  const key = subtopicKey(award);
  const keys = summary.masteredSubtopicKeys.includes(key)
    ? summary.masteredSubtopicKeys
    : [...summary.masteredSubtopicKeys, key];
  const recentMastery = [award, ...summary.recentMastery.filter((item) => subtopicKey(item) !== key)]
    .sort((left, right) => right.awardedAtMs - left.awardedAtMs)
    .slice(0, 5);
  return {
    ...summary,
    totalMasteredSubtopics: keys.length,
    masteredSubtopicKeys: keys,
    recentMastery
  };
}

export function readAchievementSummary(value: unknown): AchievementSummary | undefined {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return undefined;
  const data = value as Record<string, unknown>;
  if (data.schemaVersion !== 1 || !Array.isArray(data.completedSubtopicKeys) ||
    !data.completedSubtopicKeys.every((key) => typeof key === "string") ||
    !Array.isArray(data.recent) ||
    !Array.isArray(data.masteredSubtopicKeys) ||
    !data.masteredSubtopicKeys.every((key) => typeof key === "string") ||
    !Array.isArray(data.recentMastery)) return undefined;
  const recent = data.recent.map(readPreview);
  const recentMastery = data.recentMastery.map(readMasteryPreview);
  if (recent.some((item) => item === undefined) ||
    recentMastery.some((item) => item === undefined)) return undefined;
  const keys = [...new Set(data.completedSubtopicKeys as string[])];
  const masteryKeys = [...new Set(data.masteredSubtopicKeys as string[])];
  return {
    schemaVersion: 1,
    totalCompletedSubtopics: keys.length,
    completedSubtopicKeys: keys,
    recent: recent as AchievementPreview[],
    totalMasteredSubtopics: masteryKeys.length,
    masteredSubtopicKeys: masteryKeys,
    recentMastery: recentMastery as MasteryPreview[]
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

export function readMasteryPreview(value: unknown): MasteryPreview | undefined {
  if (value === null || typeof value !== "object" || Array.isArray(value)) return undefined;
  const item = value as Record<string, unknown>;
  for (const field of ["courseId", "topicId", "subtopicId", "templateId", "examAttemptId"]) {
    if (typeof item[field] !== "string" || item[field].length === 0) return undefined;
  }
  if (typeof item.templateVersion !== "number" || !Number.isInteger(item.templateVersion) ||
    item.templateVersion < 1 || typeof item.awardedAtMs !== "number" ||
    !Number.isFinite(item.awardedAtMs)) return undefined;
  return item as unknown as MasteryPreview;
}

/** Used once for accounts with awards issued before this projection existed. */
export function summaryFromAwards(rows: readonly unknown[]): AchievementSummary {
  const awards = rows.map((row) => {
    if (row === null || typeof row !== "object" || Array.isArray(row)) return undefined;
    const data = row as Record<string, unknown>;
    const timestamp = data.awardedAt as { toMillis?: () => number } | undefined;
    const base = {
      courseId: data.courseId,
      topicId: data.topicId,
      subtopicId: data.subtopicId,
      awardedAtMs: timestamp?.toMillis?.()
    };
    if (data.type === "subtopic_mastery") {
      const preview = readMasteryPreview({
        ...base,
        templateId: data.templateId,
        templateVersion: data.templateVersion,
        examAttemptId: data.examAttemptId
      });
      return preview === undefined ? undefined : { type: "mastery" as const, preview };
    }
    if (data.type !== undefined && data.type !== "subtopic_completed") return undefined;
    const preview = readPreview({ ...base, requirementVersion: data.requirementVersion });
    return preview === undefined ? undefined : { type: "completed" as const, preview };
  }).filter((award): award is
    { type: "mastery"; preview: MasteryPreview } | { type: "completed"; preview: AchievementPreview } =>
    award !== undefined)
    .sort((left, right) => left.preview.awardedAtMs - right.preview.awardedAtMs);
  return awards.reduce(
    (summary, award) => award.type === "mastery"
      ? includeMastery(summary, award.preview)
      : includeAchievement(summary, award.preview),
    emptyAchievementSummary()
  );
}
