# Contrato del Simulador

Compartido por el admin, Functions y la app (`iya-app/docs/simulator_contract.md`
es una copia). Diseño: lienzo «Simulador B+» (opción elegida por Kevin). Esta etapa
cubre el Simulador base: exámenes pasados y práctica libre; el plan de
entrenamiento, el XP y el ranking vienen después y reutilizan estos datos.

## 1. Exámenes pasados

Un examen pasado es un registro del catálogo
`{universities}/{universityId}/admissionExams/{examId}` (ver
`admission_exam_catalog.md`). Sus reglas para el Simulador viven en el campo
`simulator`, **separado** de los datos de catálogo: editarlas no cambia
`revision` ni reescribe las preguntas vinculadas.

| Campo `simulator.*` | Tipo | Significado |
|---|---|---|
| `questionCount` | int 1–300 | Preguntas que tuvo el examen real |
| `durationMinutes` | int 1–600 | Tiempo del examen |
| `maxScore` | int > 0 | Puntaje máximo mostrado (p. ej. 1000) |
| `correctPoints` | número > 0 | Puntos por correcta |
| `incorrectPoints` | número ≤ 0 | Puntos por incorrecta (penalidad) |
| `blankPoints` | número | Puntos por pregunta en blanco (entre incorrecta y correcta) |
| `questionOrder` | `original` \| `shuffled` | `original` ordena por `originalNumber` de cada pregunta |
| `available` | bool | Se ofrece en la app; solo si `complete` |
| `cutoffs` | mapa `professionId → int` | Puntaje mínimo de ingreso por carrera, sobre `maxScore` (opcional) |
| `publishedQuestions`, `numberedQuestions`, `complete`, `checkedAt` | calculados | Los escribe el admin al guardar |

**Completo**: preguntas publicadas del examen (`examId`, misma `universityId`,
`status: published`) = `questionCount` y, con orden `original`, todas con
`originalNumber` distinto. El admin lo recalcula al guardar y no deja marcar
`available` si no lo está. Functions lo vuelve a comprobar al crear el intento
(fuente de verdad): si un examen dejó de estar completo, rechaza con
`past_exam_incomplete`.

**Puntaje**: `raw = correctas·correctPoints + incorrectas·incorrectPoints +
blancas·blankPoints`; `score = round(max(0, raw) · maxScore /
(questionCount · correctPoints))`. Todo correcto = `maxScore`.

**Universidad**: `simulatorVisible: false` en el documento de la universidad
oculta todos sus exámenes del Simulador (por defecto visible).

La app muestra primero los exámenes de la universidad del perfil y luego los
de otras universidades visibles; solo `available`. Un examen con reglas pero
sin `available` se muestra como «Pronto».

## 2. Configuración `{config}/simulator`

Documento editable en Configuración → Simulador (`iya-config-test/simulator`).
Si falta un campo se usa el valor de fábrica.

| Campo | Fábrica | Uso |
|---|---|---|
| `practiceSizes` | `[{key:'short',label:'Corto',questions:10,minutes:15},{key:'normal',label:'Normal',questions:20,minutes:30,default:true},{key:'long',label:'Largo',questions:40,minutes:60}]` | Tamaños de la práctica libre (no hay cantidad libre) |
| `practiceTimerDefault` | `true` | Reloj activado por defecto |
| `practicePenalty` | `false` | La práctica no resta |
| `repeatWindowDays` | `14` | No repetir preguntas vistas en ese plazo |
| `defaultSource` | `both` | `real` (exámenes pasados) \| `original` (IngresoYa) \| `both` |
| `defaultDifficulty` | `mixed` | `mixed` \| `easy` \| `medium` \| `hard` |
| `showOtherUniversities` | `true` | Lista «Otras universidades» |
| `onlyCompleteExams` | `true` | Ocultar (no solo bloquear) los incompletos |
| `showExplanations` | `true` | Explicaciones en la revisión |

## 3. Intentos (Functions)

Se reutiliza el servicio de intentos (`createExamAttempt` → `startExamAttempt`
→ `saveExamAnswers` → `submitExamAttempt`, `getExamAttempt`). Código:
`functions/src/simulator_service.ts`. Dos propósitos nuevos:

