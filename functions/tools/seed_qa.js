// Datos amplios de QA para TEST (colecciones -test de ingresoya-e5115).
// Uso (desde functions/, con npm install hecho):
//   node tools/seed_qa.js <service-account.json> [--delete]
// IDs deterministas con prefijo "qa-": volver a ejecutar sobrescribe lo mismo; --delete borra todo lo sembrado.
// No toca los datos "seed-" de tools/seed_test.js ni el contenido real. La cuenta de servicio nunca va al repo.
//
// Cursos de cálculo: preguntas generadas con la respuesta calculada. Cursos de conocimientos: tablas de datos
// verificados (pregunta directa y, cuando no es ambigua, inversa). Cada parte trae lección, ejemplos, práctica,
// tarjetas, repaso relámpago y su banco de preguntas; cada subtema, su examen de dominio.
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
};
for (const name of Object.values(C)) if (!name.endsWith('-test')) throw new Error('Colección no test: ' + name);

const PREFIX = 'qa-';
const PART_TEMPLATE = 'qa-part-exam-v1';
const MASTERY_TEMPLATE = 'qa-subtopic-mastery-v1';
const MATH_PER_PART = 10;
const FACT_PER_PART = 8;
const PARTS_PER_SUBTOPIC = 2;

// PRNG determinista: cada ejecución genera exactamente lo mismo.
let seed = 20261015;
const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);
const ri = (a, b) => a + Math.floor(rnd() * (b - a + 1));
const pick = (list) => list[Math.floor(rnd() * list.length)];
const shuffle = (list) => list.map((v) => [rnd(), v]).sort((a, b) => a[0] - b[0]).map((x) => x[1]);
const gcd = (a, b) => (b === 0 ? Math.abs(a) : gcd(b, a % b));
const frac = (p, q) => {
  if (q < 0) { p = -p; q = -q; }
  const g = gcd(p, q) || 1;
  p /= g; q /= g;
  return q === 1 ? `${p}` : `$${p < 0 ? '-' : ''}\\frac{${Math.abs(p)}}{${q}}$`;
};
const lcFirst = (t) => t.charAt(0).toLowerCase() + t.slice(1);
const sgn = (n) => (n < 0 ? `− ${Math.abs(n)}` : `+ ${n}`);

/** Numeric options: the answer plus close, distinct mistakes. */
function nums(ok, unit = '', extra = []) {
  const fmt = (v) => `${v}${unit}`;
  const bad = [];
  for (const v of [...extra, ok + 1, ok - 1, ok + 2, ok * 2, ok - 2, ok + 10, ok + 3]) {
    if (Number.isFinite(v) && v !== ok && !bad.includes(v)) bad.push(v);
    if (bad.length === 4) break;
  }
  return { ok: fmt(ok), bad: bad.map(fmt) };
}

