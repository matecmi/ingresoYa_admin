# ingresoya_admin

Panel de administración de IngresoYa (Flutter) + backend en Firebase Functions (`functions/`, TypeScript).
Proyecto hermano: `../iya-app` (app del alumno). Ambos comparten contratos en `docs/` (p. ej. `subtopic_mastery_contract.md`, `question_contract_v2.md`, `admin_part_learning_contract.md`).

## Al empezar una sesión
1. Leer `PROGRESO.md` (este repo) y `../iya-app/PROGRESO.md`.
2. Revisar `git status` y la rama actual.

## Proceso obligatorio (sin preguntar)
En cada desarrollo, commit o PR, actualizar `PROGRESO.md` (y este `CLAUDE.md` si cambió algo relevante) **en este repo y en `../iya-app`**, e incluirlo en el commit/PR.

Si el cambio es funcional o de diseño, actualizar también las **guías vivas** (`docs/guias/`): la Guía de IngresoYa (pantallas y mensajes) y la Arquitectura (servicios, datos, flujos). Cómo hacerlo y sus direcciones publicadas: `docs/guias/README.md`.

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

XP y rango (fase 1): `functions/src/xp.ts` (XpService, se llama desde handlers tras submit, sección y reconcile), config `{config}/xp`, datos `{perfil}/xp/current` y `xpEvents`; admin `lib/src/domain/xp_settings.dart`, `data/repo/xp_repo.dart`, tarjetas en Configuración; retroactivo `npm run xp:retro`; contrato `docs/xp_contract.md`. Rankings (fase 3, contrato `docs/rankings_contract.md`, reemplaza al top 100 de la fase 2): `{config}/rankings` (apagado de fábrica), nombre de usuario para todos (`ranking.ts`, callable `updateRankingProfile`, `npm run rankings:aliases`), ficha pública y config (`leaderboard.ts`), liga semanal (`league.ts`, asiento dentro de `XpService.grant`, cierre programado `closeLeagueWeek` lunes 00:10 Lima en `league_job.ts`), reto del día (`challengePlan` en `simulator_service.ts`, `challenge.ts`); admin «Rankings» y «Nombres de usuario y reto de hoy» (`rankings_settings_card.dart`, `rankings_repo.dart`).

Simulador: reglas por examen pasado en el campo `simulator` de `admissionExams` (no tocan `revision`), configuración en `{config}/simulator`, intentos `past_exam`/`practice` en `functions/src/simulator_service.ts` (resultados en `{users}/{uid}/simulatorResults`, `pastExamBest`, `learningEvents`); contrato `docs/simulator_contract.md`.

El CLI `firebase` está instalado bajo el Node 20 de nvm: con Node 22 activo, añadir `C:\Users\USER\AppData\Local\nvm\v20.19.4` al final del PATH para emuladores y despliegues.

Perfiles y permisos del admin (contrato `docs/admin_staff_contract.md`): `functions/src/staff.ts` (callables `syncAdminAccess` y `manageAdminStaff`, sin App Check), colecciones `iya-admin-staff|roles|invites-{env}`, claims `{admin, role, p, cs, us}`; reglas con `can(sección, letra)` (`v e p a`) y `inCourseScope`. Admin: `domain/staff.dart`, `data/repo/staff_repo.dart`, sesión en `adminSessionProvider` (la fija el control de acceso de `app.dart`), vista previa `staffPreviewProvider`, pantalla `screens/staff/`. Usar `ref.watch(effectiveSessionProvider).can(...)` para mostrar u ocultar acciones. Sin `p`, «Publicar» → «Enviar a revisión» (`review` en la pregunta; `QuestionRepo.requestReview/returnForChanges`).

## Diseño del admin (rediseño 2026-10)
Lienzo aprobado: https://claude.ai/artifact/AzcWwYLE34iCdw4YJryZSC (v3.1). Tema claro en `lib/src/ui/theme/app_theme.dart` (tokens `ink`, `muted`, `line`, `brand`, `success/warn/error/info` + `*Soft`); fuente Plus Jakarta Sans en `assets/fonts/` (instancias estáticas 400–800 de la variable de Google Fonts, OFL). No usar `Colors.white` para texto (solo sobre fondos de marca). Piezas comunes: `lib/src/ui/widgets/admin_ui.dart` (`StatusPill`, `AdminPageHeader`, `SectionCard`, `KpiTile`, `InfoNote`, `EmptyState`). Menú por tareas y ayuda «?» de cada sección: `lib/src/ui/shell/admin_nav.dart` (agregar ahí cada sección nueva con su `help`); rutas: `lib/src/ui/admin_router.dart`.
Toda pantalla **de la app** que se muestre en el admin (vista previa, miniaturas) debe ser idéntica a la app real: capturas reales o réplica fiel de sus widgets y colores (`iya-app/lib/config/theme/app_theme.dart`, tema oscuro).
Vista previa «Así la ve el alumno»: `lib/src/app_preview/gen/*.g.dart` se **genera** desde el código de la app con `python tool/sync_app_preview.py` (tema, renderizador de preguntas y widgets del examen; textos del ARB). No editar a mano; correr `--check` antes de cada PR del admin y regenerar si la app cambió. La composición de la pantalla está en `app_preview/app_exam_preview.dart` (igual a `_buildQuestionFlow` y `AppShell`); la fuente Roboto va incluida en `assets/fonts` para que se vea igual en cualquier navegador.
Carga rápida: `/questions/quick` (`screens/question/quick_load_screen.dart`), parser `domain/quick_question_parser.dart` (a) b) c), «Clave: B», «Solución: …», `$…$` = fórmula), guardado `data/repo/quick_question_saver.dart` (mismo camino que el formulario: raíz, borrador v2, clave, espejo y explicación). Se puede abrir fijada en una parte con `?course=&topic=&subtopic=&part=`.

Capturas para revisar el diseño sin iniciar sesión: `flutter test test_shots --update-goldens` (o `--plain-name <prueba>`), salen en `test_shots/out/` (fuera del repo). Usan `FakeFirebaseFirestore` cargado con `test_shots/fixtures/test_sample.json`, una muestra de TEST leída con la cuenta de servicio (fuera del repo; si falta, base vacía). Requiere `FLUTTER_ROOT` para las fuentes de íconos.

## Documentación clave
`docs/` — arquitectura de exámenes, contrato de callables, seguridad y costos del backend, banco de preguntas publicable, editor visual, runbook de promoción a test, reglas de logros de subtema y dominio.
