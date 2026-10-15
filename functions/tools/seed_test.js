// Seed de datos de prueba para TEST (colecciones -test de ingresoya-e5115).
// Uso (desde functions/, con npm install hecho):
//   node tools/seed_test.js <service-account.json> [--delete]
// IDs deterministas con prefijo "seed-": volver a ejecutar sobrescribe; --delete borra todo lo sembrado.
// La cuenta de servicio nunca se sube al repo.
const path = require('path');
const admin = require('firebase-admin');
if (!process.argv[2]) throw new Error('Falta la ruta del service-account.json');
const sa = require(path.resolve(process.argv[2]));
const DELETE = process.argv.includes('--delete');
if (sa.project_id !== 'ingresoya-e5115') throw new Error('Proyecto inesperado: ' + sa.project_id);
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const TS = admin.firestore.FieldValue.serverTimestamp;

const C = {
  courses: 'iya-courses-test',
  questions: 'iya-questions-test',
  keys: 'iya-question-answer-keys-test',
  templates: 'iya-exam-templates-test',
  universities: 'iya-universities-test',
};
for (const name of Object.values(C)) if (!name.endsWith('-test')) throw new Error('Colección no test: ' + name);

// PRNG determinista para que cada ejecución genere lo mismo.
let seed = 20261007;
const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);
const ri = (a, b) => a + Math.floor(rnd() * (b - a + 1));

const PART_TEMPLATE = 'seed-part-exam-v1';
const MASTERY_TEMPLATE = 'seed-subtopic-mastery-v1';

// Generadores de preguntas con respuesta correcta calculada.
const gen = {
  alg: () => { const x = ri(-9, 12), a = ri(2, 9), b = ri(-20, 20); const c = a * x + b;
    return { text: `Resuelve la ecuación: ${a}x ${b < 0 ? '−' : '+'} ${Math.abs(b)} = ${c}. ¿Cuál es el valor de x?`, ok: `${x}`, bad: [`${x + 1}`, `${x - 2}`, `${-x === x ? x + 3 : -x}`] }; },
  ari: () => { const a = ri(3, 15), b = ri(3, 12), c = ri(1, 40); const r = a * b - c;
    return { text: `¿Cuánto es ${a} × ${b} − ${c}?`, ok: `${r}`, bad: [`${r + b}`, `${r - 1}`, `${a * (b - c)}` === `${r}` ? `${r + 10}` : `${a * (b - c)}`] }; },
  geo: () => { const b = ri(3, 20), h = ri(2, 15); const k = ri(0, 1);
    return k ? { text: `Un rectángulo mide ${b} cm de base y ${h} cm de altura. ¿Cuál es su área?`, ok: `${b * h} cm²`, bad: [`${2 * (b + h)} cm²`, `${b * h + b} cm²`, `${b + h} cm²`] }
      : { text: `Un rectángulo mide ${b} cm de base y ${h} cm de altura. ¿Cuál es su perímetro?`, ok: `${2 * (b + h)} cm`, bad: [`${b * h + 1} cm`, `${b + h} cm`, `${2 * (b + h) + 2} cm`] }; },
  fis: () => { const v = ri(2, 25), t = ri(2, 12);
    return { text: `Un móvil recorre ${v * t} m en ${t} s con rapidez constante. ¿Cuál es su rapidez?`, ok: `${v} m/s`, bad: [`${v + 2} m/s`, `${v * 2} m/s`, `${v * t * t} m/s`] }; },
  qui: () => { const n = ri(1, 9);
    return { text: `¿Cuántos moles hay en ${18 * n} g de agua? (M(H₂O) = 18 g/mol)`, ok: `${n} mol`, bad: [`${n + 1} mol`, `${18 * n} mol`, `${n * 2 + 1} mol`] }; },
};

const COURSES = [
  { key: 'alg', name: 'Álgebra (prueba)', topics: [['Ecuaciones', ['Ecuaciones lineales', 'Sistemas de ecuaciones']], ['Polinomios', ['Productos notables', 'Factorización']]] },
  { key: 'ari', name: 'Aritmética (prueba)', topics: [['Operaciones', ['Operaciones combinadas', 'Divisibilidad']], ['Fracciones', ['Fracciones equivalentes', 'Operaciones con fracciones']]] },
  { key: 'geo', name: 'Geometría (prueba)', topics: [['Figuras planas', ['Rectángulos', 'Triángulos']], ['Perímetros y áreas', ['Perímetros', 'Áreas compuestas']]] },
  { key: 'fis', name: 'Física (prueba)', topics: [['Cinemática', ['MRU', 'MRUV']], ['Dinámica', ['Leyes de Newton', 'Rozamiento']]] },
  { key: 'qui', name: 'Química (prueba)', topics: [['Estequiometría', ['Mol y masa molar', 'Reactivo limitante']], ['Materia', ['Estados de la materia', 'Mezclas']]] },
];
const QUESTIONS_PER_PART = 6;

