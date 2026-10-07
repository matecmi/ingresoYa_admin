# Contrato callable final con la app móvil

Las callables del flujo de intento mantienen estos nombres y payloads exactos. Todas exigen Auth y App Check donde el entorno lo habilita. El cliente no añade campos extra.

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

Acepta hasta 200 respuestas, nunca nota ni claves calculadas por la app. Devuelve `{attemptId, status: "submitted", correctAnswers, percentage, requiredCorrectAnswers, passed, review, partCompletion?, progressUpdate?}`. `progressUpdate` refleja `{partId, completed}` de `partCompletion` para el móvil. Después de entregar, `review` puede incluir la alternativa correcta y explicación autorizadas.

## Errores y diagnóstico

La app traduce `HttpsError.code` y `details.reason`; el texto inglés es solo descriptivo. El `reason` no contiene IDs de usuario, respuestas ni claves. Casos principales:

| Operación/causa | `code` | `details.reason` | Qué revisar |
| --- | --- | --- | --- |
| `create`: no existe `templateId` en la colección del entorno activo | `not-found` | `template_not_found` | `INGRESOYA_ENV`, colección `iya-exam-templates-*` y la plantilla asociada a la parte (`examTemplateId`) |
| `create`: la plantilla no es la asociada a la parte en el catálogo | `failed-precondition` | `part_template_not_associated` | `listPart[].examTemplateId` de la parte en el admin |
| `create`: plantilla no publicada/válida | `failed-precondition` | `template_not_published` | `status`, `active`, bloques y `questionCount` |
| `create`: propósito/modo incompatibles | `failed-precondition` | `template_incompatible` | `purpose=part_completion`, `mode=dynamic` |
| `create`: bloque no corresponde a la parte resuelta por el servidor | `failed-precondition` | `template_part_mismatch` | Filtros del bloque y relación curso/tema/subtema/parte |
| `create`: preguntas elegibles insuficientes | `failed-precondition` | `insufficient_questions` | Banco publicado y filtros; el detalle incluye conteos, no claves |
| `create`: referencia idempotente apunta a intento eliminado | `failed-precondition` | `request_key_orphaned` | Integridad entre `iya-profile-*/{uid}/examRequestKeys/{requestId}` e intentos; la app rota la clave una vez |
| `get`/`save`/`submit`: intento ausente o ajeno | `not-found` | `attempt_not_found` | ID del intento y propietario, sin distinguir públicamente un intento ajeno |
| `save`: demasiados cambios | `resource-exhausted` | `answer_save_rate_limit` | Esperar `retryAfterMs` y reintentar las respuestas pendientes |
| `submit`: clave de revisión congelada ausente | `failed-precondition` | `answer_key_unavailable` | Documento de clave para la versión exacta de la pregunta |
| Sección o entrega aprobada: parte fuera de la lista autorizada | `failed-precondition` | `part_not_enabled` | `allowedParts` explícito o contexto legacy validado; la ausencia de `learningProgress/current` ya no impide registrar progreso |
| Cualquier llamada: datos persistidos del intento inconsistentes | `failed-precondition` | `attempt_data_invalid` | Instantánea y metadatos del intento |
| Cualquier llamada: solicitud inválida | `invalid-argument` | `invalid_request` | Payload y versión de la app |
| Cualquier llamada: fallo inesperado | `internal` | `unexpected_server_error` | Logs de Functions y excepción del servidor |

Los logs `exam_attempt_*_rejected` y `part_section_completion_rejected` incluyen entorno, `errorCode`, `reason`, actor anonimizado y métricas de lecturas/escrituras. Nunca registran payload, IDs de usuario, respuestas, claves ni el texto de la excepción. Para localizar un fallo, filtrar por evento, entorno y razón. Si se desplegaron Functions sobre `ingresoya-e5115`, verificar además la región `southamerica-east1` de la app. Un `not-found` sin `reason` puede indicar una callable no desplegada o una versión antigua del backend; no se debe diagnosticar como intento inexistente sin más evidencia.
