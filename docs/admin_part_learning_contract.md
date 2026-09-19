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
