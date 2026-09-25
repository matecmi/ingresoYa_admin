import assert from "node:assert/strict";
import test from "node:test";

import { readBackendConfig } from "../src/config";
import { ExamBackendError } from "../src/errors";
import { requireUid } from "../src/handlers";
import {
  assessExamApproval,
  assessSectionCompletion,
  readPartProgress,
  requiredPartSections
} from "../src/part_progress";
import {
  gradeFrozenAttempt,
  projectAttemptResponse,
  validateAnswerPatch,
  type AttemptQuestionSnapshot,
  type FrozenAnswerKey
} from "../src/attempt_service";
import type { CandidateQuestion } from "../src/exam_contracts";
import { parseTemplate } from "../src/exam_contracts";
import { chooseQuestions, randomStarts, requireEnough, shuffle } from "../src/selection";
import {
  parseCreateExamAttempt,
  parseRecordPartSectionCompletion,
  parseSaveExamAnswers,
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

test("inactive templates cannot be used to create new attempts", () => {
  const active = templateRecord();
  assert.equal(parseTemplate(active, "template-1").id, "template-1");
  assert.throws(() => parseTemplate({ ...active, active: false }, "template-1"));
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

test("incremental answer saves accept a small ID-only patch", () => {
  assert.deepEqual(
    parseSaveExamAnswers({
      attemptId: "attempt-1",
      answers: { "question-1": "alternative-a" }
    }),
    { attemptId: "attempt-1", answers: { "question-1": "alternative-a" } }
  );
  assert.throws(
    () =>
      parseSaveExamAnswers({
        attemptId: "attempt-1",
        answers: Object.fromEntries(Array.from({ length: 51 }, (_, index) => [`question-${index}`, "a"]))
      }),
    isInvalidArgument
  );
});

test("part-section completion accepts only the five server-defined sections", () => {
  assert.deepEqual(
    parseRecordPartSectionCompletion({ partId: "part-1", section: "lesson" }),
    { partId: "part-1", section: "lesson" }
  );
  assert.throws(
    () => parseRecordPartSectionCompletion({ partId: "part-1", section: "clicked" }),
    isInvalidArgument
  );
});

test("recovery projects a frozen public snapshot and saved answers without keys", () => {
  const response = projectAttemptResponse("attempt-1", attemptRecord("in_progress", tomorrow()));
  assert.equal(response.status, "in_progress");
  assert.deepEqual(response.answers, { "question-1": "alternative-a" });
  assert.equal(response.questions[0]?.questionId, "question-1");
  assert.equal(response.questions[0]?.alternatives[0]?.id, "alternative-a");
  const serialized = JSON.stringify(response);
  assert.equal(serialized.includes("correctAlternativeId"), false);
  assert.equal(serialized.includes("explanation"), false);
  assert.equal(serialized.includes("isCorrect"), false);
});

test("recovery distinguishes expired and submitted attempts", () => {
  assert.equal(projectAttemptResponse("expired", attemptRecord("in_progress", yesterday())).status, "expired");
  assert.equal(projectAttemptResponse("submitted", attemptRecord("submitted", yesterday())).status, "submitted");
});

test("answer patches must target an alternative in the frozen attempt", () => {
  const questions = projectAttemptResponse("attempt-1", attemptRecord("in_progress", tomorrow())).questions;
  assert.doesNotThrow(() => validateAnswerPatch(questions, { "question-1": "alternative-a" }));
  assert.throws(() => validateAnswerPatch(questions, { "question-2": "alternative-a" }), isInvalidArgument);
  assert.throws(() => validateAnswerPatch(questions, { "question-1": "alternative-z" }), isInvalidArgument);
});

test("an exclusive 80 percent requirement needs 9 out of 10 correct answers", () => {
  const questions = frozenQuestions(10);
  const keys = frozenKeys(questions);
  const eightCorrect = Object.fromEntries(
    questions.map((question, index) => [question.questionId, index < 8 ? "a" : "b"])
  );
  const nineCorrect = { ...eightCorrect, "question-9": "a" };

  const failed = gradeFrozenAttempt(questions, eightCorrect, keys, 80);
  assert.equal(Math.floor((questions.length * 80) / 100) + 1, 9);
  assert.equal(failed.correctAnswers, 8);
  assert.equal(failed.percentage, 80);
  assert.equal(failed.passed, false);

  const passed = gradeFrozenAttempt(questions, nineCorrect, keys, 80);
  assert.equal(passed.correctAnswers, 9);
  assert.equal(passed.percentage, 90);
  assert.equal(passed.passed, true);
});

test("grading rejects a key that does not belong to the frozen question version", () => {
  const questions = frozenQuestions(1);
  const keys = frozenKeys(questions);
  keys[0] = { ...keys[0]!, correctAlternativeId: "unknown" };
  assert.throws(() => gradeFrozenAttempt(questions, { "question-1": "a" }, keys, 80));
});

test("a passed part exam remains provisional until all v2 sections have evidence", () => {
  const context = partContext();
  const state = readPartProgress(
    partProgressRecord(context, ["video", "lesson", "examples"]),
    context
  );
  const assessment = assessExamApproval(state, "attempt-1");
  assert.equal(assessment.status, "provisional");
  assert.deepEqual(assessment.missingSections, ["review", "resources"]);
  assert.equal(assessment.shouldRecordApproval, true);
  assert.equal(assessment.shouldMarkCompleted, false);
});

test("a later final section verifies a provisional approved part exactly once", () => {
  const context = partContext();
  const state = readPartProgress(
    partProgressRecord(context, ["video", "lesson", "examples", "review"], "attempt-1"),
    context
  );
  const completion = assessSectionCompletion(state, "resources");
  assert.equal(completion.status, "verified");
  assert.deepEqual(completion.missingSections, []);
  assert.equal(completion.shouldMarkCompleted, true);
  assert.equal(completion.effectiveExamAttemptId, "attempt-1");

  const verified = readPartProgress(
    partProgressRecord(context, requiredPartSections, "attempt-1", true),
    context
  );
  const retry = assessExamApproval(verified, "attempt-1");
  assert.equal(retry.status, "verified");
  assert.equal(retry.shouldRecordApproval, false);
  assert.equal(retry.shouldMarkCompleted, false);
});

test("legacy section clicks never become v2 completion evidence", () => {
  const context = partContext();
  const legacy = readPartProgress(
    { videoViewed: true, lessonClicked: true, sections: { video: { clickedAt: "old" } } },
    context
  );
  const assessment = assessExamApproval(legacy, "attempt-1");
  assert.equal(assessment.status, "provisional");
  assert.deepEqual(assessment.missingSections, requiredPartSections);
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

function templateRecord(): Record<string, unknown> {
  return {
    schemaVersion: 2,
    id: "template-1",
    version: 1,
    title: "Plantilla",
    status: "published",
    active: true,
    purpose: "part_completion",
    mode: "dynamic",
    selectionPolicy: "strict",
    allowedFallbackSources: [],
    questionCount: 1,
    passPercentExclusive: 80,
    blocks: [{ count: 1, filter: { partId: "part-1" } }]
  };
}

function attemptRecord(status: string, expiresAt: Date): Record<string, unknown> {
  return {
    userId: "user-1",
    status,
    expiresAt,
    requiredCorrectAnswers: 1,
    templateSnapshot: { title: "Práctica", hiddenPolicy: "private" },
    answers: { "question-1": "alternative-a", unknown: "alternative-a" },
    result: { score: 1 },
    questionSnapshots: [
      {
        questionId: "question-1",
        version: 1,
        order: 0,
        content: [{ type: "paragraph", text: "Enunciado" }],
        sourceLabel: "Origen",
        correctAlternativeId: "alternative-a",
        explanation: "Privada",
        alternatives: [
          {
            id: "alternative-a",
            label: "A",
            content: [{ type: "paragraph", text: "Una" }],
            isCorrect: true
          },
          {
            id: "alternative-b",
            label: "B",
            content: [{ type: "paragraph", text: "Dos" }],
            isCorrect: false
          }
        ],
        alternativeOrder: ["alternative-b", "alternative-a"]
      }
    ]
  };
}

function tomorrow(): Date {
  return new Date(Date.now() + 24 * 60 * 60 * 1000);
}

function yesterday(): Date {
  return new Date(Date.now() - 24 * 60 * 60 * 1000);
}

function frozenQuestions(count: number): AttemptQuestionSnapshot[] {
  return Array.from({ length: count }, (_, index) => ({
    questionId: `question-${index + 1}`,
    version: 1,
    order: index,
    content: [],
    alternatives: [
      { id: "a", label: "A", content: [] },
      { id: "b", label: "B", content: [] }
    ],
    sourceLabel: "Origen",
    alternativeOrder: ["a", "b"]
  }));
}

function frozenKeys(questions: readonly AttemptQuestionSnapshot[]): FrozenAnswerKey[] {
  return questions.map((question) => ({
    questionId: question.questionId,
    version: question.version,
    correctAlternativeId: "a",
    explanation: [{ id: `explanation-${question.questionId}`, type: "text", text: "Explicación" }]
  }));
}

function partContext() {
  return { partId: "part-1", courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1" };
}

function partProgressRecord(
  context: ReturnType<typeof partContext>,
  sections: readonly string[],
  approvedExamAttemptId?: string,
  completed = false
): Record<string, unknown> {
  return {
    schemaVersion: 2,
    ...context,
    sections: Object.fromEntries(sections.map((section) => [section, { completedAt: "server" }])),
    ...(approvedExamAttemptId === undefined ? {} : { approvedExamAttemptId }),
    ...(completed ? { completed: true, examAttemptId: approvedExamAttemptId } : {})
  };
}
