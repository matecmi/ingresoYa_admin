import assert from "node:assert/strict";
import test from "node:test";

import { readBackendConfig } from "../src/config";
import {
  emptyAchievementSummary,
  includeAchievement,
  includeMastery,
  readAchievementSummary,
  summaryFromAwards
} from "../src/achievement_summary";
import { asHttpsError, ExamBackendError, notFound } from "../src/errors";
import { requireUid } from "../src/handlers";
import { errorDiagnostic } from "../src/logging";
import { OperationMetrics } from "../src/operation_metrics";
import {
  assessExamApproval,
  assessSectionCompletion,
  readPartProgress,
  requiredPartSections,
  requiredSectionsForPart
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
import {
  bindSubtopicMasteryBlocks,
  chooseQuestions,
  matchesFilter,
  randomStarts,
  requireEnough,
  shuffle
} from "../src/selection";
import {
  assessSubtopicCompletion,
  masteryAwardId,
  publishedSubtopicRequirement
} from "../src/subtopic_achievement";
import {
  parseCreateExamAttempt,
  parseGetAchievementSummary,
  parseRecordPartSectionCompletion,
  parseSaveExamAnswers,
  parseSubmitExamAttempt
} from "../src/validation";

test("achievement projection keeps one badge per subtopic across requirement versions", () => {
  const base = {
    courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1"
  };
  const first = includeAchievement(emptyAchievementSummary(), {
    ...base, requirementVersion: "v1", awardedAtMs: 10
  });
  const next = includeAchievement(first, {
    ...base, requirementVersion: "v2", awardedAtMs: 20
  });
  assert.equal(next.totalCompletedSubtopics, 1);
  assert.equal(next.recent.length, 1);
  assert.equal(next.recent[0]?.requirementVersion, "v2");
  assert.equal(summaryFromAwards([]).totalCompletedSubtopics, 0);
});

test("mastery summary extends legacy fields and deduplicates by subtopic", () => {
  const completed = includeAchievement(emptyAchievementSummary(), {
    courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1",
    requirementVersion: "parts-v1", awardedAtMs: 10
  });
  const preview = {
    courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1",
    templateId: "mastery-1", templateVersion: 1, examAttemptId: "attempt-1", awardedAtMs: 20
  };
  const first = includeMastery(completed, preview);
  const repeated = includeMastery(first, { ...preview, templateVersion: 2, awardedAtMs: 30 });
  assert.equal(repeated.totalCompletedSubtopics, 1);
  assert.equal(repeated.totalMasteredSubtopics, 1);
  assert.equal(repeated.recentMastery.length, 1);
  assert.equal(repeated.recentMastery[0]?.templateVersion, 2);
  assert.deepEqual(readAchievementSummary(repeated), repeated);
  assert.equal(readAchievementSummary({
    schemaVersion: 1, completedSubtopicKeys: [], recent: []
  }), undefined);
  const revised = { ...preview, templateVersion: 3 };
  assert.equal(masteryAwardId(preview), masteryAwardId(revised));
});

test("achievement summary callable accepts no client-controlled scope", () => {
  assert.doesNotThrow(() => parseGetAchievementSummary({}));
  assert.throws(() => parseGetAchievementSummary({ uid: "other-user" }), ExamBackendError);
});

test("maps each declared deployment environment to isolated collections", () => {
  expectConfig("test", "iya-questions-test");
  expectConfig("staging", "iya-questions-staging");
  expectConfig("production", "iya-questions");
});

test("selection cost limits have bounded, versioned defaults", () => {
  const defaults = readBackendConfig({ INGRESOYA_ENV: "test" }).selection;
  assert.deepEqual(defaults, {
    candidateStartsPerBlock: 4,
    maxCandidatesPerStart: 80,
    recentQuestionLimit: 200
  });
  assert.throws(
    () => readBackendConfig({ INGRESOYA_ENV: "test", EXAM_MAX_CANDIDATES_PER_START: "81" }),
    /EXAM_MAX_CANDIDATES_PER_START/
  );
});

test("operation telemetry reports only aggregate work counts", () => {
  const metrics = new OperationMetrics();
  metrics.readDocument(3);
  metrics.readQuery(5);
  metrics.writeDocument(2);
  metrics.transactionAttempt();
  const fields = metrics.logFields();
  assert.equal(fields.observedDocumentReads, 8);
  assert.equal(fields.directDocumentReads, 3);
  assert.equal(fields.queryCalls, 1);
  assert.equal(fields.queryDocuments, 5);
  assert.equal(fields.plannedDocumentWrites, 2);
  assert.equal(fields.transactionAttempts, 1);
});

test("callable errors expose a stable reason without leaking private data to logs", () => {
  const error = notFound("Exam template not found.", "template_not_found");
  assert.deepEqual(asHttpsError(error).details, { reason: "template_not_found" });
  const diagnostic = errorDiagnostic(error, { environment: "test", uid: "private-user-id" });
  assert.equal(diagnostic.errorCode, "not-found");
  assert.equal(diagnostic.reason, "template_not_found");
  assert.equal(diagnostic.environment, "test");
  assert.match(diagnostic.actor ?? "", /^[a-f0-9]{12}$/);
  assert.equal(JSON.stringify(diagnostic).includes("private-user-id"), false);
  assert.equal(JSON.stringify(diagnostic).includes("Exam template not found"), false);
  assert.equal(errorDiagnostic(new Error("secret answer"), { environment: "test" }).reason,
    "unexpected_server_error");
});

test("App Check is enforced in production and can be explicitly configured per environment", () => {
  assert.equal(
    readBackendConfig({ INGRESOYA_ENV: "production" }).enforceAppCheck,
    true
  );
  assert.equal(
    readBackendConfig({
      INGRESOYA_ENV: "staging",
      FUNCTIONS_ENFORCE_APP_CHECK: "true"
    }).enforceAppCheck,
    true
  );
  assert.equal(
    readBackendConfig({
      INGRESOYA_ENV: "test",
      FUNCTIONS_ENFORCE_APP_CHECK: "false"
    }).enforceAppCheck,
    false
  );
  assert.throws(
    () => readBackendConfig({ INGRESOYA_ENV: "test", FUNCTIONS_ENFORCE_APP_CHECK: "yes" }),
    /FUNCTIONS_ENFORCE_APP_CHECK/
  );
  assert.throws(
    () => readBackendConfig({ INGRESOYA_ENV: "production", FUNCTIONS_ENFORCE_APP_CHECK: "false" }),
    /cannot be false in production/
  );
});

test("requires an explicit environment outside tests and emulators", () => {
  assert.throws(() => readBackendConfig({}), /INGRESOYA_ENV/);
});

test("inactive templates cannot be used to create new attempts", () => {
  const active = templateRecord();
  assert.equal(parseTemplate(active, "template-1").id, "template-1");
  assert.throws(() => parseTemplate({ ...active, active: false }, "template-1"));
});

test("mastery template is dynamic and blocks stay inside the requested subtopic", () => {
  const raw = { ...templateRecord(), purpose: "subtopic_mastery", blocks: [{ count: 1, filter: {} }] };
  const template = parseTemplate(raw, "template-1");
  assert.equal(template.purpose, "subtopic_mastery");
  assert.throws(() => parseTemplate({ ...raw, mode: "fixed" }, "template-1"));
  const context = { courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1" };
  const bound = bindSubtopicMasteryBlocks(template.blocks, context);
  assert.equal(bound[0]?.filter.partId, "");
  assert.equal(matchesFilter(candidate("question-1", "university-1", "original"), bound[0]!.filter), true);
  const partBlock = bindSubtopicMasteryBlocks(
    [{ count: 1, filter: { ...bound[0]!.filter, partId: "part-1" } }], context
  );
  assert.equal(partBlock[0]?.filter.partId, "part-1");
  assert.throws(() => bindSubtopicMasteryBlocks(
    [{ count: 1, filter: { ...bound[0]!.filter, subtopicId: "other" } }], context
  ));
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

test("mastery create accepts only request ID, purpose, context and template", () => {
  const request = {
    requestId: "mastery-request-1", purpose: "subtopic_mastery",
    courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1",
    templateId: "mastery-1"
  };
  assert.deepEqual(parseCreateExamAttempt(request), request);
  for (const extra of [{ count: 10 }, { filters: {} }, { passPercentExclusive: 80 }, { partId: "part-1" }]) {
    assert.throws(() => parseCreateExamAttempt({ ...request, ...extra }), isInvalidArgument);
  }
  assert.throws(() => parseCreateExamAttempt({ ...request, topicId: undefined }), isInvalidArgument);
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
  assert.deepEqual(
    parseRecordPartSectionCompletion({ partId: "part-1", sections: ["video", "lesson"] }),
    { partId: "part-1", sections: ["video", "lesson"] }
  );
  for (const sections of [[], ["video", "video"], ["video", "clicked"]]) {
    assert.throws(
      () => parseRecordPartSectionCompletion({ partId: "part-1", sections }),
      isInvalidArgument
    );
  }
  assert.throws(
    () => parseRecordPartSectionCompletion({ partId: "part-1", section: "video", sections: ["lesson"] }),
    isInvalidArgument
  );
});

test("recovery projects a frozen public snapshot and saved answers without keys", () => {
  const response = projectAttemptResponse("attempt-1", attemptRecord("in_progress", tomorrow()));
  assert.equal(response.status, "in_progress");
  assert.deepEqual(response.answers, { "question-1": "alternative-a" });
  assert.equal(response.questions[0]?.questionId, "question-1");
  assert.equal(response.questions[0]?.alternatives[0]?.id, "alternative-a");
  assert.equal(response.requestId, "request-1");
  assert.equal(response.templateId, "template-1");
  assert.equal(response.partId, "part-1");
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

test("a part only requires the sections it has content for", () => {
  assert.deepEqual(
    requiredSectionsForPart({
      linkVideo: "https://youtu.be/x", content: "Lección", examples: [{}],
      flashcards: [{}], linkPdf: "https://example.com/a.pdf"
    }),
    requiredPartSections
  );
  assert.deepEqual(
    requiredSectionsForPart({ linkVideo: "  ", content: "Lección", flashcards: [{}] }),
    ["lesson", "review"]
  );
  assert.deepEqual(requiredSectionsForPart({}), []);
});

test("a part without a video is verified with its own sections and the exam", () => {
  const context = partContext();
  const required = ["lesson", "examples", "review", "resources"] as const;
  const state = readPartProgress(
    partProgressRecord(context, ["lesson", "examples", "review", "resources"]),
    context,
    required
  );
  const assessment = assessExamApproval(state, "attempt-1");
  assert.equal(assessment.status, "verified");
  assert.equal(assessment.shouldMarkCompleted, true);
  assert.deepEqual(assessment.missingSections, []);

  // Stored with the list it was verified with, it stays valid later.
  const stored = readPartProgress(
    {
      ...partProgressRecord(context, [...required], "attempt-1", true),
      requiredSections: [...required]
    },
    context
  );
  assert.equal(stored.completed, true);
});

test("part requests may say where the part lives, all three IDs or none", () => {
  const base = { requestId: "r-1", purpose: "part_completion", templateId: "t-1", partId: "p-1" };
  assert.deepEqual(parseCreateExamAttempt(base), base);
  assert.deepEqual(
    parseCreateExamAttempt({ ...base, courseId: "c-1", topicId: "t-9", subtopicId: "s-1" }),
    { ...base, catalog: { courseId: "c-1", topicId: "t-9", subtopicId: "s-1" } }
  );
  assert.throws(() => parseCreateExamAttempt({ ...base, courseId: "c-1" }), isInvalidArgument);
  assert.deepEqual(
    parseRecordPartSectionCompletion({
      partId: "p-1", sections: ["lesson"], courseId: "c-1", topicId: "t-9", subtopicId: "s-1"
    }),
    { partId: "p-1", sections: ["lesson"], catalog: { courseId: "c-1", topicId: "t-9", subtopicId: "s-1" } }
  );
  assert.throws(
    () => parseRecordPartSectionCompletion({ partId: "p-1", section: "lesson", subtopicId: "s-1" }),
    isInvalidArgument
  );
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

test("a subtopic award requirement versions the active part set, not its order or labels", () => {
  const context = { courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1" };
  const active = { active: true };
  const original = publishedSubtopicRequirement(context, active, active, {
    active: true,
    listPart: [{ id: "part-2", name: "Second" }, { id: "part-1", name: "First" }]
  });
  const reordered = publishedSubtopicRequirement(context, active, active, {
    active: true,
    listPart: [{ id: "part-1", name: "Renamed" }, { id: "part-2" }]
  });
  const expanded = publishedSubtopicRequirement(context, active, active, {
    active: true,
    listPart: [{ id: "part-1" }, { id: "part-2" }, { id: "part-3" }]
  });
  assert.ok(original);
  assert.ok(reordered);
  assert.ok(expanded);
  assert.deepEqual(original.requiredPartIds, ["part-1", "part-2"]);
  assert.equal(original.requirementVersion, reordered.requirementVersion);
  assert.notEqual(original.requirementVersion, expanded.requirementVersion);
  assert.equal(
    publishedSubtopicRequirement(context, active, active, {
      active: true,
      listPart: [{ id: "part-1" }, { id: "part-2", active: false }]
    })?.requiredPartIds.length,
    1
  );
});

test("subtopic completion accepts only verified v2 parts and fails closed on invalid catalogs", () => {
  const context = { courseId: "course-1", topicId: "topic-1", subtopicId: "subtopic-1" };
  const active = { active: true };
  const catalog = { active: true, listPart: [{ id: "part-1" }, { id: "part-2" }] };
  const requirement = publishedSubtopicRequirement(context, active, active, catalog);
  assert.ok(requirement);
  const firstContext = { ...context, partId: "part-1" };
  const progress = {
    "part-1": partProgressRecord(firstContext, requiredPartSections, "attempt-1", true),
    "part-2": { completed: true, score: 100 }
  };
  assert.deepEqual(assessSubtopicCompletion(requirement, progress), {
    complete: false,
    missingPartIds: ["part-2"]
  });
  assert.deepEqual(assessSubtopicCompletion(requirement, progress, "part-2"), {
    complete: true,
    missingPartIds: []
  });
  assert.deepEqual(assessSubtopicCompletion(requirement, {
    "part-1": { ...progress["part-1"], subtopicId: "other-subtopic" },
    "part-2": progress["part-2"]
  }), { complete: false, missingPartIds: ["part-1", "part-2"] });
  assert.equal(publishedSubtopicRequirement(context, active, active, { listPart: [] }), undefined);
  assert.equal(
    publishedSubtopicRequirement(context, active, active, {
      listPart: [{ id: "part-1" }, { id: "part-1" }]
    }),
    undefined
  );
  assert.equal(publishedSubtopicRequirement(context, active, { active: false }, catalog), undefined);
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
    requestId: "request-1",
    templateId: "template-1",
    templateVersion: 1,
    partId: "part-1",
    createdAtMs: 1,
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
