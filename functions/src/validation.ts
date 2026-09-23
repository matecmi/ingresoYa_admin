import { invalidArgument } from "./errors";

export interface CreateExamAttemptInput {
  requestId: string;
  templateId: string;
  partId?: string;
}

export interface GetExamAttemptInput {
  attemptId: string;
}

export interface SubmitExamAttemptInput {
  attemptId: string;
  answers: Readonly<Record<string, string>>;
}

const identifier = /^[A-Za-z0-9_-]{1,128}$/;

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
  onlyKeys(value, ["requestId", "templateId", "partId"]);
  const partId = value.partId === undefined ? undefined : id(value.partId, "partId");
  return {
    requestId: id(value.requestId, "requestId"),
    templateId: id(value.templateId, "templateId"),
    ...(partId === undefined ? {} : { partId })
  };
}

export function parseGetExamAttempt(data: unknown): GetExamAttemptInput {
  const value = object(data, "data");
  onlyKeys(value, ["attemptId"]);
  return { attemptId: id(value.attemptId, "attemptId") };
}

export function parseSubmitExamAttempt(data: unknown): SubmitExamAttemptInput {
  const value = object(data, "data");
  onlyKeys(value, ["attemptId", "answers"]);
  const rawAnswers = object(value.answers, "answers");
  const entries = Object.entries(rawAnswers);
  if (entries.length > 200) {
    throw invalidArgument("answers exceeds the maximum supported exam size.");
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
