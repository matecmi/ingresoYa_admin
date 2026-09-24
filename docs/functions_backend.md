# Functions del backend de exámenes

`functions/` contiene el backend TypeScript de Firebase Functions v2. Usa
Node 20, Firebase Admin SDK y el runtime `nodejs20` declarado en
`firebase.json`. No se despliega ningún recurso desde este cambio.

## Entornos y colecciones

Antes de desplegar, se debe definir `INGRESOYA_ENV` como `test`, `staging` o
`production`; fuera de pruebas y emuladores no tiene valor por defecto. La
función resuelve únicamente las colecciones del entorno indicado, por ejemplo
`iya-questions-test` o `iya-questions`. Esto evita que una configuración local
apunte a producción por accidente. `FUNCTIONS_REGION` es explícita y por
defecto usa `southamerica-east1`.

Copiar `functions/.env.example` a un archivo de entorno local no versionado.
Para un despliegue, configurar esas mismas variables en el entorno seguro de
Firebase/Cloud Run para el proyecto correspondiente. Nunca colocar claves de
servicio ni secretos en archivos `.env` versionados.

## Comandos

Desde `functions/`:

```text
npm install
npm run lint
npm run build
npm test
npm run emulators
npm run test:emulators
```

El último comando utiliza Auth, Firestore y Functions de la Emulator Suite;
los puertos se fijan en `firebase.json`. El build y el lint son hooks previos
al despliegue, pero no se ejecuta `firebase deploy` como parte de este trabajo.

## Superficie callable

Las funciones `createExamAttempt`, `getExamAttempt`, `saveExamAnswers`,
`recordPartSectionCompletion` y `submitExamAttempt` requieren autenticación y
aceptan únicamente
identificadores acotados. La creación recibe `requestId`, `templateId` y
`partId`; la recuperación recibe sólo `attemptId`; el guardado incremental y
la entrega reciben `attemptId` y el mapa `questionId -> alternativeId`. Se
rechazan campos extra como `userId`, puntaje, duración, lista de preguntas o
versión.

Las cinco callables están disponibles. Las escrituras usan
`serverTimestamp()` de Admin SDK, nunca el reloj enviado por el cliente.

Los errores se traducen a códigos callable tipados y los logs registran sólo
el evento, categoría y un hash corto del actor; nunca solicitudes, respuestas,
explicaciones, claves ni UID sin transformar.

## Crear un intento para una parte

`createExamAttempt` recibe exactamente `requestId`, `purpose:
"part_completion"`, `partId` y `templateId`. El cliente no puede enviar
universidad, versión, preguntas, duración, nota mínima, orden ni puntaje.

La Function lee la universidad del perfil y el documento server-owned
`users/{uid}/learningProgress/current`, cuyo arreglo `allowedParts` contiene
`{partId, courseId, topicId, subtopicId}`. Verifica otra vez esa jerarquía en
el catálogo y exige que curso, tema, subtema y parte permanezcan activos. Las
reglas niegan al cliente la escritura de progreso.

La plantilla debe ser v2, publicada, de propósito `part_completion` y modo
dinámico. Cada bloque queda restringido al contexto de la parte solicitada; un
bloque que declare otro curso, tema, subtema o parte se rechaza. Nunca se
amplían referencias académicas silenciosamente.

Los candidatos son `published` de la parte, con límites por punto de inicio de
`randomKey`. Se vuelven a validar universidad, tipo, examen, modalidad, año,
curso, tema, subtema, parte y dificultad. `strict` exige el filtro exacto;
`prefer_profile_university` prioriza la universidad del perfil y sólo completa
con tipos presentes en `allowedFallbackSources`. Se reducen repeticiones
recientes, se eliminan duplicados y se mezclan preguntas y alternativas. Es una
muestra aleatorizada razonable, no uniformidad matemática perfecta.

Al faltar candidatos, responde `failed-precondition` con `reason:
insufficient_questions`, `available`, `required` y `blockIndex`. El índice
`status + partIds CONTAINS + randomKey` está declarado para los tres entornos,
sin despliegue.

`requestId` se reserva transaccionalmente bajo el usuario: dobles pulsaciones y
reintentos simultáneos devuelven el mismo intento. La instantánea guarda
pregunta, versión, orden, contenido, alternativas, procedencia y orden de
alternativas; nunca clave correcta ni explicación. Los timestamps se resuelven
en servidor y el vencimiento procede de la duración de plantilla (una hora si
no está definida), nunca del reloj cliente.

