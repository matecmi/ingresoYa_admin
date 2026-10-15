# ingresoya_admin

Panel de administración de IngresoYa (Flutter) + backend en Firebase Functions (`functions/`, TypeScript).
Proyecto hermano: `../iya-app` (app del alumno). Ambos comparten contratos en `docs/` (p. ej. `subtopic_mastery_contract.md`, `question_contract_v2.md`, `admin_part_learning_contract.md`).

## Al empezar una sesión
1. Leer `PROGRESO.md` (este repo) y `../iya-app/PROGRESO.md`.
2. Revisar `git status` y la rama actual.

## Proceso obligatorio (sin preguntar)
En cada desarrollo, commit o PR, actualizar `PROGRESO.md` (y este `CLAUDE.md` si cambió algo relevante) **en este repo y en `../iya-app`**, e incluirlo en el commit/PR.

## Flujo Git
- `main` = producción, `desarrollo` = integración estable.
- Cada cambio en rama nueva desde `desarrollo` con prefijo `codex/`. PR hacia `desarrollo`; release con PR `desarrollo` → `main`.
- No trabajar directamente en `main` ni `desarrollo`. No fusionar PRs automáticamente.

## Stack
- Flutter (Dart ^3.9.2), Riverpod, go_router, Firebase Auth, Cloud Firestore, flutter_math_fork.
- Functions: Node 22 (runtime `nodejs22`)/TypeScript, firebase-functions 7, firebase-admin 13. Código en `functions/src/` (`attempt_service.ts`, `selection.ts`, `subtopic_achievement.ts`, `achievement_summary.ts`, `handlers.ts`, ...).

## Configuración que lee la app
Colección `AppEnv.configCollection` (`iya-config-test`): `sync` (sincronización del progreso) y `study` (reglas de «Revisado» de la guía), editables en «Configuración» (`lib/src/ui/screens/settings/`).

## Comandos
```powershell
# Flutter (admin)
flutter pub get
flutter analyze
flutter test
flutter run

# Functions (desde functions/)
npm run build
npm run lint
npm test
npm run test:emulators   # reglas + attempt_service con emuladores
npm run emulators
```

Datos de prueba en TEST: `node tools/seed_test.js <service-account.json> [--delete]` desde `functions/` (cursos «(prueba)» `seed-*`; la cuenta de servicio nunca va al repo). Datos amplios de QA: `node tools/seed_qa.js <service-account.json> [--dry-run|--delete]` (12 cursos «(QA)» `qa-*`, 988 preguntas con respuesta calculada o de tablas verificadas, contenido completo en cada parte y plantillas `qa-part-exam-v1` / `qa-subtopic-mastery-v1`; además exámenes pasados UNPRG Ordinario 2025 I, 2025 II y 2026 II con 60 preguntas `qa-pex-*` y reglas de ejemplo). Node local: 22 (`nvm use 22.23.3`).

Simulador: reglas por examen pasado en el campo `simulator` de `admissionExams` (no tocan `revision`), configuración en `{config}/simulator`, intentos `past_exam`/`practice` en `functions/src/simulator_service.ts` (resultados en `{users}/{uid}/simulatorResults`, `pastExamBest`, `learningEvents`); contrato `docs/simulator_contract.md`.

El CLI `firebase` está instalado bajo el Node 20 de nvm: con Node 22 activo, añadir `C:\Users\USER\AppData\Local\nvm\v20.19.4` al final del PATH para emuladores y despliegues.

## Documentación clave
`docs/` — arquitectura de exámenes, contrato de callables, seguridad y costos del backend, banco de preguntas publicable, editor visual, runbook de promoción a test, reglas de logros de subtema y dominio.
