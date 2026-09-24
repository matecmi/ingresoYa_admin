import { invalidArgument } from "./errors";
import { isPartSection, type PartSection } from "./part_progress";

export interface CreateExamAttemptInput {
  requestId: string;
  purpose: "part_completion";
  templateId: string;
  partId: string;
}

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

export interface RecordPartSectionCompletionInput {
  partId: string;
  section: PartSection;
}

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

function id(value: unknown, name: string): string {
  if (typeof value !== "string" || !identifier.test(value)) {
    throw invalidArgument(`${name} must be an identifier of up to 128 characters.`);
  }
  return value;
}

export function parseCreateExamAttempt(data: unknown): CreateExamAttemptInput {
  const value = object(data, "data");
  onlyKeys(value, ["requestId", "purpose", "templateId", "partId"]);
  if (value.purpose !== "part_completion") {
    throw invalidArgument("purpose must be part_completion.");
  }
  return {
    requestId: id(value.requestId, "requestId"),
    purpose: "part_completion",
    templateId: id(value.templateId, "templateId"),
    partId: id(value.partId, "partId")
  };
}

export function parseGetExamAttempt(data: unknown): GetExamAttemptInput {
  const value = object(data, "data");
  onlyKeys(value, ["attemptId"]);
  return { attemptId: id(value.attemptId, "attemptId") };
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
  onlyKeys(value, ["partId", "section"]);
  if (!isPartSection(value.section)) {
    throw invalidArgument("section must be a supported part section.");
  }
  return { partId: id(value.partId, "partId"), section: value.section };
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
