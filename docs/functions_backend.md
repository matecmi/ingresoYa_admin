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

## Superficie callable inicial

Las funciones `createExamAttempt`, `getExamAttempt` y `submitExamAttempt`
requieren autenticación y aceptan únicamente identificadores acotados. La
creación recibe `requestId`, `templateId` y `partId` opcional; la entrega
recibe sólo `attemptId` y el mapa `questionId -> alternativeId`. Se rechazan
campos extra como `userId`, puntaje, duración, lista de preguntas o versión.

No se persisten respuestas incrementalmente en esta etapa: `saveExamAnswers`
no se expone, reduciendo la superficie de escritura. `createExamAttempt` se
implementa en BACKEND-2; la lectura segura y la calificación llegan en tareas
posteriores y sus callables continúan devolviendo `failed-precondition`.
Las futuras escrituras deben usar `serverTimestamp()` de Admin SDK, nunca el
reloj enviado por el cliente.

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
