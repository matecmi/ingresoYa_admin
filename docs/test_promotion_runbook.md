# Runbook: emulador, validación y promoción

Este procedimiento no despliega ni migra producción automáticamente.

## 1. Iniciar emuladores

En una terminal, desde `functions/`:

```powershell
$env:INGRESOYA_ENV = 'test'
$env:FUNCTIONS_ENFORCE_APP_CHECK = 'false'
npm run emulators
```

Arranca Auth, Firestore, Storage y Functions con el proyecto local `ingresoya-security-rules` y los puertos declarados en `firebase.json`.

## 2. Cargar fixtures locales

En otra terminal, desde `functions/` y únicamente con emuladores activos:

```powershell
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
$env:GCLOUD_PROJECT = 'ingresoya-security-rules'
npm run fixtures:emulators
```

El cargador se niega a ejecutarse si falta cualquiera de las dos variables de emulador. Crea el usuario local `fixture-student@example.test` con contraseña `FixturePass1!`, una plantilla de 10 preguntas, catálogo, progreso y claves solo dentro del emulador.

## 3. Validar flujo completo

1. Abrir el admin contra emuladores y revisar/crear un borrador; la publicación incompleta debe fallar con errores editoriales.
2. Autenticarse como el fixture en la app móvil contra emuladores.
3. Llamar `createExamAttempt` con `requestId` nuevo, `partId: part-1` y `templateId: part-exam-v1`; recuperar con `getExamAttempt` y verificar mismo orden sin claves.
4. Guardar respuestas, entregar 8/10 y comprobar fallo; crear otro intento, entregar 9/10 y comprobar aprobación. Repetir `submit` y comprobar que el resultado no cambia.
5. Registrar las cinco secciones mediante la callable de progreso y comprobar transición de `provisional` a `verified`.

Ejecutar además `npm run test:emulators`, `npm test` y, desde la raíz, `flutter test`.

## 4. Desplegar primero a test

Solo tras revisión humana de Rules, índices y configuración, seleccionar el proyecto Firebase **de test** y ejecutar manualmente un despliegue acotado:

```powershell
firebase --project <PROYECTO_TEST> deploy --only functions,firestore:rules,firestore:indexes,storage
```

No sustituir `<PROYECTO_TEST>` por producción. Esperar a que la creación de índices termine antes de probar selección de exámenes.

## 5. Validar test

Repetir el flujo completo, medir eventos de `*_completed`, revisar errores, p95/p99 y los conteos documentados en `backend_costs.md`. Ejecutar un dry-run de migración desde la herramienta editorial; revisar el reporte y no pasar a escritura sin aprobación.

## 6. Promover a producción

Requiere autorización explícita del responsable, confirmación de App Check, backup/plan de reversión, índices listos y validación satisfactoria en test. Entonces seleccionar conscientemente el proyecto de producción y ejecutar el mismo despliegue manual. La migración productiva sigue siendo un proceso separado: primero dry-run, revisión de casos manuales y autorización final.
