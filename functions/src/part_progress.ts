/** Server-owned evidence required to verify a part-completion exam. */
export const requiredPartSections = [
  "video",
  "lesson",
  "examples",
  "review",
  "resources"
] as const;

export type PartSection = (typeof requiredPartSections)[number];
export type PartProgressStatus = "not_approved" | "provisional" | "verified";

export interface ProgressPartContext {
  partId: string;
  courseId: string;
  topicId: string;
  subtopicId: string;
}

export interface PartProgressState {
  readonly context: ProgressPartContext;
  readonly completedSections: ReadonlySet<PartSection>;
  /** Sections this part requires; all five unless the catalog says less. */
  readonly requiredSections: readonly PartSection[];
  readonly approvedExamAttemptId?: string;
  readonly completed: boolean;
  readonly examAttemptId?: string;
}

export interface PartProgressAssessment {
  status: PartProgressStatus;
  missingSections: PartSection[];
  shouldRecordApproval: boolean;
  shouldMarkCompleted: boolean;
  effectiveExamAttemptId?: string;
}

export function isPartSection(value: unknown): value is PartSection {
  return typeof value === "string" && (requiredPartSections as readonly string[]).includes(value);
}

/**
 * A section is required only when the catalog part has content for it, so a
 * part without a video (or flashcards, PDF...) can still be completed. Same
 * rule as `requiredReviewItemsFor` in the app.
 */
export function requiredSectionsForPart(part: Record<string, unknown>): PartSection[] {
  const text = (key: string) => typeof part[key] === "string" && (part[key] as string).trim().length > 0;
  const list = (key: string) => Array.isArray(part[key]) && (part[key] as unknown[]).length > 0;
  const required: PartSection[] = [];
  if (text("linkVideo")) required.push("video");
  if (text("content") || text("summary") || list("objectives") || list("keyPoints") || list("formulas")) {
    required.push("lesson");
  }
  if (list("examples") || list("exercises")) required.push("examples");
  if (list("flashcards")) required.push("review");
  if (text("linkPdf") || list("images") || list("externalLinks")) required.push("resources");
  return required;
}

/** Valid stored or frozen section list, or undefined. */
export function parseRequiredSections(value: unknown): PartSection[] | undefined {
  if (!Array.isArray(value) || !value.every(isPartSection)) return undefined;
  return requiredPartSections.filter((section) => value.includes(section));
}

/**
 * Legacy "clicked"/"viewed" fields intentionally do not appear here. Only
 * v2 section evidence written by the callable, with server timestamps, counts.
 */
export function readPartProgress(
  value: unknown,
  context: ProgressPartContext,
  requiredSections?: readonly PartSection[]
): PartProgressState {
  const stored = isObject(value) ? parseRequiredSections(value.requiredSections) : undefined;
  const required = requiredSections ?? stored ?? requiredPartSections;
  if (!isObject(value) || value.schemaVersion !== 2) return emptyProgress(context, required);
  if (
    value.partId !== context.partId ||
    value.courseId !== context.courseId ||
    value.topicId !== context.topicId ||
    value.subtopicId !== context.subtopicId
  ) {
    throw new Error("Part progress context does not match its allowed part.");
  }
  const sections = new Set<PartSection>();
  if (isObject(value.sections)) {
    for (const section of requiredPartSections) {
      const evidence = value.sections[section];
      if (isObject(evidence) && Object.hasOwn(evidence, "completedAt")) sections.add(section);
    }
  }
  const completed = value.completed === true;
  // A verified part keeps the evidence it was verified with, even if the
  // catalog later adds a section.
  const verifiedWith = stored ?? requiredPartSections;
  if (completed && verifiedWith.some((section) => !sections.has(section))) {
    throw new Error("Verified part progress has incomplete section evidence.");
  }
  const approvedExamAttemptId = stringOrUndefined(value.approvedExamAttemptId);
  const examAttemptId = stringOrUndefined(value.examAttemptId);
  if (completed && examAttemptId === undefined) {
    throw new Error("Verified part progress has no completing exam attempt.");
  }
  return {
    context,
    completedSections: sections,
    requiredSections: required,
    approvedExamAttemptId,
    completed,
    examAttemptId
  };
}

export function assessExamApproval(
  state: PartProgressState,
  approvedAttemptId: string
): PartProgressAssessment {
  if (state.completed) return verified(state);
  const effectiveExamAttemptId = state.approvedExamAttemptId ?? approvedAttemptId;
  const missingSections = missingPartSections(state.completedSections, state.requiredSections);
  return {
    status: missingSections.length === 0 ? "verified" : "provisional",
    missingSections,
    shouldRecordApproval: state.approvedExamAttemptId === undefined,
    shouldMarkCompleted: missingSections.length === 0,
    effectiveExamAttemptId
  };
}

export function assessSectionCompletion(
  state: PartProgressState,
  section: PartSection
): PartProgressAssessment {
  return assessSectionsCompletion(state, [section]);
}

export function assessSectionsCompletion(
  state: PartProgressState,
  sections: readonly PartSection[]
): PartProgressAssessment {
  if (state.completed) return verified(state);
  const completedSections = new Set(state.completedSections);
  for (const section of sections) completedSections.add(section);
  const missingSections = missingPartSections(completedSections, state.requiredSections);
  const effectiveExamAttemptId = state.approvedExamAttemptId;
  return {
    status:
      effectiveExamAttemptId === undefined
        ? "not_approved"
        : missingSections.length === 0
          ? "verified"
          : "provisional",
    missingSections,
    shouldRecordApproval: false,
    shouldMarkCompleted: effectiveExamAttemptId !== undefined && missingSections.length === 0,
    effectiveExamAttemptId
  };
}

export function missingPartSections(
  completedSections: ReadonlySet<PartSection>,
  required: readonly PartSection[] = requiredPartSections
): PartSection[] {
  return required.filter((section) => !completedSections.has(section));
}

function verified(state: PartProgressState): PartProgressAssessment {
  return {
    status: "verified",
    missingSections: [],
    shouldRecordApproval: false,
    shouldMarkCompleted: false,
    effectiveExamAttemptId: state.examAttemptId
  };
}

function emptyProgress(
  context: ProgressPartContext,
  requiredSections: readonly PartSection[]
): PartProgressState {
  return { context, completedSections: new Set(), requiredSections, completed: false };
}

function isObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}
