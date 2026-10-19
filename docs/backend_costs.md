# Costos y medición de exámenes

Esta guía describe trabajo de Firestore **observado por la Function**, no una
cotización ni una garantía de facturación. Firestore puede cobrar lecturas de
entradas de índice para determinadas consultas, reintentar transacciones y
cambiar condiciones de facturación. Antes de estimar gasto se deben recopilar
los logs de staging con distribución real de banco y concurrencia.

## Telemetría segura

Al completar o rechazar una callable se registra un evento sin payload,
respuestas, claves, explicaciones ni UID. Sus campos numéricos son:

- `durationMs`: tiempo de pared de la Function;
- `observedDocumentReads`: suma de lecturas directas y documentos devueltos por
  consultas;
- `queryCalls`, `queryDocuments`, `plannedDocumentWrites` y
  `transactionAttempts`.

No representan el recibo de Firebase. Sirven para medir percentiles de latencia
por operación y detectar aumentos de consultas/devueltos o reintentos. Deben
agregarse por nombre de evento en Cloud Logging/Monitoring, en staging, y
compararse antes y después de cambiar un índice o una plantilla.

## Trabajo observado por operación

La siguiente tabla asume un intento nuevo dinámico de un solo bloque para una
parte y una transacción sin reintentos. `R` es la cantidad real de documentos en
`recentQuestions` devueltos (límite 200); `Q` los documentos realmente devueltos
por los escaneos de candidatos. Los límites se muestran como máximos de código,
no como lecturas garantizadas.

| Operación | Lecturas observadas | Escrituras lógicas | Notas |
| --- | --- | --- | --- |
| Crear 10 preguntas | `8 + R + Q`, con `Q ≤ 4 × 80 = 320` | `10 + 2 = 12` | 8 lecturas directas: idempotencia inicial/transaccional, perfil, progreso, plantilla y tres documentos académicos. |
| Crear 15 preguntas | `8 + R + Q`, con `Q ≤ 4 × 80 = 320` | `15 + 2 = 17` | El límite por escaneo llega a 80 desde 10 preguntas; no crece por encima de ese tope. |
| Reintento con el mismo `requestId` | 2 | 0 | Clave idempotente e intento congelado; no se vuelve a seleccionar. |
| Recuperar intento | 1 | 0 | Un documento de intento, con instantánea y respuestas ya guardadas. Vigilar tamaño del documento. |
| Guardar respuestas modificadas | 1 | 1 | Una transacción; un patch sin cambios no escribe. |
| Calificar 10 preguntas | 11, o 12 si hay progreso de parte | 1, o hasta 2 con progreso | Intento + 10 claves; parte aprobada añade progreso. |
| Calificar 15 preguntas | 16, o 17 si hay progreso de parte | 1, o hasta 2 con progreso | Las claves se leen en un `transaction.getAll`, una llamada agrupada, no N+1 de red. |

Las transacciones pueden reintentarse por contención: el campo
`transactionAttempts` permite identificarlo, y cada reintento vuelve a ejecutar
sus lecturas. `plannedDocumentWrites` cuenta planes de escritura ejecutados por
la Function y puede crecer con un reintento; las escrituras de la tabla son
documentos lógicos del camino exitoso. Ninguna cifra incluye costes de índices
ni de red.

## Selección, políticas y banco insuficiente

Cada bloque hace hasta `EXAM_CANDIDATE_STARTS_PER_BLOCK` escaneos de `randomKey`
(por defecto 4). Cada uno está limitado a
`min(EXAM_MAX_CANDIDATES_PER_START, max(20, cantidad × 8))`, con máximo 80. La
consulta filtra en servidor por `status`, curso, tema, subtema, parte y, cuando
corresponde, `sourceType`; universidad, modalidad, examen, dificultad y año se
validan luego sobre ese conjunto ya acotado. `strict` y
`prefer_profile_university` no añaden consultas: cambian solo el ranking local.

