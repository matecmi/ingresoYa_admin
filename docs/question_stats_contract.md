# Estadísticas por pregunta y «Preguntas a revisar»

Rediseño del admin, fase 7 (lienzo v3.1, tablero 11).

## Suma de respuestas (servidor)

`functions/src/question_stats.ts` lee los intentos entregados (`{attempts}` con `submittedAt`) desde el último cursor y suma, por versión de pregunta, en `iya-question-stats-{env}/{questionId}_{version}`:

`{questionId, version, correctAlternativeId, labels: {altId: "A"}, answered, blank, correct, byAlternative: {altId: n}, updatedAt, review?}`

- La alternativa correcta sale de la clave congelada de esa versión (`{answerKeys}/{questionId}_{version}`); sin clave, la pregunta no se cuenta.
- El cursor vive en `iya-question-stats-{env}/_cursor` (`submittedAt` + `doneIds` del mismo instante) para no contar dos veces un intento.
- Se ejecuta cada noche (`nightlyQuestionStats`, 03:30 Lima; hasta tres pasadas de 20 000 intentos si la anterior llenó el cupo, Fase 4B de costos) y con «Actualizar ahora» (callable `refreshQuestionStats`, requiere `questions:v`, sin App Check). Las alternativas de cada pregunta se toman de `questionSnapshots` cuando `questions` solo trae id, versión y orden.

## Señales (admin)

Umbrales en `{config}/quality` (Configuración → «Preguntas a revisar»): `minAnswers` 20, `failPercent` 90, `dominantWrongPercent` 50, `easyPercent` 95, `deadAlternativeAnswers` 60. Reglas en `lib/src/domain/question_signals.dart`:

| Señal | Cuándo |
|---|---|
| Una alternativa equivocada atrae a la mayoría | error ≥ `failPercent` y una incorrecta se lleva ≥ `dominantWrongPercent` de las respuestas → «Es probable que la clave marcada (X) esté mal.» |
| Casi todos fallan | error ≥ `failPercent` y las respuestas se reparten. |
| Demasiado fáciles | acierto ≥ `easyPercent`. |
| Alternativas que nadie elige | con ≥ `deadAlternativeAnswers` respuestas, una incorrecta con 0. |

Solo con `answered ≥ minAnswers`. «Está bien así» guarda `review: {answered, by, note, atMs}` (única escritura permitida al admin, con `questions:e`); la pregunta vuelve a la lista cuando tiene un 50 % más de respuestas.

## Reglas

Lectura con `questions:v`; el admin solo puede cambiar el campo `review`. Además, con `students:v` el admin lee `simulatorResults`, `pastExamBest`, `simulatorTopicStats`, `learningEvents` y `learningProgress/current` de un alumno (ficha del alumno).
