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
 * Legacy "clicked"/"viewed" fields intentionally do not appear here. Only
 * v2 section evidence written by the callable, with server timestamps, counts.
 */
export function readPartProgress(
  value: unknown,
  context: ProgressPartContext
): PartProgressState {
  if (!isObject(value) || value.schemaVersion !== 2) return emptyProgress(context);
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
  if (completed && sections.size !== requiredPartSections.length) {
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
  const missingSections = missingPartSections(state.completedSections);
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
  if (state.completed) return verified(state);
  const completedSections = new Set(state.completedSections);
  completedSections.add(section);
  const missingSections = missingPartSections(completedSections);
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
  completedSections: ReadonlySet<PartSection>
): PartSection[] {
  return requiredPartSections.filter((section) => !completedSections.has(section));
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

function emptyProgress(context: ProgressPartContext): PartProgressState {
  return { context, completedSections: new Set(), completed: false };
}

function isObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function stringOrUndefined(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}
