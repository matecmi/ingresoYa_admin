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
| `saveEverySeconds` | number | 0 a 300 | 30 | Segundos como máximo entre un cambio y su guardado cuando no se llega a `saveEveryAnswers`. 0 = sin guardado por tiempo: solo por lote, al pausar o salir y al enviar. |
| `candidateStartsPerBlock` | number | 1 a 8 | 2 | Fase 3C. Escaneos aleatorios del banco por bloque al armar un examen de la guía. Más = más variedad y más lecturas. |
| `maxCandidatesPerStart` | number | 20 a 80 | 40 | Fase 3C. Candidatas por escaneo; también tope de cada pool por curso del Simulador. |
| `recentQuestionLimit` | number | 1 a 200 | 60 | Fase 3C. Preguntas recientes del alumno que la guía revisa para no repetir. |
| `simulatorSeenLimit` | number | 20 a 500 | 100 | Fase 3C. Preguntas vistas que el Simulador revisa dentro de sus «días sin repetir». |
| `attemptRetentionDays` | number | 30 a 730 | 180 | Fase 4A. Días que un intento enviado permanece en Firestore (`expireAt`, política TTL de `attempts`). El historial, las estadísticas y los mejores puntajes viven en resúmenes aparte y no se borran. |
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
  respuestas siguientes no posponen. Con `saveEverySeconds` = 0 no hay
  temporizador (2026-10-19): un alumno que tarda más de 30 s por pregunta
  hacía casi un guardado por respuesta.
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


## Selección de preguntas (Fase 3C, 2026-10-18)

Las Functions leen `{config}/exam` (`functions/src/exam_config.ts`) en vez
de las variables de entorno `EXAM_*`, que quedan como respaldo cuando el
documento no existe o un valor está fuera de rango. El documento se lee una
vez por instancia y se recuerda 5 minutos (`config_cache.ts`); un cambio del
admin tarda a lo sumo eso en aplicarse.

- Examen de la guía (`attempt_service.ts`): `recentQuestionLimit` preguntas
  recientes y `candidateStartsPerBlock × maxCandidatesPerStart` candidatas
  como máximo por bloque.
- Simulador (`simulator_service.ts`): `simulatorSeenLimit` vistas en la
  ventana de repetición (antes 500 fijas) y pools por curso acotados por
  `maxCandidatesPerStart`.
- La lista de cursos activos se recuerda 5 minutos por instancia
  (`catalog_cache.ts`): el modo aleatorio, el diagnóstico y el reto del día
  ya no leen la colección completa en cada llamada.
- **Reto del día de noche:** `generateDailyChallenges` (00:05 Lima) arma el
  reto de cada universidad activa; el primer alumno del día ya no paga las
  ~1.400 lecturas de construirlo. Si la tarea falló, `createExamAttempt` lo
  arma al pedirlo, como antes.

Preajustes en Configuración → Exámenes: Económico (1 / 20 / 30 / 50),
Recomendado (2 / 40 / 60 / 100) y Variado (4 / 80 / 200 / 300).

## Costo esperado

| Caso | Antes | Después (de fábrica) |
| --- | --- | --- |
| Examen de parte, 10 preguntas | ≈ 6,5 guardados + envío | 2 guardados + envío |
| Examen pasado, 100 preguntas | ≈ 100 guardados | ≈ 20 guardados |
| Subtema con 5 secciones | 5 llamadas (y 5 rechequeos de XP) | 1 llamada |

Cada guardado evitado ahorra una invocación, una lectura y una escritura del
intento completo. La medición antes y después está en `docs/cost_baseline.md`.
