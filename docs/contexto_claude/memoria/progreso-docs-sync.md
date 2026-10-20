---
name: progreso-docs-sync
description: Siempre (sin preguntar) mantener CLAUDE.md y PROGRESO.md en ingresoya_admin e iya-app y actualizarlos en cada desarrollo/commit/PR
metadata:
  node_type: memory
  type: feedback
  originSessionId: d1c0097b-87f3-4861-a14d-4ba9a9448dfa
  modified: 2026-10-06T01:46:09.519Z
---

Proceso obligatorio y automático: si faltan `CLAUDE.md`/`PROGRESO.md` en un proyecto, crearlos. En cada desarrollo, commit o PR en `ingresoya_admin` o `iya-app`, actualizar `PROGRESO.md` (y `CLAUDE.md` si aplica) en los dos proyectos e incluirlo en el commit/PR. Nunca preguntar antes.

**Why:** Kevin trabaja desde varias máquinas y quiere retomar el trabajo donde quedó vía git, sin depender del historial local de Claude. Pidió explícitamente que sea un proceso fijo, no a pedido.
**How to apply:** Antes de cerrar un commit/PR, editar PROGRESO.md en ambos repos (hecho, pendiente, siguiente paso). Al iniciar sesión, leer PROGRESO.md. Regla también en ~/.claude/CLAUDE.md.
