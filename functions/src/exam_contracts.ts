import { failedPrecondition } from "./errors";

export type SourceType =
  | "admission_exam"
  | "official_practice"
  | "other"
  | "original"
  | "adapted";

export interface ExamFilter {
  universityId: string;
  sourceExamId: string;
  modalityId: string;
  courseId: string;
  topicId: string;
  subtopicId: string;
  partId: string;
  sourceType: SourceType | "any";
  difficulty: "easy" | "medium" | "hard" | "any";
  yearFrom?: number;
  yearTo?: number;
}

export interface TemplateBlock {
  count: number;
  filter: ExamFilter;
}

export interface ExamTemplateRecord {
  id: string;
  version: number;
  title: string;
  purpose: "practice" | "part_completion" | "simulation";
  mode: "dynamic" | "fixed";
  selectionPolicy: "strict" | "prefer_profile_university";
  allowedFallbackSources: SourceType[];
  questionCount: number;
  durationSeconds?: number;
  passPercentExclusive: number;
  blocks: TemplateBlock[];
}

export interface CandidateQuestion {
  questionId: string;
  version: number;
  randomKey: number;
  sourceLabel: string;
  universityId: string;
  sourceType: SourceType;
  sourceExamId: string;
  modalityId: string;
  year?: number;
  courseId: string;
  topicId: string;
  subtopicId: string;
  partIds: string[];
  difficulty: "easy" | "medium" | "hard";
  content: unknown[];
  alternatives: AttemptAlternative[];
}

export interface AttemptAlternative {
  id: string;
  label: string;
  content: unknown[];
}

export interface PartContext {
  partId: string;
  courseId: string;
  topicId: string;
  subtopicId: string;
}

const sourceTypes = new Set<SourceType>([
  "admission_exam",
  "official_practice",
  "other",
  "original",
  "adapted"
]);

const difficulties = new Set(["easy", "medium", "hard"]);

const asRecord = (value: unknown): Record<string, unknown> | undefined =>
  value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;

const asString = (value: unknown): string | undefined =>
  typeof value === "string" && value.trim().length > 0 ? value : undefined;

const asNumber = (value: unknown): number | undefined =>
  typeof value === "number" && Number.isFinite(value) ? value : undefined;

const asPositiveInt = (value: unknown): number | undefined => {
  const number = asNumber(value);
  return number !== undefined && Number.isInteger(number) && number > 0
    ? number
    : undefined;
};

const optionalId = (value: unknown): string =>
  typeof value === "string" ? value.trim() : "";

function parseFilter(value: unknown): ExamFilter | undefined {
  const raw = asRecord(value);
  if (raw === undefined) return undefined;
  const sourceType = raw.sourceType === undefined ? "any" : raw.sourceType;
  const difficulty = raw.difficulty === undefined ? "any" : raw.difficulty;
  const yearFrom = raw.yearFrom === undefined ? undefined : asPositiveInt(raw.yearFrom);
  const yearTo = raw.yearTo === undefined ? undefined : asPositiveInt(raw.yearTo);
  if (
    (sourceType !== "any" && !sourceTypes.has(sourceType as SourceType)) ||
    (difficulty !== "any" && (typeof difficulty !== "string" || !difficulties.has(difficulty))) ||
    (raw.yearFrom !== undefined && yearFrom === undefined) ||
    (raw.yearTo !== undefined && yearTo === undefined) ||
    (yearFrom !== undefined && yearTo !== undefined && yearFrom > yearTo)
  ) {
    return undefined;
  }
  return {
    universityId: optionalId(raw.universityId),
    sourceExamId: optionalId(raw.sourceExamId),
    modalityId: optionalId(raw.modalityId),
    courseId: optionalId(raw.courseId),
    topicId: optionalId(raw.topicId),
    subtopicId: optionalId(raw.subtopicId),
    partId: optionalId(raw.partId),
    sourceType: sourceType as ExamFilter["sourceType"],
    difficulty: difficulty as ExamFilter["difficulty"],
    ...(yearFrom === undefined ? {} : { yearFrom }),
    ...(yearTo === undefined ? {} : { yearTo })
  };
}

