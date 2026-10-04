import { createHash } from "node:crypto";

import { readPartProgress, type ProgressPartContext } from "./part_progress";

export interface SubtopicContext {
  courseId: string;
  topicId: string;
  subtopicId: string;
}

/** Frozen, catalog-derived requirement for one version of a subtopic award. */
export interface SubtopicRequirement extends SubtopicContext {
  schemaVersion: 1;
  requirementVersion: string;
  requiredPartIds: readonly string[];
}

export interface SubtopicCompletionAssessment {
  complete: boolean;
  missingPartIds: string[];
}

/** Stable across template revisions and later catalog changes. */
export function masteryAwardId(context: SubtopicContext): string {
  const digest = createHash("sha256")
    .update(JSON.stringify([context.courseId, context.topicId, context.subtopicId]))
    .digest("hex");
  return `mastery-v1-${digest}`;
}

/**
 * An inactive or malformed catalog cannot grant an award. The version is a
 * digest of the active part IDs and academic context, not an admin-maintained
 * counter that could be forgotten when the catalog changes.
 */
export function publishedSubtopicRequirement(
  context: SubtopicContext,
  course: unknown,
  topic: unknown,
  subtopic: unknown
): SubtopicRequirement | undefined {
  if (!active(course) || !active(topic) || !active(subtopic)) return undefined;
  const parts = (subtopic as Record<string, unknown>).listPart;
  if (!Array.isArray(parts) || parts.length === 0) return undefined;

  const ids: string[] = [];
  for (const part of parts) {
    if (!isObject(part)) return undefined;
    if (!active(part)) continue;
    const id = part.id;
    if (typeof id !== "string" || id.trim() !== id || id.length === 0) return undefined;
    ids.push(id);
  }
  if (ids.length === 0 || new Set(ids).size !== ids.length) return undefined;
  ids.sort();
  const digest = createHash("sha256")
    .update(JSON.stringify([context.courseId, context.topicId, context.subtopicId, ids]))
    .digest("hex");
  return {
    ...context,
    schemaVersion: 1,
    requirementVersion: `parts-v1-${digest}`,
    requiredPartIds: ids
  };
}

/** Historic click/score fields never count; only server-owned v2 evidence does. */
export function assessSubtopicCompletion(
  requirement: SubtopicRequirement,
  partProgress: unknown,
  newlyServerVerifiedPartId?: string
): SubtopicCompletionAssessment {
  const stored = isObject(partProgress) ? partProgress : {};
  const missingPartIds = requirement.requiredPartIds.filter((partId) => {
    if (partId === newlyServerVerifiedPartId) return false;
    const context: ProgressPartContext = { ...requirement, partId };
    try {
      return !readPartProgress(stored[partId], context).completed;
    } catch {
      // A damaged older part cannot grant an award or interrupt the current
      // exam submission; repair/reconciliation can inspect it separately.
      return true;
    }
  });
  return { complete: missingPartIds.length === 0, missingPartIds };
}

function active(value: unknown): value is Record<string, unknown> {
  if (!isObject(value)) return false;
  const status = value.active;
  return status !== false && status !== "N" && status !== "false" && status !== 0;
}

function isObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
