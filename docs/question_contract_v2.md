# Contrato compartido del banco de preguntas — etapa 1

Estado: implementado como modelos Dart puros y ejemplos de prueba; sin cambios de UI, escrituras remotas ni migración de datos. Versión del protocolo: `schemaVersion: 2`. Los ejemplos UNPRG son ficticios.

## Distribución y mantenimiento

`lib/shared/question_contract/` tiene contenido idéntico en app y admin. No depende de Flutter, Firestore ni rutas externas al repositorio. Ambos proyectos ejecutan `test/question_contract_v2_test.dart` sobre el mismo `test/fixtures/question_contract_v2.json`. Cada cambio del contrato debe actualizar los dos repositorios y pasar esas pruebas; no editar una copia de forma aislada. Una futura extracción a paquete versionado reemplazará las copias sin cambiar el JSON.

Importar `question_contract.dart` desde el proyecto correspondiente. Los modelos se construyen con `fromJson` y se serializan con `toJson`; sus listas y mapas públicos son inmutables. No se aceptan versiones futuras silenciosamente.

## Modelos

| Modelo | Responsabilidad |
| --- | --- |
| `SourceExam` | Universidad, tipo, modalidad, año, período opcional y referencia documental del examen real. |
| `QuestionVersionRef` | Par estable `questionId` + `version`, entero positivo. |
| `QuestionDocument` | Una revisión de pregunta, sus bloques, alternativas, procedencia y clasificación. No contiene claves. |
| `QuestionContent` | Arreglo ordenado de bloques reutilizado en enunciado, alternativas y explicación. |
| `QuestionAlternative` | ID estable, etiqueta visible y contenido multimedia. |
| `QuestionAnswerKey` | Referencia a revisión, alternativa correcta y explicación; documento privado. |
| `ExamFilter` | Filtros académicos y de origen, dificultad e intervalo de años. |
| `ExamTemplateBlock` | Cantidad de preguntas y filtros para un bloque del examen. |
| `ExamTemplate` | Configuración dinámica por bloques o fija por referencias versionadas. |
| `AttemptQuestion` | Referencia de pregunta y orden exacto de IDs de alternativas. |
| `ExamAttempt` | Propietario, solicitud, plantilla/version, selección ordenada, respuestas y resultado opcional. |
| `ExamResult` | Conteos y regla de aprobación verificados por servidor; porcentaje/aprobación se derivan. |
| `LegacyQuestionImport` | Lectura no destructiva del formato anterior, claves separadas y advertencias editoriales. |

## Contenido y editor futuro

El índice dentro del arreglo determina el orden visual. Los IDs identifican bloques durante la edición y deben ser únicos dentro de cada `QuestionContent`. Se preservan caracteres Unicode, espacios, saltos de línea y LaTeX exacto.

- `text`: `{id, type: "text", text}` para párrafos sencillos.
- `paragraph`: `{id, type: "paragraph", spans: [...]}` para una línea que mezcla texto y fórmulas. Cada span usa `type: "text", text` o `type: "formula", latex`. `marks` opcional admite `bold` e `italic`.
- `formula`: `{id, type: "formula", latex, displayMode: "block"}`. Las fórmulas dentro de párrafos usan spans, no un bloque con `displayMode: "inline"`.
- `image`: `{id, type: "image", storagePath, altText, caption?, width?, height?}`. Para imágenes antiguas/externas puede usarse `url` HTTP(S) en lugar de `storagePath`. Debe existir exactamente una fuente. Las dimensiones se proporcionan juntas, en píxeles y positivas; son opcionales antes de subir el archivo.
- `legacy`: `{id, type: "legacy", raw}` exclusivamente para compatibilidad. Conserva el formato previo sin pérdida; no es una herramienta nueva del editor.

Storage contendrá los bytes de las imágenes. Firestore contendrá referencias; no base64. Las rutas serán relativas al bucket configurado para el entorno, por ejemplo `questions/q-01/v1/figure.webp`. El servidor y las reglas comprobarán acceso y existencia en etapas posteriores. El cliente resolverá la URL al representar el bloque.

Ejemplo: texto → imagen → fórmula → párrafo con fórmula intercalada, disponible completo en la fixture compartida. Las alternativas y la explicación soportan exactamente los mismos bloques.

LaTeX en JSON requiere escapar una barra inversa como `\\`: `"latex": "A = \\frac{8x}{2}"`. En Dart puede escribirse `r'A = \frac{8x}{2}'`. No convertir `\f` en un carácter de control ni aplicar escapes dos veces. En esta etapa se valida la estructura, no la sintaxis matemática.

## Procedencia y clasificación

`SourceExam.id`, `universityId` y `modalityId` serán IDs del catálogo; no nombres ni siglas usadas como claves. `QuestionDocument.sourceExam` es una copia de los datos de origen correspondiente a esa revisión. El origen real no cambia porque el estudiante elija otra universidad.

`sourceType`: `admission_exam`, `official_practice`, `original`, `adapted` o `unknown` (compatibilidad/borrador). Una pregunta de examen requiere origen compatible. Una original no puede atribuirse un examen real; una adaptada se identifica como adaptada.

