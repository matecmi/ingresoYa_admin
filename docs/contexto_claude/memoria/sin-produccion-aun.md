---
name: sin-produccion-aun
description: IngresoYa aún no tiene producción; todo se despliega solo en test y nada se fusiona a main hasta publicar en Play Console
metadata:
  node_type: memory
  type: project
  originSessionId: 22abdff5-6fc0-4b71-a250-e5b88c2f32e2
  modified: 2026-10-06T13:14:31.041Z
---

IngresoYa (admin + app) sigue en desarrollo/test (estado al 2026-10-06). No existe proyecto ni entorno de producción todavía.

- Desplegar solo en test (`ingresoya-e5115`, `INGRESOYA_ENV=test`).
- No abrir ni fusionar nada hacia `main`.
- Cuando se publique en Play Console: entonces se configura `INGRESOYA_ENV=production`, se crea el entorno de producción y se hace el release `desarrollo` → `main`.

**Why:** Kevin lo indicó explícitamente: "aun no estamos en produccion... no fusiones nada a main... cuando ya hagamos el despliegue a play console hay migraremos a main".
**How to apply:** No proponer ni ejecutar despliegues a producción ni PRs a `main` hasta que Kevin anuncie la publicación en Play Console. Fecha de Node 20 (2026-10-30) solo afecta a test por ahora. Ver [[progreso-docs-sync]].