// ---------------------------------------------------------------- Generadores (cursos de cálculo)
// Cada uno devuelve { text, ok, bad[], exp }.
const G = {
  // Álgebra
  lineales: () => { const x = ri(-9, 12), a = ri(2, 9), b = ri(1, 20) * pick([1, -1]); const c = a * x + b;
    return { text: `Resuelve: $${a}x ${sgn(b)} = ${c}$. ¿Cuánto vale $x$?`, ...nums(x, '', [-x || 5]), exp: `$${a}x = ${c - b}$, entonces $x = ${x}$.` }; },
  sistemas: () => { const x = ri(1, 12), y = ri(1, 12);
    return { text: `Si $x + y = ${x + y}$ y $x - y = ${x - y}$, ¿cuánto vale $x \\cdot y$?`, ...nums(x * y, '', [x + y, x * y + x]), exp: `Sumando: $2x = ${2 * x}$, $x = ${x}$ e $y = ${y}$; $xy = ${x * y}$.` }; },
  cuadraticas: () => { const r1 = ri(1, 9), r2 = ri(1, 9); const s = r1 + r2, p = r1 * r2; const sum = rnd() < 0.5;
    return { text: `En la ecuación $x^2 - ${s}x + ${p} = 0$, ¿cuánto vale ${sum ? 'la suma' : 'el producto'} de sus raíces?`, ...nums(sum ? s : p, '', [sum ? -s : -p, sum ? p : s]),
      exp: `Las raíces son ${r1} y ${r2}: suma ${s}, producto ${p}.` }; },
  productos: () => { const a = ri(1, 9), b = ri(1, 9); const s = a + b, p = a * b;
    return { text: `Si $a + b = ${s}$ y $ab = ${p}$, ¿cuánto vale $a^2 + b^2$?`, ...nums(s * s - 2 * p, '', [s * s, s * s - p]), exp: `$a^2 + b^2 = (a+b)^2 - 2ab = ${s * s} - ${2 * p} = ${s * s - 2 * p}$.` }; },
  factorizacion: () => { let r1 = ri(2, 9), r2 = ri(2, 9); if (r1 === r2) r2 = r1 === 9 ? 2 : r1 + 1; const s = r1 + r2, p = r1 * r2;
    return { text: `¿Cuál es la factorización de $x^2 + ${s}x + ${p}$?`, ok: `$(x + ${r1})(x + ${r2})$`,
      bad: [`$(x - ${r1})(x - ${r2})$`, `$(x + ${p})(x + 1)$`, `$(x + ${r1})(x - ${r2})$`, `$(x + ${s})(x + 1)$`], exp: `${r1} + ${r2} = ${s} y ${r1} · ${r2} = ${p}.` }; },
  exponentes: () => { const b = pick([2, 3]); const m = ri(2, b === 2 ? 6 : 4), n = ri(1, 3), k = ri(1, 2); const e = m + n - k;
    return { text: `¿Cuánto vale $\\dfrac{${b}^{${m}} \\cdot ${b}^{${n}}}{${b}^{${k}}}$?`, ...nums(b ** e, '', [b ** (e + 1), b * e]), exp: `Se suman y restan exponentes: $${b}^{${m}+${n}-${k}} = ${b}^{${e}} = ${b ** e}$.` }; },
  funciones: () => { const a = ri(2, 6), b = ri(-5, 9), c = ri(1, 4), d = ri(-3, 5), k = ri(-3, 4); const g = c * k + d;
    return { text: `Si $f(x) = ${a}x ${sgn(b)}$ y $g(x) = ${c === 1 ? '' : c}x ${sgn(d)}$, ¿cuánto vale $f(g(${k}))$?`, ...nums(a * g + b, '', [c * (a * k + b) + d]), exp: `$g(${k}) = ${g}$ y $f(${g}) = ${a * g + b}$.` }; },
  // Aritmética
  combinadas: () => { const a = ri(3, 15), b = ri(3, 12), c = ri(1, 40); const r = a * b - c;
    return { text: `¿Cuánto es $${a} \\times ${b} - ${c}$?`, ...nums(r, '', [a * (b - c)]), exp: `Primero la multiplicación: ${a * b} − ${c} = ${r}.` }; },
  mcdmcm: () => { const [m, n] = pick([[2, 3], [3, 4], [2, 5], [3, 5], [4, 5], [5, 6], [3, 7], [2, 7], [4, 7], [5, 7]]); const g = ri(2, 12); const A = g * m, B = g * n; const mcd = rnd() < 0.5;
    return { text: `¿Cuál es el ${mcd ? 'MCD' : 'MCM'} de ${A} y ${B}?`, ...nums(mcd ? g : g * m * n, '', [mcd ? g * m * n : g, A * B]), exp: `${A} = ${g}·${m} y ${B} = ${g}·${n}: MCD = ${g}, MCM = ${g * m * n}.` }; },
  fracciones: () => { const b = pick([2, 3, 4, 5, 6]), d = pick([2, 3, 4, 5, 6]), a = ri(1, b - 1 || 1), c = ri(1, d - 1 || 1);
    const p = a * d + c * b, q = b * d; const ok = frac(p, q);
    const bad = [frac(a + c, b + d), frac(p + 1, q), frac(a * c, b * d), frac(p, q + b)].filter((v, i, l) => v !== ok && l.indexOf(v) === i);
    return { text: `¿Cuánto es $\\frac{${a}}{${b}} + \\frac{${c}}{${d}}$?`, ok, bad, exp: `$\\frac{${a * d} + ${c * b}}{${q}}$ = ${ok}.` }; },
  porcentajes: () => { const p = pick([5, 10, 15, 20, 25, 30, 40, 50, 60, 75]); const n = 20 * ri(1, 30);
    return { text: `¿Cuánto es el ${p} % de ${n}?`, ...nums((p * n) / 100, '', [n - (p * n) / 100, p * 10]), exp: `${p}/100 × ${n} = ${(p * n) / 100}.` }; },
  reglaTres: () => { if (rnd() < 0.5) { const u = ri(2, 9), n = ri(2, 8), m = ri(3, 15);
      return { text: `Si ${n} cuadernos cuestan ${n * u} soles, ¿cuánto cuestan ${m} cuadernos?`, ...nums(m * u, ' soles', [m * n]), exp: `Cada cuaderno cuesta ${u} soles: ${m} × ${u} = ${m * u}.` }; }
    const a = ri(2, 8), r = ri(2, 12); const T = a * ri(3, 15); const divs = []; for (let b = 2; b <= 24; b++) if (T % b === 0 && b !== a && T / b >= 2) divs.push(b); const b = divs.length ? pick(divs) : a + 1; const d = T / a; if (T % b) return G.reglaTres();
    return { text: `${a} obreros hacen una obra en ${d} días. ¿En cuántos días la harían ${b} obreros trabajando igual?`, ...(({ ok, bad }) => ({ ok, bad: bad.filter((v) => !/^[01] días$/.test(v)) }))(nums(T / b, ' días', [Math.round((b * d) / a) || r].filter((v) => v > 1))), exp: `Es inversa: ${a} × ${d} = ${b} × x, x = ${T / b}.` }; },
  interes: () => { const Cp = 100 * ri(5, 50), r = ri(2, 12), t = ri(1, 5); const I = (Cp * r * t) / 100;
    return { text: `¿Qué interés simple produce un capital de S/ ${Cp} al ${r} % anual durante ${t} año${t > 1 ? 's' : ''}?`, ...nums(I, ' soles', [(Cp * r) / 100, Cp + I]), exp: `I = C·r·t/100 = ${Cp}·${r}·${t}/100 = ${I}.` }; },
  promedios: () => { const m = ri(10, 17); let a, b, c, d; do { a = ri(m - 4, m + 3); b = ri(m - 4, m + 3); c = ri(m - 4, m + 3); d = 4 * m - a - b - c; } while (d < 0 || d > 20);
    return { text: `Las notas de un alumno son ${a}, ${b}, ${c} y ${d}. ¿Cuál es su promedio?`, ...nums(m, '', [Math.max(a, b, c, d)]), exp: `(${a} + ${b} + ${c} + ${d}) / 4 = ${4 * m} / 4 = ${m}.` }; },
  // Geometría
  angulos: () => { const x = ri(10, 80); const comp = rnd() < 0.5;
    return { text: `¿Cuál es el ${comp ? 'complemento' : 'suplemento'} de un ángulo de ${x}°?`, ...nums(comp ? 90 - x : 180 - x, '°', [comp ? 180 - x : 90 - x, x]), exp: comp ? `90° − ${x}° = ${90 - x}°.` : `180° − ${x}° = ${180 - x}°.` }; },
  poligonos: () => { const n = ri(5, 12); const sum = rnd() < 0.5;
    return { text: sum ? `¿Cuánto suman los ángulos interiores de un polígono de ${n} lados?` : `¿Cuántas diagonales tiene un polígono de ${n} lados?`,
      ...(sum ? nums(180 * (n - 2), '°', [180 * n, 360]) : nums((n * (n - 3)) / 2, '', [n * (n - 3), n])), exp: sum ? `180°(n − 2) = 180° · ${n - 2} = ${180 * (n - 2)}°.` : `n(n − 3)/2 = ${n}·${n - 3}/2 = ${(n * (n - 3)) / 2}.` }; },
  pitagoras: () => { const [a, b, c] = pick([[3, 4, 5], [5, 12, 13], [8, 15, 17], [7, 24, 25]]).map((v) => v); const k = ri(1, 4); const hyp = rnd() < 0.5;
    return hyp ? { text: `Los catetos de un triángulo rectángulo miden ${a * k} y ${b * k} cm. ¿Cuánto mide la hipotenusa?`, ...nums(c * k, ' cm', [(a + b) * k]), exp: `$\\sqrt{${a * k}^2 + ${b * k}^2} = ${c * k}$.` }
      : { text: `La hipotenusa de un triángulo rectángulo mide ${c * k} cm y un cateto ${a * k} cm. ¿Cuánto mide el otro cateto?`, ...nums(b * k, ' cm', [(c - a) * k]), exp: `$\\sqrt{${c * k}^2 - ${a * k}^2} = ${b * k}$.` }; },
  areaTriangulo: () => { const b = 2 * ri(2, 12), h = ri(2, 15);
    return { text: `Un triángulo tiene ${b} cm de base y ${h} cm de altura. ¿Cuál es su área?`, ...nums((b * h) / 2, ' cm²', [b * h]), exp: `b·h/2 = ${b}·${h}/2 = ${(b * h) / 2} cm².` }; },
  rectangulos: () => { const b = ri(3, 20), h = ri(2, 15); const area = rnd() < 0.5;
    return area ? { text: `Un rectángulo mide ${b} cm de base y ${h} cm de altura. ¿Cuál es su área?`, ...nums(b * h, ' cm²', [2 * (b + h)]), exp: `${b} × ${h} = ${b * h} cm².` }
      : { text: `Un rectángulo mide ${b} cm de base y ${h} cm de altura. ¿Cuál es su perímetro?`, ...nums(2 * (b + h), ' cm', [b * h, b + h]), exp: `2(${b} + ${h}) = ${2 * (b + h)} cm.` }; },
  circulo: () => { const r = ri(2, 12); const area = rnd() < 0.5; const v = area ? r * r : 2 * r;
    const opts = [v, area ? 2 * r : r * r, v + 1, v * 2, area ? r : r + 2].filter((x, i, l) => l.indexOf(x) === i && (i === 0 || x !== v));
    const f = (x) => `${x}π cm${area ? '²' : ''}`;
    return { text: `¿Cuál es ${area ? 'el área' : 'la longitud'} de una circunferencia de radio ${r} cm?`, ok: f(v), bad: opts.slice(1, 5).map(f), exp: area ? `πr² = ${r * r}π cm².` : `2πr = ${2 * r}π cm.` }; },
  volumenes: () => { if (rnd() < 0.5) { const a = ri(2, 9); return { text: `¿Cuál es el volumen de un cubo de arista ${a} cm?`, ...nums(a ** 3, ' cm³', [a * a, 6 * a * a]), exp: `a³ = ${a}³ = ${a ** 3} cm³.` }; }
    const a = ri(2, 8), b = ri(2, 8), c = ri(2, 8);
    return { text: `¿Cuál es el volumen de un prisma rectangular de ${a} cm × ${b} cm × ${c} cm?`, ...nums(a * b * c, ' cm³', [a + b + c, 2 * (a * b + b * c + a * c)]), exp: `${a}·${b}·${c} = ${a * b * c} cm³.` }; },
  // Trigonometría (valores racionales de ángulos notables, incluido el triángulo de 37° y 53°)
  razones: () => { const [a, b, c] = pick([[3, 4, 5], [5, 12, 13], [8, 15, 17], [7, 24, 25]]); const k = ri(1, 3); const r = pick(['sen', 'cos', 'tan']);
    const val = { sen: [a, c], cos: [b, c], tan: [a, b] }[r]; const ok = frac(...val);
    const bad = [frac(b, c), frac(a, c), frac(a, b), frac(b, a), frac(c, a)].filter((v, i, l) => v !== ok && l.indexOf(v) === i);
    return { text: `En un triángulo rectángulo los catetos miden ${a * k} y ${b * k}, y la hipotenusa ${c * k}. Si $\\alpha$ es el ángulo opuesto al cateto ${a * k}, ¿cuánto vale $\\${r === 'sen' ? 'sin' : r}\\alpha$?`,
      ok, bad, exp: `${r} α = ${{ sen: 'opuesto/hipotenusa', cos: 'adyacente/hipotenusa', tan: 'opuesto/adyacente' }[r]} = ${ok}.` }; },
  notables: () => { const V = [['\\sin 30^\\circ', 1, 2], ['\\cos 60^\\circ', 1, 2], ['\\tan 45^\\circ', 1, 1], ['\\sin 90^\\circ', 1, 1], ['\\cos 0^\\circ', 1, 1], ['\\sin 37^\\circ', 3, 5], ['\\cos 37^\\circ', 4, 5], ['\\tan 37^\\circ', 3, 4], ['\\sin 53^\\circ', 4, 5], ['\\cos 53^\\circ', 3, 5], ['\\tan 53^\\circ', 4, 3]];
    const x = pick(V); let y = pick(V); while (y === x) y = pick(V); const m = ri(1, 3), n = ri(1, 3);
    const p = m * x[1] * y[2] + n * y[1] * x[2], q = x[2] * y[2]; const ok = frac(p, q);
    const bad = [frac(p + q, q), frac(m * x[1] + n * y[1], x[2] + y[2]), frac(p, 2 * q), frac(p - q, q)].filter((v, i, l) => v !== ok && l.indexOf(v) === i);
    return { text: `Calcula $E = ${m > 1 ? m : ''}${x[0]} + ${n > 1 ? n : ''}${y[0]}$ (usa los valores notables).`, ok, bad, exp: `$${x[0]} = ${frac(x[1], x[2]).replace(/\$/g, '')}$ y $${y[0]} = ${frac(y[1], y[2]).replace(/\$/g, '')}$; E = ${ok}.` }; },
  radianes: () => { const T = [[30, 1, 6], [45, 1, 4], [60, 1, 3], [90, 1, 2], [120, 2, 3], [135, 3, 4], [150, 5, 6], [180, 1, 1], [270, 3, 2], [360, 2, 1]];
    const [d, p, q] = pick(T); const f = (a, b) => (b === 1 ? (a === 1 ? '$\\pi$ rad' : `$${a}\\pi$ rad`) : `$\\frac{${a === 1 ? '' : a}\\pi}{${b}}$ rad`);
    const ok = f(p, q); const bad = shuffle(T.filter((t) => t[0] !== d)).slice(0, 4).map((t) => f(t[1], t[2]));
    return { text: `¿Cuántos radianes son ${d}°?`, ok, bad, exp: `${d}° × π/180 = ${ok.replace(' rad', '')} rad.` }; },
  sistemasAng: () => { const S = 9 * ri(1, 20); const C2 = (10 * S) / 9;
    return { text: `Un ángulo mide ${S}° en el sistema sexagesimal. ¿Cuánto mide en el sistema centesimal?`, ...nums(C2, 'ᵍ', [S + 10, (9 * S) / 10]), exp: `$\\frac{S}{180} = \\frac{C}{200}$, C = 10S/9 = ${C2}ᵍ.` }; },
  identidades: () => { const k = ri(2, 7), m = ri(-5, 9);
    return { text: `Simplifica $E = ${k}\\sin^2 x + ${k}\\cos^2 x ${sgn(m)}$.`, ...nums(k + m, '', [m, 2 * k + m, k]), exp: `$\\sin^2 x + \\cos^2 x = 1$, entonces E = ${k} ${sgn(m)} = ${k + m}.` }; },
  // Física (g = 10 m/s²)
  mru: () => { const v = ri(2, 25), t = ri(2, 12); const ask = pick(['v', 'd']);
    return ask === 'v' ? { text: `Un móvil recorre ${v * t} m en ${t} s con rapidez constante. ¿Cuál es su rapidez?`, ...nums(v, ' m/s', [v * t * t]), exp: `v = d/t = ${v * t}/${t} = ${v} m/s.` }
      : { text: `Un móvil viaja a ${v} m/s con rapidez constante durante ${t} s. ¿Qué distancia recorre?`, ...nums(v * t, ' m', [v + t]), exp: `d = v·t = ${v}·${t} = ${v * t} m.` }; },
  mruv: () => { const v0 = ri(0, 10), a = ri(1, 5), t = 2 * ri(1, 5); const vel = rnd() < 0.5;
    return vel ? { text: `Un auto parte con ${v0} m/s y acelera a ${a} m/s². ¿Qué rapidez tiene a los ${t} s?`, ...nums(v0 + a * t, ' m/s', [a * t, v0 * t]), exp: `v = v₀ + at = ${v0} + ${a}·${t} = ${v0 + a * t} m/s.` }
      : { text: `Un auto parte con ${v0} m/s y acelera a ${a} m/s². ¿Qué distancia recorre en ${t} s?`, ...nums(v0 * t + (a * t * t) / 2, ' m', [v0 * t + a * t * t]), exp: `d = v₀t + at²/2 = ${v0 * t} + ${(a * t * t) / 2} = ${v0 * t + (a * t * t) / 2} m.` }; },
  newton: () => { const m = ri(2, 20), a = ri(1, 8); const askF = rnd() < 0.5;
    return askF ? { text: `¿Qué fuerza neta necesita un cuerpo de ${m} kg para acelerar a ${a} m/s²?`, ...nums(m * a, ' N', [m + a]), exp: `F = m·a = ${m}·${a} = ${m * a} N.` }
      : { text: `Sobre un cuerpo de ${m} kg actúa una fuerza neta de ${m * a} N. ¿Cuál es su aceleración?`, ...nums(a, ' m/s²', [m * a * m]), exp: `a = F/m = ${m * a}/${m} = ${a} m/s².` }; },
  peso: () => { const m = ri(2, 90);
    return { text: `¿Cuál es el peso de un cuerpo de ${m} kg? (g = 10 m/s²)`, ...nums(10 * m, ' N', [m]), exp: `W = m·g = ${m}·10 = ${10 * m} N.` }; },
  trabajo: () => { const F = ri(5, 60), d = ri(2, 20);
    return { text: `Una fuerza de ${F} N desplaza un bloque ${d} m en su misma dirección. ¿Qué trabajo realiza?`, ...nums(F * d, ' J', [F + d]), exp: `W = F·d = ${F}·${d} = ${F * d} J.` }; },
  cinetica: () => { const m = 2 * ri(1, 10), v = ri(1, 12);
    return { text: `¿Qué energía cinética tiene un cuerpo de ${m} kg que se mueve a ${v} m/s?`, ...nums((m * v * v) / 2, ' J', [m * v * v, (m * v) / 2]), exp: `Ec = mv²/2 = ${m}·${v * v}/2 = ${(m * v * v) / 2} J.` }; },
  potencia: () => { const t = ri(2, 10), P = ri(5, 80);
    return { text: `Un motor realiza un trabajo de ${P * t} J en ${t} s. ¿Cuál es su potencia?`, ...nums(P, ' W', [P * t * t]), exp: `P = W/t = ${P * t}/${t} = ${P} W.` }; },
  // Química
  temperatura: () => { const c = ri(-40, 120);
    return { text: `¿A cuántos kelvin equivalen ${c} °C?`, ...nums(c + 273, ' K', [c - 273, 273 - c]), exp: `K = °C + 273 = ${c + 273} K.` }; },
  densidad: () => { const V = ri(2, 20), d = ri(1, 13);
    return { text: `Un cuerpo de ${V * d} g ocupa ${V} cm³. ¿Cuál es su densidad?`, ...nums(d, ' g/cm³', [V * d * V]), exp: `ρ = m/V = ${V * d}/${V} = ${d} g/cm³.` }; },
  particulas: () => { // [símbolo, Z, A, carga habitual del ion]
    const E = pick([['N', 7, 14, -3], ['O', 8, 16, -2], ['Na', 11, 23, 1], ['Mg', 12, 24, 2], ['Al', 13, 27, 3], ['P', 15, 31, -3], ['S', 16, 32, -2], ['Cl', 17, 35, -1], ['K', 19, 39, 1], ['Ca', 20, 40, 2], ['Fe', 26, 56, 3], ['Zn', 30, 65, 2]]);
    const [s, Z, A, q] = E; const kind = pick(['n', 'e', 'ion']);
    if (kind === 'n') return { text: `El átomo $^{${A}}_{${Z}}\\mathrm{${s}}$, ¿cuántos neutrones tiene?`, ...nums(A - Z, '', [A, Z]), exp: `n = A − Z = ${A} − ${Z} = ${A - Z}.` };
    if (kind === 'e') return { text: `Un átomo neutro de ${s} tiene número atómico ${Z}. ¿Cuántos electrones tiene?`, ...nums(Z, '', [A, A - Z]), exp: `En un átomo neutro, electrones = protones = Z = ${Z}.` };
    return { text: `¿Cuántos electrones tiene el ion $\\mathrm{${s}}^{${Math.abs(q) > 1 ? Math.abs(q) : ''}${q > 0 ? '+' : '-'}}$ (Z = ${Z})?`, ...nums(Z - q, '', [Z + q, Z]), exp: `Un catión pierde y un anión gana electrones: ${Z} ${q > 0 ? '−' : '+'} ${Math.abs(q)} = ${Z - q}.` }; },
  moles: () => { const [f, M] = pick([['H_2O', 18], ['CO_2', 44], ['CH_4', 16], ['O_2', 32], ['NH_3', 17], ['N_2', 28]]); const n = ri(1, 9);
    return { text: `¿Cuántos moles hay en ${M * n} g de $\\mathrm{${f}}$? (M = ${M} g/mol)`, ...nums(n, ' mol', [M * n, n * 2 + 1]), exp: `n = m/M = ${M * n}/${M} = ${n} mol.` }; },
  molaridad: () => { const M = ri(1, 6), V = pick([1, 2, 3, 4]); const n = M * V;
    return { text: `Se disuelven ${n} mol de soluto en ${V} L de solución. ¿Cuál es su molaridad?`, ...nums(M, ' M', [n * V, M + 1]), exp: `M = n/V = ${n}/${V} = ${M} mol/L.` }; },
};

