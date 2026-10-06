# Progreso — ingresoya_admin

> Actualizar en cada desarrollo, commit o PR (también `../iya-app/PROGRESO.md`).

_Última actualización: 2026-10-06_

## Estado actual
- `desarrollo` en `2ca373f` (Merge PR #18). Dominio del subtema completo en admin y Functions.
- Rama `codex/functions-node22`: migración de Functions a Node.js 22 (PR abierto, sin desplegar).

## Hecho (reciente)
- Migración Functions a Node.js 22 (`codex/functions-node22`): `firebase.json` `runtime: nodejs22`, `engines.node: 22`, doc actualizado. Lint OK; 29 unitarias OK en Node 20 y Node 22; 19 de emulador OK. No desplegado.
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

## Piloto (2026-10-05, desde la UI del admin web en entorno TEST)
- Plantilla `dominio-sumatorias-v1` «Examen integrador: Sumatorias»: Dominio del subtema, dinámica, 4 preguntas, >80 % (4 de 4), activa, v1.
- Asociada al subtema Razonamiento Matemático › Series y Sumatorias › Sumatorias. El selector solo listó plantillas de dominio publicadas.

## Pendiente / siguiente paso
- Recorrido E2E con cuenta de prueba (partes → integrador → reprobar/reintentar → aprobar → submit repetido → Perfil).
- Fusionar el PR de Node 22 y redesplegar Functions en test **antes del 2026-10-30** (con `FUNCTIONS_DISCOVERY_TIMEOUT=120`); luego en producción. Opcional: instalar Node 22 en local (`nvm install 22`).
- App: PR matecmi/IngresoYa#33 fusionado en `desarrollo` (verificado en GitHub: 2026-10-06, merge `64f6661`).

## Decisiones
- Contrato de dominio del subtema: `docs/subtopic_mastery_contract.md` (compartido con iya-app). Solo modo `dynamic` en esta versión; solo Functions califica y concede logros.
