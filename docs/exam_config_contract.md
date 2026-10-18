# Configuración de exámenes (`{config}/exam`)

Contrato compartido entre `ingresoya_admin` (lo edita en Configuración → tema
«Exámenes») e `iya-app` (lo lee una vez por sesión). Fase 3A de la
reestructuración de costos (2026-10-18). La Fase 3C suma aquí los límites de
selección de preguntas que hoy son variables de entorno de las Functions.

## Problema

Durante un examen la app llamaba a `saveExamAnswers` 700 ms después de cada
respuesta: unas 6,5 llamadas por examen de 10 preguntas y hasta 100 en un
examen pasado, cada una con una lectura y una escritura del intento completo
(25 a 250 KB). Las secciones de una parte se confirmaban al servidor una por
una (`recordPartSectionCompletion`, 5 llamadas por parte), y cada llamada
rechequeaba la XP.

## Documento

| Campo | Tipo | Límites | De fábrica | Significado |
| --- | --- | --- | --- | --- |
| `saveEveryAnswers` | number | 1 a 20 | 5 | Respuestas nuevas que la app acumula antes de guardarlas en el servidor. 1 = una llamada por respuesta, como antes. |
| `saveEverySeconds` | number | 5 a 300 | 30 | Segundos como máximo entre un cambio y su guardado cuando no se llega a `saveEveryAnswers`. |
| `schemaVersion`, `updatedAt`, `updatedBy` | — | — | — | Los escribe el admin al guardar. |

Lectura: como el resto del catálogo (reglas `isCatalog`). Escritura: solo el
admin (`AppConfigRepo.saveExamSettings`).

## Qué hace la app

**Examen (`PartExamAttemptScreen`, `ExamSettings`, `exam_save_scheduler.dart`):**

- Cada respuesta se guarda al instante en el teléfono (almacén de
  recuperación) y se marca pendiente.
- Con `saveEveryAnswers` pendientes se llama a `saveExamAnswers` tras 700 ms
  (cambios rápidos de la misma respuesta se juntan). Si no se llega, la
  primera pendiente arranca un temporizador de `saveEverySeconds` que las
  respuestas siguientes no posponen.
- Al pausar la app, al salir del examen («Pausar y salir») y al enviar se
  manda todo lo pendiente; `submitExamAttempt` ya acepta las respuestas en la
  misma llamada (hasta 300), así que el envío nunca depende de un guardado
  previo.
- Un fallo de guardado se muestra igual que antes y se reintenta.

**Secciones de una parte (`SubtopicStudyPage`):**

- Al marcar una sección como revisada, el avance local se guarda como siempre
  y la parte queda en una cola de confirmación.
- Las secciones revisadas de cada parte viajan en **una** llamada
  `recordPartSectionCompletion` con `sections: [...]` al salir del subtema, al
  pausar la app o a los 2 minutos, lo que ocurra primero. Antes de iniciar el
  examen de la parte se envían también (ya existía).
- La XP de las secciones llega con ese envío; la barra de progreso es local y
  no espera.

## Costo esperado

| Caso | Antes | Después (de fábrica) |
| --- | --- | --- |
| Examen de parte, 10 preguntas | ≈ 6,5 guardados + envío | 2 guardados + envío |
| Examen pasado, 100 preguntas | ≈ 100 guardados | ≈ 20 guardados |
| Subtema con 5 secciones | 5 llamadas (y 5 rechequeos de XP) | 1 llamada |

Cada guardado evitado ahorra una invocación, una lectura y una escritura del
intento completo. La medición antes y después está en `docs/cost_baseline.md`.
