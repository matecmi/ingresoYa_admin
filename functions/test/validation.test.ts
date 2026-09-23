import assert from "node:assert/strict";
import test from "node:test";

import { readBackendConfig } from "../src/config";
import { ExamBackendError } from "../src/errors";
import { requireUid } from "../src/handlers";
import {
  parseCreateExamAttempt,
  parseSubmitExamAttempt
} from "../src/validation";

test("maps each declared deployment environment to isolated collections", () => {
  expectConfig("test", "iya-questions-test");
  expectConfig("staging", "iya-questions-staging");
  expectConfig("production", "iya-questions");
});

test("requires an explicit environment outside tests and emulators", () => {
  assert.throws(() => readBackendConfig({}), /INGRESOYA_ENV/);
});

test("create input rejects client-controlled attempt fields", () => {
  assert.throws(
    () =>
      parseCreateExamAttempt({
        requestId: "request-1",
        templateId: "template-1",
        questionCount: 999,
        userId: "another-user"
      }),
    isInvalidArgument
  );
});

test("submit accepts IDs only and bounds answer payloads", () => {
  assert.deepEqual(
    parseSubmitExamAttempt({
      attemptId: "attempt-1",
      answers: { "question-1": "alternative-a" }
    }),
    { attemptId: "attempt-1", answers: { "question-1": "alternative-a" } }
  );
  assert.throws(
    () =>
      parseSubmitExamAttempt({
        attemptId: "attempt-1",
        answers: { "bad id": "alternative-a" }
      }),
    isInvalidArgument
  );
});

test("callables reject anonymous callers with a typed error", () => {
  assert.throws(
    () => requireUid({} as Parameters<typeof requireUid>[0]),
    (error: unknown) =>
      error instanceof ExamBackendError && error.code === "unauthenticated"
  );
});

function expectConfig(environment: string, questions: string): void {
  const config = readBackendConfig({ INGRESOYA_ENV: environment });
  assert.equal(config.collections.questions, questions);
}

function isInvalidArgument(error: unknown): boolean {
  return error instanceof ExamBackendError && error.code === "invalid-argument";
}
