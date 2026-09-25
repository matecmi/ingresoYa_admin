# Contrato callable final con la app móvil

Las cuatro callables del flujo de intento mantienen estos nombres y payloads exactos. Todas exigen Auth y App Check donde el entorno lo habilita. El cliente no añade campos extra.

## `createExamAttempt`

```json
{
  "requestId": "uuid-estable",
  "purpose": "part_completion",
  "partId": "part-01",
  "templateId": "part-exam-v1"
}
```

Devuelve `{attemptId, status: "in_progress", title, questionCount, requiredCorrectAnswers, expiresAt, questions}`. Cada pregunta tiene `questionId`, `version`, `order`, `content`, `alternatives`, `sourceLabel` y `alternativeOrder`; no contiene `correctAlternativeId`, `isCorrect` ni `explanation`.

## `getExamAttempt`

```json
{ "attemptId": "attempt-123" }
```

Devuelve la misma instantánea y orden, más `answers` y estado `in_progress`, `submitted` o `expired`. No devuelve claves ni explicación.

## `saveExamAnswers`

```json
{
  "attemptId": "attempt-123",
  "answers": { "question-01": "alternative-a" }
}
```

Acepta hasta 50 pares de IDs presentes en la instantánea abierta. El valor es el `alternativeId` estable, no el label visual A/B/C. Es idempotente para el mismo valor y limita un cambio por segundo; responde la proyección segura del intento.

## `submitExamAttempt`

```json
{
  "attemptId": "attempt-123",
  "answers": { "question-01": "alternative-a" }
}
```

Acepta hasta 200 respuestas, nunca nota ni claves calculadas por la app. Devuelve `{attemptId, status: "submitted", correctAnswers, percentage, requiredCorrectAnswers, passed, review, partCompletion?}`. Después de entregar, `review` puede incluir la alternativa correcta y explicación autorizadas.

## Errores estables

La app debe traducir el código `HttpsError`: `invalid-argument`, `unauthenticated`, `not-found`, `failed-precondition`, `resource-exhausted` o `internal`. Cuando aplica, `failed-precondition.details.reason` es estable: `insufficient_questions`, `attempt_not_open` o `answer_save_rate_limit`. No se debe basar la UI en el texto del mensaje.
