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
no se expone, reduciendo la superficie de escritura. La selección, congelado,
lectura segura y calificación se implementan en las tareas backend siguientes;
por ahora las callables devuelven `failed-precondition` sin escribir datos.
Las futuras escrituras deben usar `serverTimestamp()` de Admin SDK, nunca el
reloj enviado por el cliente.

Los errores se traducen a códigos callable tipados y los logs registran sólo
el evento, categoría y un hash corto del actor; nunca solicitudes, respuestas,
explicaciones, claves ni UID sin transformar.
