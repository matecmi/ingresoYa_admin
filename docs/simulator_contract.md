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
→ `saveExamAnswers` → `submitExamAttempt`, `getExamAttempt`). Dos propósitos
nuevos:

- `past_exam`: `{requestId, purpose, universityId, examId}`. Todas las
  preguntas publicadas del examen, en el orden de `questionOrder`. Duración y
  reglas de puntaje se copian al intento.
- `practice`: `{requestId, purpose, mode: 'course'|'mix'|'random',
  courseIds[], topicIds?[], size, timed, source?, difficulty?}`. El servidor
  valida los cursos contra el catálogo, reparte las preguntas entre los cursos,
  evita las vistas en `repeatWindowDays` y rechaza con `insufficient_questions`
  si no alcanzan. Sin penalidad salvo `practicePenalty`.

Cada intento guarda el **contexto**: `universityId` y `professionId` del perfil
al crearlo, `purpose`, `examId` o `mode`/`courseIds`, `size`, `timed`.

El **resultado** guarda correctas, incorrectas, en blanco, `rawScore`, `score`
(oficial) o porcentaje (práctica), tiempo usado y aciertos por curso y por tema
(`byCourse`, `byTopic`). La revisión trae, por pregunta, la marcada, la
correcta, la explicación y sus `partIds` (para «Ir a la guía»).

Además, el servidor guarda:

- `pastExamBest/{uid}_{examId}`: mejor puntaje y último intento por examen.
- `learningEvents/{uid}_{eventId}`: eventos verificados con id fijo
  (`past_exam_completed_{attemptId}`, `practice_completed_{attemptId}`,
  `part_passed_{partId}`, `subtopic_completed_{subtopicId}`,
  `subtopic_mastered_{subtopicId}`). Base del XP futuro; no se muestran aún.

El historial se lee de los intentos propios (reglas: el dueño lee los suyos),
ordenados por fecha de entrega.
