# Banco de preguntas: filtros, cursores e índices

La pantalla del banco no observa ni descarga la colección completa. Cada
solicitud llama a `QuestionRepo.fetchQuestionPage`, ordena en Firestore y pide
26 documentos como máximo: 25 para mostrar y uno para decidir si existe otra
página. El siguiente botón usa el `QueryDocumentSnapshot` final con
`startAfterDocument`; no usa offsets ni vuelve a leer las páginas previas.

Los filtros se traducen directamente a `where` sobre la colección configurada
por `AppEnv`:

| Filtro de UI | Campo consultado |
| --- | --- |
| Estado | `status` |
| Universidad / examen / tipo / modalidad | `universityId`, `sourceExamId`, `sourceType`, `modalityId` |
| Año o rango | `year` |
| Curso / tema / subtema / parte | `courseId`, `topicId`, `subtopicId`, `partIds array-contains` |
| Dificultad | `difficulty` |
| Texto o identificador | `searchTokens array-contains` |

`searchTokens` contiene términos normalizados y prefijos de al menos tres
caracteres provenientes del enunciado, etiqueta, clasificación e
identificadores. Por ello la caja de búsqueda es una búsqueda por palabra o
prefijo, no una búsqueda de subcadena arbitraria. Las preguntas legacy que aún
no tienen este campo siguen visibles sin filtro; se indexan progresivamente al
volver a guardarlas, sin migración automática destructiva.

Cuando se seleccionan simultáneamente una parte y texto, el repositorio usa
`partSearchTokens` (`partId|token`) en vez de dos `array-contains`, combinación
que Firestore no permite. También se escribe progresivamente al guardar la
pregunta.

## Índices declarados

`firestore.indexes.json` declara las mismas diez familias para `test`,
`staging` y producción:

| Familia de índice | Filtros cubiertos |
| --- | --- |
| `status, updatedAt` | estado y orden editorial |
| `universityId, sourceExamId, updatedAt` | universidad y examen |
| `universityId, modalityId, sourceType, year, updatedAt` | procedencia, modalidad, tipo y rango de año |
| `courseId, topicId, subtopicId, updatedAt` | clasificación académica |
| `courseId, topicId, subtopicId, partIds CONTAINS, updatedAt` | parte dentro del contexto académico |
| `searchTokens CONTAINS, updatedAt` | texto o identificador por token/prefijo |
| `partSearchTokens CONTAINS, updatedAt` | combinación de parte y texto en una sola consulta |
| `year, updatedAt` | rango de año sin otra procedencia |
| `status, courseId, topicId, subtopicId, partIds CONTAINS, randomKey` | selección acotada de examen por parte y punto aleatorio |
| `status, courseId, topicId, subtopicId, sourceType, partIds CONTAINS, randomKey` | selección anterior con tipo de fuente específico |

Firestore combina filtros de igualdad con estas rutas. Las familias con rango
(`year`) y con arreglo (`partIds`, `searchTokens` o `partSearchTokens`) se declaran explícitamente
porque no deben depender de la combinación local de documentos. El manifiesto
está registrado en `firebase.json`, pero este cambio no despliega índices.
