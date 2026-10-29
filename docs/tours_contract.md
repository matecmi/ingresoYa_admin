# Contrato: Recorridos del búho (guía la primera vez)

Diseño aprobado: lienzo «Recorrido guiado del búho» (https://claude.ai/artifact/5fKmk6QjuQNpSXvKUKXvSz), 2026-10-29.

Copia en `../iya-app/docs/tours_contract.md` (mantener iguales).

## 1. Qué es

La primera vez que el alumno entra a la app (bienvenida) y a cada sección de gran impacto, el búho (con la bufanda de su universidad, ver `universities_contract.md` → `identity`) lo guía en 2–6 pasos: oscurece la pantalla, ilumina la pieza que explica con un aro que late y habla desde un globo con «Siguiente» y «Saltar». Cada sección tiene un botón «?» que repite su guía; Perfil → «Recorridos del búho» repite la bienvenida o vuelve a mostrar todas.

Lo visto se guarda **en el teléfono** (SharedPreferences, por cuenta y versión): sin lecturas ni escrituras en Firebase.

## 2. Ajustes `{config}/tours`

Viaja en `{config}/app` (sección `tours`). Todo campo ausente o inválido usa el de fábrica.

| Campo | Fábrica | Límites | Qué es |
|---|---|---|---|
| `enabled` | `true` | | Interruptor general. Apagado no se muestra ninguna guía sola (el «?» sigue funcionando). |
| `animate` | `true` | | Animar al búho y al aro. Con «reducir movimiento» nunca se anima. |
| `maxPerSession` | 1 | 1–5 | Guías que se abren solas por sesión (la bienvenida cuenta). |
| `version` | 1 | 1–100 | Subirla vuelve a mostrar todas las guías a quien ya las vio. |
| `tours.{id}.enabled` | `true` | | Guía de esa sección. |
| `tours.{id}.steps.{stepId}` | — | | `{title ≤ 60, text ≤ 160, pose}`: reemplaza el texto de fábrica del paso. Vacío = el de fábrica. `pose`: `wave`, `point`, `explain`, `celebrate`. En los textos, `{nombre}` = nombre del alumno. |

Lo que señala cada paso (la pieza de la pantalla) lo fija la app; el admin solo cambia textos y gesto.

## 3. Guías y pasos

| `id` | Dónde | Pasos (`stepId`) |
|---|---|---|
| `welcome` | Inicio, la primera vez | `intro` (saluda), `home`, `guide`, `simulator`, `progress`, `profile` (celebra) — señala cada pestaña de la barra |
| `guide` | Guía de estudio | `courses`, `course` |
| `simulator` | Simulador | `summary`, `challenge`, `exams` |
| `mistakes` | Mis errores | `mission`, `stats`, `courses` |
| `rankings` | Rankings | `tabs`, `league` |
| `progress` | Progreso | `tabs`, `path` |
| `profile` | Perfil | `rank`, `tours` |

Los textos de fábrica están en la app (`lib/l10n/app_es.arb`, claves `tour…`) y en el admin (`domain/tour_settings.dart`, para mostrarlos como sugerencia).
