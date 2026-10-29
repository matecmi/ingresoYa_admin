# Contrato: sonidos de logros (`{config}/sounds`)

Lienzo aprobado: https://claude.ai/artifact/2E7GTptcH6pLFAPmymMbrC (familia **A · Campanita**).

La app suena **solo al completar algo**: nunca en medio de una pregunta ni durante el simulacro (el sonido llega en la pantalla de resultado).

## Documento

`{config}/sounds` (viaja dentro de `{config}/app`, sección `sounds`; sin lecturas extra):

| Campo | Tipo | Defecto | Regla |
|---|---|---|---|
| `enabled` | bool | `true` | Apagado: no suena ni vibra y Perfil oculta los interruptores. |
| `volume` | int 0-100 | `70` | Relativo al volumen multimedia del celular. 0 = solo vibración. |
| `levels` | map `"1".."4"` → bool | todos `true` | Encender o apagar cada nivel. |
| `smallCooldownSeconds` | int 0-60 | `3` | Pausa mínima entre dos sonidos del nivel 1. |
| `vibrate` | bool | `true` | Pulso corto al celebrar (50 ms niveles 1-2, 160 ms niveles 3-4). |
| `updatedAt`, `updatedBy` | — | — | Los escribe el admin. |

## Niveles

| Nivel | Archivo (app) | Cuándo |
|---|---|---|
| 1 · Pequeño | `assets/sounds/logro_1.ogg` | Tarjeta «Ganaste XP» con XP > 0; resultado con preguntas corregidas de «Mis errores». |
| 2 · Medio | `logro_2.ogg` | Misión del día completada; parte o subtema completados; nueva estrella de rango. |
| 3 · Grande | `logro_3.ogg` | Subir de rango; completar un tema; ascender de liga al cerrar la semana. |
| 4 · Dominio | `logro_4.ogg` | Dominar un subtema; subir al último rango (Maestro). Reservado, como el dorado. |

Los archivos se generan con `tool/make_sounds.py` de la app (≈46 KB en total).

## Reglas de la app

- **Uno a la vez:** lo que llega en 300 ms se junta y suena solo el mayor; tras un sonido, otro igual o menor no suena en 2,5 s.
- **Timbre del celular** (canal `ingresoya/sound` en `MainActivity`): normal → suena (y vibra); vibración → solo vibra; silencio → nada.
- **No pausa la música** del alumno (sin foco de audio, volumen multimedia).
- **Perfil → «Sonidos de logros»:** interruptores «Sonidos» y «Vibración» guardados en el teléfono (`achievement_sound_on`, `achievement_vibration_on`) y botón «Probar».