// ---------------------------------------------------------------- Tablas (cursos de conocimientos)
// Cada fila: [dato, respuesta]. ask(dato) arma la pregunta directa; back(respuesta) la inversa (null si sería ambigua).
const T = {
  organelos: { ask: (o) => `¿Cuál es la función principal de ${o}?`, back: (f) => `¿Qué organelo se encarga de: ${lcFirst(f)}?`, rows: [
    ['la mitocondria', 'Respiración celular y producción de ATP'], ['el cloroplasto', 'Realizar la fotosíntesis'], ['el ribosoma', 'Síntesis de proteínas'],
    ['el lisosoma', 'Digestión celular'], ['el aparato de Golgi', 'Empaquetar y secretar sustancias'], ['el núcleo', 'Contener el material genético (ADN)'],
    ['el retículo endoplasmático liso', 'Síntesis de lípidos'], ['el centriolo', 'Formar el huso acromático en la división celular'], ['la membrana plasmática', 'Regular el paso de sustancias'] ] },
  sistemas: { ask: (o) => `¿A qué sistema del cuerpo humano pertenece ${o}?`, back: null, rows: [
    ['el corazón', 'Circulatorio'], ['el pulmón', 'Respiratorio'], ['el riñón', 'Excretor (urinario)'], ['el estómago', 'Digestivo'], ['el cerebro', 'Nervioso'],
    ['la glándula tiroides', 'Endocrino'], ['el fémur', 'Óseo (esquelético)'], ['el bíceps', 'Muscular'], ['el intestino delgado', 'Digestivo'], ['la médula espinal', 'Nervioso'], ['la tráquea', 'Respiratorio'] ] },
  hormonas: { ask: (h) => `¿Qué glándula produce la ${h}?`, back: (g) => `¿Qué hormona produce esta glándula: ${lcFirst(g)}?`, rows: [
    ['insulina', 'Páncreas'], ['tiroxina', 'Tiroides'], ['adrenalina', 'Glándulas suprarrenales'], ['hormona del crecimiento', 'Hipófisis'], ['melatonina', 'Glándula pineal'], ['testosterona', 'Testículos'] ] },
  genetica: { ask: (c) => c, back: null, rows: [
    ['En el cruce $Aa \\times Aa$ (A domina sobre a), ¿qué proporción fenotípica se espera?', '3 : 1', ['1 : 1', '1 : 2 : 1', '9 : 3 : 3 : 1', '2 : 1']],
    ['En el cruce $AA \\times aa$, ¿qué proporción de la descendencia muestra el carácter dominante?', '100 %', ['75 %', '50 %', '25 %', '0 %']],
    ['En el cruce $Aa \\times aa$, ¿qué proporción fenotípica se espera?', '1 : 1', ['3 : 1', '1 : 2 : 1', '2 : 1', '9 : 3 : 3 : 1']],
    ['En el cruce $Aa \\times Aa$, ¿qué probabilidad hay de un descendiente $aa$?', '1/4', ['1/2', '3/4', '1/8', '0']],
    ['¿Con qué base nitrogenada se aparea la adenina en el ADN?', 'Timina', ['Citosina', 'Guanina', 'Uracilo', 'Adenina']],
    ['¿Con qué base nitrogenada se aparea la guanina en el ADN?', 'Citosina', ['Timina', 'Adenina', 'Uracilo', 'Guanina']],
    ['¿Qué base nitrogenada tiene el ARN en lugar de la timina?', 'Uracilo', ['Citosina', 'Guanina', 'Adenina', 'Ribosa']],
    ['¿Cuántos cromosomas tiene una célula somática humana?', '46', ['23', '44', '48', '92']],
    ['¿Cuántos cromosomas tiene un gameto humano?', '23', ['46', '22', '24', '92']] ] },
  ecologia: { ask: (d) => `¿Cómo se llama la relación en la que ${d}?`, back: (n) => `¿Qué ocurre en la relación de ${n.toLowerCase()}?`, rows: [
    ['ambas especies se benefician', 'Mutualismo'], ['una especie se beneficia y la otra se perjudica viviendo a su costa', 'Parasitismo'],
    ['una especie se beneficia y la otra no se afecta', 'Comensalismo'], ['una especie caza y se alimenta de otra', 'Depredación'], ['dos especies disputan un mismo recurso', 'Competencia'] ] },
  culturas: { ask: (c) => `¿Por qué se reconoce a la cultura ${c}?`, back: (d) => `¿Qué cultura es conocida por: ${lcFirst(d)}?`, rows: [
    ['Caral', 'Ser la civilización más antigua de América (valle de Supe)'], ['Chavín', 'El Lanzón monolítico en Áncash'], ['Paracas', 'Sus mantos y las trepanaciones craneanas'],
    ['Nazca', 'Las líneas o geoglifos del desierto'], ['Moche', 'Los huacos retrato y la tumba del Señor de Sipán'], ['Tiahuanaco', 'La Puerta del Sol, cerca del lago Titicaca'],
    ['Wari', 'Ser el primer imperio andino (Ayacucho)'], ['Chimú', 'La ciudadela de barro de Chan Chan'] ] },
  incas: { ask: (i) => `¿Qué se recuerda de ${i}?`, back: (h) => `¿Qué inca ${lcFirst(h)}?`, rows: [
    ['Manco Cápac', 'Fundó, según la leyenda, el Cusco'], ['Pachacútec', 'Venció a los chancas e inició la expansión del Tahuantinsuyo'],
    ['Huayna Cápac', 'Murió y su sucesión llevó a la guerra civil'], ['Atahualpa', 'Fue capturado por Pizarro en Cajamarca'], ['Huáscar', 'Se enfrentó a Atahualpa en la guerra civil'] ] },
  fechas: { ask: (e) => `¿En qué año ocurrió ${e}?`, back: null, rows: [
    ['la captura de Atahualpa en Cajamarca', '1532'], ['la fundación de Lima', '1535'], ['la rebelión de Túpac Amaru II', '1780'], ['la proclamación de la independencia del Perú', '1821'],
    ['la batalla de Ayacucho', '1824'], ['la abolición de la esclavitud por Ramón Castilla', '1854'], ['el combate del Dos de Mayo', '1866'], ['el combate de Angamos', '1879'], ['la batalla de Arica', '1880'] ] },
  personajes: { ask: (p) => `¿Por qué se recuerda a ${p}?`, back: (h) => `¿Quién es recordado por: ${lcFirst(h)}?`, rows: [
    ['José de San Martín', 'Proclamar la independencia del Perú en 1821'], ['Miguel Grau', 'Comandar el Huáscar en el combate de Angamos'], ['Francisco Bolognesi', 'Defender Arica en 1880'],
    ['Ramón Castilla', 'Abolir la esclavitud en 1854'], ['Andrés A. Cáceres', 'Dirigir la Campaña de la Breña'], ['Simón Bolívar', 'Culminar la independencia tras Junín y Ayacucho'] ] },
  capitales: { ask: (d) => `¿Cuál es la capital del departamento de ${d}?`, back: (c) => `¿De qué departamento es capital ${c}?`, rows: [
    ['Amazonas', 'Chachapoyas'], ['Áncash', 'Huaraz'], ['Apurímac', 'Abancay'], ['Junín', 'Huancayo'], ['La Libertad', 'Trujillo'], ['Lambayeque', 'Chiclayo'],
    ['Loreto', 'Iquitos'], ['Madre de Dios', 'Puerto Maldonado'], ['Pasco', 'Cerro de Pasco'], ['San Martín', 'Moyobamba'], ['Ucayali', 'Pucallpa'], ['Huánuco', 'Huánuco'], ['Piura', 'Piura'] ] },
  regiones: { ask: (r) => `¿Entre qué altitudes se ubica la región ${r} (según Pulgar Vidal)?`, back: (a) => `¿Qué región natural (Pulgar Vidal) se ubica ${lcFirst(a)}?`, rows: [
    ['Chala', 'Entre 0 y 500 m s. n. m.'], ['Yunga', 'Entre 500 y 2300 m s. n. m.'], ['Quechua', 'Entre 2300 y 3500 m s. n. m.'], ['Suni', 'Entre 3500 y 4000 m s. n. m.'],
    ['Puna', 'Entre 4000 y 4800 m s. n. m.'], ['Janca', 'Sobre los 4800 m s. n. m.'], ['Rupa Rupa (selva alta)', 'Entre 400 y 1000 m s. n. m.'], ['Omagua (selva baja)', 'Entre 80 y 400 m s. n. m.'] ] },
  sudamerica: { ask: (p) => `¿Cuál es la capital de ${p}?`, back: (c) => `¿De qué país es capital ${c}?`, rows: [
    ['Argentina', 'Buenos Aires'], ['Brasil', 'Brasilia'], ['Chile', 'Santiago'], ['Colombia', 'Bogotá'], ['Ecuador', 'Quito'], ['Paraguay', 'Asunción'], ['Uruguay', 'Montevideo'], ['Venezuela', 'Caracas'] ] },
  acentuacion: { ask: (w) => `Según su acento, ¿cómo se clasifica la palabra «${w}»?`, back: null, rows: [
    ['canción', 'Aguda'], ['café', 'Aguda'], ['reloj', 'Aguda'], ['corazón', 'Aguda'], ['árbol', 'Llana (grave)'], ['lápiz', 'Llana (grave)'], ['examen', 'Llana (grave)'], ['fácil', 'Llana (grave)'],
    ['música', 'Esdrújula'], ['pájaro', 'Esdrújula'], ['teléfono', 'Esdrújula'], ['brújula', 'Esdrújula'], ['cómpramelo', 'Sobresdrújula'], ['dígaselo', 'Sobresdrújula'], ['devuélvemelo', 'Sobresdrújula'] ] },
  categorias: { ask: (w) => `¿Qué categoría gramatical es «${w}» en «${{ casa: 'La casa es grande', correr: 'Me gusta correr', hermoso: 'Un día hermoso', lentamente: 'Camina lentamente', ellos: 'Ellos llegaron', en: 'Está en Lima', y: 'Pan y leche', 'ojalá': '¡Ojalá llueva!', libro: 'Leí un libro', escribió: 'Ana escribió', azul: 'El cielo azul', nosotros: 'Nosotros ganamos', desde: 'Vine desde Puno', pero: 'Quiero, pero no puedo', ayer: 'Llegó ayer' }[w]}»?`, back: null, rows: [
    ['casa', 'Sustantivo'], ['libro', 'Sustantivo'], ['correr', 'Verbo'], ['escribió', 'Verbo'], ['hermoso', 'Adjetivo'], ['azul', 'Adjetivo'], ['lentamente', 'Adverbio'], ['ayer', 'Adverbio'],
    ['ellos', 'Pronombre'], ['nosotros', 'Pronombre'], ['en', 'Preposición'], ['desde', 'Preposición'], ['y', 'Conjunción'], ['pero', 'Conjunción'], ['ojalá', 'Interjección'] ] },
  sinonimos: { ask: (w) => `¿Cuál es un sinónimo de «${w}»?`, back: null, rows: [
    ['alegre', 'Contento'], ['rápido', 'Veloz'], ['valiente', 'Osado'], ['generoso', 'Dadivoso'], ['antiguo', 'Vetusto'], ['abundante', 'Copioso'], ['efímero', 'Fugaz'],
    ['diáfano', 'Claro'], ['locuaz', 'Hablador'], ['sagaz', 'Astuto'], ['perenne', 'Perpetuo'], ['exiguo', 'Escaso'] ] },
  antonimos: { ask: (w) => `¿Cuál es un antónimo de «${w}»?`, back: null, rows: [
    ['alegre', 'Triste'], ['rápido', 'Lento'], ['valiente', 'Cobarde'], ['generoso', 'Tacaño'], ['antiguo', 'Moderno'], ['abundante', 'Escaso'], ['efímero', 'Duradero'],
    ['diáfano', 'Turbio'], ['locuaz', 'Callado'], ['sagaz', 'Ingenuo'], ['soberbio', 'Humilde'], ['prolijo', 'Descuidado'] ] },
  obras: { ask: (o) => `¿Quién escribió «${o}»?`, back: null, rows: [
    ['Cien años de soledad', 'Gabriel García Márquez'], ['La ciudad y los perros', 'Mario Vargas Llosa'], ['Los ríos profundos', 'José María Arguedas'], ['Trilce', 'César Vallejo'],
    ['Tradiciones peruanas', 'Ricardo Palma'], ['Don Quijote de la Mancha', 'Miguel de Cervantes'], ['Comentarios reales', 'Inca Garcilaso de la Vega'], ['El mundo es ancho y ajeno', 'Ciro Alegría'],
    ['La Odisea', 'Homero'], ['Romeo y Julieta', 'William Shakespeare'], ['Rayuela', 'Julio Cortázar'], ['Pedro Páramo', 'Juan Rulfo'], ['Veinte poemas de amor y una canción desesperada', 'Pablo Neruda'] ] },
  nacionalidad: { ask: (a) => `¿De qué nacionalidad es el escritor ${a}?`, back: null, rows: [
    ['César Vallejo', 'Peruano'], ['Pablo Neruda', 'Chileno'], ['Gabriel García Márquez', 'Colombiano'], ['Julio Cortázar', 'Argentino'], ['Juan Rulfo', 'Mexicano'],
    ['Miguel de Cervantes', 'Español'], ['William Shakespeare', 'Inglés'], ['Homero', 'Griego'], ['Rubén Darío', 'Nicaragüense'] ] },
};

