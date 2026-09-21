# Banco publicable, plantillas e intentos — etapa 3A

Este documento fija el esquema de persistencia que consumen el administrador,
la app y las Functions. Es complementario al contrato v2 en
`lib/shared/question_contract/`; no migra ni elimina registros existentes.

## Nombres por entorno

Los nombres lógicos del contrato se resuelven mediante `AppEnv`; no se usan
colecciones genéricas sin prefijo. La configuración actual es `test`:

| Lógico | test | staging | producción |
| --- | --- | --- | --- |
| `questions` | `iya-questions-test` | `iya-questions-staging` | `iya-questions` |
| `questionAnswerKeys` | `iya-question-answer-keys-test` | `iya-question-answer-keys-staging` | `iya-question-answer-keys` |
| `examTemplates` | `iya-exam-templates-test` | `iya-exam-templates-staging` | `iya-exam-templates` |
| `examAttempts` | `iya-exam-attempts-test` | `iya-exam-attempts-staging` | `iya-exam-attempts` |
| `users` | `iya-profile-test` | `iya-profile-staging` | `iya-profile` |

Los catálogos ya existentes conservan sus nombres configurables: universidades,
modalidades y exámenes de origen siguen bajo `iya-universities-<entorno>`;
cursos, temas, subtemas y partes bajo `iya-courses-<entorno>`.

## Colecciones definitivas

`questions/{questionId}` es la proyección vigente y seleccionable únicamente
cuando `status == "published"`. Contiene el `QuestionDocument` v2 más los
campos de consulta: `questionId`, `version`, `sourceExamId`, `universityId`,
`modalityId`, `year`, `period`, `sourceLabel`, `randomKey`, `createdAt`,
`updatedAt` y `publishedAt`. Por tanto incluye `content` y todas las
`alternatives` en el mismo documento. No contiene `correctAlternativeId`,
`explanation` ni `isCorrect`.

`questions/{questionId}/versions/{version}` es una copia inmutable del mismo
payload público al publicar. Conserva la revisión que referencia un intento;
el cliente no la lee directamente y la Function la usa con Admin SDK.

`questionAnswerKeys/{questionId}_{version}` tiene `questionId`, `version`,
`correctAlternativeId`, `explanation`, `createdAt` y `updatedAt`. Es privado:
solo el administrador puede verlo desde el panel; la app jamás recibe este
documento antes de entregar una respuesta.

`examTemplates/{templateId}` contiene el `ExamTemplate` v2 vigente;
`examTemplates/{templateId}/versions/{version}` congela las plantillas
publicadas. Los bloques dinámicos y las referencias fijas se almacenan tal
cual exige el contrato compartido.

`examAttempts/{attemptId}` contiene el `ExamAttempt` v2 completo pero sin
claves de respuesta. La Function es la única que lo crea, congela, recibe y
califica. El alumno puede leer solamente su intento seguro ya creado.

`users/{uid}/examRequestKeys/{requestId}` (en el prefijo `iya-profile-*`) es
el registro server-owned de idempotencia para crear intentos. `users/{uid}/
recentQuestions/{questionId}` registra la exposición reciente para selección.
El cliente no puede escribir ni leer estos dos árboles.

## Ciclo de vida de una pregunta

1. Se guarda un `draft` v2 con su clave privada de la misma versión.
2. Al publicar, una transacción valida enunciado, clasificación, dos o más
   alternativas con contenido y correspondencia exacta con la clave. Copia la
   revisión una sola vez a `versions/{version}` y marca la raíz `published`.
3. Editar una publicada ejecuta **crear borrador de revisión**: duplica en la
   raíz la revisión y clave como `version + 1`, `status: draft`; no cambia la
   snapshot previa ni su clave. Mientras ese borrador no se publique deja de
   ser seleccionable, evitando que una edición parcial entre a un examen.
4. `retired` impide nuevas selecciones sin borrar snapshots, claves o intentos;
   no se elimina una pregunta v2 que ya fue publicada.

`PublishableQuestionRepo` implementa estas transacciones. La UI legacy aún
usa alternativas en subcolección y explicación editorial privada; no se la
migra automáticamente. Una migración o botón editorial posterior debe crear
el payload v2 explícitamente y pasar por este repositorio, nunca copiar
`isCorrect` a la raíz pública.

## Seguridad y compatibilidad

Las reglas separan el root público de las subcolecciones legacy: las
alternativas legacy y explicaciones quedan solo para `admin: true`. Las claves,
snapshots, request keys e historial son privados o server-owned. Los snapshots
de pregunta y plantilla permiten exclusivamente `create`, nunca `update` o
`delete`.

No se han desplegado reglas, Functions, índices ni datos. Las futuras
Functions deben residir en `functions/`, usar Admin SDK y ejecutar selección,
congelamiento y calificación; no se autoriza a trasladar esa lógica de
confianza al cliente.