function part(id, topicId, subtopicId, order, name, full) {
  const p = { id, active: true, name, idSubtopic: subtopicId, idTopic: topicId,
    content: `Contenido de prueba de «${name}». Lee la explicación y luego rinde el examen de la parte.`,
    order, linkVideo: '', linkPdf: '', examTemplateId: PART_TEMPLATE };
  if (full) Object.assign(p, {
    summary: `Resumen de ${name}.`,
    objectives: ['Comprender el concepto', 'Resolver ejercicios tipo examen'],
    keyPoints: ['Lee con cuidado el enunciado', 'Despeja la incógnita: si $ax = b$, entonces $x = \\frac{b}{a}$', 'Verifica tu respuesta'],
    estimatedMinutes: 15, difficulty: 'intermediate',
    examples: [{ id: `${id}-ex1`, title: 'Ejemplo 1', problem: 'Resuelve 2x + 4 = 10', steps: ['2x = 6', 'x = 3'], answer: 'x = 3' }],
    exercises: [{ id: `${id}-ej1`, statement: 'Resuelve 3x = 12', hint: 'Divide entre 3', answer: 'x = 4', difficulty: 'basic' }],
    flashcards: [{ id: `${id}-fc1`, front: '¿Qué es una ecuación?', back: 'Una igualdad con incógnitas' }, { id: `${id}-fc2`, front: '¿Qué es despejar?', back: 'Aislar la incógnita' }],
    quizQuestions: [
      { id: `${id}-qz1`, question: '¿Cuánto vale $x$ en $2x = 8$?', options: ['2', '4', '8', '16'], correctIndex: 1, explanation: 'Divide ambos lados entre 2: $x = 4$.' },
      { id: `${id}-qz2`, question: '¿Qué se hace para despejar $x$ en $x + 5 = 9$?', options: ['Sumar 5', 'Restar 5 a ambos lados', 'Multiplicar por 5'], correctIndex: 1, explanation: 'Se resta 5 a ambos lados y queda $x = 4$.' },
    ],
    externalLinks: [{ id: `${id}-l1`, title: 'Material de apoyo', url: 'https://es.khanacademy.org/math', type: 'article' }],
  });
  return p;
}

