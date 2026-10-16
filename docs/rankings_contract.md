# Contrato de Rankings (XP fase 3): nombre de usuario, liga semanal y reto del día

Compartido por el admin, Functions y la app (`iya-app/docs/rankings_contract.md` es una copia). Reemplaza al top 100 «Los más dedicados» y a «Aparecer en rankings» de la fase 2 (`docs/xp_contract.md` §7).

## 1. Decisiones

- **Rango de perfil ≠ ranking.** El rango (Bronce I…Maestro III, estrellas) es el nivel personal y nunca baja; en los rankings se muestra como insignia junto al nombre de usuario. No hay top de XP total.
- **Todos tienen nombre de usuario** (se elige en el onboarding; si no, se genera uno al azar). En los rankings nunca se ve el nombre real, el correo ni las respuestas.
- **«Ocultarme de los rankings»** (apagado por defecto): el alumno juega igual y ve su puesto, pero los demás lo ven como «Postulante oculto», sin nombre de usuario ni insignia.
- **Interruptor general** en el admin, **apagado de fábrica**: sin él la app no muestra Rankings, liga ni reto, y el servidor no arma grupos ni retos. El nombre de usuario existe igual.
- La liga usa como puntos el **XP ganado en la semana** (una sola moneda).

## 2. Configuración `{config}/rankings`

Todo campo ausente o inválido usa el de fábrica.

| Campo | Fábrica | Qué es |
|---|---|---|
| `enabled` | `false` | Interruptor general. |
| `startWeek` | — | Lunes (`YYYY-MM-DD`) desde el que corre la liga; el admin lo fija al encender (el lunes siguiente). |
| `bannedWords` | `[]` | Palabras prohibidas en el nombre de usuario (además de las de fábrica). |
| `league.stageNames` | Aspirante, Postulante, Finalista, Ingresante | Etapas, de menor a mayor (2 a 8). |
| `league.groupSize` | 30 | Alumnos por grupo. |
| `league.promotePercent` / `demotePercent` | 15 / 15 | % del grupo que sube / baja. |
| `league.minGroupForDemotion` | 5 | En grupos más chicos nadie baja. |
| `league.preferSameUniversity` | `false` | Grupos separados por universidad. |
| `league.showWeekPositions` | `true` | «Esta semana: N° en la UNPRG · M° en Ing. Civil». |
| `league.minCareerPlayers` | 5 | Mínimo para mostrar el puesto/tabla por carrera de la semana. |
| `challenge.enabled` | `true` | Reto del día (solo si `enabled`). |
| `challenge.questionCount` / `minutes` | 10 / 15 | Tamaño y reloj. |
| `challenge.bonusXp` | 20 | Bono por completarlo (además del XP de sesión). |
| `challenge.ownPastExamQuestions` | 6 | Preguntas de exámenes pasados de la propia universidad (las que haya, hasta este número; nunca menos de 1 si existen). |
| `challenge.noRepeatDays` | 30 | No repetir preguntas de retos de esos días. |
| `challenge.minCareerPlayers` | 5 | Mínimo para mostrar la pestaña de carrera del reto. |

## 3. Nombre de usuario

- `{perfil}/ranking/current`: `alias`, `hidden`, `moderatedReason`, `updatedAtMs`. Solo lo escriben Functions (y el admin al retirar un alias); el dueño lo lee.
- Callable `updateRankingProfile({alias?, hidden?})`: valida y reserva el alias (reglas de `xp_contract.md` §7: 3-20, letras/números/_, sin palabras prohibidas ni el nombre o correo, único sin tildes). Sin alias guardado y sin `alias` en la llamada, el servidor **genera uno** («Animal_Carrera_NN»). Responde `{alias, hidden}`.
- Alumnos existentes: `npm run rankings:aliases -- [--dry-run]` les genera uno.

## 4. Ficha pública `iya-leaderboard-{env}/{uid}`

Una por alumno con nombre de usuario (oculto o no). La escribe Functions al cambiar el nombre/ocultarse y en cada XP (`XpService.grant`).

`alias` (null si `hidden`), `hidden`, `rankStep`, `stars` (null si oculto), `universityId`, `professionId`, `universityAcronym`, `professionName`, `weekKey`, `weekXp`, `stage`, `updatedAtMs`.

«Esta semana» por universidad/carrera: `where weekKey == semana [&& universityId] [&& professionId] orderBy weekXp desc`; puesto = `count(weekXp > mío) + 1`.

## 5. Liga semanal

- **Semana:** lunes 00:00 a domingo 23:59, hora de Lima (`peruWeek`). Etapa inicial: la primera.
- **Entrar a un grupo:** al ganar el primer XP de la semana (en `XpService.grant`), en la misma transacción: puntero `{leagueGroups}/{semana}_{etapa}[_{universidad}]_open` → grupo con cupo o uno nuevo (`{semana}_{etapa}[_{univ}]_{n}`).
- `{leagueMembers}/{semana}_{uid}`: `week`, `groupId`, `stage`, `weekXp`, `alias`, `hidden`, `rankStep`, `stars`, `universityId`, `professionId`, `joinedAtMs`. Se actualiza en cada XP de esa semana. Lectura pública para alumnos con sesión.
- **Cierre** (tarea programada, lunes 00:10 Lima, solo si `enabled`): por grupo, orden `weekXp desc, joinedAtMs asc`; suben `max(1, round(n·p))` (no en la última etapa), bajan `round(n·d)` si `n ≥ minGroupForDemotion` (no en la primera); nunca se cruzan. Escribe en `ranking/current`: `stage` y `lastResult{week, from, to, position, size, seen:false}`.

## 6. Reto del día

- `{dailyChallenges}/{día}_{universidad}`: `day`, `universityId`, `questions[{questionId, version}]`, `courseIds`, `durationSeconds`, `createdAtMs`. Lo crea el servidor **la primera vez que alguien lo pide ese día** (idempotente, sin tarea programada).
- **Preguntas:** publicadas, repartidas entre los cursos de la universidad; primero hasta `ownPastExamQuestions` de exámenes pasados de esa universidad; el resto de exámenes pasados de otras universidades o propias de IngresoYa; sin preguntas usadas en sus retos de los últimos `noRepeatDays` días.
- **Intento:** `createExamAttempt` con `purpose: "daily_challenge"`; request ID fijo `challenge_{día}` → un solo intento por alumno y día. Debe **empezarse** ese día (hora de Lima); tiene sus `minutes` completos.
- **Al entregar:** puntaje, aciertos y tiempo; **las respuestas y explicaciones no se devuelven hasta el día siguiente** (Lima). XP: sesión normal + `daily_challenge_{día}` (`bonusXp`, sin tope diario).
- `{challengeEntries}/{día}_{uid}`: `day`, `universityId`, `professionId`, `alias`, `hidden`, `rankStep`, `stars`, `correct`, `total`, `timeUsedSeconds`, `submittedAtMs`. Tabla: `where day == && universityId == [&& professionId ==] orderBy correct desc, timeUsedSeconds asc`. Puesto = mejores + 1 (más correctas, o iguales con menos tiempo).

## 7. Permisos

- Fichas, miembros de la liga y entradas del reto: lectura para alumnos con sesión; escritura solo Functions (el admin puede borrar al moderar).
- `ranking/current`: lectura del dueño; escritura Functions/admin.
- `dailyChallenges`: solo Functions (la app recibe el reto a través del intento).