- `past_exam`: `{requestId, purpose, universityId, examId}`. Todas las
  preguntas publicadas del examen (`examId` y misma `universityId`), en el
  orden de `questionOrder` (`original`: por `originalNumber` y alternativas en
  su orden; `shuffled`: preguntas y alternativas mezcladas). Duración
  `durationMinutes` y reglas de puntaje se copian al intento. Se rechaza con
  `past_exam_unavailable` (universidad oculta o inactiva, examen sin
  `available`, otra universidad con `showOtherUniversities: false`) o
  `past_exam_incomplete` (las publicadas no coinciden con `questionCount`).
- `practice`: `{requestId, purpose, mode: 'course'|'mix'|'random',
  courseIds[], topicIds?[], size, timed, source?, difficulty?}`.
  `course` = 1 curso (los `topicIds` opcionales lo acotan); `mix` = 2 a 10
  cursos; `random` = sin cursos (el servidor elige hasta 3 activos). `size` es
  la `key` de un tamaño de `practiceSizes` (si no existe:
  `practice_size_unavailable`). `source`/`difficulty` por defecto los de la
  configuración; `real` = `admission_exam` u `official_practice`. Las
  preguntas se reparten parejo entre cursos (lo que falte en uno lo cubren los
  otros); primero las no vistas en `repeatWindowDays` y, solo si no alcanzan,
  vistas. Si aun así faltan: `insufficient_questions`. Puntaje sobre 100; sin
  penalidad salvo `practicePenalty` (−0,25 por incorrecta). Sin reloj
  (`timed: false`) el intento igual cierra a las 4 h.

Cada intento guarda el **contexto** en `simulator` (`purpose`, `timed`,
`universityId` y `professionId` del perfil al crearlo, `examId` y
`examUniversityId` o `mode`/`courseIds`/`topicIds`/`size`/`source`/
`difficulty`, `scoring` y `cutoffScore` = mínimo de la carrera del perfil si el
examen es de su universidad) y `questionMeta` (curso, tema, subtema y
`partIds` por pregunta). `templateId` es `simulator_past_exam` o
`simulator_practice` y `partId` va vacío.

Las respuestas de crear/obtener traen `simulator` público: `{purpose, timed,
examId?, examUniversityId?, mode?, courseIds, size?, questionCourseIds}`
(`questionCourseIds[i]` = curso de la pregunta `i`).

**Entrega**: se califica una sola vez (repetir devuelve lo mismo). Si el reloj
ya venció se califica igual con lo guardado; las respuestas que llegan con la
entrega solo cuentan hasta 2 min después del vencimiento. El resultado
(`simulator` en la respuesta y `simulatorResult` en el intento): `total`,
`correct`, `incorrect`, `blank`, `rawScore`, `score` (oficial sobre
`maxScore`, o 0–100 en práctica), `maxScore`, `percentage`,
`timeUsedSeconds`, `byCourse`, `byTopic` (`{id,total,correct,incorrect,blank}`),
`examId?`, `cutoffScore?`, `reachedCutoff?`. `passed` = `reachedCutoff`
(falso si no hay mínimo). La revisión trae, por pregunta, la marcada, la
correcta, la explicación (vacía si `showExplanations: false`) y `courseId`,
`topicId`, `subtopicId`, `partIds` (para «Ir a la guía»).

Además, el servidor guarda en el perfil (`{users}/{uid}/…`, el dueño solo lee):

- `simulatorResults/{attemptId}`: resumen para el historial y Estadísticas
  (`purpose`, `title`, `examId`, `mode`, `courseIds`, conteos, `score`,
  `maxScore`, `percentage`, `timeUsedSeconds`, `byCourse`, `cutoffScore?`,
  `reachedCutoff?`, `submittedAtMs`). El historial se lee ordenado por
  `submittedAtMs`.
- `pastExamBest/{examId}`: `bestScore`, `bestAttemptId`, `lastScore`,
  `lastAttemptId`, `attempts`, `maxScore`.
- `learningEvents/{eventId}`: eventos verificados con id fijo
  (`past_exam_completed_{attemptId}`, `practice_completed_{attemptId}`,
  `part_passed_{partId}`, `subtopic_completed_{subtopicId}`,
  `subtopic_mastered_{subtopicId}`), con `type` y `occurredAtMs`. Base del XP
  futuro; no se muestran aún.
