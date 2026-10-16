# Contrato de XP y rango de perfil (fases 1 y 2)

Compartido por el admin, Functions y la app (`iya-app/docs/xp_contract.md` es una copia). Diseño: lienzo «Rango de perfil y XP».

## 1. Principios

- El XP lo otorga **solo el servidor** (`functions/src/xp.ts`), y siempre **después** de que el evento ya quedó registrado por su propia operación: examen calificado, parte verificada o logro concedido.
- Cada otorgamiento tiene un **id fijo**. Repetir una llamada o volver a ejecutar el script retroactivo nunca suma dos veces.
- Si otorgar el XP falla, la operación principal no falla: se registra en el log y la siguiente llamada sobre el mismo evento lo recupera.
- El **día** y la **semana** son los de Perú (UTC−5). La semana empieza el lunes.

## 2. Eventos

| Tipo (`type`) | Id fijo | XP (fábrica) | Tope diario |
|---|---|---|---|
| `section_reviewed` | `section_{partId}_{section}` | 2 | no |
| `part_passed` | `part_passed_{partId}` | 40 | no |
| `subtopic_completed` | `subtopic_completed_{subtopicId}` | 80 | no |
| `subtopic_mastered` | `subtopic_mastered_{subtopicId}` | 150 | no |
| `simulator_session` | `session_{attemptId}` | 10 (si ≥ `minQuestionsPerSession` preguntas) | sí |
| `correct_answers` | `correct_{attemptId}` | 1 por correcta **nueva** | sí |
| `diagnostic` | `diagnostic` | 30 (una vez) | no |
| `past_exam_completed` | `past_exam_{examId}_{día}` | 50, como máximo cada `pastExamEveryDays` días por examen | no |
| `past_exam_improvement` | `improve_{attemptId}` | 1 por cada 10 puntos sobre el mejor anterior, máx. 50 | no |
| `streak_day` | `streak_{día}` | 5 por día con sesión que cuenta | sí |
| `weekly_goal` | `weekly_goal_{lunes}` | 50 al llegar a las sesiones por semana de la meta (`simulatorPlan/current.sessionsPerWeek`) | no |
| `daily_challenge` | `daily_challenge_{día}` | Bono del reto del día (`{config}/rankings.challenge.bonusXp`, 20), además de la sesión | no |

**Respuesta correcta nueva:** al crear el intento, el servidor anota en `xpFreshQuestionIds` las preguntas que el alumno no vio en `repeatWindowDays`. Al entregar, guarda en `xpBasis.freshCorrect` cuántas de esas acertó.

**Juego limpio:**
- Una sesión del Simulador respondida a menos de `minSecondsPerQuestion` segundos por pregunta en promedio no da XP.
- El tope diario (`dailyCap`) limita solo los tipos marcados con «sí» en la tabla.

**Cuándo se otorga:**
- `submitExamAttempt`: Simulador, o parte, subtema y dominio de la guía.
- `recordPartSectionCompletion`: secciones, parte y subtema.
- `reconcileSubtopicAchievement`: subtema.

Las tres respuestas incluyen `xp` (§4) cuando algo se otorgó.

## 3. Datos

| Ruta | Contenido | Escribe | Lee |
|---|---|---|---|
| `{config}/xp` | `ranks[{name, minXp, image}]`, `starsEnabled`, `xpPerStar`, `amounts{…}`, `dailyCap`, `minQuestionsPerSession`, `repeatWindowDays`, `minSecondsPerQuestion`, `pastExamEveryDays` | Admin | Functions, app |
| `{profile}/{uid}/xp/current` | `total`, `rankStep` (el más alto alcanzado), `today{day, capped}`, `week{key, xp, sessionDays[]}`, `pastExamDays{examId: día}`, `updatedAtMs` | Functions (y el admin al revertir) | Dueño, admin |
| `{profile}/{uid}/xpEvents/{id}` | `type`, `xp`, `requested`, `count?`, `day`, `week`, `atMs`, `source{…}`, `createdAt`; si se revirtió: `reverted`, `revertedXp`, `revertReason`, `revertedBy`, `revertedAtMs` | Functions (y el admin al revertir) | Dueño, admin |
| `{profile}/{uid}/ranking/current` | `alias`, `visible`, `moderatedReason`, `updatedAtMs` (fase 2) | Functions (y el admin al retirar un alias) | Dueño, admin |
| `iya-leaderboard-{env}/{uid}` | `alias`, `total`, `rankStep`, `stars`, `universityId`, `universityAcronym`, `professionId`, `professionName`, `updatedAtMs` (fase 2) | Functions (el admin actualiza al revertir y borra al moderar) | Cualquier alumno con sesión |
| `iya-aliases-{env}/{alias sin tildes, minúsculas}` | `uid`, `alias` (fase 2) | Functions (el admin borra al moderar) | Admin |

