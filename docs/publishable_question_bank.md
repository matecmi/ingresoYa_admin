# Banco publicable, plantillas e intentos — etapa 3

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

## Plantillas de examen

El administrador crea plantillas desde **Plantillas**. Cada formulario incluye
título, descripción, propósito, cantidad, duración, porcentaje exclusivo de
aprobación y el número derivado de respuestas correctas requeridas. También
configura una universidad prioritaria, política (`strict` o
`prefer_profile_university`), fuentes complementarias autorizadas y el estado
activo/inactivo. La prioridad es metadato editorial; para restringir las
preguntas a una universidad concreta se usa `universityId` en cada bloque.

Una plantilla puede ser dinámica, con bloques por tipo de fuente, modalidad,
examen, intervalo de años, dificultad y curso/tema/subtema/parte, o fija, con
referencias `{questionId, version}`. El editor exige que la suma de bloques o
la lista fija coincida con `questionCount`; el contrato impide preguntas fijas
repetidas. Antes de guardar, una transacción comprueba IDs y estado activo de
catálogos, jerarquía académica, examen/modalidad y revisiones publicadas.

Cada guardado aumenta `version`, escribe una nueva snapshot inmutable en
`versions/{version}` y reemplaza sólo la proyección vigente. Las snapshots y
los intentos anteriores no se modifican. `active: false` impide que Functions
cree intentos nuevos; volver a activar también crea una versión nueva y exige
la misma validación. No se elimina ninguna plantilla desde el panel.

`examAttempts/{attemptId}` contiene el `ExamAttempt` v2 completo pero sin
claves de respuesta. La Function es la única que lo crea, congela, recibe y
califica. El alumno puede leer solamente su intento seguro ya creado.

`users/{uid}/examRequestKeys/{requestId}` (en el prefijo `iya-profile-*`) es
el registro server-owned de idempotencia para crear intentos. `users/{uid}/
recentQuestions/{questionId}` registra la exposición reciente para selección.
El cliente no puede escribir ni leer estos dos árboles.

## Ciclo de vida de una pregunta

1. Se guarda un `draft` v2 con su clave privada de la misma versión.
2. Al publicar, una transacción valida el contrato v2 completo: enunciado,
   dificultad definida, clasificación y partes activas, procedencia coherente,
   examen de origen activo cuando corresponde, dos o más alternativas no
   duplicadas, una única clave privada y explicación con contenido. También
   verifica que cada fórmula LaTex pueda ser interpretada y que cada imagen
   tenga una ruta Storage relativa o URL HTTP(S) válida. Copia la revisión una
   sola vez a `versions/{version}` y marca la raíz `published`.
3. Editar una publicada ejecuta **crear borrador de revisión**: duplica en la
   raíz la revisión y clave como `version + 1`, `status: draft`; no cambia la
   snapshot previa ni su clave. Mientras ese borrador no se publique deja de
   ser seleccionable, evitando que una edición parcial entre a un examen.
4. `retired` impide nuevas selecciones sin borrar snapshots, claves o intentos;
   no se elimina una pregunta v2 que ya fue publicada.

## Clasificación académica

El formulario encadena curso → tema → subtema → una o varias partes. Los IDs
persistidos son `courseId`, `topicId`, `subtopicId` y `partIds`; las copias
`courseName`, `topicName`, `subtopicName` y `partNames` son solo etiquetas de
visualización del editor legacy y no autorizan ni resuelven una referencia.

Al cambiar un padre se borran sus descendientes y las partes elegidas. La UI
mantiene una referencia antigua visible y deshabilitada como “registro guardado
no disponible”, en vez de borrarla silenciosamente. No permite elegir catálogos
ni partes inactivas.

Antes de crear/editar una clasificación completa y nuevamente antes de publicar,
una transacción lee la ruta real `courses/{course}/topics/{topic}/subtopics/
{subtopic}`. Exige que todos los documentos y partes existan, estén activos y
que `partIds` no tenga duplicados. Esto impide asociar una pregunta a una parte
de otro subtema. El generador podrá filtrar por `partIds` y excluir preguntas
de partes que el alumno no haya completado.

`PublishableQuestionRepo` implementa estas transacciones. Al publicar también
vuelve a leer el examen de origen dentro de la transacción: debe seguir
existiendo y estar activo. Rechaza además alternativas sin contenido o con el
mismo contenido v2. Así, un cambio concurrente de catálogo no puede publicar
una referencia inválida.

## Flujo editorial del administrador

El formulario de pregunta reúne en una sola hoja el enunciado visual, número
original, dificultad, procedencia, clasificación, alternativas, clave,
explicación, estado y vista previa. Las alternativas tienen UUID estable y
etiquetas de presentación `A`, `B`, … recalculadas según el orden; arrastrarlas
no cambia el UUID. Se exige un mínimo configurable de dos (actualmente dos) y
exactamente una correcta para publicar. Borradores incompletos se pueden
guardar para terminar después.

La clave y la explicación se escriben en `questionAnswerKeys` con la misma
versión del documento público. Al editar una publicación, el repositorio crea
la siguiente versión en borrador antes de permitir cambios; la versión
publicada y su clave nunca se sobrescriben.

Para compatibilidad, cada guardado v2 **solo inserta o actualiza** las
alternativas editadas en la subcolección legacy `alternatives`, preservando su
UUID, contenido visual y marca editorial privada. No borra documentos legacy
huérfanos ni ejecuta una migración masiva automática. La explicación legacy
también se conserva como copia editorial; la fuente de verdad para la
calificación v2 es exclusivamente `questionAnswerKeys`.

## Validación, publicación y retiro

El botón **Validar borrador** guarda el estado parcial permitido y muestra una
lista de errores concreta en el formulario: campos faltantes, alternativa o
explicación vacía, clave inválida, fórmulas no interpretables, referencias de
catálogo inexistentes/inactivas e imágenes sin fuente válida. **Publicar**
ejecuta esa prevalidación y repite las verificaciones críticas dentro de la
transacción; un cambio concurrente no puede introducir una pregunta inválida.

Una pregunta `draft` no es seleccionable, `published` es la única proyección
que puede entrar a exámenes nuevos y `retired` deja de ser seleccionable sin
borrar su snapshot. Desde el listado, el botón de archivo retira una pregunta
publicada; no borra versiones ni intentos. Editar una publicada crea la
siguiente revisión `draft`, de modo que los intentos existentes continúan
referenciando su versión congelada.

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
