---
name: historial-propuestas
description: «Tu progreso e historial» 3 + 2 implementado y fusionado 2026-10-19 (admin #113, app #129); totales en simulatorSummary.totals; pendiente admin «Salud del contenido»
metadata:
  type: project
---

Lienzo: https://claude.ai/artifact/1EWCP88CmP5aEmuVk1ErtZ (capturas reales + 5 propuestas: 1 resumen exacto y últimos 10, 2 tendencia, 3 qué hacer ahora, 4 por tipo de examen, 5 semana y racha). Pantalla actual: `iya-app/lib/features/simulator/presentation/pages/history/simulator_history_screen.dart` (lista no tocable).

Decidido con Kevin: se sigue guardando todo como hoy (simulatorResults, recentResults 200 en el resumen); solo se MUESTRAN los últimos 10 (ajuste nuevo del admin «Exámenes en el historial», 5–30, 10 de fábrica). Hay que agregar totales acumulados en `simulatorSummary/current` (la tarjeta «Tus simulacros» y Stats hoy suman solo la lista → incompletos con >60 exámenes); migración con consulta de suma. Corregir la descripción de «Resultados que baja la app» (ya no cuesta lecturas). Kevin eligió 3 + 2 (fila «Elegida: 3 + 2» del lienzo: C1 al abrir con búho + gráfico de 10 + último examen + 3 temas; C2 al bajar con totales + historial de 10 con filtros). Implementado y fusionado en desarrollo el 2026-10-19 (admin #113, app #129; Functions en TEST; validado en el teléfono). Los totales del servidor se crean en el primer envío de cada alumno; hasta entonces la app suma lo bajado. «Salud del contenido» del admin: Kevin aprobó las propuestas 1 + 2 el 2026-10-19; implementadas en la rama codex/salud-contenido (reporte en iya-admin-reports, callable refreshContentHealth, índice con partes).

**Why:** Kevin pidió mostrar solo lo útil sin romper otras funciones.
**How to apply:** al implementar, cada examen abre su revisión (1 lectura al tocar); parámetros en el admin ([[parametros-en-admin]]); pantallas iguales a la app ([[pantallas-app-identicas]]); guías ([[guias-vivas]]).