## Recuperación y respuestas guardadas

`getExamAttempt` exige autenticación y comprueba que `userId` del intento sea
el actor autenticado; un intento ajeno responde como no encontrado. Recupera
la misma instantánea y el mismo orden que se crearon, junto con el mapa de
respuestas ya guardadas. Su proyección copia sólo `questionId`, versión, orden,
contenido, alternativas públicas, orden de alternativas y procedencia: nunca
incluye claves, `isCorrect`, explicaciones ni resultados.

El estado devuelto es `in_progress`, `submitted` o `expired`. Un intento que
sigue almacenado como `in_progress` pero cuyo `expiresAt` ya pasó se trata como
`expired` con el reloj del servidor; un intento enviado o calificado se expone
como `submitted`. La recuperación no reordena ni vuelve a consultar el banco,
por lo que una edición posterior de una pregunta no afecta al intento.

`saveExamAnswers` está implementada para persistir borradores. Sólo acepta un
mapa de hasta 50 pares `questionId -> alternativeId`; cada par se comprueba
contra la instantánea congelada, no contra el banco mutable. Se verifica
propietario y que el intento permanezca abierto. Los parches idénticos son
idempotentes y no escriben; un cambio se guarda en una transacción y se limita
a un parche por intento cada segundo. El límite devuelve `resource-exhausted`
con `retryAfterMs`. No se escribe ningún campo de resultado y los intentos
`submitted` o `expired` no se pueden modificar.

## Entrega y calificación

`submitExamAttempt` verifica autenticación, propietario, estado y cada ID de
pregunta y alternativa recibido. Combina el mapa final con los borradores ya
guardados; una ausencia queda sin responder y cuenta como incorrecta. No
acepta puntaje, porcentaje, regla de aprobación, duración, versiones ni claves
proporcionadas por el cliente.

Para cada referencia congelada `{questionId, version}`, la Function lee
`questionAnswerKeys/{questionId}_{version}` con Admin SDK y comprueba que la
clave corresponda exactamente a la versión y a una alternativa de la
instantánea. Calcula aciertos y porcentaje sin redondeos para decidir: la
regla es `correct * 100 > total * passPercentExclusive`. Por eso, para diez
preguntas y umbral exclusivo de 80, `requiredCorrectAnswers` es 9: 8/10 falla
y 9/10 aprueba.

La transición y la escritura del resultado suceden en una sola transacción. El
documento del intento conserva sólo conteos, regla congelada y marca de tiempo;
no guarda claves ni explicaciones. Un reintento, incluso simultáneo, no vuelve
a calificar ni cambia el resultado: devuelve la misma revisión derivada de las
claves privadas e inmutables. La respuesta callable al dueño incluye la
revisión por pregunta, alternativa seleccionada, alternativa correcta y
explicación solamente después de entregar; `getExamAttempt` sigue sin exponer
esa información antes de la entrega.

## Progreso verificable de partes

Una parte de `part_completion` se completa sólo con dos clases de evidencia
server-owned: un intento aprobado y las cinco secciones `video`, `lesson`,
`examples`, `review` y `resources`. La app registra cada sección mediante
`recordPartSectionCompletion({partId, section})`; la Function confirma que la
parte sigue en `allowedParts`, escribe la evidencia con timestamp de servidor y
mantiene los IDs de curso, tema y subtema asociados. No se aceptan secciones
libres ni timestamps del cliente.

El estado se guarda bajo
`users/{uid}/learningProgress/current.partProgress.{partId}`. Mientras falte
una sección, una aprobación registra `approvedExamAttemptId` y
`examApprovedAt`, con `verificationStatus: provisional`, y la respuesta de
`submitExamAttempt` devuelve `partCompletion.missingSections`. Si el alumno
visita después las secciones pendientes, la llamada de sección reconcilia en
transacción: al registrar la última, escribe una sola vez `completed: true`,
`examAttemptId`, `completedAt` y `verificationStatus: verified`.

`completed` nunca se restablece a `false`. Una repetición de sección ya
registrada o de `submitExamAttempt` no reescribe timestamps ni crea XP, logros
o intentos (el backend no emite esos efectos secundarios). Los viejos campos
de clics/vistas no se migran ni cuentan: únicamente la evidencia v2 con
`schemaVersion: 2` y `sections.{section}.completedAt` registrada por la nueva
callable puede satisfacer requisitos. Esto permite que secciones revisadas
después de aprobar culminen la parte sin convertir interacciones históricas en
aprobaciones.