export function parseTemplate(
  data: Record<string, unknown>,
  expectedId: string
): ExamTemplateRecord {
  const rawBlocks: unknown[] | undefined = Array.isArray(data.blocks)
    ? (data.blocks as unknown[])
    : undefined;
  const blocks = rawBlocks !== undefined
    ? rawBlocks
        .map((raw) => {
          const block = asRecord(raw);
          const count = block === undefined ? undefined : asPositiveInt(block.count);
          const filter = block === undefined ? undefined : parseFilter(block.filter);
          return count === undefined || filter === undefined ? undefined : { count, filter };
        })
        .filter((block): block is TemplateBlock => block !== undefined)
    : [];
  const rawFallback: unknown[] | undefined = Array.isArray(data.allowedFallbackSources)
    ? (data.allowedFallbackSources as unknown[])
    : undefined;
  const fallback = rawFallback !== undefined
    ? rawFallback.filter(
        (source): source is SourceType => typeof source === "string" && sourceTypes.has(source as SourceType)
      )
    : [];
  const id = asString(data.id);
  const version = asPositiveInt(data.version);
  const title = asString(data.title);
  const questionCount = asPositiveInt(data.questionCount);
  const passPercentExclusive = asNumber(data.passPercentExclusive);
  const duration = data.durationSeconds === undefined ? undefined : asPositiveInt(data.durationSeconds);
  if (
    data.schemaVersion !== 2 ||
    data.status !== "published" ||
    data.active === false ||
    id !== expectedId ||
    version === undefined ||
    title === undefined ||
    !["practice", "part_completion", "simulation"].includes(data.purpose as string) ||
    !["dynamic", "fixed"].includes(data.mode as string) ||
    !["strict", "prefer_profile_university"].includes(data.selectionPolicy as string) ||
    questionCount === undefined ||
    passPercentExclusive === undefined ||
    !Number.isInteger(passPercentExclusive) ||
    passPercentExclusive < 0 ||
    passPercentExclusive >= 100 ||
    (data.durationSeconds !== undefined && duration === undefined) ||
    (rawBlocks === undefined || rawBlocks.length !== blocks.length) ||
    (rawFallback === undefined || rawFallback.length !== fallback.length) ||
    (data.mode === "dynamic" && blocks.reduce((sum, block) => sum + block.count, 0) !== questionCount) ||
    (data.selectionPolicy === "strict" && fallback.length > 0)
  ) {
    throw failedPrecondition("The selected template is not publishable.");
  }
  return {
    id,
    version,
    title,
    purpose: data.purpose as ExamTemplateRecord["purpose"],
    mode: data.mode as ExamTemplateRecord["mode"],
    selectionPolicy: data.selectionPolicy as ExamTemplateRecord["selectionPolicy"],
    allowedFallbackSources: fallback,
    questionCount,
    ...(duration === undefined ? {} : { durationSeconds: duration }),
    passPercentExclusive,
    blocks
  };
}

export function parseCandidateQuestion(
  questionId: string,
  data: Record<string, unknown>
): CandidateQuestion | undefined {
  const alternatives = Array.isArray(data.alternatives)
    ? data.alternatives
        .map((value) => {
          const alternative = asRecord(value);
          const id = alternative === undefined ? undefined : asString(alternative.id);
          const label = alternative === undefined ? undefined : asString(alternative.label);
          const content = alternative?.content;
          if (
            alternative === undefined ||
            id === undefined ||
            label === undefined ||
            !Array.isArray(content)
          ) {
            return undefined;
          }
          // A malformed public projection is not an eligible candidate.
          if (Object.hasOwn(alternative, "isCorrect")) return undefined;
          return { id, label, content };
        })
        .filter((alternative): alternative is AttemptAlternative => alternative !== undefined)
    : [];
  const sourceType = data.sourceType;
  const difficulty = data.difficulty;
  const version = asPositiveInt(data.version);
  const randomKey = asNumber(data.randomKey);
  if (
    data.schemaVersion !== 2 ||
    data.status !== "published" ||
    Object.hasOwn(data, "correctAlternativeId") ||
    Object.hasOwn(data, "explanation") ||
    version === undefined ||
    randomKey === undefined ||
    randomKey < 0 ||
    randomKey >= 1 ||
    !sourceTypes.has(sourceType as SourceType) ||
    typeof difficulty !== "string" ||
    !difficulties.has(difficulty) ||
    !Array.isArray(data.content) ||
    alternatives.length < 2 ||
    new Set(alternatives.map((alternative) => alternative.id)).size !== alternatives.length
  ) {
    return undefined;
  }
  const partIds = Array.isArray(data.partIds)
    ? data.partIds.filter((part): part is string => typeof part === "string" && part.length > 0)
    : [];
  return {
    questionId,
    version,
    randomKey,
    sourceLabel: typeof data.sourceLabel === "string" ? data.sourceLabel : "",
    universityId: optionalId(data.universityId),
    sourceType: sourceType as SourceType,
    sourceExamId: optionalId(data.sourceExamId),
    modalityId: optionalId(data.modalityId),
    ...(asPositiveInt(data.year) === undefined ? {} : { year: asPositiveInt(data.year) }),
    courseId: optionalId(data.courseId),
    topicId: optionalId(data.topicId),
    subtopicId: optionalId(data.subtopicId),
    partIds,
    difficulty: difficulty as CandidateQuestion["difficulty"],
    content: data.content,
    alternatives
  };
}
