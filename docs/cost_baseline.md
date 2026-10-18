# Línea base de costos y medición por fase

Plan de ejecución: https://claude.ai/code/artifact/9593d89b-8959-4507-826c-300792dd21c0 ·
Análisis de costos (18-oct-2026): https://claude.ai/code/artifact/67c4d360-d8ac-48d3-9b94-7796330b092f

Este documento guarda **lo medido**, no lo estimado. Cada subfase de la
reestructuración de costos se cierra cuando la medición de aquí baja respecto de
la línea base, no cuando su PR se fusiona.

## Qué se mide y con qué

| Dato | Fuente | Cómo |
| --- | --- | --- |
| Lecturas, escrituras y borrados de Firestore por día | Consola de Firebase → Uso y facturación → Firestore | Captura diaria a la misma hora |
| Invocaciones y tiempo de Functions | Consola → Functions → Uso, o Cloud Monitoring | Captura diaria |
| Egreso de Storage (imágenes) | Consola → Storage → Uso | Captura diaria; requiere Storage activo en TEST |
| Lecturas, escrituras y duración **por operación del servidor** | `node tools/cost_report.js --days 3 --sessions N` desde `functions/` | Agrega la telemetría de las Functions (`observedDocumentReads`, `plannedDocumentWrites`, `durationMs`) por evento. Requiere `gcloud auth login` una vez |
| Lecturas **de la app** (listeners, rankings, catálogo) | Diferencia entre el total de Firestore y lo que reporta `cost_report.js` | Se calcula al final de cada ventana |

`cost_report.js` no es la factura: Firestore puede cobrar lecturas de índices y
reintentos que el contador no ve. Sirve para comparar antes y después.

## Sesión típica (guion para cada cuenta de prueba)

Hacerla una vez al día por cuenta, de corrido, unos 20 minutos:

1. Abrir la app en frío (cerrarla del todo antes). Mirar el Inicio: noticias, historias, pendiente.
2. Entrar a Guía de estudio → un curso → un subtema. Revisar las 5 secciones (video, lección, ejemplos, repaso, recursos).
3. Hacer el Repaso relámpago completo.
4. Rendir el examen de la parte (10 preguntas) y verlo calificado.
5. Ir a Simulador y hacer el reto del día (o «Hoy te toca» si el reto ya se hizo).
6. Abrir Rankings (universidad y carrera) y Perfil.
7. Cerrar la app.

Anotar la hora de inicio y fin de cada sesión para delimitar la ventana de
`cost_report.js` con `--since` y `--until`.

## Línea base (antes de la Fase 1)

Ventana: _pendiente_ · Cuentas: 2 · Sesiones por día: 2

| Día | Lecturas Firestore | Escrituras | Borrados | Invocaciones | Egreso Storage (MB) | Sesiones | Lecturas / sesión | Escrituras / sesión | Invocaciones / sesión |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | | | | | | 2 | | | |
| 2 | | | | | | 2 | | | |
| 3 | | | | | | 2 | | | |
| **Promedio** | | | | | | | | | |

Salida de `cost_report.js` para la misma ventana (pegar la tabla):

_pendiente_

Estimación de partida del análisis del 18-oct-2026, para contrastar: 900
lecturas, 110 escrituras, 40 invocaciones y 6 MB de egreso por sesión típica;
`createExamAttempt` con `durationMs` p50 ≈ 800 ms.

## Resultados por subfase

Se agrega una fila al cerrar cada subfase, con la misma sesión típica.

| Subfase | Fecha | Lecturas / sesión (app + servidor) | Escrituras / sesión | Invocaciones / sesión | Egreso / sesión (MB) | `createExamAttempt` p50 (ms) | Lecturas p50 de `exam_attempt_create_completed` | Cierra |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Línea base | | | | | | | | — |
| 1A | | | | | | | | p50 < 600 ms y lecturas de examen −40 % |
| 2A | | | | | | | | < 10 lecturas de catálogo en segunda apertura |
| 2C | | | | | | | | < 90 lecturas desde la app |
| 3A | | | | | | | | ≤ 5 invocaciones por examen de 10 |
| 3C | | | | | | | | create ≤ 80 lecturas; plan ≤ 150; reto ≤ 30 |
| 2B | | | | | | | | 1 lectura de configuración por arranque |
| 2D | | | | | | | | < 2 MB de egreso por sesión |
| 3B | | | | | | | | sección ≤ 6 lecturas; submit ≤ n + 8 |
| 4A | | | | | | | | índices de `attempts` bajan; sin listener de temas |
| 4B | | | | | | | | pruebas en verde; liga sintética cierra a tiempo |
| Cierre | | | | | | | | < 300 lecturas, 60 escrituras, 20 invocaciones, 1.5 MB |

## Alertas de presupuesto

Proyecto TEST `ingresoya-e5115`: presupuesto de $10 al mes con avisos al 50 %,
90 % y 100 % al correo del propietario. Producción (cuando exista): $50.