Si el conjunto no alcanza, se devuelve `insufficient_questions` con disponibles
y requeridas antes de crear la transacción: hay las lecturas de validación y
escaneos, pero cero escrituras de intento, idempotencia o repetición. Esto no es
una prueba de que no existan más documentos fuera de la ventana aleatoria; es el
comportamiento deliberadamente limitado de esta política.

## Límites e índices versionados

Los límites se leen desde configuración de Functions y están acotados para
impedir una consulta accidentalmente abierta:

| Variable | Predeterminado | Rango permitido |
| --- | ---: | ---: |
| `EXAM_CANDIDATE_STARTS_PER_BLOCK` | 4 (TEST usa 2) | 1–8 |
| `EXAM_MAX_CANDIDATES_PER_START` | 80 (TEST usa 40) | 20–80 |
| `EXAM_RECENT_QUESTION_LIMIT` | 200 (TEST usa 60) | 1–200 |

Desde la Fase 1A de la reestructuración de costos (2026-10-18) TEST corre con
2 / 40 / 60. Desde la Fase 3C los límites vigentes salen de `{config}/exam`
(Configuración → Exámenes, `docs/exam_config_contract.md`); las variables de
entorno son solo el respaldo.
La medición antes y después está en `docs/cost_baseline.md`.

`firestore.rules`, `storage.rules`, `firestore.indexes.json`, `firebase.json`,
`functions/src/config.ts` y `.env.example` permanecen versionados. Los dos
índices de selección por parte añaden el contexto académico y su variante con
`sourceType`; están declarados para test, staging y producción. Este repositorio
no despliega ninguno de esos artefactos.

## Protocolo de medición antes de producción

1. Cargar en staging un banco sintético representativo, sin datos reales.
2. Ejecutar lotes de creación de 10 y 15 preguntas para cada política y
   distribución de plantilla, incluyendo banco justo e insuficiente.
3. Agregar `durationMs`, lecturas, consultas, documentos devueltos y reintentos
   por evento; revisar p50/p95/p99 y errores estructurados.
4. Confirmar con el panel de uso/facturación de Firebase para el proyecto de
   staging. No extrapolar métricas del emulador a costos de producción.

## Fase 3B de la reestructuración de costos (2026-10-18): menos trabajo por llamada

- **Configuración en caché por instancia** (`config_cache.ts`, 5 minutos):
  `{config}/xp`, `rankings`, `simulator` y `exam` ya no se leen en cada
  llamada. Un envío de reto del día leía `xp` tres veces; ahora cero en una
  instancia caliente.
- **El intento se lee una vez por envío:** `submit` devuelve el documento tal
  como quedó (`attemptData`, interno) y `afterAttempt`,
  `afterSimulatorAttempt` y `recordEntry` lo reutilizan. Antes el mismo
  intento (25 a 250 KB) se leía 2 o 3 veces en la misma llamada.
- **Sin rechequeo de XP cuando no hay nada nuevo:**
  `recordPartSectionCompletion` devuelve `changed: false` si la llamada no
  registró ninguna sección ni completó la parte, y el handler no llama a
  `afterGuide` (que leía el avance, hasta 3 eventos y hasta 8 movimientos de
  XP para no conceder nada).
- **Tarjeta pública solo con rankings encendidos:** `XpService.grant` deja de
  escribir `leaderboard/{uid}` mientras `{config}/rankings.enabled` es false;
  la siguiente concesión tras encenderlos la reescribe.

| Operación | Antes (lecturas) | Después |
| --- | ---: | ---: |
| Sección repetida (`recordPartSectionCompletion`) | 5 + 10 a 15 | 5 |
| Envío de examen de parte (incluida la XP) | n + 3 + 1 + 15 | n + 3 + 10 |
| Envío de reto del día | n + 4 + 3 lecturas de `xp` + 2 del intento | n + 4 |

## Fase 4B de la reestructuración de costos (2026-10-18)

