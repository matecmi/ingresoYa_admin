// Reporte de costo observado por operación, a partir de la telemetría que ya
// emiten las Functions (docs/backend_costs.md): observedDocumentReads,
// queryCalls, queryDocuments, plannedDocumentWrites, transactionAttempts y
// durationMs por evento (exam_attempt_create_completed, xp_granted, ...).
//
// Uso (desde functions/, con `gcloud auth login` hecho una vez):
//   node tools/cost_report.js [--project ingresoya-e5115] [--days 3] [--sessions N] [--json]
//   node tools/cost_report.js --since 2026-10-20T00:00:00Z --until 2026-10-23T00:00:00Z
//
// El token sale de `gcloud auth print-access-token`; también se acepta
// GOOGLE_OAUTH_ACCESS_TOKEN en el entorno. No lee ni imprime payloads ni UIDs:
// solo agrega los campos numéricos que las Functions ya registran.
//
// No es la factura de Firebase: Firestore puede cobrar lecturas de índices y
// reintentos que este contador no ve. Sirve para comparar antes y después.
'use strict';
const { execFileSync } = require('child_process');
const https = require('https');

const args = parseArgs(process.argv.slice(2));
const project = args.project || 'ingresoya-e5115';
const days = Number(args.days || 3);
const until = args.until ? new Date(args.until) : new Date();
const since = args.since ? new Date(args.since) : new Date(until.getTime() - days * 864e5);
const sessions = args.sessions ? Number(args.sessions) : null;
const maxPages = Number(args['max-pages'] || 50);

const NUMERIC = ['durationMs', 'observedDocumentReads', 'directDocumentReads', 'queryCalls', 'queryDocuments', 'plannedDocumentWrites', 'transactionAttempts'];

main().catch((e) => { console.error('Error:', e.message); process.exit(1); });

async function main() {
  const token = process.env.GOOGLE_OAUTH_ACCESS_TOKEN || gcloudToken();
  const filter = [
    '(resource.type="cloud_run_revision" OR resource.type="cloud_function")',
    'jsonPayload.durationMs:*',
    `timestamp>="${since.toISOString()}"`,
    `timestamp<="${until.toISOString()}"`,
  ].join(' AND ');
  const entries = await listEntries(token, project, filter);
  const byEvent = new Map();
  for (const e of entries) {
    const p = e.jsonPayload || {};
    const event = String(p.message || e.textPayload || 'sin_nombre');
    if (!byEvent.has(event)) byEvent.set(event, { n: 0, samples: Object.fromEntries(NUMERIC.map((k) => [k, []])) });
    const bucket = byEvent.get(event);
    bucket.n += 1;
    for (const k of NUMERIC) if (typeof p[k] === 'number') bucket.samples[k].push(p[k]);
  }
  const rows = [...byEvent.entries()]
    .map(([event, b]) => ({
      event,
      n: b.n,
      durP50: pct(b.samples.durationMs, 50),
      durP95: pct(b.samples.durationMs, 95),
      readsMean: mean(b.samples.observedDocumentReads),
      readsP95: pct(b.samples.observedDocumentReads, 95),
      queryDocsMean: mean(b.samples.queryDocuments),
      writesMean: mean(b.samples.plannedDocumentWrites),
      txMean: mean(b.samples.transactionAttempts),
      readsTotal: sum(b.samples.observedDocumentReads),
      writesTotal: sum(b.samples.plannedDocumentWrites),
    }))
    .sort((a, b) => b.readsTotal - a.readsTotal);
  const totals = {
    invocations: rows.reduce((s, r) => s + r.n, 0),
    reads: rows.reduce((s, r) => s + r.readsTotal, 0),
    writes: rows.reduce((s, r) => s + r.writesTotal, 0),
  };
  if (args.json) {
    console.log(JSON.stringify({ project, since, until, rows, totals, sessions }, null, 2));
    return;
  }
  console.log(`# Costo observado por operación · ${project}`);
  console.log(`Ventana: ${since.toISOString()} → ${until.toISOString()} · ${entries.length} eventos con telemetría\n`);
  console.log('| Evento | n | durationMs p50 | p95 | lecturas media | lecturas p95 | docs de consulta media | escrituras media | tx media | lecturas total | escrituras total |');
  console.log('| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |');
  for (const r of rows) {
    console.log(`| ${r.event} | ${r.n} | ${f(r.durP50)} | ${f(r.durP95)} | ${f(r.readsMean, 1)} | ${f(r.readsP95)} | ${f(r.queryDocsMean, 1)} | ${f(r.writesMean, 1)} | ${f(r.txMean, 2)} | ${r.readsTotal} | ${r.writesTotal} |`);
  }
  console.log(`\n**Totales del servidor:** ${totals.invocations} invocaciones con telemetría · ${totals.reads} lecturas observadas · ${totals.writes} escrituras planificadas.`);
  if (sessions) {
    console.log(`**Por sesión (${sessions} sesiones):** ${f(totals.invocations / sessions, 1)} invocaciones · ${f(totals.reads / sessions, 1)} lecturas · ${f(totals.writes / sessions, 1)} escrituras.`);
  }
  console.log('\nLas lecturas de la app (listeners, rankings, catálogo) no pasan por aquí: salen del panel Uso y facturación de Firebase restando estas.');
}

function gcloudToken() {
  const cmd = process.platform === 'win32' ? 'gcloud.cmd' : 'gcloud';
  try {
    return execFileSync(cmd, ['auth', 'print-access-token'], { encoding: 'utf8' }).trim();
  } catch (e) {
    throw new Error('No se pudo obtener el token. Ejecuta `gcloud auth login` una vez o define GOOGLE_OAUTH_ACCESS_TOKEN.');
  }
}

async function listEntries(token, projectId, filter) {
  const out = [];
  let pageToken;
  for (let page = 0; page < maxPages; page += 1) {
    const body = { resourceNames: [`projects/${projectId}`], filter, orderBy: 'timestamp desc', pageSize: 1000, pageToken };
    const res = await post('https://logging.googleapis.com/v2/entries:list', token, body);
    out.push(...(res.entries || []));
    pageToken = res.nextPageToken;
    if (!pageToken) break;
  }
  return out;
}

function post(url, token, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(url, { method: 'POST', headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } }, (res) => {
      let buf = '';
      res.on('data', (c) => { buf += c; });
      res.on('end', () => {
        if (res.statusCode >= 300) return reject(new Error(`HTTP ${res.statusCode}: ${buf.slice(0, 300)}`));
        resolve(JSON.parse(buf || '{}'));
      });
    });
    req.on('error', reject);
    req.end(data);
  });
}

function parseArgs(list) {
  const o = {};
  for (let i = 0; i < list.length; i += 1) {
    const a = list[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    const next = list[i + 1];
    if (next === undefined || next.startsWith('--')) o[key] = true;
    else { o[key] = next; i += 1; }
  }
  return o;
}

function sum(xs) { return xs.reduce((s, x) => s + x, 0); }
function mean(xs) { return xs.length ? sum(xs) / xs.length : null; }
function pct(xs, p) {
  if (!xs.length) return null;
  const s = [...xs].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))];
}
function f(v, d = 0) { return v === null || v === undefined ? '—' : Number(v).toFixed(d); }