La etiqueta deriva de los campos, por ejemplo: **Pregunta del examen de admisión ordinario 2026-I | UNPRG**. Con período vacío se muestra **2026**. Las preguntas desconocidas no infieren año/universidad desde el label antiguo.

Clasificación: `courseId`, `topicId`, `subtopicId`, `partIds`. Una pregunta puede asociarse con varias partes sin duplicarse. En publicación se validará que los IDs existan, pertenezcan a la jerarquía correcta y que los conocimientos requeridos correspondan a cada parte. Los nombres se resuelven mediante el catálogo. Dificultad: `easy`, `medium`, `hard`, `unknown`.

## Versiones, almacenamiento y permisos previstos

Nombres lógicos, sujetos al prefijo de cada entorno:

- `sourceExams/{id}`: catálogo de orígenes.
- `questions/{questionId}`: revisión vigente y metadatos consultables.
- `questions/{questionId}/versions/{version}`: revisión inmutable utilizada por intentos.
- `questionAnswerKeys/{questionId-version}`: clave privada de esa revisión.
- `examTemplates/{templateId}` y sus versiones: configuraciones publicadas.
- `examAttempts/{attemptId}`: selección estable y resultado propiedad de un alumno.

Estado de pregunta: `draft`, `published`, `retired`. Una modificación del contenido publicado genera nueva versión. Nunca sobrescribir una revisión o imagen referenciada por un intento; retirar impide nuevas selecciones pero preserva los intentos anteriores.

Los clientes no deben leer claves antes de entregar. La app no podrá escribir resultado, propietario, versión o lista de preguntas del intento. Construir un `ExamResult` localmente no le concede validez: la autorización y calificación pertenecen al servidor. Las reglas reales, funciones e índices se implementarán en las siguientes etapas. No se han desplegado recursos en esta etapa.

## Plantillas, filtros e intentos

`purpose`: `practice`, `part_completion`, `simulation`. `mode: dynamic` exige bloques cuya suma coincida con `questionCount`; `mode: fixed` exige esa cantidad de referencias versionadas, sin duplicar preguntas. Ambos modos son excluyentes.

`selectionPolicy: strict` no acepta fuentes de respaldo. `prefer_profile_university` prioriza el perfil y permite solo `allowedFallbackSources` explícitas; una lista vacía no autoriza ampliar fuentes. El motor futuro no relajará filtros académicos. Los filtros permitidos son los declarados por `ExamFilter`; esto no promete consultas arbitrarias sin índices.

En el intento se conserva el orden de preguntas y `alternativeOrder`. Las respuestas se envían como `questionId: alternativeId`, nunca como índice o letra visible. Ausencia de una entrada significa sin responder. `requestId` será la clave de idempotencia de la creación, combinada con el propietario. No regenerar preguntas al recuperar un intento. `templateVersion` congela las reglas aplicables.

Tiempos del contrato: enteros UTC en milisegundos (`createdAtMs`, `gradedAtMs`); no strings locales ni objetos Firebase. La capa de persistencia realizará la conversión cuando proceda.

Estados de intento: `in_progress` → `submitted` → `graded`; `in_progress` → `abandoned`. El resultado solo aparece en `graded`. Las transiciones autorizadas e idempotencia se verificarán en servidor, no en el constructor del modelo.

Se evalúa selección única y puntuación uniforme por pregunta. `passPercentExclusive: 80` significa estrictamente mayor que 80. Con diez preguntas se necesitan nueve correctas. Se compara `correct * 100 > total * threshold`, sin redondear el porcentaje antes de decidir.

## Compatibilidad y migración

`LegacyQuestionImport.fromJson(json, documentId: ...)` conserva un archivo JSON íntegro del registro original y crea un borrador v2. Preserva `statementText`, `descriptionText` y marcadores `[@]TEXT`, `[@]MATH`, `[@]URL`, `[%]`, `[#]` dentro de bloques `legacy`. Conserva labels, nombres, section/group IDs y otros campos antiguos en `restoreOriginal()` sin inventar procedencia.

Las alternativas ausentes/null representan una lista aún no cargada o incompleta, no un banco publicable. Una sola `isCorrect: Y` produce clave privada; cero o varias producen advertencia y ninguna clave. Los enlaces inválidos se conservan como raw y se reportan para revisión.

No se reescribe Firestore ni se cambia el renderer existente. La conversión editorial a bloques y la representación visual se harán en sus etapas. La compatibilidad es de lectura y conservación; no se afirma que el renderer antiguo represente contenido v2 nuevo.

## Validación y ejecución

Desde cada repositorio: `flutter test test/question_contract_v2_test.dart`.

Pruebas: ida y vuelta JSON de modelos, orden y acentos, LaTeX, fórmulas intercaladas, alternativas multimedia, labels con/sin período, revisión/clave, conservación legacy, IDs duplicados, entradas inválidas, inmutabilidad, filtros, cantidades y resultados 8/10 y 9/10.

La publicación añadirá validación editorial (contenido no vacío, alternativas suficientes, clave y archivos disponibles). Los modelos permiten borradores incompletos en esos campos para que el futuro editor pueda guardarlos.
