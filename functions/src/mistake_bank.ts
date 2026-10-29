/**
 * «Mis errores» (lienzo «Mis errores · Flujo D», 2026-10-29): el banco de
 * preguntas falladas o en blanco de cada alumno y su misión diaria
 * («Corrige 5 errores»). Vive dentro de `simulatorSummary/current.mistakes`,
 * que el envío del Simulador ya lee y escribe: no suma operaciones.
 * Contrato: docs/mistakes_contract.md.
 */

/** `{config}/simulator.mistakes`; todo campo ausente o inválido usa el de fábrica. */
export interface MistakeSettings {
  enabled: boolean;
  missionEnabled: boolean;
  /** Errores a corregir en el día para cumplir la misión. */
  missionSize: number;
  missionXp: number;
  /** Aciertos seguidos para salir del banco. */
  exitHits: number;
  bankMax: number;
  /** Lo más largo que ofrece «Practicar» (la app arma 3/10/20 hasta este tope). */
  practiceMax: number;
  /** Sumar también los exámenes de la guía (parte y dominio). */
  includeGuide: boolean;
  fixXp: number;
  fixXpDailyCap: number;
}

export const defaultMistakeSettings: MistakeSettings = {
  enabled: true,
  missionEnabled: true,
  missionSize: 5,
  missionXp: 15,
  exitHits: 1,
  bankMax: 300,
  practiceMax: 20,
  includeGuide: false,
  fixXp: 3,
  fixXpDailyCap: 30
};

function bounded(value: unknown, fallback: number, min: number, max: number): number {
  return typeof value === "number" && Number.isInteger(value) && value >= min && value <= max ? value : fallback;
}

export function parseMistakeSettings(value: unknown): MistakeSettings {
  const raw = value !== null && typeof value === "object" ? value as Record<string, unknown> : {};
  const d = defaultMistakeSettings;
  return {
    enabled: raw.enabled !== false,
    missionEnabled: raw.missionEnabled !== false,
    missionSize: bounded(raw.missionSize, d.missionSize, 1, 20),
    missionXp: bounded(raw.missionXp, d.missionXp, 0, 200),
    exitHits: bounded(raw.exitHits, d.exitHits, 1, 3),
    bankMax: bounded(raw.bankMax, d.bankMax, 50, 500),
    practiceMax: bounded(raw.practiceMax, d.practiceMax, 5, 50),
    includeGuide: raw.includeGuide === true,
    fixXp: bounded(raw.fixXp, d.fixXp, 0, 50),
    fixXpDailyCap: bounded(raw.fixXpDailyCap, d.fixXpDailyCap, 0, 500)
  };
}

/** Una pregunta en el banco. Claves cortas: el documento guarda hasta 500. */
export interface BankItem {
  /** Curso, tema y subtema. */
  c: string;
  t: string;
  s: string;
  /** Extracto del enunciado (texto y fórmulas como `$…$`). */
  x: string;
  /** Veces fallada o en blanco. */
  n: number;
  /** Aciertos seguidos desde la última falla (sale al llegar a `exitHits`). */
  h: number;
  /** Última falla (ms). */
  at: number;
  /** En blanco la última vez. */
  b?: boolean;
  /** Día Perú desde el que se puede practicar (errores del reto de hoy). */
  from?: string;
}

/** Una pregunta corregida (las últimas [fixedMax]). */
export interface FixedItem {
  q: string;
  c: string;
  x: string;
  at: number;
  /** Dónde se corrigió: `mistakes`, `daily`, `past_exam`, `practice`, `guide`… */
  w: string;
}

export interface MistakeBank {
  items: Record<string, BankItem>;
  fixed: FixedItem[];
  fixedTotal: number;
  /** Corregidas en el día [day] (la misión). */
  mission: { day: string; done: number; completed: boolean };
  /** Días seguidos cumpliendo la misión; [day] = último día cumplido. */
  streak: { day: string; days: number };
  /** XP por corregir ya dado en [day] (tope diario propio). */
  xpDay: { day: string; xp: number };
}

export const fixedMax = 50;
export const excerptMax = 140;

