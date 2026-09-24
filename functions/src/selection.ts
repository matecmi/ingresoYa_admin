import { createHash } from "node:crypto";

import type {
  CandidateQuestion,
  ExamFilter,
  PartContext,
  SourceType,
  TemplateBlock
} from "./exam_contracts";
import { failedPrecondition } from "./errors";

export interface BoundBlock {
  count: number;
  filter: ExamFilter;
}

export interface SelectedQuestion {
  question: CandidateQuestion;
  alternativeOrder: string[];
}

export interface InsufficientSelection {
  blockIndex: number;
  available: number;
  required: number;
}

export function bindPartCompletionBlocks(
  blocks: readonly TemplateBlock[],
  context: PartContext
): BoundBlock[] {
  return blocks.map((block, index) => {
    const filter = block.filter;
    for (const [name, expected, actual] of [
      ["course", context.courseId, filter.courseId],
      ["topic", context.topicId, filter.topicId],
      ["subtopic", context.subtopicId, filter.subtopicId],
      ["part", context.partId, filter.partId]
    ] as const) {
      if (actual.length > 0 && actual !== expected) {
        throw failedPrecondition(`Template block ${index + 1} does not target the requested ${name}.`);
      }
    }
    return {
      count: block.count,
      filter: {
        ...filter,
        courseId: context.courseId,
        topicId: context.topicId,
        subtopicId: context.subtopicId,
        partId: context.partId
      }
    };
  });
}

export function matchesFilter(question: CandidateQuestion, filter: ExamFilter): boolean {
  return (
    question.partIds.includes(filter.partId) &&
    question.courseId === filter.courseId &&
    question.topicId === filter.topicId &&
    question.subtopicId === filter.subtopicId &&
    (filter.universityId.length === 0 || question.universityId === filter.universityId) &&
    (filter.sourceExamId.length === 0 || question.sourceExamId === filter.sourceExamId) &&
    (filter.modalityId.length === 0 || question.modalityId === filter.modalityId) &&
    (filter.sourceType === "any" || question.sourceType === filter.sourceType) &&
    (filter.difficulty === "any" || question.difficulty === filter.difficulty) &&
    (filter.yearFrom === undefined || (question.year !== undefined && question.year >= filter.yearFrom)) &&
    (filter.yearTo === undefined || (question.year !== undefined && question.year <= filter.yearTo))
  );
}

export function randomStarts(seed: string, count = 4): number[] {
  const random = seededRandom(seed);
  const starts = new Set<number>();
  while (starts.size < count) starts.add(random());
  return [...starts];
}

/**
 * Applies the policy after bounded random-key scans. It favors questions that
 * have lower recent exposure, but sampling and tie-breaks are deliberately
 * not claimed to produce mathematically perfect uniformity.
 */
export function chooseQuestions({
  candidates,
  selectedIds,
  filter,
  count,
  selectionPolicy,
  profileUniversityId,
  allowedFallbackSources,
  recentExposure,
  seed
}: {
  candidates: readonly CandidateQuestion[];
  selectedIds: ReadonlySet<string>;
  filter: ExamFilter;
  count: number;
  selectionPolicy: "strict" | "prefer_profile_university";
  profileUniversityId: string;
  allowedFallbackSources: readonly SourceType[];
  recentExposure: ReadonlyMap<string, number>;
  seed: string;
}): SelectedQuestion[] {
  const eligible = candidates.filter(
    (question) => !selectedIds.has(question.questionId) && matchesFilter(question, filter)
  );
  const primary = eligible.filter((question) => question.universityId === profileUniversityId);
  const fallback = eligible.filter(
    (question) =>
      question.universityId !== profileUniversityId &&
      allowedFallbackSources.includes(question.sourceType)
  );
  const ordered =
    selectionPolicy === "strict"
      ? rank(eligible, recentExposure, seed)
      : [...rank(primary, recentExposure, `${seed}:primary`), ...rank(fallback, recentExposure, `${seed}:fallback`)];
  return ordered.slice(0, count).map((question, index) => ({
    question,
    alternativeOrder: shuffle(
      question.alternatives.map((alternative) => alternative.id),
      `${seed}:alternative:${index}`
    )
  }));
}

export function requireEnough(
  selected: readonly SelectedQuestion[],
  available: number,
  required: number,
  blockIndex: number
): void {
  if (selected.length < required) {
    throw failedPrecondition("Not enough eligible published questions.", {
      reason: "insufficient_questions",
      blockIndex: blockIndex + 1,
      available,
      required
    });
  }
}

export function shuffle<T>(values: readonly T[], seed: string): T[] {
  const random = seededRandom(seed);
  const result = [...values];
  for (let index = result.length - 1; index > 0; index--) {
    const swap = Math.floor(random() * (index + 1));
    [result[index], result[swap]] = [result[swap]!, result[index]!];
  }
  return result;
}

function rank(
  candidates: readonly CandidateQuestion[],
  recentExposure: ReadonlyMap<string, number>,
  seed: string
): CandidateQuestion[] {
  const random = seededRandom(seed);
  return candidates
    .map((question) => ({ question, exposure: recentExposure.get(question.questionId) ?? 0, tie: random() }))
    .sort((left, right) => left.exposure - right.exposure || left.tie - right.tie)
    .map(({ question }) => question);
}

function seededRandom(seed: string): () => number {
  let state = createHash("sha256").update(seed).digest().readUInt32BE(0) || 1;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return (state >>> 0) / 0x1_0000_0000;
  };
}
