---
name: telefono-solo-con-permiso
description: Kevin usa su teléfono personal para las pruebas; antes de tocarlo por adb comprobar qué app está al frente y parar si no es IngresoYa
metadata:
  node_type: memory
  type: feedback
  originSessionId: 040734b8-b867-4e16-8b29-ba048341054a
  modified: 2026-10-19T22:38:17.133Z
---

El teléfono de pruebas es el teléfono personal de Kevin (WhatsApp, Outlook, llamadas de trabajo). El 2026-10-19 dos tandas de toques por adb cayeron fuera de la app: una abrió la cortina de notificaciones y un chat de WhatsApp, y otra cayó sobre una videollamada en curso.

**Why:** los toques a ciegas por coordenadas pueden marcar mensajes como leídos o tocar controles de una llamada real.

**How to apply:** antes de cada tanda de toques, comprobar con `adb shell dumpsys window | grep mCurrentFocus` que el foco es `com.ingresoya.app.dev`; si no lo es, no tocar nada y avisar a Kevin. Hacer tandas cortas y verificar el foco entre pasos; no usar la tecla atrás a ciegas. Ver [[herramientas-cli-entorno]].