- **Cierre de liga por páginas:** `closeLeagueWeek` lee los asientos de la
  semana de 500 en 500 (`orderBy(documentId)` + `startAfter`) en vez de una sola
  consulta; con decenas de miles de asientos la consulta única superaba la
  memoria y el tiempo de la instancia.
- **Nocturno de estadísticas con varias pasadas:** `nightlyQuestionStats` repite
  `refresh(20000)` hasta tres veces si la pasada anterior llenó el cupo; antes,
  con más de ~6 000 alumnos activos al día, el trabajo se atrasaba y los
  intentos caducaban (TTL de la Fase 4A) sin contarse. `questionsOf` toma las
  alternativas de `questionSnapshots` cuando `questions` no las trae.
- **Historial más liviano:** las copias `before`/`after` del historial del admin
  solo se guardan hasta 60 KB (antes 180 KB); por encima queda la lista de
  campos cambiados y `tooLarge`.
- **Tope de 100 preguntas por examen pasado:** `questionCount` 1–100 en el admin
  (`ExamSimulatorRules.validate`) y en `parsePastExamRules`.

## Lecturas de una práctica del Simulador (2026-10-19)

Una práctica por curso de 20 preguntas costaba 234 lecturas y 27 escrituras del servidor: 100 para leer las preguntas vistas (un documento por pregunta en `recentQuestions`), 80 de dos muestras de 40 candidatas y 20 para repasar las vistas por el XP; y 20 escrituras, una por pregunta vista. Dos cambios (PR admin #111):

- **Preguntas vistas en un documento** `{perfil}/{uid}/examMemory/recent` (`exam_memory.ts`): `q[questionId] = {t, n}`, las últimas 600, una lectura y una escritura por examen. Lo usan el Simulador (ventana de repetición y XP de respuesta nueva) y el examen de parte (`recentQuestionLimit`). Migración sola: si el documento no existe, se leen una vez los `recentQuestions` antiguos y se copian; esos documentos ya no se escriben y caducan por TTL.
- **Índice de preguntas por curso** `{questionIndex}/{courseId}` (`question_index.ts`): `q[questionId] = {v, t, s, d, o, u}` de las preguntas publicadas, mantenido por el disparador `indexQuestions`; carga inicial con `node tools/build_question_index.js --env <env> --project <id>`. `coursePool` ordena el índice con la semilla, deja las vistas al final, filtra origen y dificultad y lee solo las que usará + 2; sin índice usa las consultas de antes. Sirve a práctica, plan, diagnóstico y reto del día. Límite: un curso cabe hasta unas 5 000 preguntas por documento.

| Medido en TEST | Antes | Después |
| --- | ---: | ---: |
| Crear una práctica de 20: lecturas / escrituras | 208 / 22 | 28 / 3 |
| Crear: duración | 1,5 a 3,4 s | 0,6 s |
| Entregar: lecturas | 25 | 23 |

La primera práctica de un alumno de antes del cambio lee una vez su historial antiguo (hasta 600 documentos) para migrarlo.

No se hizo «claves congeladas en el intento»: las preguntas publicadas no llevan respuesta ni explicación (contrato v2), así que congelarlas al crear exige leer las mismas 20 claves al crear; solo cambia el momento de la lectura.

## Fase 5B de costos: plan premium (2026-10-19)

- `premium` y `usage` viven en el documento del perfil que la app ya lee al entrar: saber si el alumno
  es premium no cuesta lecturas extra; el tope diario de exámenes pasados usa el mismo perfil que
  `createExamAttempt` ya carga y se escribe en la misma transacción del intento (+1 escritura solo
  en exámenes pasados de cuentas gratuitas).
- `verifyPurchase`: 1 llamada a la API de Play + 1 lectura del índice de tokens + 3 escrituras
  (índice, perfil, bitácora), una vez por compra o restauración. Las renovaciones llegan por Pub/Sub
  (`onPlayNotification`), sin sondeos.
- `{config}/premium` viaja dentro de `{config}/app` (ninguna lectura adicional).
