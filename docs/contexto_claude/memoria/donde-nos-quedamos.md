---
name: donde-nos-quedamos
description: Punto exacto de retomar (2026-10-19 noche) y cómo restaurar el contexto de Claude en otra máquina desde docs/contexto_claude del admin
metadata:
  node_type: memory
  type: project
  originSessionId: 040734b8-b867-4e16-8b29-ba048341054a
  modified: 2026-10-20T01:23:16.882Z
---

Al 2026-10-19 (noche) todo está fusionado en `desarrollo` (último: admin #114, app #130) y desplegado en TEST. Kevin va a cambiar de máquina: el contexto completo (resumen de la sesión, pendientes, copia de estas memorias y de sus preferencias globales) está en `ingresoya_admin/docs/contexto_claude/README.md`.

**Última pregunta abierta:** Kevin preguntó si alguna sección del admin sigue disparando lecturas. Respuesta: dos. «Importar examen pasado», en el paso Clasificar, lee las 1 432 preguntas y las escucha en vivo. «Preguntas a revisar» lee hasta 500 estadísticas. Propuse: (1) un documento compacto por curso con el texto corto de las preguntas clasificadas, unos 18 documentos en vez de 1 432; (2) tope de 100 con «Ver más», o que el servidor guarde ya filtradas las que superan los umbrales. **Kevin aún no aprobó ninguna.**

**Why:** Kevin quiere que una terminal nueva sepa exactamente dónde quedamos.
**How to apply:** en una sesión nueva, leer `docs/contexto_claude/README.md` y los `PROGRESO.md`; si la memoria local está vacía, copiar `docs/contexto_claude/memoria/*` a la carpeta de memoria del proyecto. Ver [[progreso-docs-sync]] y [[analisis-costos-firebase]].
