import assert from "node:assert/strict";
import test from "node:test";

import { readBackendConfig } from "../src/config";
import { ExamBackendError } from "../src/errors";
import { requireUid } from "../src/handlers";
import type { CandidateQuestion } from "../src/exam_contracts";
import { chooseQuestions, randomStarts, requireEnough, shuffle } from "../src/selection";
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
        purpose: "part_completion",
        templateId: "template-1",
        questionCount: 999,
        userId: "another-user"
      }),
    isInvalidArgument
  );
});

test("selection prefers the profile university before authorized fallback sources", () => {
  const filter = {
    universityId: "",
    sourceExamId: "",
    modalityId: "",
    courseId: "course-1",
    topicId: "topic-1",
    subtopicId: "subtopic-1",
    partId: "part-1",
    sourceType: "any" as const,
    difficulty: "any" as const
  };
  const selected = chooseQuestions({
    candidates: [candidate("profile", "university-1", "original"), candidate("fallback", "university-2", "adapted")],
    selectedIds: new Set(),
    filter,
    count: 2,
    selectionPolicy: "prefer_profile_university",
    profileUniversityId: "university-1",
    allowedFallbackSources: ["adapted"],
    recentExposure: new Map([["profile", 5], ["fallback", 0]]),
    seed: "selection"
  });
  assert.deepEqual(selected.map((item) => item.question.questionId), ["profile", "fallback"]);
  assert.throws(() => requireEnough(selected.slice(0, 1), 1, 2, 0), (error: unknown) => {
    return error instanceof ExamBackendError && error.details?.available === 1 && error.details.required === 2;
  });
});

test("selection never uses an unauthorized fallback and random starts are distinct", () => {
  const filter = {
    universityId: "",
    sourceExamId: "",
    modalityId: "",
    courseId: "course-1",
    topicId: "topic-1",
    subtopicId: "subtopic-1",
    partId: "part-1",
    sourceType: "any" as const,
    difficulty: "any" as const
  };
  const selected = chooseQuestions({
    candidates: [candidate("other", "university-2", "admission_exam")],
    selectedIds: new Set(),
    filter,
    count: 1,
    selectionPolicy: "prefer_profile_university",
    profileUniversityId: "university-1",
    allowedFallbackSources: ["adapted"],
    recentExposure: new Map(),
    seed: "strict-fallback"
  });
  assert.equal(selected.length, 0);
  const starts = randomStarts("starts", 4);
  assert.equal(new Set(starts).size, 4);
  assert.deepEqual(shuffle(["a", "b", "c"], "stable"), shuffle(["a", "b", "c"], "stable"));
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

function candidate(
  questionId: string,
  universityId: string,
  sourceType: CandidateQuestion["sourceType"]
): CandidateQuestion {
  return {
    questionId,
    version: 1,
    randomKey: 0.5,
    sourceLabel: "Fuente",
    universityId,
    sourceType,
    sourceExamId: "",
    modalityId: "",
    courseId: "course-1",
    topicId: "topic-1",
    subtopicId: "subtopic-1",
    partIds: ["part-1"],
    difficulty: "medium",
    content: [],
    alternatives: [
      { id: "a", label: "A", content: [] },
      { id: "b", label: "B", content: [] }
    ]
  };
}