/** All questions of a fact table: direct ones and, if unambiguous, the inverse ones. */
function factItems(table) {
  const fix = (t) => t.replace(/ de el /g, ' del ');
  const answers = [...new Set(table.rows.map((r) => r[1]))];
  const items = table.rows.map(([k, v, own]) => ({ text: table.ask(k), ok: v, bad: own || shuffle(answers.filter((a) => a !== v)).slice(0, 4), exp: `${k.charAt(0).toUpperCase() + k.slice(1)}: ${v}.` }));
  if (table.back) {
    const keys = table.rows.map((r) => r[0]);
    for (const [k, v] of table.rows) items.push({ text: table.back(v), ok: k.charAt(0).toUpperCase() + k.slice(1), bad: shuffle(keys.filter((x) => x !== k)).slice(0, 4).map((x) => x.charAt(0).toUpperCase() + x.slice(1)), exp: `${v}: ${k}.` });
  }
  return shuffle(items.map((q) => ({ ...q, text: fix(q.text) })));
}

// ---------------------------------------------------------------- Cursos
// [clave, nombre, descripción, [[tema, [[subtema, generador o tabla], ...]], ...]]
const MATH = [
  ['alg', 'Álgebra (QA)', 'Ecuaciones, polinomios, exponentes y funciones.', [
    ['Ecuaciones', [['Ecuaciones lineales', 'lineales'], ['Sistemas de ecuaciones', 'sistemas'], ['Ecuaciones cuadráticas', 'cuadraticas']]],
    ['Polinomios', [['Productos notables', 'productos'], ['Factorización', 'factorizacion']]],
    ['Exponentes y funciones', [['Leyes de exponentes', 'exponentes'], ['Composición de funciones', 'funciones']]]]],
  ['ari', 'Aritmética (QA)', 'Operaciones, divisibilidad, fracciones y proporcionalidad.', [
    ['Números', [['Operaciones combinadas', 'combinadas'], ['MCD y MCM', 'mcdmcm']]],
    ['Fracciones y porcentajes', [['Suma de fracciones', 'fracciones'], ['Tanto por ciento', 'porcentajes']]],
    ['Proporcionalidad', [['Regla de tres', 'reglaTres'], ['Interés simple', 'interes'], ['Promedios', 'promedios']]]]],
  ['geo', 'Geometría (QA)', 'Ángulos, triángulos, áreas y volúmenes.', [
    ['Ángulos y polígonos', [['Complemento y suplemento', 'angulos'], ['Polígonos', 'poligonos']]],
    ['Triángulos', [['Teorema de Pitágoras', 'pitagoras'], ['Área del triángulo', 'areaTriangulo']]],
    ['Áreas y volúmenes', [['Rectángulos', 'rectangulos'], ['Circunferencia y círculo', 'circulo'], ['Volúmenes', 'volumenes']]]]],
  ['tri', 'Trigonometría (QA)', 'Razones trigonométricas, ángulos notables, sistemas de medida e identidades.', [
    ['Razones trigonométricas', [['Razones en el triángulo rectángulo', 'razones'], ['Ángulos notables', 'notables']]],
    ['Sistemas de medida angular', [['Grados y radianes', 'radianes'], ['Sexagesimal y centesimal', 'sistemasAng']]],
    ['Identidades', [['Identidad pitagórica', 'identidades']]]]],
  ['fis', 'Física (QA)', 'Cinemática, dinámica y energía.', [
    ['Cinemática', [['MRU', 'mru'], ['MRUV', 'mruv']]],
    ['Dinámica', [['Segunda ley de Newton', 'newton'], ['Peso', 'peso']]],
    ['Trabajo y energía', [['Trabajo mecánico', 'trabajo'], ['Energía cinética', 'cinetica'], ['Potencia', 'potencia']]]]],
  ['qui', 'Química (QA)', 'Materia, estructura atómica y estequiometría.', [
    ['Materia', [['Escalas de temperatura', 'temperatura'], ['Densidad', 'densidad']]],
    ['Estructura atómica', [['Protones, neutrones y electrones', 'particulas']]],
    ['Estequiometría', [['Mol y masa molar', 'moles'], ['Molaridad', 'molaridad']]]]],
];
const FACTS = [
  ['bio', 'Biología (QA)', 'Célula, cuerpo humano, genética y ecología.', [
    ['La célula', [['Organelos celulares', 'organelos']]],
    ['Cuerpo humano', [['Sistemas del cuerpo', 'sistemas'], ['Hormonas y glándulas', 'hormonas']]],
    ['Genética y ecología', [['Herencia y ADN', 'genetica'], ['Relaciones entre especies', 'ecologia']]]]],
  ['his', 'Historia del Perú (QA)', 'Culturas preíncas, incas, independencia y república.', [
    ['Perú antiguo', [['Culturas preíncas', 'culturas'], ['Los incas', 'incas']]],
    ['Independencia y república', [['Fechas clave', 'fechas'], ['Personajes', 'personajes']]]]],
  ['geg', 'Geografía (QA)', 'Departamentos, regiones naturales y Sudamérica.', [
    ['Geografía del Perú', [['Departamentos y capitales', 'capitales'], ['Regiones naturales', 'regiones']]],
    ['Sudamérica', [['Capitales de Sudamérica', 'sudamerica']]]]],
  ['len', 'Lenguaje (QA)', 'Acentuación y categorías gramaticales.', [
    ['Ortografía', [['Clasificación por el acento', 'acentuacion']]],
    ['Gramática', [['Categorías gramaticales', 'categorias']]]]],
  ['rv', 'Razonamiento Verbal (QA)', 'Sinónimos y antónimos.', [
    ['Series y relaciones léxicas', [['Sinónimos', 'sinonimos'], ['Antónimos', 'antonimos']]]]],
  ['lit', 'Literatura (QA)', 'Obras y autores de la literatura peruana y universal.', [
    ['Obras y autores', [['¿Quién escribió…?', 'obras'], ['Nacionalidad de los autores', 'nacionalidad']]]]],
];

