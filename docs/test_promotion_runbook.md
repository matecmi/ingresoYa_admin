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

Requiere autorización explícita del responsable, confirmación de App Check, backup/plan de reversión, índices listos y validación satisfactoria en test. Entonces seleccionar conscientemente el proyecto de producción (alias `production` = `ingresoya-prod`) y ejecutar el mismo despliegue manual. La migración productiva sigue siendo un proceso separado: primero dry-run, revisión de casos manuales y autorización final.

## 7. Primer despliegue a `ingresoya-prod` (Fase 1B de costos, 2026-10-19)

Producción nace en una sola región: proyecto `ingresoya-prod` (número `790256878690`), Firestore nativo en **us-central1**, Functions en us-central1 (`functions/.env.production`, `FUNCTIONS_REGION=us-central1`, `FUNCTIONS_MIN_INSTANCES=0`). Nada se publica hasta Play Console.

Ya hecho por CLI: proyecto, Firebase, base de datos, app Android `com.ingresoya.app` (`1:790256878690:android:d8d2956d3d5b02c6b0bd3b`) con huellas SHA-1/SHA-256 de debug y release, API de Firestore / Auth / Rules / App Check / FCM / Storage, `google-services.json` de producción en la app, alias `production` en ambos `.firebaserc`.

**Antes del despliegue (Kevin, acciones de pago o de consola):**

1. Facturación Blaze: `gcloud billing projects link ingresoya-prod --billing-account=015523-06CE55-5C0BD1`.
2. Presupuesto de $50: `gcloud billing budgets create --billing-account=015523-06CE55-5C0BD1 --display-name=IngresoYa-PROD-50USD --budget-amount=50USD --filter-projects=projects/790256878690 --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 --threshold-rule=percent=1.0`.
3. Storage: consola de Firebase → Storage → Comenzar → ubicación **us-central1** (bucket `ingresoya-prod.firebasestorage.app`).
4. Authentication → Método de acceso → Google (y la pantalla de consentimiento OAuth). Después, regenerar el `google-services.json` de producción (`firebase apps:sdkconfig ANDROID 1:790256878690:android:d8d2956d3d5b02c6b0bd3b --project ingresoya-prod`) para que traiga los clientes OAuth.
5. App Check: registrar la app Android con Play Integrity (recordatorio de la recta final).

**Despliegue (Claude, con autorización):**

```powershell
gcloud services enable cloudfunctions.googleapis.com run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com eventarc.googleapis.com cloudscheduler.googleapis.com secretmanager.googleapis.com --project=ingresoya-prod
firebase --project production deploy --only firestore:rules,firestore:indexes,storage
firebase --project production deploy --only functions
firebase functions:list --project production   # todo en us-central1
```

Luego, desde el admin apuntando a producción, la configuración inicial: `{config}/exam`, `xp`, `rankings` (apagados), `simulator`, `news`, `ads` (apagado hasta tener los ID reales), `sync`, `study`; el disparador `auditConfig` arma `{config}/app`. Verificar en la consola que base, bucket y Functions estén en us-central1 y que las políticas TTL de `iya-exam-attempts`, `recentQuestions` y `examRequestKeys` queden activas.

## 8. Suscripciones de Google Play (Fase 5B de costos, 2026-10-19)

**Kevin, en Play Console:** crear las suscripciones `premium_monthly` (S/ 9.90) y `premium_yearly`
(S/ 59) con un plan base auto-renovable cada una; en Usuarios y permisos invitar la cuenta de
servicio de las Functions del proyecto (`<número>-compute@developer.gserviceaccount.com`) con
«Ver datos financieros» y «Administrar pedidos y suscripciones»; en Monetización → Configuración de
monetización apuntar las notificaciones en tiempo real al tema `projects/<id>/topics/play-rtdn-<env>`;
agregar su cuenta como tester de licencias y subir el AAB al canal interno.

**Claude, después:** `PLAY_VERIFIER=google` (y `PLAY_PACKAGE_NAME` si cambia) en el `.env` del
entorno, `firebase deploy --only functions:verifyPurchase,functions:onPlayNotification`, dar a Play
permiso de publicar en el tema (`gcloud pubsub topics add-iam-policy-binding play-rtdn-<env>
--member=serviceAccount:google-play-developer-notifications@system.gserviceaccount.com
--role=roles/pubsub.publisher`) y una compra de prueba con la cuenta de tester. Hasta entonces el
premium se prueba con «Regalar premium» desde la ficha del alumno.