**Valores de fábrica** (cualquier campo ausente o inválido usa el suyo):
- **Escalera** de 18 escalones:
  - Bronce I-III: 0 · 150 · 350
  - Plata I-III: 600 · 900 · 1 250
  - Platino I-III: 1 650 · 2 100 · 2 600
  - Zafiro I-III: 3 200 · 3 900 · 4 700
  - Amatista I-III: 5 600 · 6 600 · 7 700
  - Maestro I-III: 9 000 · 10 500 · 12 000
- **Imágenes:** `{bronze|silver|platinum|sapphire|amethyst|master}_{1|6|12}`. Son las que trae la app en `assets/ranks/`.
- **Estrellas:** activadas, una cada 2 000 XP después del último escalón.
- **Límites:** `dailyCap` 300, `minQuestionsPerSession` 10, `repeatWindowDays` 14, `minSecondsPerQuestion` 5, `pastExamEveryDays` 7.

**Reglas de la escalera:** debe empezar en 0, crecer siempre y usar imágenes de la lista. Si no cumple, se usa la de fábrica.

**El rango nunca baja:** `rankStep` guarda el más alto alcanzado. Si el admin sube los umbrales, nadie pierde su rango.

## 4. Respuesta `xp` (`XpAward`)

`{gained, items[{type, xp, requested, count?}], totalBefore, total, rankStepBefore, rankStep, starsBefore, stars, todayCapped, dailyCap}`

La app la usa para mostrar «+N XP» con su desglose y celebrar si `rankStep` o `stars` subieron.

## 5. Revertir (admin)

En Configuración → XP de un alumno se busca al alumno por correo o uid, se ve su libro de XP y se revierte un evento indicando el motivo. Todo ocurre en una transacción:
- El evento queda `reverted: true` con su motivo.
- Se restan sus XP de `total`, y de `week.xp` si es de la semana actual.
- `rankStep` se recalcula con el nuevo total. Es la única forma en que un rango puede bajar.

El evento revertido no se vuelve a otorgar, porque su id sigue existiendo.

## 6. Retroactivo

`npm run xp:retro -- [--dry-run]` (con `GOOGLE_APPLICATION_CREDENTIALS` e `INGRESOYA_ENV`) otorga, con los mismos ids que en vivo:
- secciones registradas,
- partes aprobadas,
- subtemas completados y dominados,
- sesiones del Simulador,
- diagnóstico,
- exámenes pasados,
- días de racha.

No cubre aciertos nuevos, mejoras de puntaje ni metas semanales, porque esos datos no se pueden saber después.

## 7. Fase 2: alias y top 100 «Los más dedicados» (reemplazada)

> **Reemplazada por la fase 3** (`docs/rankings_contract.md`): ya no hay top 100 ni «Aparecer en rankings»; todos tienen nombre de usuario y pueden ocultarse. Las reglas del alias de abajo siguen vigentes.

**Configuración** `{config}/xp.leaderboard`: `enabled` (true), `size` (100, de 10 a 500), `universityFilterMin` (50), `bannedWords` (lista del admin; además hay una de fábrica en `functions/src/ranking.ts`).

**Callable `updateRankingProfile({visible, alias?})`** (transacción):
- Si `alias` cambia, se valida y se reserva en `iya-aliases-{env}/{clave}`; el alias anterior se libera. Errores (`failed-precondition` salvo el último):
  - `alias_length`: de 3 a 20 caracteres.
  - `alias_characters`: solo letras (con tildes y ñ), números y `_`, con al menos una letra.
  - `alias_banned`: una palabra prohibida (palabra completa; las de 6 letras o más, también dentro del alias, para no rechazar «Cálculo»).
  - `alias_personal`: contiene una palabra de 4 letras o más del nombre o del correo del perfil.
  - `alias_required`: `visible: true` sin alias.
  - `alias_taken` (`already-exists`): otro alumno ya lo usa (sin importar tildes ni mayúsculas).
- Guarda `ranking/current` y crea (`visible`) o borra la fila del top. Responde `{alias, visible}`.

**Sincronía:** `XpService.grant` lee `ranking/current` y el perfil dentro de la transacción del XP y reescribe la fila si `visible`. Al revertir XP, el admin actualiza `total`, `rankStep` y `stars` de la fila si existe.

**Lectura en la app:** top = `orderBy(total desc).limit(size)` (filtrado por `universityId` si su universidad tiene `universityFilterMin` alumnos visibles o más); puesto = `count(total > mío) + 1`, también si el alumno no aparece (solo él lo ve).

**Moderación (admin):** «Top 100 y alias» borra la fila y el alias, y deja `ranking/current` con `alias: null`, `visible: false` y `moderatedReason`, que la app muestra hasta que elija otro.

## 8. Fases siguientes

- Fase 3 (hecha): nombre de usuario, liga semanal y reto del día → `docs/rankings_contract.md`.
- Pendiente: XP del ranking de admisión (cuando exista el ranking de simulacros).
