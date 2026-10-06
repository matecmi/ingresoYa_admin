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
- Functions: Node/TypeScript, firebase-functions 7, firebase-admin 13. Código en `functions/src/` (`attempt_service.ts`, `selection.ts`, `subtopic_achievement.ts`, `achievement_summary.ts`, `handlers.ts`, ...).

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

## Documentación clave
`docs/` — arquitectura de exámenes, contrato de callables, seguridad y costos del backend, banco de preguntas publicable, editor visual, runbook de promoción a test, reglas de logros de subtema y dominio.
