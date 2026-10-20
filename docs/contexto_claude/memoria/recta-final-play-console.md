---
name: recta-final-play-console
description: Recordar a Kevin en la recta final antes de enviar a Play Console los pasos pospuestos (App Check en Firebase)
metadata:
  node_type: memory
  type: project
  originSessionId: 45340872-5a5a-44b2-be34-077f4125e6ff
  modified: 2026-10-16T16:38:46.995Z
---

Kevin pidió (2026-10-16) dejar de lado por ahora la activación de App Check en Firebase y que se lo **recuerde en la recta final, cuando estemos preparando la versión para Play Console**.

Pendiente a recordar entonces (detalle en `iya-app/docs/app_check.md`):
1. Activar la «Firebase App Check API» en el proyecto (hoy apagada).
2. Registrar las apps Android con Play Integrity (SHA-256 de la firma de Play Console).
3. Registrar los tokens de depuración de los teléfonos de prueba.
4. Mirar métricas unos días y luego exigirlo: `FUNCTIONS_ENFORCE_APP_CHECK=true` + Firestore «Enforce».

La app ya activa App Check al arrancar (PR app #93). Es gratis para Android (Play Integrity 10.000/día).

**Why:** Kevin no quiere tocar la configuración de Firebase todavía.
**How to apply:** cuando se hable de publicar, release, Play Console o pasar a producción, sacar esta lista antes de dar el visto bueno. Relacionado: [[sin-produccion-aun]].