function tokens(text) {
  return [...new Set(text.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').split(/[^a-z0-9]+/).filter(t => t.length >= 3))].slice(0, 30);
}

async function commitAll(ops) {
  for (let i = 0; i < ops.length; i += 400) {
    const batch = db.batch();
    ops.slice(i, i + 400).forEach(op => op(batch));
    await batch.commit();
  }
}

function template(id, title, purpose, count, pass) {
  const blank = { universityId: '', sourceExamId: '', modalityId: '', courseId: '', topicId: '', subtopicId: '', partId: '', sourceType: 'any', difficulty: 'any' };
  return { schemaVersion: 2, id, version: 1, title, purpose, mode: 'dynamic', selectionPolicy: 'strict', allowedFallbackSources: [],
    questionCount: count, passPercentExclusive: pass, durationSeconds: 1200, blocks: [{ count, filter: blank }], fixedQuestions: [],
    status: 'published', active: true };
}

async function main() {
  const existing = await db.collection(C.courses).get();
  console.log('Cursos existentes:', existing.docs.map(d => `${d.id}:${d.data().name}`).join(' | ') || '(ninguno)');
  const unis = await db.collection(C.universities).get();
  console.log('Universidades existentes:', unis.size);

  if (DELETE) {
    const refs = [];
    for (const c of COURSES) refs.push(db.collection(C.courses).doc(`seed-${c.key}`));
    for (const r of [...refs]) await db.recursiveDelete(r);
    const qs = await db.collection(C.questions).where(admin.firestore.FieldPath.documentId(), '>=', 'seed-').where(admin.firestore.FieldPath.documentId(), '<', 'seed.').get();
    for (const q of qs.docs) { await db.recursiveDelete(q.ref); await db.collection(C.keys).doc(`${q.id}_1`).delete(); }
    for (const t of [PART_TEMPLATE, MASTERY_TEMPLATE]) await db.recursiveDelete(db.collection(C.templates).doc(t));
    await db.recursiveDelete(db.collection(C.universities).doc('seed-universidad'));
    console.log(`Borrado: ${COURSES.length} cursos, ${qs.size} preguntas, 2 plantillas.`);
    return;
  }

  const ops = [];
  const set = (ref, data) => ops.push(b => b.set(ref, data));
  let nQ = 0, nParts = 0;

  // Plantillas genéricas: Functions rellenan curso/tema/subtema/parte desde la solicitud.
  for (const t of [template(PART_TEMPLATE, 'Examen de parte (prueba)', 'part_completion', 5, 79),
                   template(MASTERY_TEMPLATE, 'Dominio del subtema (prueba)', 'subtopic_mastery', 8, 74)]) {
    const ref = db.collection(C.templates).doc(t.id);
    set(ref, { ...t, createdAt: TS(), updatedAt: TS() });
    set(ref.collection('versions').doc('1'), { ...t, createdAt: TS(), updatedAt: TS(), versionedAt: TS() });
  }

  // Universidad solo si no hay ninguna (el onboarding de la app la necesita).
  if (unis.size === 0) {
    const id = 'seed-universidad';
    set(db.collection(C.universities).doc(id), { id, idDoc: id, name: 'Universidad de Prueba', acronym: 'UPRUEBA', active: true,
      slogan: '', address: '', urlImage: '', location: '', ubigeo: '', department: '', province: '', district: '', links: [], modes: [],
      professions: [{ id: 'seed-ingenieria', idDoc: 'seed-ingenieria', name: 'Ingeniería', acronym: 'ING', active: true }],
      createdAt: TS(), updatedAt: TS() });
  }

  for (const c of COURSES) {
    const courseId = `seed-${c.key}`;
    const courseRef = db.collection(C.courses).doc(courseId);
    set(courseRef, { idDoc: courseId, name: c.name, description: `Curso de prueba para validar sincronización y exámenes (${c.name}).`, active: true, createdAt: TS(), updatedAt: TS() });
    c.topics.forEach(([topicName, subs], ti) => {
      const topicId = `${courseId}-t${ti + 1}`;
      const topicRef = courseRef.collection('topics').doc(topicId);
      set(topicRef, { name: topicName, description: `Tema de prueba: ${topicName}.`, order: ti + 1, summary: '', active: true, createdAt: TS(), updatedAt: TS() });
      subs.forEach((subName, si) => {
        const subtopicId = `${topicId}-s${si + 1}`;
        // Parte 1 solo con lección (rápida de completar); parte 2 completa (lección, ejemplos, repaso, recursos).
        const parts = [part(`${subtopicId}-p1`, topicId, subtopicId, 1, `${subName}: conceptos`, false),
                       part(`${subtopicId}-p2`, topicId, subtopicId, 2, `${subName}: práctica`, true)];
        nParts += parts.length;
        set(topicRef.collection('subtopics').doc(subtopicId), { name: subName, content: '', order: si + 1, linkVideo: '', idTopic: topicId,
          masteryTemplateId: MASTERY_TEMPLATE, active: true, listPart: parts, createdAt: TS(), updatedAt: TS() });
        for (const p of parts) for (let k = 1; k <= QUESTIONS_PER_PART; k++) {
          const g = gen[c.key]();
          const questionId = `${p.id}-q${k}`;
          const opts = [g.ok, ...g.bad.filter((v, i, a) => v !== g.ok && a.indexOf(v) === i)];
          while (opts.length < 4) opts.push(`${opts.length * 7 + 1}`);
          const order = opts.slice(0, 4).map(v => [rnd(), v]).sort((a, b) => a[0] - b[0]).map(x => x[1]);
          const ids = ['a', 'b', 'c', 'd'];
          const correctId = ids[order.indexOf(g.ok)];
          const tk = tokens(`${g.text} ${c.name} ${topicName} ${subName}`);
          const q = { schemaVersion: 2, questionId, version: 1, status: 'published', sourceType: 'original',
            courseId, topicId, subtopicId, partIds: [p.id], difficulty: ['easy', 'medium', 'hard'][k % 3],
            content: [{ id: `${questionId}-c1`, type: 'text', text: g.text }],
            alternatives: order.map((v, i) => ({ id: ids[i], label: ids[i].toUpperCase(), content: [{ id: `${questionId}-${ids[i]}`, type: 'text', text: v }] })),
            sourceExamId: '', universityId: '', modalityId: '', year: null, period: '', sourceLabel: 'Pregunta de práctica IngresoYa (prueba)',
            randomKey: rnd(), searchTokens: tk, partSearchTokens: tk.map(t => `${p.id}|${t}`) };
          const qRef = db.collection(C.questions).doc(questionId);
          set(qRef, { ...q, createdAt: TS(), updatedAt: TS(), publishedAt: TS() });
          set(qRef.collection('versions').doc('1'), { ...q, createdAt: TS(), updatedAt: TS(), publishedAt: TS() });
          set(db.collection(C.keys).doc(`${questionId}_1`), { schemaVersion: 2, questionId, version: 1, correctAlternativeId: correctId,
            explanation: [{ id: `${questionId}-e1`, type: 'text', text: `La respuesta correcta es ${g.ok}.` }], createdAt: TS(), updatedAt: TS() });
          nQ++;
        }
      });
    });
  }
  await commitAll(ops);
  console.log(`OK: ${COURSES.length} cursos, ${COURSES.length * 2} temas, ${COURSES.length * 4} subtemas, ${nParts} partes, ${nQ} preguntas (+claves y versiones), 2 plantillas${unis.size === 0 ? ', 1 universidad' : ''}. Escrituras: ${ops.length}.`);
}
main().catch(e => { console.error(e); process.exit(1); });