// ---------------------------------------------------------------- Contenido de una parte
function partDoc(id, topicId, subtopicId, order, name, subName, samples) {
  const [a, b, c, d] = samples;
  return {
    id, active: true, name, idSubtopic: subtopicId, idTopic: topicId, order, linkVideo: '', linkPdf: '', examTemplateId: PART_TEMPLATE,
    content: `En esta parte estudiarás ${subName.toLowerCase()}. Lee el resumen, revisa los ejemplos resueltos, practica y luego rinde el examen de la parte.`,
    summary: `${name}: ${a.exp}`,
    objectives: [`Reconocer los casos de ${subName.toLowerCase()}`, 'Resolver preguntas tipo examen de admisión', 'Verificar la respuesta antes de marcar'],
    keyPoints: [a.exp, b.exp, 'Descarta primero las alternativas que no cumplen la condición'],
    estimatedMinutes: 10 + 5 * (order % 3), difficulty: ['basic', 'intermediate', 'advanced'][order % 3],
    examples: [a, b].map((g, i) => ({ id: `${id}-ex${i + 1}`, title: `Ejemplo ${i + 1}`, problem: g.text, steps: [g.exp], answer: g.ok })),
    exercises: [c, d].map((g, i) => ({ id: `${id}-ej${i + 1}`, statement: g.text, hint: 'Revisa el resumen y los ejemplos.', answer: g.ok, difficulty: i ? 'intermediate' : 'basic' })),
    flashcards: [a, b, c].map((g, i) => ({ id: `${id}-fc${i + 1}`, front: g.text, back: g.ok })),
    quizQuestions: [c, d].map((g, i) => {
      const options = shuffle([g.ok, ...g.bad.slice(0, 3)]);
      return { id: `${id}-qz${i + 1}`, question: g.text, options, correctIndex: options.indexOf(g.ok), explanation: g.exp };
    }),
    externalLinks: [{ id: `${id}-l1`, title: 'Material de apoyo', url: 'https://es.khanacademy.org/', type: 'article' }],
  };
}