export function emptyMistakeBank(): MistakeBank {
  return {
    items: {},
    fixed: [],
    fixedTotal: 0,
    mission: { day: "", done: 0, completed: false },
    streak: { day: "", days: 0 },
    xpDay: { day: "", xp: 0 }
  };
}

const str = (v: unknown) => (typeof v === "string" ? v : "");
const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : 0);
const obj = (v: unknown): Record<string, unknown> | undefined =>
  v !== null && typeof v === "object" && !Array.isArray(v) ? v as Record<string, unknown> : undefined;

export function parseMistakeBank(value: unknown): MistakeBank {
  const raw = obj(value);
  if (raw === undefined) return emptyMistakeBank();
  const items: Record<string, BankItem> = {};
  for (const [id, entry] of Object.entries(obj(raw.items) ?? {})) {
    const item = obj(entry);
    if (item === undefined) continue;
    items[id] = {
      c: str(item.c), t: str(item.t), s: str(item.s), x: str(item.x),
      n: Math.max(1, num(item.n)), h: num(item.h), at: num(item.at),
      ...(item.b === true ? { b: true } : {}),
      ...(typeof item.from === "string" ? { from: item.from } : {})
    };
  }
  const fixed = Array.isArray(raw.fixed)
    ? raw.fixed.map(obj).filter((e): e is Record<string, unknown> => e !== undefined && typeof e.q === "string")
      .map((e) => ({ q: str(e.q), c: str(e.c), x: str(e.x), at: num(e.at), w: str(e.w) }))
    : [];
  const mission = obj(raw.mission);
  const streak = obj(raw.streak);
  const xpDay = obj(raw.xpDay);
  return {
    items,
    fixed,
    fixedTotal: num(raw.fixedTotal),
    mission: { day: str(mission?.day), done: num(mission?.done), completed: mission?.completed === true },
    streak: { day: str(streak?.day), days: num(streak?.days) },
    xpDay: { day: str(xpDay?.day), xp: num(xpDay?.xp) }
  };
}

