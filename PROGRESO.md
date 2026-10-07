# Progreso — ingresoya_admin

> Actualizar en cada desarrollo, commit o PR (también `../iya-app/PROGRESO.md`).

_Última actualización: 2026-10-06_

## Estado actual
- `desarrollo` en `cd3c532` (Merge PR #19). Functions en Node.js 22, desplegadas en test.

## Hecho (reciente)
- Rama `codex/plantilla-examen-parte` (admin + app): el examen de parte usa la plantilla que el admin asocia a cada parte (`listPart[].examTemplateId`), igual que `masteryTemplateId` del subtema. Admin: selector «Examen de la parte» (solo `part_completion` dinámicas, activas y publicadas, revalidado en la transacción que guarda `listPart`); la lista de partes avisa «Sin examen de parte». Functions: `createExamAttempt` rechaza otra plantilla con `part_template_not_associated`. App: lee `examTemplateId` (DTO + Hive campo 20), lo envía en vez de `part-exam-v1` fijo y no inicia el examen si la parte no tiene plantilla. Pruebas: Functions lint, 29 unitarias, 20 emulador; admin 70; app 281 y analyze sin avisos.
- #19 Migración Functions a Node.js 22: `firebase.json` `runtime: nodejs22`, `engines.node: 22`. Lint OK; 29 unitarias OK en Node 20 y Node 22; 19 de emulador OK.
- #17 Functions: examen `subtopic_mastery` y logro «Dominio del subtema» (validación de sesión, logro previo, asociación publicada; idempotencia por `requestId`; concesión única en la transacción del submit; `getAchievementSummary` ampliado con `totalMasteredSubtopics`, `masteredSubtopicKeys`, `recentMastery`; pruebas unitarias y de emulador).
- #16 Plantillas `subtopic_mastery` (solo `dynamic`) y asociación `masteryTemplateId` en el editor de subtemas.
- #15 Resumen de logros propiedad del servidor (`getAchievementSummary`).
- #14 Logro «Subtema completado» versionado a partir de partes verificadas.
- #13 / #12 / #11 / #10 Rendimiento y correcciones del flujo de exámenes.

## Despliegue en test (2026-10-05)
- Proyecto `ingresoya-e5115` (`INGRESOYA_ENV=test`, región `southamerica-east1`), desde `desarrollo` `2ca373f`.
- Desplegados 7 índices nuevos de Firestore (`achievements` + selección por subtema); no se eliminó ninguno.
- Actualizadas las 6 callables por nombre: createExamAttempt, getExamAttempt, saveExamAnswers, submitExamAttempt, getAchievementSummary, recordPartSectionCompletion.
- En Windows el deploy necesita `FUNCTIONS_DISCOVERY_TIMEOUT=120` (sin él: "User code failed to load... Timeout after 10000").
- Pruebas previas: Functions lint OK, 29 unitarias + 19 emulador OK; admin 67 tests OK (0 errores de análisis, 406 avisos antiguos).

## Despliegue Node 22 en test (2026-10-06)
- Desde `desarrollo` `cd3c532`, solo las 6 callables (`--only functions:<nombre>`), con `FUNCTIONS_DISCOVERY_TIMEOUT=120`. Las 6 verificadas con `firebase functions:list`: `nodejs22`.

## Piloto (2026-10-05, desde la UI del admin web en entorno TEST)
- Plantilla `dominio-sumatorias-v1` «Examen integrador: Sumatorias»: Dominio del subtema, dinámica, 4 preguntas, >80 % (4 de 4), activa, v1.
- Asociada al subtema Razonamiento Matemático › Series y Sumatorias › Sumatorias. El selector solo listó plantillas de dominio publicadas.

## Datos de prueba: subtema «Sucesiones» (2026-10-06, entorno TEST)
- Creado desde el admin web: RM › Series y Sumatorias › **Sucesiones** (orden 2, sin examen integrador), con las partes «Sucesiones aritméticas» y «Sucesiones geométricas» (importadas con «Importar JSON»: lección, fórmulas, ejemplos, ejercicios, tarjetas, quiz, video y PDF).
- 20 preguntas publicadas v1 (10 por parte; 6 fáciles, 10 medias, 4 difíciles; 5 alternativas y explicación). Se cargaron por script con Admin SDK, imitando lo que escriben `QuestionRepo`/`PublishableQuestionRepo` (raíz, `versions/1`, clave privada, explicación del editor y alternativas legacy). Procedencia: UNPRG Ordinario 2026 I, porque `part-exam-v1` solo selecciona `admission_exam`; es contenido original, no del examen real.
- IDs: subtema `6ae5265b-3268-432f-b882-a12812ef1956`; partes `6626f77a-5181-466f-987a-406ed620ecad` (aritméticas) y `c5d3db7b-d0df-42bc-a706-b6bee40d6a98` (geométricas).
- Siguiente: validar ambas partes en la app y el logro «Subtema completado». Opcional: plantilla de dominio para este subtema.

## Pendiente / siguiente paso
- **Antes de desplegar Functions de `codex/plantilla-examen-parte`**: asociar `part-exam-v1` a las 6 partes de TEST (4 de Sumatorias, 2 de Sucesiones) desde el admin (editar parte → «Examen de la parte»). Sin eso, esas partes no podrán validarse. Después: desplegar `createExamAttempt` y probar en la app.
- Opcional: instalar Node 22 en local (`nvm install 22`).
- App: PR matecmi/IngresoYa#33 fusionado en `desarrollo` (verificado en GitHub: 2026-10-06, merge `64f6661`). E2E del integrador probado por Kevin: funciona.
- App: mejora de logros en 3 PRs (ver `../iya-app/PROGRESO.md`). Los 3 fusionados en `desarrollo` (2026-10-06): #36 «Examen integrador visible», #37 «Estados de logro y celebración de dominio» y #38 «Mis logros como colección». Falta probarlos en dispositivo. No requiere cambios en Functions ni en el admin.

## Decisiones
- **Aún no hay producción.** Todo se despliega solo en test (`ingresoya-e5115`). Nada se fusiona a `main` hasta publicar en Play Console; en ese momento se configura `INGRESOYA_ENV=production` y se hace el release `desarrollo` → `main`.
- Contrato de dominio del subtema: `docs/subtopic_mastery_contract.md` (compartido con iya-app). Solo modo `dynamic` en esta versión; solo Functions califica y concede logros.