function tokens(text) {
  return [...new Set(text.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').split(/[^a-z0-9]+/).filter((t) => t.length >= 3))].slice(0, 30);
}

function template(id, title, purpose, count, pass) {
  const blank = { universityId: '', sourceExamId: '', modalityId: '', courseId: '', topicId: '', subtopicId: '', partId: '', sourceType: 'any', difficulty: 'any' };
  return { schemaVersion: 2, id, version: 1, title, purpose, mode: 'dynamic', selectionPolicy: 'strict', allowedFallbackSources: [],
    questionCount: count, passPercentExclusive: pass, durationSeconds: purpose === 'subtopic_mastery' ? 1800 : 900, blocks: [{ count, filter: blank }], fixedQuestions: [],
    status: 'published', active: true };
}

async function commitAll(ops) {
  for (let i = 0; i < ops.length; i += 400) {
    const batch = db.batch();
    ops.slice(i, i + 400).forEach((op) => op(batch));
    await batch.commit();
    process.stdout.write(`\r  escrituras ${Math.min(i + 400, ops.length)}/${ops.length}`);
  }
  process.stdout.write('\n');
}

async function removeAll() {
  for (const [key] of [...MATH, ...FACTS]) await db.recursiveDelete(db.collection(C.courses).doc(`${PREFIX}${key}`));
  const FP = admin.firestore.FieldPath.documentId();
  const qs = await db.collection(C.questions).where(FP, '>=', PREFIX).where(FP, '<', PREFIX.slice(0, -1) + '.').get();
  for (const q of qs.docs) { await db.recursiveDelete(q.ref); await db.collection(C.keys).doc(`${q.id}_1`).delete(); }
  for (const t of [PART_TEMPLATE, MASTERY_TEMPLATE]) await db.recursiveDelete(db.collection(C.templates).doc(t));
  console.log(`Borrado: ${MATH.length + FACTS.length} cursos, ${qs.size} preguntas y 2 plantillas.`);
}

async function main() {
  if (DELETE) return removeAll();
  const ops = [];
  const set = (ref, data) => ops.push((b) => b.set(ref, data));
  const stats = { courses: 0, topics: 0, subtopics: 0, parts: 0, questions: 0 };

  // Plantillas genéricas: Functions completan curso, tema, subtema y parte desde la solicitud.
  for (const t of [template(PART_TEMPLATE, 'Examen de la parte (QA)', 'part_completion', 5, 79),
                   template(MASTERY_TEMPLATE, 'Examen de dominio (QA)', 'subtopic_mastery', 8, 74)]) {
    const ref = db.collection(C.templates).doc(t.id);
    set(ref, { ...t, createdAt: TS(), updatedAt: TS() });
    set(ref.collection('versions').doc('1'), { ...t, createdAt: TS(), updatedAt: TS(), versionedAt: TS() });
  }

  const courses = [...MATH.map((c) => [...c, 'math']), ...FACTS.map((c) => [...c, 'fact'])];
  for (const [key, name, description, topics, kind] of courses) {
    const courseId = `${PREFIX}${key}`;
    const courseRef = db.collection(C.courses).doc(courseId);
    set(courseRef, { idDoc: courseId, name, description, active: true, createdAt: TS(), updatedAt: TS() });
    stats.courses++;
    topics.forEach(([topicName, subtopics], ti) => {
      const topicId = `${courseId}-t${ti + 1}`;
      const topicRef = courseRef.collection('topics').doc(topicId);
      set(topicRef, { name: topicName, description: `${topicName}: teoría, ejemplos y preguntas tipo admisión.`, order: ti + 1, summary: `Tema ${ti + 1} de ${name}.`, active: true, createdAt: TS(), updatedAt: TS() });
      stats.topics++;
      subtopics.forEach(([subName, source], si) => {
        const subtopicId = `${topicId}-s${si + 1}`;
        const pool = kind === 'math' ? null : factItems(T[source]);
        // Sin repetir preguntas cuando la tabla alcanza; nunca menos de las 5 que pide el examen de la parte.
        const perPart = pool ? Math.max(5, Math.min(FACT_PER_PART, Math.floor(pool.length / PARTS_PER_SUBTOPIC))) : MATH_PER_PART;
        let cursor = 0;
        const next = () => (pool ? pool[cursor++ % pool.length] : G[source]());
        const parts = [];
        const banks = [];
        for (let pi = 1; pi <= PARTS_PER_SUBTOPIC; pi++) {
          const bank = Array.from({ length: perPart }, next);
          const samples = pool ? [pool[(cursor + 1) % pool.length], pool[(cursor + 2) % pool.length], bank[0], bank[1]] : [G[source](), G[source](), G[source](), G[source]()];
          parts.push(partDoc(`${subtopicId}-p${pi}`, topicId, subtopicId, pi, `${subName} ${pi === 1 ? '(conceptos)' : '(práctica)'}`, subName, samples));
          banks.push(bank);
        }
        stats.subtopics++;
        stats.parts += parts.length;
        set(topicRef.collection('subtopics').doc(subtopicId), { name: subName, content: `Subtema ${subName} del curso ${name}.`, order: si + 1, linkVideo: '', idTopic: topicId,
          masteryTemplateId: MASTERY_TEMPLATE, active: true, listPart: parts, createdAt: TS(), updatedAt: TS() });
        parts.forEach((p, pi) => banks[pi].forEach((g, k) => {
          const questionId = `${p.id}-q${String(k + 1).padStart(2, '0')}`;
          const ids = ['a', 'b', 'c', 'd', 'e'];
          const unique = [g.ok, ...g.bad.filter((v, i, l) => v !== g.ok && l.indexOf(v) === i).slice(0, 4)];
          if (unique.length < 5) unique.push('Ninguna de las anteriores');
          if (unique.length < 4 || new Set(unique).size !== unique.length) throw new Error(`Alternativas inválidas en ${questionId}: ${JSON.stringify(unique)}`);
          const options = shuffle(unique);
          const correctId = ids[options.indexOf(g.ok)];
          const tk = tokens(`${g.text} ${name} ${topicName} ${subName}`);
          const q = { schemaVersion: 2, questionId, version: 1, status: 'published', sourceType: 'original',
            courseId, topicId, subtopicId, partIds: [p.id], difficulty: ['easy', 'medium', 'hard'][k % 3],
            content: [{ id: `${questionId}-c1`, type: 'text', text: g.text }],
            alternatives: options.map((v, i) => ({ id: ids[i], label: ids[i].toUpperCase(), content: [{ id: `${questionId}-${ids[i]}`, type: 'text', text: v }] })),
            sourceExamId: '', universityId: '', modalityId: '', year: null, period: '', sourceLabel: 'Pregunta de práctica IngresoYa (QA)',
            randomKey: rnd(), searchTokens: tk, partSearchTokens: tk.map((t) => `${p.id}|${t}`) };
          const qRef = db.collection(C.questions).doc(questionId);
          set(qRef, { ...q, createdAt: TS(), updatedAt: TS(), publishedAt: TS() });
          set(qRef.collection('versions').doc('1'), { ...q, createdAt: TS(), updatedAt: TS(), publishedAt: TS() });
          set(db.collection(C.keys).doc(`${questionId}_1`), { schemaVersion: 2, questionId, version: 1, correctAlternativeId: correctId,
            explanation: [{ id: `${questionId}-e1`, type: 'text', text: g.exp }], createdAt: TS(), updatedAt: TS() });
          stats.questions++;
        }));
      });
    });
  }
  if (process.argv.includes('--dry-run')) {
    console.log('Simulación (sin escribir):', JSON.stringify(stats), 'escrituras:', ops.length);
    return;
  }
  await commitAll(ops);
  console.log(`OK: ${stats.courses} cursos, ${stats.topics} temas, ${stats.subtopics} subtemas, ${stats.parts} partes, ${stats.questions} preguntas (+claves y versiones), 2 plantillas.`);
}

module.exports = { G, T, factItems };
if (require.main === module) main().catch((e) => { console.error(e); process.exit(1); });
