# Seguridad del banco y exámenes

Este repositorio prepara las reglas y Functions; no despliega reglas, índices,
Functions ni datos. Cada entorno usa sus colecciones aisladas `-test`,
`-staging` o de producción, según `INGRESOYA_ENV`.

## Firestore

- Un alumno autenticado puede leer solo los catálogos configurados y sus propios
  intentos. Las preguntas se entregan únicamente dentro de la instantánea
  congelada de ese intento; así no se puede enumerar el banco.
- `questionAnswerKeys`, explicaciones editoriales, snapshots de versión,
  plantillas y alternativas legacy con `isCorrect` son exclusivos del claim
  `admin`.
- Los intentos, resultados, claves de idempotencia, historial de repetición y
  progreso académico son propiedad del servidor: el cliente no los escribe.
- El claim `admin: true` puede administrar banco, catálogos y plantillas. No se
  concede acceso administrativo por UID en las reglas.

Las Functions usan Admin SDK para crear, congelar y calificar intentos; nunca
envían ni guardan una clave correcta en la proyección del alumno.

## Storage

- Las imágenes publicables se suben de forma inmutable a
  `question-public/...`. Solo un administrador puede crear PNG, JPEG o WebP de
  hasta 5 MiB; un usuario autenticado puede leerlas para renderizar preguntas.
- Las rutas históricas `question-editor/...` siguen privadas para administradores.
- No existe una regla de lectura global: toda nueva carpeta privada debe añadir
  su regla explícita. El contenido v2 persiste `storagePath`, no una URL con
  token de descarga.

## Functions y App Check

Todas las callable exigen autenticación y usan validadores de payload con
límites de tamaño/cantidad. Los logs de auditoría guardan solamente el evento y
un hash corto del actor; no contienen UIDs, respuestas, claves ni explicaciones.

`FUNCTIONS_ENFORCE_APP_CHECK` acepta `true` o `false`. Producción lo aplica por
defecto; staging debe habilitarlo explícitamente cuando su proveedor real esté
configurado; test/emulador usa `false`. Producción rechaza explícitamente una
configuración que intentaría deshabilitarlo.

## Pruebas de reglas

Con Java y Firebase CLI disponibles, ejecutar desde `functions/`:

```text
npm run test:emulators
```

El comando inicia Auth, Firestore y Storage Emulator, y prueba que el alumno no
lee claves/borradores/archivos privados ni escribe intentos, preguntas o
progreso; también prueba el acceso del administrador y los límites MIME de
Storage. `npm test` cubre validación y reglas de dominio sin emulador.
