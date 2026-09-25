# Costos y medición de exámenes

Esta guía describe trabajo de Firestore **observado por la Function**, no una
cotización ni una garantía de facturación. Firestore puede cobrar lecturas de
entradas de índice para determinadas consultas, reintentar transacciones y
cambiar condiciones de facturación. Antes de estimar gasto se deben recopilar
los logs de staging con distribución real de banco y concurrencia.

## Telemetría segura

Al completar o rechazar una callable se registra un evento sin payload,
respuestas, claves, explicaciones ni UID. Sus campos numéricos son:

- `durationMs`: tiempo de pared de la Function;
- `observedDocumentReads`: suma de lecturas directas y documentos devueltos por
  consultas;
- `queryCalls`, `queryDocuments`, `plannedDocumentWrites` y
  `transactionAttempts`.

No representan el recibo de Firebase. Sirven para medir percentiles de latencia
por operación y detectar aumentos de consultas/devueltos o reintentos. Deben
agregarse por nombre de evento en Cloud Logging/Monitoring, en staging, y
compararse antes y después de cambiar un índice o una plantilla.

## Trabajo observado por operación

La siguiente tabla asume un intento nuevo dinámico de un solo bloque para una
parte y una transacción sin reintentos. `R` es la cantidad real de documentos en
`recentQuestions` devueltos (límite 200); `Q` los documentos realmente devueltos
por los escaneos de candidatos. Los límites se muestran como máximos de código,
no como lecturas garantizadas.

| Operación | Lecturas observadas | Escrituras lógicas | Notas |
| --- | --- | --- | --- |
| Crear 10 preguntas | `8 + R + Q`, con `Q ≤ 4 × 80 = 320` | `10 + 2 = 12` | 8 lecturas directas: idempotencia inicial/transaccional, perfil, progreso, plantilla y tres documentos académicos. |
| Crear 15 preguntas | `8 + R + Q`, con `Q ≤ 4 × 80 = 320` | `15 + 2 = 17` | El límite por escaneo llega a 80 desde 10 preguntas; no crece por encima de ese tope. |
| Reintento con el mismo `requestId` | 2 | 0 | Clave idempotente e intento congelado; no se vuelve a seleccionar. |
| Recuperar intento | 1 | 0 | Un documento de intento, con instantánea y respuestas ya guardadas. Vigilar tamaño del documento. |
| Guardar respuestas modificadas | 1 | 1 | Una transacción; un patch sin cambios no escribe. |
| Calificar 10 preguntas | 11, o 12 si hay progreso de parte | 1, o hasta 2 con progreso | Intento + 10 claves; parte aprobada añade progreso. |
| Calificar 15 preguntas | 16, o 17 si hay progreso de parte | 1, o hasta 2 con progreso | Las claves se leen en un `transaction.getAll`, una llamada agrupada, no N+1 de red. |

Las transacciones pueden reintentarse por contención: el campo
`transactionAttempts` permite identificarlo, y cada reintento vuelve a ejecutar
sus lecturas. `plannedDocumentWrites` cuenta planes de escritura ejecutados por
la Function y puede crecer con un reintento; las escrituras de la tabla son
documentos lógicos del camino exitoso. Ninguna cifra incluye costes de índices
ni de red.

## Selección, políticas y banco insuficiente

Cada bloque hace hasta `EXAM_CANDIDATE_STARTS_PER_BLOCK` escaneos de `randomKey`
(por defecto 4). Cada uno está limitado a
`min(EXAM_MAX_CANDIDATES_PER_START, max(20, cantidad × 8))`, con máximo 80. La
consulta filtra en servidor por `status`, curso, tema, subtema, parte y, cuando
corresponde, `sourceType`; universidad, modalidad, examen, dificultad y año se
validan luego sobre ese conjunto ya acotado. `strict` y
`prefer_profile_university` no añaden consultas: cambian solo el ranking local.

Si el conjunto no alcanza, se devuelve `insufficient_questions` con disponibles
y requeridas antes de crear la transacción: hay las lecturas de validación y
escaneos, pero cero escrituras de intento, idempotencia o repetición. Esto no es
una prueba de que no existan más documentos fuera de la ventana aleatoria; es el
comportamiento deliberadamente limitado de esta política.

## Límites e índices versionados

Los límites se leen desde configuración de Functions y están acotados para
impedir una consulta accidentalmente abierta:

| Variable | Predeterminado | Rango permitido |
| --- | ---: | ---: |
| `EXAM_CANDIDATE_STARTS_PER_BLOCK` | 4 | 1–8 |
| `EXAM_MAX_CANDIDATES_PER_START` | 80 | 20–80 |
| `EXAM_RECENT_QUESTION_LIMIT` | 200 | 1–200 |

`firestore.rules`, `storage.rules`, `firestore.indexes.json`, `firebase.json`,
`functions/src/config.ts` y `.env.example` permanecen versionados. Los dos
índices de selección por parte añaden el contexto académico y su variante con
`sourceType`; están declarados para test, staging y producción. Este repositorio
no despliega ninguno de esos artefactos.

## Protocolo de medición antes de producción

1. Cargar en staging un banco sintético representativo, sin datos reales.
2. Ejecutar lotes de creación de 10 y 15 preguntas para cada política y
   distribución de plantilla, incluyendo banco justo e insuficiente.
3. Agregar `durationMs`, lecturas, consultas, documentos devueltos y reintentos
   por evento; revisar p50/p95/p99 y errores estructurados.
4. Confirmar con el panel de uso/facturación de Firebase para el proyecto de
   staging. No extrapolar métricas del emulador a costos de producción.
