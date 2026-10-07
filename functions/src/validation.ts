import { invalidArgument } from "./errors";
import { isPartSection, type PartSection } from "./part_progress";

/**
 * Where the app found the part in the catalog. A hint only: the server checks
 * that the part exists, active, inside exactly this course/topic/subtopic.
 */
export interface PartCatalogHint {
  courseId: string;
  topicId: string;
  subtopicId: string;
}

export type CreateExamAttemptInput = {
  requestId: string;
  purpose: "part_completion";
  templateId: string;
  partId: string;
  catalog?: PartCatalogHint;
} | {
  requestId: string;
  purpose: "subtopic_mastery";
  templateId: string;
  courseId: string;
  topicId: string;
  subtopicId: string;
};

export interface GetExamAttemptInput {
  attemptId: string;
}

export interface SubmitExamAttemptInput {
  attemptId: string;
  answers: Readonly<Record<string, string>>;
}

export interface SaveExamAnswersInput {
  attemptId: string;
  answers: Readonly<Record<string, string>>;
}

export type RecordPartSectionCompletionInput = ({
  partId: string;
  section: PartSection;
  sections?: never;
} | {
  partId: string;
  sections: readonly PartSection[];
  section?: never;
}) & { catalog?: PartCatalogHint };

const identifier = /^[A-Za-z0-9_-]{1,128}$/;
export const maxAnswersPerSave = 50;
const maxAnswersAtSubmit = 200;

function object(value: unknown, name: string): Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    throw invalidArgument(`${name} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function onlyKeys(value: Record<string, unknown>, allowed: readonly string[]): void {
  for (const key of Object.keys(value)) {
    if (!allowed.includes(key)) {
      throw invalidArgument(`Unexpected field: ${key}.`);
    }
  }
}

/** All three academic IDs, or none (older app versions). */
function catalogHint(value: Record<string, unknown>): PartCatalogHint | undefined {
  const keys = ["courseId", "topicId", "subtopicId"] as const;
  const present = keys.filter((key) => Object.hasOwn(value, key));
  if (present.length === 0) return undefined;
  if (present.length !== keys.length) {
    throw invalidArgument("Provide courseId, topicId and subtopicId together.");
  }
  return {
    courseId: id(value.courseId, "courseId"),
    topicId: id(value.topicId, "topicId"),
    subtopicId: id(value.subtopicId, "subtopicId")
  };
}

function id(value: unknown, name: string): string {
  if (typeof value !== "string" || !identifier.test(value)) {
    throw invalidArgument(`${name} must be an identifier of up to 128 characters.`);
  }
  return value;
}

export function parseCreateExamAttempt(data: unknown): CreateExamAttemptInput {
  const value = object(data, "data");
  if (value.purpose === "subtopic_mastery") {
    onlyKeys(value, ["requestId", "purpose", "templateId", "courseId", "topicId", "subtopicId"]);
    return {
      requestId: id(value.requestId, "requestId"),
      purpose: "subtopic_mastery",
      templateId: id(value.templateId, "templateId"),
      courseId: id(value.courseId, "courseId"),
      topicId: id(value.topicId, "topicId"),
      subtopicId: id(value.subtopicId, "subtopicId")
    };
  }
  if (value.purpose !== "part_completion") {
    throw invalidArgument("purpose must be part_completion or subtopic_mastery.");
  }
  onlyKeys(value, ["requestId", "purpose", "templateId", "partId", "courseId", "topicId", "subtopicId"]);
  const catalog = catalogHint(value);
  return {
    requestId: id(value.requestId, "requestId"),
    purpose: "part_completion",
    templateId: id(value.templateId, "templateId"),
    partId: id(value.partId, "partId"),
    ...(catalog === undefined ? {} : { catalog })
  };
}

export function parseGetExamAttempt(data: unknown): GetExamAttemptInput {
  const value = object(data, "data");
  onlyKeys(value, ["attemptId"]);
  return { attemptId: id(value.attemptId, "attemptId") };
}

export interface ReconcileSubtopicAchievementInput {
  courseId: string;
  topicId: string;
  subtopicId: string;
}

/** Only the subtopic to re-check; the server reads everything else. */
export function parseReconcileSubtopicAchievement(
  data: unknown
): ReconcileSubtopicAchievementInput {
  const value = object(data, "data");
  onlyKeys(value, ["courseId", "topicId", "subtopicId"]);
  return {
    courseId: id(value.courseId, "courseId"),
    topicId: id(value.topicId, "topicId"),
    subtopicId: id(value.subtopicId, "subtopicId")
  };
}

export function parseGetAchievementSummary(data: unknown): void {
  const value = object(data, "data");
  onlyKeys(value, []);
}

export function parseSubmitExamAttempt(data: unknown): SubmitExamAttemptInput {
  const { attemptId, answers } = parseAnswers(data, maxAnswersAtSubmit);
  return { attemptId, answers };
}

/** Incremental saves are deliberately smaller than final submission payloads. */
export function parseSaveExamAnswers(data: unknown): SaveExamAnswersInput {
  const { attemptId, answers } = parseAnswers(data, maxAnswersPerSave);
  return { attemptId, answers };
}

export function parseRecordPartSectionCompletion(
  data: unknown
): RecordPartSectionCompletionInput {
  const value = object(data, "data");
  onlyKeys(value, ["partId", "section", "sections", "courseId", "topicId", "subtopicId"]);
  const partId = id(value.partId, "partId");
  const catalog = catalogHint(value);
  const withCatalog = catalog === undefined ? {} : { catalog };
  if (Object.hasOwn(value, "section") === Object.hasOwn(value, "sections")) {
    throw invalidArgument("Provide exactly one of section or sections.");
  }
  if (Object.hasOwn(value, "section")) {
    if (!isPartSection(value.section)) {
      throw invalidArgument("section must be a supported part section.");
    }
    return { partId, section: value.section, ...withCatalog };
  }
  const sections = value.sections;
  if (!Array.isArray(sections) || sections.length < 1 || sections.length > 5 ||
    !sections.every(isPartSection) || new Set(sections).size !== sections.length) {
    throw invalidArgument("sections must contain 1 to 5 distinct supported sections.");
  }
  return { partId, sections: sections as PartSection[], ...withCatalog };
}

function parseAnswers(
  data: unknown,
  maximum: number
): { attemptId: string; answers: Record<string, string> } {
  const value = object(data, "data");
  onlyKeys(value, ["attemptId", "answers"]);
  const rawAnswers = object(value.answers, "answers");
  const entries = Object.entries(rawAnswers);
  if (entries.length > maximum) {
    throw invalidArgument(`answers exceeds the maximum of ${maximum} entries.`);
  }
  const answers: Record<string, string> = {};
  for (const [questionId, alternativeId] of entries) {
    answers[id(questionId, "answers question ID")] = id(
      alternativeId,
      "answers alternative ID"
    );
  }
  return { attemptId: id(value.attemptId, "attemptId"), answers };
}
