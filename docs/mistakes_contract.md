# Contrato: Mis errores (banco de errores y misión diaria)

Diseño aprobado: lienzo «Mis errores · pantallas», página «Flujo D (misión)» (https://claude.ai/artifact/Uuxb14Cf9XfJ5ncgmCyXZT), 2026-10-29.

Copia en `../iya-app/docs/mistakes_contract.md` (mantener iguales).

## 1. Ajustes `{config}/simulator.mistakes`

Viaja en `{config}/app` con el resto de `simulator`. Todo campo ausente o inválido usa el de fábrica.

| Campo | Fábrica | Límites | Qué es |
|---|---|---|---|
| `enabled` | `true` | | Interruptor general del banco. |
| `missionEnabled` | `true` | | Misión diaria «Corrige N errores». |
| `missionSize` | 5 | 1–20 | Errores a corregir en el día. |
| `missionXp` | 15 | 0–200 | Bono una vez al día al cumplirla. |
| `exitHits` | 1 | 1–3 | Aciertos seguidos para salir del banco. |
| `bankMax` | 300 | 50–500 | Tope por alumno; al llenarse salen las fallas más antiguas. |
| `practiceMax` | 20 | 5–50 | Lo más largo que se puede practicar de una vez. |
| `includeGuide` | `false` | | Sumar los exámenes de la guía (reservado: aún no se aplica). |
| `fixXp` | 3 | 0–50 | XP por pregunta corregida. |
| `fixXpDailyCap` | 30 | 0–500 | Tope diario del XP por corregir. |

## 2. Datos: `{perfil}/simulatorSummary/current.mistakes`

Dentro del resumen que el envío del Simulador ya lee y escribe en su transacción: **cero lecturas y escrituras extra**. Solo lo escribe el servidor (regla existente del resumen).

```
mistakes: {
  items: { <questionId>: { c, t, s, x, n, h, at, b?, from? } },
  fixed: [ { q, c, x, at, w } ],      // últimas 50 corregidas, la más nueva primero
  fixedTotal: number,
  mission: { day, done, completed },  // día Perú
  streak: { day, days },              // días seguidos cumpliendo la misión
  xpDay: { day, xp }                  // XP por corregir ya dado ese día
}
```

- `c`/`t`/`s`: curso, tema y subtema; `x`: extracto del enunciado (máx. 140, fórmulas como `$…$`); `n`: veces fallada o en blanco; `h`: aciertos seguidos desde la última falla; `at`: última falla (ms); `b`: en blanco la última vez; `from`: día desde el que se puede practicar.
- `w` (dónde se corrigió): `mistakes`, `daily`, `challenge`, `diagnostic`, `past_exam`, `practice`.

## 3. Reglas (`functions/src/mistake_bank.ts`, `applyGraded`)

- En cada envío del Simulador (todos los modos): lo fallado o en blanco **entra** (o suma `n` y pone `h` en 0); lo acertado que estaba en el banco suma `h` y **sale** a `fixed` al llegar a `exitHits`.
- Reto del día: lo que entra lleva `from` = mañana (no revela respuestas hoy).
- Misión: `done` cuenta las salidas del día; al llegar a `missionSize` se marca `completed` (una vez por día) y `streak` suma 1 si el último día cumplido fue ayer (si no, vuelve a 1).
- XP: `fixXp` por salida con el tope `fixXpDailyCap` (eventos `mistake_fixed_{attemptId}`, tipo `mistake_fixed`) y `missionXp` al cumplirla (`mistake_mission_{día}`, tipo `mistake_mission`). No usan el tope diario general del XP.
- El resultado del envío (`simulator.mistakes`) trae `{added, fixed, left, missionDone, missionSize, missionCompleted}` para «4 se sumaron a Mis errores».

## 4. Practicar: `createExamAttempt`

```
{ requestId, purpose: "practice", mode: "mistake_bank",
  count: 1–50, courseId?, topicId?, order: "most_missed" | "mixed", timed }
```

- `count` se recorta a `practiceMax`. «Más falladas primero»: por `n` y luego la falla más reciente.
- Lee el resumen (1) y las preguntas elegidas (versión publicada actual). Sin preguntas: `failed-precondition` con `reason: "no_mistakes"`; banco apagado: `mistakes_unavailable`.
- Sin penalidad por error; con reloj, 90 s por pregunta.
