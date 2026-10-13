# Contrato de contenido enriquecido para partes

Las partes se guardan en `courses/{courseId}/topics/{topicId}/subtopics/{subtopicId}`,
dentro del arreglo `listPart`. Todos los campos enriquecidos son opcionales para
mantener compatibilidad con documentos antiguos. El administrador nunca debe
guardar progreso, respuestas o estado de finalización del estudiante.

## Esquema

Campos existentes: `id`, `name`, `idSubtopic`, `idTopic`, `content`, `order`,
`linkVideo` y `linkPdf`.

Campos opcionales:

- `summary`: string.
- `objectives`, `keyPoints`: listas de string.
- `estimatedMinutes`: entero positivo.
- `difficulty`: `basic`, `intermediate` o `advanced`.
- `formulas`: `{id, title, latex, description}`.
- `examples`: `{id, title, problem, steps: string[], answer}`.
- `exercises`: `{id, statement, hint, answer, difficulty}`.
- `images`: `{id, url, caption}`.
- `externalLinks`: `{id, title, url, type}`.
- `flashcards`: `{id, front, back}`.
- `quizQuestions`: `{id, question, options: string[], correctIndex, explanation}`.
- `active`: bool. Lo escribe siempre el formulario («Parte activa»). Una parte
  inactiva no se muestra en la app ni cuenta para el logro del subtema. Editar
  una parte conserva los campos que el admin no maneja.
- `examTemplateId`: string. Plantilla `part_completion` que valida la parte.
  El admin solo deja elegir plantillas dinámicas, activas y publicadas, y lo
  vuelve a comprobar en la transacción que guarda `listPart`. La app la lee del
  catálogo y la envía en `createExamAttempt`; Functions rechaza cualquier otra
  plantilla con `part_template_not_associated`. Sin este campo la parte no
  tiene examen y no se puede validar.

Cada objeto anidado conserva un UUID estable. `correctIndex` usa índice basado en
cero y debe estar entre `0` y `options.length - 1`. Todas las URLs aceptadas usan
HTTP o HTTPS. El texto LaTeX se almacena con una sola barra invertida real; el
escape doble solamente aparece al representar el valor como JSON.

## Ejemplo JSON

```json
{
  "id": "part-1",
  "name": "Ecuaciones lineales",
  "idSubtopic": "subtopic-1",
  "idTopic": "topic-1",
  "content": "Una ecuación relaciona dos expresiones.",
  "order": "1",
  "linkVideo": "https://example.com/video",
  "linkPdf": "https://example.com/material.pdf",
  "summary": "Introducción a ecuaciones de primer grado.",
  "objectives": ["Despejar una incógnita"],
  "keyPoints": ["Realizar la misma operación en ambos lados"],
  "estimatedMinutes": 15,
  "difficulty": "basic",
  "formulas": [{"id":"formula-1","title":"Forma general","latex":"ax+b=0","description":"Con a distinto de cero"}],
  "examples": [{"id":"example-1","title":"Ejemplo","problem":"2x=6","steps":["Dividir entre 2"],"answer":"x=3"}],
  "exercises": [{"id":"exercise-1","statement":"3x=12","hint":"Divide entre 3","answer":"x=4","difficulty":"basic"}],
  "images": [{"id":"image-1","url":"https://example.com/image.png","caption":"Balanza"}],
  "externalLinks": [{"id":"link-1","title":"Lectura","url":"https://example.com/lesson","type":"article"}],
  "flashcards": [{"id":"card-1","front":"¿Qué es una incógnita?","back":"Un valor desconocido"}],
  "quizQuestions": [{"id":"quiz-1","question":"¿Cuánto vale x en 2x=8?","options":["2","4","8"],"correctIndex":1,"explanation":"8 dividido entre 2 es 4"}]
}
```

## Cuándo una sección cuenta como «Revisado»

Solo se exigen las secciones con contenido (`requiredReviewItemsFor` en la app, `requiredSectionsForPart` en Functions): `video` (hay `linkVideo`), `lesson` (contenido, resumen, objetivos, puntos clave o fórmulas), `examples` (ejemplos o ejercicios), `review` (flashcards), `resources` (PDF, imágenes o enlaces). Con todas revisadas se habilita el examen de la parte.

Las reglas se editan en el admin («Configuración» → «Revisión de la guía de estudio») y se guardan en `{config}/study` (`iya-config-test/study` en TEST):

| Campo | Por defecto | Efecto |
|---|---|---|
| `strict` | `true` | `false`: basta con entrar a la sección (se marca al cerrarla) y, en el video, con reproducirlo |
| `videoMinPercent` | 60 (1–100) | Porcentaje del video en reproducción real (adelantar no suma) |
| `sectionMinSeconds` | 5 (0–300) | Tiempo mínimo abierta para Lección, Ejemplos, Repasar y Recursos |

La app lee el documento una vez por sesión y lo guarda en el equipo (`study_review_rules_v1`); sin documento usa los valores por defecto. El callable `recordPartSectionCompletion` no valida tiempo ni porcentaje: estas reglas se aplican en la app.

## Fórmulas dentro del texto

En resumen, contenido, objetivos, puntos clave, problema/pasos/respuesta de ejemplos, enunciado/pista/respuesta de ejercicios y tarjetas, lo que va entre `$…$` se dibuja como fórmula LaTeX dentro de la línea (`MathText` en la app y en la vista previa del admin). Ejemplo: `Suma de los naturales: $\frac{n(n+1)}{2}$`. Una fórmula que no se puede interpretar se muestra tal cual.