/** Texto corto del enunciado: párrafos y fórmulas (`$…$`), sin imágenes. */
export function questionExcerpt(content: readonly unknown[], max = excerptMax): string {
  const parts: string[] = [];
  for (const block of content) {
    const b = obj(block);
    if (b === undefined) continue;
    if (b.type === "text") parts.push(str(b.text));
    else if (b.type === "formula") parts.push(`$${str(b.latex)}$`);
    else if (b.type === "paragraph" && Array.isArray(b.spans)) {
      parts.push(b.spans.map((span) => {
        const s = obj(span);
        return s?.type === "formula" ? `$${str(s.latex)}$` : str(s?.text);
      }).join(""));
    } else if (b.type === "legacy") {
      parts.push(str(b.raw).replace(/\[[@%#]\][A-Z]*/g, " "));
    }
  }
  const text = parts.join(" ").replace(/\s+/g, " ").trim();
  if (text.length <= max) return text;
  // Sin cortar una fórmula a la mitad.
  let cut = text.slice(0, max);
  if ((cut.match(/\$/g)?.length ?? 0) % 2 === 1) cut = cut.slice(0, cut.lastIndexOf("$"));
  return `${cut.trimEnd()}…`;
}

/** Una pregunta calificada de un examen recién entregado. */
export interface GradedQuestion {
  questionId: string;
  correct: boolean;
  blank: boolean;
  courseId: string;
  topicId: string;
  subtopicId: string;
  excerpt: string;
}

export interface BankUpdate {
  bank: MistakeBank;
  /** Entraron por primera vez. */
  added: number;
  /** Salieron a «Corregidas» con este envío. */
  fixed: number;
  /** XP por corregir de este envío (ya con el tope diario). */
  fixXp: number;
  /** La misión se cumplió con este envío. */
  missionCompleted: boolean;
}

function previousDay(day: string): string {
  const date = new Date(`${day}T00:00:00Z`);
  return new Date(date.getTime() - 86_400_000).toISOString().slice(0, 10);
}

/**
 * Aplica un examen al banco. Pura. [holdUntil]: día desde el que se pueden
 * practicar los errores que entran ahora (el reto de hoy, mañana). [where]:
 * de qué examen viene, para «Corregidas».
 */
export function applyGraded(
  previous: MistakeBank,
  graded: readonly GradedQuestion[],
  settings: MistakeSettings,
  options: { now: number; day: string; where: string; holdUntil?: string }
): BankUpdate {
  const bank: MistakeBank = {
    items: { ...previous.items },
    fixed: [...previous.fixed],
    fixedTotal: previous.fixedTotal,
    mission: previous.mission.day === options.day ? { ...previous.mission } : { day: options.day, done: 0, completed: false },
    streak: { ...previous.streak },
    xpDay: previous.xpDay.day === options.day ? { ...previous.xpDay } : { day: options.day, xp: 0 }
  };
  let added = 0;
  let fixed = 0;
  for (const question of graded) {
    const current = bank.items[question.questionId];
    if (question.correct) {
      if (current === undefined) continue;
      const hits = current.h + 1;
      if (hits < settings.exitHits) {
        bank.items[question.questionId] = { ...current, h: hits };
        continue;
      }
      delete bank.items[question.questionId];
      fixed += 1;
      bank.fixed.unshift({ q: question.questionId, c: current.c, x: current.x, at: options.now, w: options.where });
      continue;
    }
    if (current === undefined) added += 1;
    bank.items[question.questionId] = {
      c: question.courseId || current?.c || "",
      t: question.topicId || current?.t || "",
      s: question.subtopicId || current?.s || "",
      x: question.excerpt || current?.x || "",
      n: (current?.n ?? 0) + 1,
      h: 0,
      at: options.now,
      ...(question.blank ? { b: true } : {}),
      ...(options.holdUntil !== undefined ? { from: options.holdUntil } : current?.from !== undefined ? { from: current.from } : {})
    };
  }
  bank.fixed = bank.fixed.slice(0, fixedMax);
  bank.fixedTotal += fixed;
  // Tope del banco: salen las fallas más antiguas.
  const ids = Object.keys(bank.items);
  if (ids.length > settings.bankMax) {
    ids.sort((a, b) => bank.items[a]!.at - bank.items[b]!.at);
    for (const id of ids.slice(0, ids.length - settings.bankMax)) delete bank.items[id];
  }
  const fixXp = Math.min(fixed * settings.fixXp, Math.max(0, settings.fixXpDailyCap - bank.xpDay.xp));
  bank.xpDay.xp += fixXp;
  let missionCompleted = false;
  if (fixed > 0) {
    bank.mission.done += fixed;
    if (settings.missionEnabled && !bank.mission.completed && bank.mission.done >= settings.missionSize) {
      bank.mission.completed = true;
      missionCompleted = true;
      bank.streak = {
        day: options.day,
        days: bank.streak.day === previousDay(options.day) ? bank.streak.days + 1 : bank.streak.day === options.day ? bank.streak.days : 1
      };
    }
  }
  return { bank, added, fixed, fixXp, missionCompleted };
}

/** Lo que se puede practicar hoy: sin los errores del reto de hoy. */
export function practicableIds(bank: MistakeBank, day: string): string[] {
  return Object.entries(bank.items)
    .filter(([, item]) => item.from === undefined || item.from <= day)
    .map(([id]) => id);
}

/**
 * Elige [count] preguntas del banco, de un curso o tema si se pide. «Más
 * falladas primero»: por veces falladas y luego la más reciente; si no, en
 * el orden de [shuffleIds].
 */
export function pickFromBank(
  bank: MistakeBank,
  day: string,
  options: { count: number; courseId?: string; topicId?: string; order: "most_missed" | "mixed"; shuffleIds?: (ids: string[]) => string[] }
): string[] {
  let ids = practicableIds(bank, day).filter((id) => {
    const item = bank.items[id]!;
    return (options.courseId === undefined || item.c === options.courseId) &&
      (options.topicId === undefined || item.t === options.topicId);
  });
  if (options.order === "most_missed") {
    ids.sort((a, b) => bank.items[b]!.n - bank.items[a]!.n || bank.items[b]!.at - bank.items[a]!.at);
  } else if (options.shuffleIds !== undefined) {
    ids = options.shuffleIds(ids);
  }
  return ids.slice(0, Math.max(0, options.count));
}
