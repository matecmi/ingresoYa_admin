# Arquitectura de preguntas publicables y exámenes

## Límites de datos

`questions/{questionId}` es la proyección pública editorial v2: contiene contenido, alternativas, clasificación, procedencia, estado y versión; no contiene respuesta correcta ni explicación. Cada publicación copia una instantánea inmutable a `questions/{questionId}/versions/{version}`. `questionAnswerKeys/{questionId}_{version}` conserva la clave y explicación privadas de esa misma revisión.

Las preguntas `draft` y `retired` no son candidatas. Editar una publicada crea un borrador con versión nueva; los intentos ya creados usan la instantánea `{questionId, version}` y nunca releen el banco mutable.

## Flujo de examen

```text
Cliente autenticado
  -> createExamAttempt(requestId, partId, templateId)
  -> examAttempts/{attemptId}: instantánea sin claves
  -> getExamAttempt / saveExamAnswers
  -> submitExamAttempt: claves privadas por ID+versión
  -> resultado y revisión autorizada al propietario
```

La Function obtiene perfil, progreso, catálogo y plantilla del servidor. La selección exige contexto académico, limita consultas por `randomKey`, no admite duplicados y respeta la política de universidad. `examRequestKeys` hace idempotente la creación; `recentQuestions` reduce repeticiones; ambos son server-owned.

La aprobación de una parte requiere tanto intento aprobado como evidencia v2 de `video`, `lesson`, `examples`, `review` y `resources`. Antes de reunir ambos requisitos, el progreso es `provisional`; solo una transacción lo marca `verified`.

## Seguridad y operación

Rules permiten al alumno únicamente catálogos necesarios y sus intentos. Banco, plantillas, claves, historial de repetición y progreso son administrados por claim `admin` o Functions. Storage almacena imágenes nuevas por `storagePath`; no persiste URL con token. La telemetría guarda conteos y latencia agregados, nunca respuestas ni claves. Ver [backend_security.md](backend_security.md) y [backend_costs.md](backend_costs.md).
